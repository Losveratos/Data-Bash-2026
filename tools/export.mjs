// Prüft das Deck und exportiert PDF und Folienbilder.
// Aufruf: node tools/export.mjs [de|en|both] [--shots]
// Playwright: global installiert (%APPDATA%\npm\node_modules\playwright) oder per PW_PATH.
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const pw = process.env.PW_PATH || path.join(process.env.APPDATA || '', 'npm/node_modules/playwright');
const { chromium } = require(pw);

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const arg = process.argv[2] || 'both';
const shots = process.argv.includes('--shots');
const langs = arg === 'both' ? ['de', 'en'] : [arg];
const url = l => pathToFileURL(path.join(root, 'index.html')).href + '?lang=' + l;

const browser = await chromium.launch();
let problems = 0;
for (const lang of langs) {
  const ctx = await browser.newContext({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  const errs = [];
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errs.push(m.type() + ': ' + m.text()); });
  page.on('pageerror', e => errs.push('pageerror: ' + e));
  page.on('requestfailed', r => errs.push('requestfailed: ' + r.url()));
  page.on('request', r => { if (!r.url().startsWith('file:') && !r.url().startsWith('data:')) errs.push('external request: ' + r.url()); });
  await page.goto(url(lang), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const n = await page.evaluate(() => window.deckState().count);
  // overflow check: content wider/taller than the slide, images not loaded
  const issues = await page.evaluate(() => {
    const out = [];
    document.querySelectorAll('#stage>.slide').forEach((s, i) => {
      s.classList.add('on'); s.style.display = 'flex';
      s.querySelectorAll('img').forEach(im => { if (!im.complete || im.naturalWidth === 0) out.push(`slide ${i + 1}: image missing ${im.getAttribute('src')}`); });
      const sr = s.getBoundingClientRect();
      s.querySelectorAll('h1,h2,p,li,.card,.fig,table,pre,.cmd,.wave,.num').forEach(e => {
        if (e.offsetParent === null) return;
        const r = e.getBoundingClientRect();
        if (r.bottom > sr.bottom + 1 || r.right > sr.right + 1) out.push(`slide ${i + 1}: overflow ${e.tagName}.${e.className} "${(e.textContent || '').trim().slice(0, 40)}"`);
        if (e.scrollHeight > e.clientHeight + 2 && getComputedStyle(e).overflow === 'hidden') out.push(`slide ${i + 1}: clipped ${e.tagName}.${e.className}`);
      });
      s.style.display = ''; if (i) s.classList.remove('on');
    });
    return out;
  });
  if (shots) {
    const dir = path.join(root, 'export', 'shots-' + lang); fs.mkdirSync(dir, { recursive: true });
    for (let i = 0; i < n; i++) {
      await page.evaluate(i => window.deckShow(i), i); await page.waitForTimeout(120);
      await page.screenshot({ path: path.join(dir, String(i + 1).padStart(2, '0') + '.png') });
    }
  }
  await page.emulateMedia({ media: 'print' });
  const pdf = path.join(root, 'export', `Data-Bash-2026-IBCS-Fabric-Apps-${lang.toUpperCase()}.pdf`);
  await page.pdf({ path: pdf, width: '1920px', height: '1080px', printBackground: true, preferCSSPageSize: true });
  console.log(`[${lang}] ${n} Folien · PDF ${path.basename(pdf)} · Konsole ${errs.length} · Layout ${issues.length}`);
  [...errs, ...issues].forEach(x => console.log('   ' + x));
  problems += errs.length + issues.length;
  await ctx.close();
}
await browser.close();
process.exit(problems ? 1 : 0);
