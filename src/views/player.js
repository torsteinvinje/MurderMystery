// Player view: join the party with a code, get a role card, mark suspicion,
// follow the polaroids, and see the reveal when the host opens the vault.
// Everything sensitive stays in the database — this file only ever sees what
// the RPCs are willing to hand a player.

import '../styles/main.css'
import { rpc } from '../lib/supabase.js'
import { watchGame } from '../lib/realtime.js'
import { esc, escMultiline } from '../lib/util.js'
import { icon, I } from '../lib/icons.js'
import { hero } from '../lib/hero.js'
import heroJoin from '../assets/mood/study.webp'
import { PHASES, phaseIndex, phaseLabel } from '../lib/phases.js'
import { loadPlayer, savePlayer, clearPlayer } from '../lib/tokens.js'

const app = document.querySelector('#app')

// All screen state lives here; render() redraws everything from it.
const state = {
  screen: 'loading', // 'loading' | 'join' | 'game'
  error: '',
  joining: false,
  me: null, // result of get_my_player: { player, game, suspect }
  suspects: [],
  polaroids: [],
  suspicions: new Map(), // suspect_id -> level (0–3)
  reveal: null,
  secretShown: false,
}

let stopWatching = null

const token = () => loadPlayer()?.player_token ?? null

init()

async function init() {
  if (!token()) {
    state.screen = 'join'
    render()
    return
  }
  try {
    await refresh()
    startWatching()
    state.screen = 'game'
  } catch {
    // The saved token no longer matches a player (game deleted, storage from
    // an old party, ...) — forget it and show the join screen.
    clearPlayer()
    state.screen = 'join'
  }
  render()
}

function startWatching() {
  if (stopWatching) stopWatching()
  const gameId = state.me?.game?.id
  if (!gameId) return
  stopWatching = watchGame(gameId, () => refresh().catch(() => {}))
}

// Re-fetch everything through the RPCs. Cheap at party scale, and it means
// realtime only ever has to say "something changed".
async function refresh() {
  const t = token()
  if (!t) return

  const me = await rpc('get_my_player', { p_player_token: t })
  const [suspects, polaroids, mySuspicions] = await Promise.all([
    rpc('get_public_suspects', { p_player_token: t }),
    rpc('get_public_polaroids', { p_player_token: t }),
    rpc('get_my_suspicions', { p_player_token: t }),
  ])

  state.me = me
  state.suspects = suspects
  state.polaroids = polaroids
  state.suspicions = new Map(mySuspicions.map((s) => [s.suspect_id, s.level]))

  // Only ask for the solution once the host has opened the vault; before
  // that the database refuses (and must keep refusing).
  if (me.game.status === 'revealed' && !state.reveal) {
    try {
      state.reveal = await rpc('get_reveal', { p_player_token: t })
    } catch {
      /* not ready yet */
    }
  }

  render()
}

// --------------------------------------------------------------------------
// Actions
// --------------------------------------------------------------------------

async function onJoin(event) {
  event.preventDefault()
  const form = event.target
  const code = form.elements.code.value
  const name = form.elements.name.value

  state.joining = true
  state.error = ''
  render()

  try {
    const joined = await rpc('join_game', { p_code: code, p_name: name })
    savePlayer({ player_token: joined.player_token, game_id: joined.game_id })
    await refresh()
    startWatching()
    state.screen = 'game'
  } catch (err) {
    state.error = err.message
  }
  state.joining = false
  render()
}

// Tap the magnifier button: cycle suspicion 0 → 1 → 2 → 3 → 0.
async function cycleSuspicion(suspectId) {
  const current = state.suspicions.get(suspectId) ?? 0
  const next = (current + 1) % 4
  state.suspicions.set(suspectId, next) // optimistic — feels instant at the party
  render()
  try {
    await rpc('set_suspicion', { p_player_token: token(), p_suspect_id: suspectId, p_level: next })
  } catch {
    state.suspicions.set(suspectId, current) // roll back if the write failed
    render()
  }
}

function leaveGame() {
  if (!confirm('Forlate festen? Du mister rollen din på denne telefonen.')) return
  if (stopWatching) stopWatching()
  clearPlayer()
  location.reload()
}

// --------------------------------------------------------------------------
// Rendering
// --------------------------------------------------------------------------

function render() {
  if (state.screen === 'loading') {
    app.innerHTML = `<div class="sheet"><p class="notice">Blar i saksmappa …</p></div>`
  } else if (state.screen === 'join') {
    renderJoin()
  } else {
    renderGame()
  }
}

function renderJoin() {
  app.innerHTML = `
    <div class="sheet">
      ${hero({
        image: heroJoin,
        context: 'Strengt fortrolig',
        title: 'Bli med på mysteriet',
        lede: 'Tast inn festkoden, så får du rollekort, hemmelighet og alibi rett på telefonen.',
      })}

      ${state.error ? `<p class="error">${icon(I.error, { lead: true })}${esc(state.error)}</p>` : ''}

      <form id="join-form">
        <label for="join-code">${icon(I.code, { lead: true })}Festkode</label>
        <input id="join-code" name="code" maxlength="4" autocapitalize="characters"
               autocomplete="off" spellcheck="false" required placeholder="F.eks. KX7M" />
        <label for="join-name">Navnet ditt</label>
        <input id="join-name" name="name" maxlength="40" required placeholder="Slik de andre gjestene kjenner deg" />
        <button ${state.joining ? 'disabled' : ''}>${state.joining ? 'Åpner saksmappa …' : `${icon(I.join, { lead: true })}Bli med på festen`}</button>
      </form>

      <footer class="app-footer">
        <span>Er du verten? <a href="/host.html">${icon(I.host, { lead: true })}Til vertskontrollen</a></span>
      </footer>
    </div>`

  app.querySelector('#join-form').addEventListener('submit', onJoin)
}

function renderGame() {
  const { player, game, suspect } = state.me
  const idx = phaseIndex(game.phase)
  const phase = PHASES[idx]

  const parts = []

  parts.push(`
    <header class="case-header">
      <div class="case-no">
        <span class="brand">${icon(I.brand, { lead: true })}MurderMystery · ${esc(game.code)}</span>
        <span>${esc(player.display_name)}</span>
      </div>
      <h1>${esc(game.title)}</h1>
      <span class="badge${game.status === 'revealed' ? ' red' : ''}">${esc(phaseLabel(game.phase))}</span>
    </header>`)

  // What the guest should be doing right now.
  parts.push(`
    <div class="phase-hint">
      <p class="kicker">Nå skjer det:</p>
      <p>${esc(phase.player)}</p>
    </div>`)

  // The intro is the whole backstory — always available for re-reading.
  if (idx === 0) {
    parts.push(`<div class="card"><p class="kicker">Åstedsrapport</p><p>${escMultiline(game.intro)}</p></div>`)
  } else {
    parts.push(`
      <details class="editor">
        <summary>Les åstedsrapporten på nytt</summary>
        <div class="card"><p>${escMultiline(game.intro)}</p></div>
      </details>`)
  }

  // The reveal trumps everything else on screen.
  if (state.reveal) {
    parts.push(renderReveal())
  }

  // Role card, once roles are being handed out.
  if (idx >= phaseIndex('roller')) {
    parts.push(renderRoleCard(suspect))
  }

  // Polaroid evidence, as soon as the host has revealed any.
  if (state.polaroids.length > 0 && !state.reveal) {
    parts.push(`<h2>${icon(I.evidence, { lead: true })}Bevis fra åstedet</h2>`)
    parts.push(state.polaroids.map(renderPolaroid).join(''))
  }

  // The suspect list with magnifier marks, once mingling has started.
  if (idx >= phaseIndex('mingling') && !state.reveal) {
    parts.push(renderSuspectList())
  }

  parts.push(`
    <footer class="app-footer">
      <span>MurderMystery</span>
      <a href="#" id="leave-link">${icon(I.leave, { lead: true })}Forlat festen</a>
    </footer>`)

  app.innerHTML = `<div class="sheet">${parts.join('')}</div>`

  app.querySelector('#leave-link').addEventListener('click', (e) => {
    e.preventDefault()
    leaveGame()
  })
  const secretBtn = app.querySelector('#secret-toggle')
  if (secretBtn) {
    secretBtn.addEventListener('click', () => {
      state.secretShown = !state.secretShown
      render()
    })
  }
  app.querySelectorAll('[data-suspect]').forEach((btn) => {
    btn.addEventListener('click', () => cycleSuspicion(btn.dataset.suspect))
  })
}

function renderRoleCard(suspect) {
  if (!suspect) {
    return `
      <div class="card">
        <p class="kicker">${icon(I.role, { lead: true })}Din rolle</p>
        <h3>Etterforsker</h3>
        <p>Du har ingen hemmeligheter — du er vertens høyre hånd. Forhør de
        mistenkte, sammenlign alibier og hjelp festen med å avsløre morderen.</p>
      </div>`
  }
  return `
    <div class="card">
      <p class="kicker">${icon(I.role, { lead: true })}Din rolle — vis den ikke til noen</p>
      <h3>${esc(suspect.name)}</h3>
      <p class="lede">${esc(suspect.tagline)}</p>
      <p><strong>Dette vet alle:</strong> ${escMultiline(suspect.public_info)}</p>
      <div class="secret-box">
        <button id="secret-toggle" class="btn-quiet">
          ${state.secretShown
            ? `${icon(I.unlocked, { lead: true })}Skjul hemmeligheten`
            : `${icon(I.locked, { lead: true })}Vis hemmeligheten din (se deg rundt først)`}
        </button>
        ${state.secretShown ? `<div class="secret-content"><strong>Din hemmelighet:</strong> ${escMultiline(suspect.secret)}</div>` : ''}
      </div>
      <p><strong>Ditt alibi</strong> (les det høyt under forhøret):</p>
      <div class="alibi">«${escMultiline(suspect.alibi)}»</div>
    </div>`
}

function renderPolaroid(polaroid) {
  return `
    <div class="polaroid">
      ${
        polaroid.image_url
          ? `<img src="${esc(polaroid.image_url)}" alt="${esc(polaroid.title)}" />`
          : `<div class="photo-area">${icon(I.evidence, { lead: true })}Bevisfoto</div>`
      }
      <div class="caption">
        <p class="p-title">${esc(polaroid.title)}</p>
        <p>${escMultiline(polaroid.caption)}</p>
      </div>
    </div>`
}

const LUPE_LABELS = ['Ingen mistanke', 'Litt skummel', 'Mistenkelig', 'HOVEDMISTENKT']

function renderSuspectList() {
  const myId = state.me.suspect?.id
  const rows = state.suspects
    .map((s) => {
      const level = state.suspicions.get(s.id) ?? 0
      const isMe = s.id === myId
      return `
        <div class="suspect-row">
          <div class="who">
            <strong>${esc(s.name)}</strong>${isMe ? ' <span class="badge">deg</span>' : ''}
            <div class="tagline">${esc(s.tagline)}</div>
          </div>
          <button class="lupe-btn${level === 3 ? ' max' : ''}" data-suspect="${esc(s.id)}"
                  title="${esc(LUPE_LABELS[level])}" aria-label="${esc(s.name)}: ${esc(LUPE_LABELS[level])}">
            ${level === 0 ? `${icon(I.clue, { lead: true })}Merk` : icon(I.clue).repeat(level)}
          </button>
        </div>`
    })
    .join('')

  return `
    <h2>${icon(I.suspects, { lead: true })}De mistenkte</h2>
    <p class="lede">Trykk på lupene for å justere mistanken din: én = litt skummel,
    to = mistenkelig, tre = hovedmistenkt. Bare du ser dine egne luper.</p>
    ${rows}`
}

function renderReveal() {
  const { killer, resolution } = state.reveal
  return `
    <div class="reveal-card">
      <span class="stamp">${icon(I.reveal, { lead: true })}Sak oppklart</span>
      <p class="kicker">Morderen er …</p>
      <p class="killer-name">${esc(killer.name)}</p>
      <p class="lede">${esc(killer.tagline)}</p>
      <div class="resolution">${escMultiline(resolution)}</div>
    </div>`
}
