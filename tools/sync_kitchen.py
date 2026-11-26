"""Kopiert das Deck in den Kitchen-Talk talks/databash-2026/ (Fontpfade, Bildpfade, Canonical; der SEO-Block bleibt).
Aufruf: python tools/sync_kitchen.py <Kitchen-Repo-Wurzel>  (vorher export --shots und compact_pdf laufen lassen)"""
import os, re, shutil, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
kitchen = sys.argv[1]
dst = os.path.join(kitchen, 'talks', 'databash-2026')
os.makedirs(os.path.join(dst, 'assets'), exist_ok=True)
target = os.path.join(dst, 'index.html')

s = open(os.path.join(root, 'index.html'), encoding='utf-8').read()
old = open(target, encoding='utf-8').read() if os.path.exists(target) else ''
m = re.search(r'<!--seo-ld:start-->.*?<!--seo-ld:end-->', old, re.S)
seo = m.group(0) if m else '<!--seo-ld:start--><!--seo-ld:end-->'

head = ('<link rel="canonical" href="https://datenwgknowledgekitchen.com/talks/databash-2026/">\n'
        '<meta name="description" content="Folien zum Vortrag A Playbook for Generating IBCS-Inspired Reproducible Fabric Apps '
        'for Controlling and Finance, Data Bash 2026: eine App-Spec, Fabric App und Power BI mit denselben Visuals, '
        'Prüfstand und fabscan. Deutsch und Englisch.">\n' + seo)
s = s.replace('<meta name="robots" content="noindex, nofollow">\n', '')
s = s.replace('href="assets/fonts/', 'href="../../assets/fonts/').replace('src="assets/img/', 'src="assets/')
s = re.sub(r'<meta name="description" content="[^"]*">', lambda _: head, s, count=1)
open(target, 'w', encoding='utf-8', newline='\n').write(s)

used = sorted(set(re.findall(r'src="assets/([^"]+)"', s)))
for f in os.listdir(os.path.join(dst, 'assets')):
    if f not in used:
        os.remove(os.path.join(dst, 'assets', f))
for f in used:
    shutil.copy2(os.path.join(root, 'assets', 'img', f), os.path.join(dst, 'assets', f))
for lang in ('DE', 'EN'):
    src = os.path.join(root, 'export', f'Data-Bash-2026-IBCS-Fabric-Apps-{lang}-web.pdf')
    if os.path.exists(src):
        shutil.copy2(src, os.path.join(dst, f'Fabric-Apps-Playbook-{lang}.pdf'))
print('synced', len(used), 'Bilder')
