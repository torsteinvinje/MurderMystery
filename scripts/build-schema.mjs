// Generates supabase-schema.sql from supabase/migrations/.
//
// WHY THIS EXISTS
// The canonical schema used to be assembled by hand: every migration had to be
// copied into it as well as written as a numbered file. That is two places to
// keep in step, and they drifted — the file grew to ~4800 lines containing the
// same function defined five times, with no way for a reader to tell which
// definition won.
//
// Now the file is derived: it is the migrations replayed in order, which is
// exactly what an upgraded database has had applied. That makes a fresh
// install and an upgraded install provably identical, and removes the manual
// sync step (CI fails if the two disagree).
//
// Later definitions of a function deliberately supersede earlier ones — that
// is how migrations work. To spare readers from tracing 5000 lines to find the
// authoritative version, the generated header carries an index naming the file
// each function's FINAL definition comes from.
//
// Run with:  npm run schema:build
import { readFile, readdir, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const migrationsDir = join(root, 'supabase', 'migrations')
const outFile = join(root, 'supabase-schema.sql')

const files = (await readdir(migrationsDir))
  .filter((f) => f.endsWith('.sql') && !f.endsWith('_down.sql'))
  .sort() // zero-padded numeric prefixes make lexical order the right order

// Track where each function is last defined, so the header can point at it.
const finalDefinition = new Map() // function name -> migration file
const parts = []

for (const file of files) {
  const sql = await readFile(join(migrationsDir, file), 'utf8')

  for (const match of sql.matchAll(/^create or replace function\s+(\w+)\s*\(/gim)) {
    finalDefinition.set(match[1], file)
  }

  parts.push(
    `-- ${'='.repeat(74)}\n` +
    `-- ▼ ${file}\n` +
    `-- ${'='.repeat(74)}\n\n` +
    sql.trimEnd() + '\n'
  )
}

// Public functions first (what a reader is usually looking for), then internal.
const names = [...finalDefinition.keys()].sort()
const publicFns = names.filter((n) => !n.startsWith('_'))
const internalFns = names.filter((n) => n.startsWith('_'))
const indexLine = (n) => `--   ${n.padEnd(38)} ${finalDefinition.get(n)}`

const header = `-- ${'='.repeat(74)}
-- MURDERMYSTERY — KOMPLETT DATABASESKJEMA
--
-- ⚠️  GENERERT FIL — IKKE REDIGER DIREKTE.
--     Lag en ny migrasjon i supabase/migrations/ og kjør: npm run schema:build
--     (CI feiler hvis denne fila ikke er i takt med migrasjonene.)
--
-- HVA DETTE ER
--   Alle migrasjonene i supabase/migrations/ satt sammen i rekkefølge —
--   nøyaktig det en oppdatert database har fått kjørt. Kjør hele fila på en
--   fersk database, så får du samme resultat som en som har fulgt
--   migrasjonene fra dag én.
--
-- HVORDAN LESE DEN
--   Fila kjøres ovenfra og ned, og SENERE definisjoner av samme funksjon
--   ERSTATTER tidligere. Noen funksjoner står derfor flere ganger; det er
--   migrasjonshistorikken, ikke en feil. Indeksen under sier hvilken fil den
--   gjeldende versjonen av hver funksjon kommer fra.
--
-- SIKKERHETSMODELLEN (kortversjonen)
--   • RLS er PÅ for alle tabeller, UTEN policies. Klienten når aldri en
--     tabell direkte.
--   • All tilgang går via SECURITY DEFINER-funksjoner som validerer et
--     hemmelig token og returnerer kun det den kalleren har krav på.
--   • Morderen (is_killer) og oppklaringen (resolution) forlater aldri
--     databasen til en spiller før verten har avslørt — eneste vei ut er
--     get_reveal, som krever spillstatus 'revealed'.
--
-- Generert fra ${files.length} migrasjoner: ${files[0]} … ${files[files.length - 1]}
-- ${'='.repeat(74)}
--
-- INDEKS — gjeldende definisjon av hver funksjon:
--
-- OFFENTLIGE (kallbare via RPC):
${publicFns.map(indexLine).join('\n')}
--
-- INTERNE (execute trukket tilbake fra anon/authenticated):
${internalFns.map(indexLine).join('\n')}
--
-- ${'='.repeat(74)}

`

await writeFile(outFile, header + parts.join('\n'), 'utf8')

console.log(`supabase-schema.sql regenerated from ${files.length} migrations`)
console.log(`  ${publicFns.length} public functions, ${internalFns.length} internal`)
