// The seven phases of the party, in order. `id` is what games.phase stores.
// `player` is the hint shown on guests' phones; `script` is the host's stage
// direction shown only in the host view.
export const PHASES = [
  {
    id: 'velkommen',
    label: 'Velkommen',
    player: 'Finn deg noe å drikke og hold deg i nærheten — verten tar snart ordet.',
    script: 'Ønsk gjestene velkommen mens alle blir med i appen. Når alle er inne: les åstedsrapporten (introduksjonen) høyt — et lik er nettopp funnet.',
  },
  {
    id: 'roller',
    label: 'Rollene deles ut',
    player: 'Du får snart utdelt rollen din. Les kortet i stillhet — og ikke vis NOEN hemmeligheten din!',
    script: 'Del ut roller under «Spillere» (eller trykk «Del ut automatisk»). Be alle lese rollekortet sitt i stillhet. Ingen skal vise skjermen sin til andre.',
  },
  {
    id: 'mingling',
    label: 'Etterforskningen',
    player: 'Etterforskningen er i gang! Forhør de andre gjestene. Du må svare på spørsmål, men du velger selv hvor mye du røper — bare ikke lyv om det som står under «Dette vet alle».',
    script: 'Slipp gjestene løs på hverandre i 15–20 minutter. Alle skal snakke med minst tre andre. Minn dem på: hemmeligheten er hemmelig, men de offentlige opplysningene kan ikke benektes.',
  },
  {
    id: 'ledetraader',
    label: 'Ledetrådene',
    player: 'Verten legger fram bevis fra åstedet. Følg med på polaroidene som dukker opp nedenfor.',
    script: 'Samle alle. Avslør polaroidene ett og ett under «Polaroider», og les hvert av dem høyt med passe dramatikk. Slipp gjerne løs litt diskusjon mellom hvert bevis.',
  },
  {
    id: 'forhor',
    label: 'Forhøret',
    player: 'Alle mistenkte leser alibiet sitt høyt. Lytt etter sprekker — hvem husker litt for godt, og hvem husker litt for dårlig?',
    script: 'La hver mistenkt lese alibiet sitt høyt etter tur (det står på rollekortet deres). Åpne for spørsmål fra salen etter hvert alibi.',
  },
  {
    id: 'avstemning',
    label: 'Siste mistanke',
    player: 'Siste sjanse! Sett tre luper på den du tror er morderen — det teller som stemmen din.',
    script: 'Be alle sette sin endelige mistanke i appen: tre luper på hovedmistenkten. Følg med på «Mistanker» i Avsløring-fanen mens stemmene tikker inn.',
  },
  {
    id: 'avsloring',
    label: 'Avsløringen',
    player: 'Sannhetens øyeblikk …',
    script: 'Les gjerne opp hvem festen mistenker mest. Når dere er klare: trykk på den røde knappen, og les oppklaringen høyt — med innlevelse.',
  },
]

export function phaseIndex(id) {
  const i = PHASES.findIndex((p) => p.id === id)
  return i === -1 ? 0 : i
}

export function phaseLabel(id) {
  const p = PHASES.find((p) => p.id === id)
  return p ? p.label : id
}
