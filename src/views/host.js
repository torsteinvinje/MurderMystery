// Host view ("lensmannskontoret"): create a game, run the phases, hand out
// roles, reveal polaroids, edit content, and finally reveal the murderer.
// The host is the only browser allowed to see is_killer and the resolution —
// authenticated by the secret host_token the database handed us at creation.

import '../styles/main.css'
import { rpc } from '../lib/supabase.js'
import { watchGame } from '../lib/realtime.js'
import { esc, escMultiline } from '../lib/util.js'
import { PHASES, phaseIndex } from '../lib/phases.js'
import { loadHost, saveHost, clearHost } from '../lib/tokens.js'

const app = document.querySelector('#app')

const state = {
  screen: 'loading', // 'loading' | 'landing' | 'dashboard'
  error: '',
  busy: false,
  tab: 'regi', // 'regi' | 'spillere' | 'mistenkte' | 'polaroider' | 'avsloring'
  game: null,
  players: [],
  suspects: [],
  polaroids: [],
  suspicions: [],
  showSolution: false, // host may be projecting the screen — keep it hidden by default
  confirmReveal: false, // two-tap guard on the big red button
}

let stopWatching = null
let pendingRender = false

const token = () => loadHost()?.host_token ?? null

init()

async function init() {
  if (!token()) {
    state.screen = 'landing'
    render()
    return
  }
  try {
    await refreshAll()
    startWatching()
    state.screen = 'dashboard'
  } catch {
    // Saved token doesn't match a game anymore — back to the landing page.
    clearHost()
    state.screen = 'landing'
  }
  render()
}

function startWatching() {
  if (stopWatching) stopWatching()
  if (!state.game?.id) return
  stopWatching = watchGame(state.game.id, () => refreshAll().catch(() => {}))
}

async function refreshAll() {
  const t = token()
  if (!t) return
  const [game, players, suspects, polaroids, suspicions] = await Promise.all([
    rpc('host_get_game', { p_host_token: t }),
    rpc('host_list_players', { p_host_token: t }),
    rpc('host_get_suspects', { p_host_token: t }),
    rpc('host_get_polaroids', { p_host_token: t }),
    rpc('host_get_suspicions', { p_host_token: t }),
  ])
  Object.assign(state, { game, players, suspects, polaroids, suspicions })
  render()
}

// --------------------------------------------------------------------------
// Actions
// --------------------------------------------------------------------------

async function createGame() {
  state.busy = true
  state.error = ''
  render()
  try {
    const created = await rpc('create_game')
    saveHost({ host_token: created.host_token, game_id: created.game_id, code: created.code })
    await refreshAll()
    startWatching()
    state.screen = 'dashboard'
    state.tab = 'regi'
  } catch (err) {
    state.error = err.message
  }
  state.busy = false
  render()
}

// Small wrapper: run a host RPC, surface errors, let realtime refresh the rest.
async function hostAction(name, params = {}) {
  state.error = ''
  try {
    await rpc(name, { p_host_token: token(), ...params })
    await refreshAll()
  } catch (err) {
    state.error = err.message
    render()
  }
}

async function doReveal() {
  // Point of no return: after this, get_reveal hands every player the killer.
  await hostAction('host_set_status', { p_status: 'revealed' })
  await hostAction('host_set_phase', { p_phase: 'avsloring' })
  state.confirmReveal = false
}

function newGame() {
  if (!confirm('Starte en helt ny fest? Den gamle festkoden slutter å virke på denne enheten (spillet slettes ikke).')) return
  if (stopWatching) stopWatching()
  clearHost()
  state.screen = 'landing'
  state.game = null
  render()
}

// --------------------------------------------------------------------------
// Rendering
// --------------------------------------------------------------------------

// A poke can arrive while the host is typing in an edit form. Instead of
// wiping their text, we hold the redraw until focus leaves the form.
function render() {
  const active = document.activeElement
  if (active && app.contains(active) && active.closest('[data-hold]')) {
    pendingRender = true
    return
  }
  pendingRender = false

  if (state.screen === 'loading') {
    app.innerHTML = `<div class="sheet"><p class="notice">Låser opp lensmannskontoret …</p></div>`
  } else if (state.screen === 'landing') {
    renderLanding()
  } else {
    renderDashboard()
  }
}

app.addEventListener('focusout', () => {
  // Wait a beat so document.activeElement points at the *next* focused element.
  setTimeout(() => {
    const active = document.activeElement
    if (pendingRender && !(active && app.contains(active) && active.closest('[data-hold]'))) {
      render()
    }
  }, 60)
})

function renderLanding() {
  app.innerHTML = `
    <div class="sheet">
      <header class="case-header">
        <div class="case-no"><span>Lensmannskontoret</span><span>Vollan gård</span></div>
        <h1>Ljåmordet på grillfesten</h1>
        <p class="lede">Du er lensmannen. Du styrer kvelden, deler ut roller, legger
        fram bevis — og du er den eneste som vet hvem morderen er.</p>
        <span class="stamp">Kun for lensmannen</span>
      </header>

      ${state.error ? `<p class="error">${esc(state.error)}</p>` : ''}

      <div class="card">
        <h3>Slik fungerer det</h3>
        <p>Trykk på knappen, så får du en firetegns festkode. Gjestene går til
        forsiden på telefonen sin og taster inn koden. Deretter styrer du kvelden
        fase for fase fra denne skjermen.</p>
        <button id="create-btn" ${state.busy ? 'disabled' : ''}>
          ${state.busy ? 'Åpner ny sak …' : 'Start ny grillfest'}
        </button>
      </div>

      <footer class="app-footer">
        <span>Skal du være gjest i stedet? <a href="/">Til festen →</a></span>
      </footer>
    </div>`

  app.querySelector('#create-btn').addEventListener('click', createGame)
}

function renderDashboard() {
  const game = state.game
  const tabs = [
    ['regi', 'Regi'],
    ['spillere', `Spillere (${state.players.length})`],
    ['mistenkte', 'Mistenkte'],
    ['polaroider', 'Polaroider'],
    ['avsloring', 'Avsløring'],
  ]

  app.innerHTML = `
    <div class="sheet">
      <header class="case-header">
        <div class="case-no">
          <span>Lensmannskontoret</span>
          <span>${game.status === 'revealed' ? 'SAK OPPKLART' : 'Etterforskning pågår'}</span>
        </div>
        <h1>${esc(game.title)}</h1>
        <p class="lede">Gjestene blir med på forsiden av appen med denne koden:</p>
        <div class="code-display">${esc(game.code)}</div>
      </header>

      ${state.error ? `<p class="error">${esc(state.error)}</p>` : ''}

      <nav class="tabnav">
        ${tabs
          .map(
            ([id, label]) =>
              `<button data-tab="${id}" class="${state.tab === id ? 'active' : ''}">${label}</button>`
          )
          .join('')}
      </nav>

      <main>${renderTab()}</main>

      <footer class="app-footer">
        <span>Festkode ${esc(game.code)}</span>
        <a href="#" id="new-game-link">Start ny fest</a>
      </footer>
    </div>`

  // Wire up everything that exists in the current tab.
  app.querySelectorAll('[data-tab]').forEach((btn) =>
    btn.addEventListener('click', () => {
      state.tab = btn.dataset.tab
      render()
    })
  )
  app.querySelector('#new-game-link').addEventListener('click', (e) => {
    e.preventDefault()
    newGame()
  })
  wireTabEvents()
}

function renderTab() {
  switch (state.tab) {
    case 'regi': return renderRegi()
    case 'spillere': return renderSpillere()
    case 'mistenkte': return renderMistenkte()
    case 'polaroider': return renderPolaroider()
    case 'avsloring': return renderAvsloring()
    default: return ''
  }
}

// --- Regi: the phase director ----------------------------------------------

function renderRegi() {
  const currentIdx = phaseIndex(state.game.phase)
  const steps = PHASES.map((phase, i) => {
    const isCurrent = i === currentIdx
    return `
      <div class="phase-step${isCurrent ? ' current' : ''}">
        <span class="num">${i + 1}.</span>
        <div style="flex:1; min-width:0;">
          <strong>${esc(phase.label)}</strong>${isCurrent ? ' <span class="badge red">nå</span>' : ''}
          <p class="script">${esc(phase.script)}</p>
        </div>
        ${
          isCurrent
            ? ''
            : `<button class="btn-quiet" data-phase="${phase.id}">Gå hit</button>`
        }
      </div>`
  }).join('')

  return `
    <h2>Kveldens regi</h2>
    <p class="lede">Spillernes skjermer følger fasen du velger her — de oppdateres i
    samme øyeblikk du bytter.</p>
    ${steps}
    <details class="editor">
      <summary>Åstedsrapporten (les høyt i fase 1)</summary>
      <div class="card"><p>${escMultiline(state.game.intro)}</p></div>
    </details>`
}

// --- Spillere: who's here, and who plays whom --------------------------------

function renderSpillere() {
  const takenBy = new Map(state.players.filter((p) => p.suspect_id).map((p) => [p.suspect_id, p.id]))

  const rows = state.players
    .map((player) => {
      const options = state.suspects
        .map((s) => {
          const takenByOther = takenBy.has(s.id) && takenBy.get(s.id) !== player.id
          return `<option value="${esc(s.id)}" ${s.id === player.suspect_id ? 'selected' : ''} ${takenByOther ? 'disabled' : ''}>
            ${esc(s.name)}${takenByOther ? ' (opptatt)' : ''}
          </option>`
        })
        .join('')
      return `
        <div class="suspect-row">
          <div class="who">
            <strong>${esc(player.display_name)}</strong>
            <div class="tagline">${player.suspect_name ? esc(player.suspect_name) : 'Ingen rolle ennå'}</div>
          </div>
          <select data-assign="${esc(player.id)}" style="max-width: 46%;">
            <option value="">— etterforsker (ingen rolle) —</option>
            ${options}
          </select>
        </div>`
    })
    .join('')

  return `
    <h2>Gjestene</h2>
    ${
      state.players.length === 0
        ? `<p class="notice">Ingen har meldt seg inn ennå. Be gjestene gå til forsiden
           og taste inn koden <strong>${esc(state.game.code)}</strong>.</p>`
        : rows
    }
    <div class="btn-row">
      <button id="auto-assign-btn">Del ut ledige roller automatisk</button>
    </div>
    <p class="lede">Er dere flere enn ${state.suspects.length} gjester, blir resten
    etterforskere — de er med og løser saken, men har ingen hemmelighet.</p>`
}

// --- Mistenkte: full cards, editable, killer badge behind a toggle -----------

function renderMistenkte() {
  const cards = state.suspects
    .map(
      (s) => `
      <div class="card">
        <p class="kicker">Mistenkt nr. ${s.sort_order}
          ${state.showSolution && s.is_killer ? ' — <span class="stamp">🔪 morderen</span>' : ''}
        </p>
        <h3>${esc(s.name)}</h3>
        <p class="lede">${esc(s.tagline)}</p>
        <p><strong>Dette vet alle:</strong> ${escMultiline(s.public_info)}</p>
        <p><strong>Hemmelighet:</strong> ${escMultiline(s.secret)}</p>
        <div class="alibi">«${escMultiline(s.alibi)}»</div>
        <details class="editor">
          <summary>✏️ Rediger denne mistenkte</summary>
          <form data-hold data-edit-suspect="${esc(s.id)}">
            <label>Navn <input name="name" value="${esc(s.name)}" maxlength="80" required /></label>
            <label>Kort beskrivelse <input name="tagline" value="${esc(s.tagline)}" maxlength="120" /></label>
            <label>Dette vet alle <textarea name="public_info">${esc(s.public_info)}</textarea></label>
            <label>Hemmelighet <textarea name="secret">${esc(s.secret)}</textarea></label>
            <label>Alibi <textarea name="alibi">${esc(s.alibi)}</textarea></label>
            <button>Lagre endringene</button>
          </form>
        </details>
      </div>`
    )
    .join('')

  return `
    <h2>De mistenkte</h2>
    <p class="lede">Endringer lagres i databasen og dukker opp på gjestenes
    telefoner med en gang. Hvem som er morderen kan ikke endres.</p>
    <button class="btn-quiet" id="toggle-solution">
      ${state.showSolution ? 'Skjul løsningen' : '🔒 Vis hvem morderen er (pass på hvem som ser skjermen)'}
    </button>
    ${cards}`
}

// --- Polaroider: evidence management -----------------------------------------

function renderPolaroider() {
  const cards = state.polaroids
    .map(
      (p) => `
      <div class="polaroid${p.revealed ? '' : ' hidden-from-players'}">
        ${
          p.image_url
            ? `<img src="${esc(p.image_url)}" alt="${esc(p.title)}" />`
            : `<div class="photo-area">📷 Bevisfoto</div>`
        }
        <div class="caption">
          <p class="p-title">${esc(p.title)}
            <span class="badge${p.revealed ? ' red' : ''}">${p.revealed ? 'Synlig for alle' : 'Skjult'}</span>
          </p>
          <p>${escMultiline(p.caption)}</p>
          <div class="btn-row">
            <button class="btn-quiet" data-toggle-polaroid="${esc(p.id)}" data-revealed="${p.revealed}">
              ${p.revealed ? 'Skjul for gjestene' : 'Avslør for gjestene'}
            </button>
            <button class="btn-quiet" data-delete-polaroid="${esc(p.id)}">Slett</button>
          </div>
          <details class="editor">
            <summary>✏️ Rediger</summary>
            <form data-hold data-edit-polaroid="${esc(p.id)}">
              <label>Tittel <input name="title" value="${esc(p.title)}" maxlength="120" required /></label>
              <label>Bildetekst <textarea name="caption">${esc(p.caption)}</textarea></label>
              <label>Bilde-URL (valgfritt) <input name="image_url" value="${esc(p.image_url ?? '')}" placeholder="https://…" /></label>
              <button>Lagre</button>
            </form>
          </details>
        </div>
      </div>`
    )
    .join('')

  return `
    <h2>Polaroider — bevisene</h2>
    <p class="lede">Avslør dem ett og ett i ledetråd-fasen, og les dem høyt.
    Skjulte polaroider er usynlige for gjestene.</p>
    ${cards}
    <hr class="divider" />
    <h3>Nytt polaroid</h3>
    <form data-hold id="new-polaroid-form">
      <label>Tittel <input name="title" maxlength="120" required placeholder="F.eks. «Sigarettsneipen»" /></label>
      <label>Bildetekst <textarea name="caption" placeholder="Hva viser bildet, og hvorfor er det interessant?"></textarea></label>
      <label>Bilde-URL (valgfritt) <input name="image_url" placeholder="https://…" /></label>
      <button>Legg til bevis</button>
    </form>`
}

// --- Avsløring: tally, the red button, and the solution -----------------------

function renderAvsloring() {
  const revealed = state.game.status === 'revealed'

  const tally = `
    <h3>Festens mistanker (live)</h3>
    <table class="tally">
      <thead><tr><th>Mistenkt</th><th>Lupepoeng</th><th>Hovedmistenkt-merker</th></tr></thead>
      <tbody>
        ${state.suspicions
          .map(
            (row) => `
          <tr>
            <td>${esc(row.name)}</td>
            <td>${row.total}</td>
            <td>${row.top_marks > 0 ? '🔍'.repeat(Math.min(row.top_marks, 8)) + ` (${row.top_marks})` : '—'}</td>
          </tr>`
          )
          .join('')}
      </tbody>
    </table>`

  if (revealed) {
    const killer = state.suspects.find((s) => s.is_killer)
    return `
      <h2>Saken er oppklart</h2>
      ${tally}
      <div class="reveal-card">
        <span class="stamp">Sak oppklart</span>
        <p class="kicker">Morderen er …</p>
        <p class="killer-name">${esc(killer?.name ?? '')}</p>
        <p class="lede">${esc(killer?.tagline ?? '')}</p>
        <div class="resolution">${escMultiline(state.game.resolution)}</div>
      </div>`
  }

  return `
    <h2>Avsløringen</h2>
    ${tally}
    <div class="card">
      <p class="kicker">Punkt uten retur</p>
      <p>Når du trykker på knappen, får alle gjestene se hvem morderen er og hele
      oppklaringen — samtidig, på sin egen telefon. Les gjerne opp mistanke-tabellen
      over først.</p>
      ${
        state.confirmReveal
          ? `<button class="btn-reveal" id="reveal-btn">ER DU SIKKER? Trykk igjen for å avsløre</button>
             <button class="btn-quiet" id="reveal-cancel">Avbryt</button>`
          : `<button class="btn-reveal" id="reveal-btn">🔪 Avslør morderen</button>`
      }
    </div>
    <details class="editor">
      <summary>🔒 Kikk på oppklaringen (kun for dine øyne)</summary>
      <div class="card"><p>${escMultiline(state.game.resolution)}</p></div>
    </details>`
}

// --------------------------------------------------------------------------
// Event wiring for the active tab
// --------------------------------------------------------------------------

function wireTabEvents() {
  // Regi: jump to a phase.
  app.querySelectorAll('[data-phase]').forEach((btn) =>
    btn.addEventListener('click', () => hostAction('host_set_phase', { p_phase: btn.dataset.phase }))
  )

  // Spillere: assign roles.
  app.querySelectorAll('[data-assign]').forEach((select) =>
    select.addEventListener('change', () =>
      hostAction('host_assign_suspect', {
        p_player_id: select.dataset.assign,
        p_suspect_id: select.value || null,
      })
    )
  )
  const autoBtn = app.querySelector('#auto-assign-btn')
  if (autoBtn) autoBtn.addEventListener('click', () => hostAction('host_auto_assign'))

  // Mistenkte: solution toggle + edit forms.
  const toggleSolution = app.querySelector('#toggle-solution')
  if (toggleSolution) {
    toggleSolution.addEventListener('click', () => {
      state.showSolution = !state.showSolution
      render()
    })
  }
  app.querySelectorAll('[data-edit-suspect]').forEach((form) =>
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      hostAction('host_update_suspect', {
        p_suspect_id: form.dataset.editSuspect,
        p_name: f.name.value,
        p_tagline: f.tagline.value,
        p_public_info: f.public_info.value,
        p_secret: f.secret.value,
        p_alibi: f.alibi.value,
      })
    })
  )

  // Polaroider: toggle / delete / edit / create.
  app.querySelectorAll('[data-toggle-polaroid]').forEach((btn) =>
    btn.addEventListener('click', () =>
      hostAction('host_reveal_polaroid', {
        p_polaroid_id: btn.dataset.togglePolaroid,
        p_revealed: btn.dataset.revealed !== 'true',
      })
    )
  )
  app.querySelectorAll('[data-delete-polaroid]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Slette dette beviset for godt?')) {
        hostAction('host_delete_polaroid', { p_polaroid_id: btn.dataset.deletePolaroid })
      }
    })
  )
  app.querySelectorAll('[data-edit-polaroid]').forEach((form) =>
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      hostAction('host_upsert_polaroid', {
        p_polaroid_id: form.dataset.editPolaroid,
        p_title: f.title.value,
        p_caption: f.caption.value,
        p_image_url: f.image_url.value || null,
      })
    })
  )
  const newPolaroidForm = app.querySelector('#new-polaroid-form')
  if (newPolaroidForm) {
    newPolaroidForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      hostAction('host_upsert_polaroid', {
        p_title: f.title.value,
        p_caption: f.caption.value,
        p_image_url: f.image_url.value || null,
      })
    })
  }

  // Avsløring: the two-tap red button.
  const revealBtn = app.querySelector('#reveal-btn')
  if (revealBtn) {
    revealBtn.addEventListener('click', () => {
      if (state.confirmReveal) {
        doReveal()
      } else {
        state.confirmReveal = true
        render()
      }
    })
  }
  const revealCancel = app.querySelector('#reveal-cancel')
  if (revealCancel) {
    revealCancel.addEventListener('click', () => {
      state.confirmReveal = false
      render()
    })
  }
}
