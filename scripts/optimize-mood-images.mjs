// One-off asset pipeline: turn the heavy source PNGs in mood-src/ into
// web-sized WebP heroes in src/assets/mood/. Run with:  node scripts/optimize-mood-images.mjs
// Requires the dev dependency `sharp`. The originals (mood-src/) are gitignored;
// only the optimized WebP are committed.
import sharp from 'sharp'
import { mkdir, readdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const srcDir = join(root, 'mood-src')
const outDir = join(root, 'src', 'assets', 'mood')

// Source file (in mood-src) -> short output name (in src/assets/mood).
const MAP = {
  '01_mansion_detective_study_hero.png': 'study',
  '02_candlelit_suspects_parlor.png': 'parlor',
  '03_gothic_mansion_hallway.png': 'hallway',
  '04_detective_clue_desk.png': 'desk',
  '05_suspects_and_empty_chair.png': 'suspects',
}

const WIDTH = 1440 // plenty for a hero banner; keeps files light for phones
const QUALITY = 70

await mkdir(outDir, { recursive: true })
const present = new Set(await readdir(srcDir))

for (const [file, name] of Object.entries(MAP)) {
  if (!present.has(file)) {
    console.warn(`skip: ${file} not found in mood-src/`)
    continue
  }
  const out = join(outDir, `${name}.webp`)
  const info = await sharp(join(srcDir, file))
    .resize({ width: WIDTH, withoutEnlargement: true })
    .webp({ quality: QUALITY })
    .toFile(out)
  console.log(`${name}.webp  ${(info.size / 1024).toFixed(0)} KB  ${info.width}x${info.height}`)
}
