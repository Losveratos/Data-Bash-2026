// Feinschliff der Demo-Spec: dieselben Handgriffe, die man sonst im Editor in der JSON macht.
// Formatbereich-Einstellungen stehen in der Spec genau so wie im Power-BI-Formatbereich (objects).
//
//   node feinschliff.mjs <spec.json>
import fs from "node:fs";

const file = process.argv[2];
if (!file) { console.error("Aufruf: node feinschliff.mjs <spec.json>"); process.exit(1); }
const spec = JSON.parse(fs.readFileSync(file, "utf8"));
const page = spec.pages.find(p => p.id === "uberblick") ?? spec.pages[0];
const tile = id => {
    const t = page.tiles.find(x => x.id === id);
    if (!t) { console.error(`Kachel ${id} fehlt in ${file}`); process.exit(1); }
    return t;
};
const set = (t, obj, key, value) => {
    t.objects ??= {};
    t.objects[obj] ??= {};
    console.log(`  ${t.id.padEnd(5)} objects.${obj}.${key} = ${JSON.stringify(value)}`);
    t.objects[obj][key] = value;
};

// GuV: in Mio. EUR wie im Power-BI-Formatbereich (Zahlen, Skalierung), Titelblock mit Zeitraum
const pnl = tile("t04b");
set(pnl, "numbers", "scaling", "m");
set(pnl, "titleBlock", "measureLine", "GuV in Mio. EUR, Abweichung zum Plan als Wasserfall");
set(pnl, "titleBlock", "periodLine", "Jan..Aug 2026 (YTD), AC gegen PL");

// Small Multiples: Kanäle in der Reihenfolge des Modells (Sortierspalte), wie Power BI sie zeigt
const sm = tile("c13");
sm.sortBy ??= {};
sm.sortBy["'Kunde'[Kanal]"] = "'Kunde'[Kanal Sort]";
console.log(`  c13   sortBy 'Kunde'[Kanal] = 'Kunde'[Kanal Sort]`);

fs.writeFileSync(file, JSON.stringify(spec, null, 2) + "\n");
console.log(`${file}: Feinschliff geschrieben.`);
