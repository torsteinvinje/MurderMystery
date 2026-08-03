// "Kveldens regi" for Skjult agenda — the same idea as the murder mystery's
// src/lib/phases.js: the host moves through the evening one step at a time,
// each step tells the host what to say and do, and every guest's phone shows
// the matching line so nobody has to ask "what's happening now?".
//
// `id` is what saboteur_games.phase stores. The text lives here rather than in
// the database so it can be reworded without a migration.
export const SABOTEUR_PHASES = [
  {
    id: 'lobby',
    label: 'Venter på deltakere',
    player: 'Du er med! Vent på at verten deler ut rollene. Hold telefonen for deg selv.',
    script: 'Del spillkoden. Sjekk at alle står i deltakerlista med riktig navn før du deler ut roller.',
  },
  {
    id: 'roller',
    label: 'Rollene deles ut',
    player: 'Rollen din er klar. Les den i stillhet — og ikke vis skjermen til noen!',
    script: 'Del ut roller (manuelt eller tilfeldig) og start spillet. Si høyt: «Alle ser på sin egen telefon nå — ingen viser skjermen til andre.»',
  },
  {
    id: 'oppdrag',
    label: 'Spillet er i gang',
    player: 'Spillet er i gang. Gjør oppdragene dine — og følg med på de andre.',
    script: 'Festen går som normalt. Del ut mål til Sabotørene og oppgaver til de Lojale, og godkjenn det folk melder inn etter hvert.',
  },
  {
    id: 'avstemning',
    label: 'Avstemning',
    player: 'Nå stemmer vi: hvem tror du er sabotør?',
    script: 'Samle alle. Åpne avstemningen, la folk diskutere høyt først, og lukk den når alle har stemt. Resultatet vises ikke før du avslører det.',
  },
  {
    id: 'avsloring',
    label: 'Avsløringen',
    player: 'Sannhetens øyeblikk …',
    script: 'Avslør avstemningen først, la folk reagere — og trykk så «Avslutt spillet» for å vise alle rollene.',
  },
]

export function saboteurPhaseIndex(id) {
  const i = SABOTEUR_PHASES.findIndex((p) => p.id === id)
  return i === -1 ? 0 : i
}

export function saboteurPhase(id) {
  return SABOTEUR_PHASES[saboteurPhaseIndex(id)]
}
