// Host view ("vertskontrollen"): pick a mystery, create a game, run the
// phases, hand out roles, reveal polaroids, edit content, and finally reveal
// the murderer. The host is the only browser allowed to see is_killer and the
// resolution — authenticated by the secret host_token from create_game.

import '../styles/main.css'
import { rpc } from '../lib/supabase.js'
import { watchGame } from '../lib/realtime.js'
import { esc, escMultiline } from '../lib/util.js'
import { icon, I } from '../lib/icons.js'
import { topNav, wireTopNav } from '../lib/nav.js'
import { hero } from '../lib/hero.js'
import heroHost from '../assets/mood/suspects.webp'
import { PHASES, phaseIndex } from '../lib/phases.js'
import { loadHost, saveHost, clearHost } from '../lib/tokens.js'
import { SABOTEUR_GAME_ENABLED } from '../lib/flags.js'

const app = document.querySelector('#app')

// The host dashboard's tabs; also the valid values for the URL hash. Skjult
// agenda is an opt-in mode (see src/lib/flags.js) — with the flag off,
// 'saboteur' is absent from this list, so no tab button renders and no
// #saboteur hash is ever accepted; the UI is unreachable. The real security
// boundary is still server-side regardless: every Skjult agenda RPC checks
// app_feature_flags('SABOTEUR_GAME_ENABLED') itself, first thing, before
// resolving any token.
const TAB_IDS = ['regi', 'spillere', 'mistenkte', 'polaroider', 'avsloring',
  ...(SABOTEUR_GAME_ENABLED ? ['saboteur'] : [])]

const state = {
  screen: 'loading', // 'loading' | 'landing' | 'dashboard'
  error: '',
  busy: false,
  flash: '',
  tab: 'regi', // regi | spillere | mistenkte | polaroider | bevis | avsloring
  catalog: [], // list_mysteries() for the landing picker
  selectedMystery: null,
  game: null,
  players: [],
  suspects: [],
  polaroids: [],
  suspicions: [],
  showSolution: false, // host may be projecting the screen — keep it hidden by default
  confirmReveal: false, // two-tap guard on the big red button

  // Skjult agenda (opt-in hidden-identity mode; all null/empty when disabled
  // or not yet created — see src/lib/flags.js and migration 00009/00010).
  saboteurGame: null, // host_get_saboteur_game result, or null if none created yet
  saboteurEligible: [], // host_list_eligible_participants result
  saboteurLoadError: '', // "couldn't load" (e.g. migration not applied), shown in-tab
  saboteurBusy: false,
  confirmEndSaboteur: false, // two-tap guard, mirrors confirmReveal
}

let stopWatching = null
let pendingRender = false
let flashTimer = null

const token = () => loadHost()?.host_token ?? null

init()

async function init() {
  if (!token()) {
    await loadCatalog()
    state.screen = 'landing'
    render()
    return
  }
  try {
    await refreshAll()
    startWatching()
    state.screen = 'dashboard'
    const fromHash = location.hash.slice(1)
    if (TAB_IDS.includes(fromHash)) state.tab = fromHash
  } catch {
    // Saved token doesn't match a game anymore — back to the landing page.
    clearHost()
    await loadCatalog()
    state.screen = 'landing'
  }
  render()
}

// The landing page lists every mystery in the catalog. A ?mystery=<id> in the
// URL (used by the studio's "start a party" button) preselects one.
async function loadCatalog() {
  try {
    state.catalog = await rpc('list_mysteries')
  } catch (err) {
    state.catalog = []
    state.error = err.message
  }
  const wanted = new URLSearchParams(location.search).get('mystery')
  const preselected = state.catalog.find((m) => m.id === wanted && m.ready)
  const firstReady = state.catalog.find((m) => m.ready)
  state.selectedMystery = (preselected ?? firstReady)?.id ?? null
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
  await refreshSaboteur()
  render()
}

// Loaded defensively, like every other optional sub-feature in this file: a
// failure here (flag off, migration not applied, or simply no Skjult agenda
// created yet) must never break the rest of the dashboard.
async function refreshSaboteur() {
  if (!SABOTEUR_GAME_ENABLED) return
  const sabId = loadHost()?.saboteur_game_id
  state.saboteurLoadError = ''
  if (!sabId) {
    state.saboteurGame = null
    state.saboteurEligible = []
    return
  }
  const t = token()
  try {
    const [game, eligible] = await Promise.all([
      rpc('host_get_saboteur_game', { p_host_token: t, p_saboteur_game_id: sabId }),
      rpc('host_list_eligible_participants', { p_host_token: t, p_saboteur_game_id: sabId }),
    ])
    state.saboteurGame = game
    state.saboteurEligible = eligible
  } catch (err) {
    state.saboteurGame = null
    state.saboteurLoadError = err.message
  }
}

// --------------------------------------------------------------------------
// Actions
// --------------------------------------------------------------------------

async function createGame(mysteryId) {
  state.busy = true
  state.error = ''
  render()
  try {
    const created = await rpc('create_game', { p_mystery_id: mysteryId ?? null })
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

// Small wrapper: run a host RPC, surface errors, let realtime refresh the
// rest. Pass flashText to confirm a successful save to the host.
async function hostAction(name, params = {}, flashText = '') {
  state.error = ''
  try {
    await rpc(name, { p_host_token: token(), ...params })
    await refreshAll()
    if (flashText) showFlash(flashText)
  } catch (err) {
    state.error = err.message
    render()
  }
}

function showFlash(text) {
  state.flash = text
  render()
  clearTimeout(flashTimer)
  flashTimer = setTimeout(() => {
    state.flash = ''
    render()
  }, 1600)
}

async function doReveal() {
  // Point of no return: after this, get_reveal hands every player the killer.
  await hostAction('host_set_status', { p_status: 'revealed' })
  await hostAction('host_set_phase', { p_phase: 'avsloring' })
  state.confirmReveal = false
}

// --- Skjult agenda actions ---------------------------------------------------

async function createSaboteurGame() {
  state.saboteurBusy = true
  state.error = ''
  render()
  try {
    const created = await rpc('host_create_saboteur_game', { p_host_token: token(), p_know_each_other: false })
    saveHost({ ...loadHost(), saboteur_game_id: created.saboteur_game_id })
    await refreshSaboteur()
  } catch (err) {
    state.error = err.message
  }
  state.saboteurBusy = false
  render()
}

// Every Skjult agenda host action goes through the SAME hostAction() wrapper
// as the murder-mystery actions — same error surfacing, same refresh, same
// flash-toast confirmation — just with p_saboteur_game_id folded into params.
function saboteurParams(extra = {}) {
  return { p_saboteur_game_id: loadHost()?.saboteur_game_id, ...extra }
}

async function doEndSaboteur() {
  // Point of no return: ends the game and, from this point, get_my_saboteur_brief
  // starts including the full role reveal for players.
  await hostAction('host_end_saboteur_game', saboteurParams(), 'Spillet er avsluttet — rollene er nå synlige for spillerne')
  state.confirmEndSaboteur = false
}

async function newGame() {
  if (!confirm('Starte en helt ny fest? Den gamle festkoden slutter å virke på denne enheten (spillet slettes ikke).')) return
  if (stopWatching) stopWatching()
  clearHost()
  state.game = null
  state.screen = 'loading'
  render()
  await loadCatalog()
  state.screen = 'landing'
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
    app.innerHTML = `<div class="sheet"><p class="notice">Åpner vertskontrollen …</p></div>`
  } else if (state.screen === 'landing') {
    renderLanding()
  } else {
    renderDashboard()
  }
  if (state.flash) {
    app.insertAdjacentHTML('beforeend', `<div class="flash">${icon(I.ok, { lead: true })}${esc(state.flash)}</div>`)
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
  const cards = state.catalog
    .map((m) => {
      const selected = m.id === state.selectedMystery
      return `
        <div class="mystery-card${selected ? ' selected' : ''}" data-mystery="${esc(m.id)}"
             style="cursor:${m.ready ? 'pointer' : 'default'};">
          <div class="title-row">
            <strong>${esc(m.title)}</strong>
            <span class="badge${m.ready ? ' ok' : ''}">${m.ready ? `${icon(I.ready, { lead: true })}Klart til å spilles` : `${icon(I.unfinished, { lead: true })}Uferdig`}</span>
          </div>
          <p class="meta">${icon(I.guestsCount, { lead: true })}${m.suspect_count} mistenkte · ${icon(I.evidence, { lead: true })}${m.polaroid_count} bevis${m.is_builtin ? ` · ${icon(I.builtin, { lead: true })}innebygd` : ''}</p>
          ${selected ? `<p>${esc(String(m.intro).slice(0, 180))}${String(m.intro).length > 180 ? '…' : ''}</p>` : ''}
        </div>`
    })
    .join('')

  const selected = state.catalog.find((m) => m.id === state.selectedMystery)

  app.innerHTML = `
    <div class="sheet">
      ${topNav({ active: 'host' })}
      ${hero({
        image: heroHost,
        context: 'Vertskontroll',
        title: 'Start en fest',
        lede: 'Du styrer kvelden og er den eneste som vet hvem morderen er. Velg et mysterium for å få en festkode.',
      })}

      ${state.error ? `<p class="error">${icon(I.error, { lead: true })}${esc(state.error)}</p>` : ''}

      <h2>${icon(I.tabRegi, { lead: true })}Velg mysterium</h2>
      ${cards || `<p class="notice">Fant ingen mysterier. Er databaseskjemaet kjørt i Supabase?</p>`}

      <button id="create-btn" ${state.busy || !selected ? 'disabled' : ''}>
        ${state.busy ? 'Oppretter fest …' : selected ? `${icon(I.play, { lead: true })}Start fest med «${esc(selected.title)}»` : 'Velg et mysterium først'}
      </button>

      <p class="lede" style="margin-top:18px;">Vil du lage ditt eget mysterium, med
      egne mistenkte og egen morder? <a href="/studio.html">${icon(I.studio, { lead: true })}Åpne verkstedet</a></p>

      <footer class="app-footer">
        <span>MurderMystery</span>
      </footer>
    </div>`

  wireTopNav(app)
  app.querySelectorAll('[data-mystery]').forEach((card) =>
    card.addEventListener('click', () => {
      const mystery = state.catalog.find((m) => m.id === card.dataset.mystery)
      if (!mystery?.ready) return
      state.selectedMystery = mystery.id
      render()
    })
  )
  app.querySelector('#create-btn').addEventListener('click', () => createGame(state.selectedMystery))
}

function renderDashboard() {
  const game = state.game
  const tabs = [
    ['regi', 'Regi', I.tabRegi],
    ['spillere', `Spillere (${state.players.length})`, I.tabPlayers],
    ['mistenkte', 'Mistenkte', I.tabSuspects],
    ['polaroider', 'Bevis', I.tabPolaroids],
    ['avsloring', 'Avsløring', I.tabReveal],
    ...(SABOTEUR_GAME_ENABLED ? [['saboteur', 'Skjult agenda', I.tabSaboteur]] : []),
  ]

  app.innerHTML = `
    <div class="sheet">
      ${topNav({ active: 'host', newFestInPage: true })}
      <header class="case-header">
        <div class="case-no">
          <span class="brand">${icon(I.brand, { lead: true })}MurderMystery</span>
          <span>${game.status === 'revealed' ? 'Sak oppklart' : 'Vertskontroll'}</span>
        </div>
        <h1>${esc(game.title)}</h1>
        <p class="lede">${icon(I.code, { lead: true })}Gjestene blir med på forsiden av appen med denne koden:</p>
        <div class="code-display">${esc(game.code)}</div>
      </header>

      ${state.error ? `<p class="error">${icon(I.error, { lead: true })}${esc(state.error)}</p>` : ''}

      <nav class="tabnav">
        ${tabs
          .map(
            ([id, label, iconName]) =>
              `<button data-tab="${id}" class="${state.tab === id ? 'active' : ''}">${icon(iconName, { lead: true })}${label}</button>`
          )
          .join('')}
      </nav>

      <main>${renderTab()}</main>

      <footer class="app-footer">
        <span>Festkode ${esc(game.code)}</span>
      </footer>
    </div>`

  // Nav's "Start ny fest" button ends the current party and returns to landing.
  wireTopNav(app, { onNewFest: newGame })
  // Wire up everything that exists in the current tab. The active tab is kept
  // in the URL hash so it survives a refresh and can be linked to directly.
  app.querySelectorAll('[data-tab]').forEach((btn) =>
    btn.addEventListener('click', () => {
      state.tab = btn.dataset.tab
      history.replaceState(null, '', `#${btn.dataset.tab}`)
      render()
    })
  )
  wireTabEvents()
}

function renderTab() {
  switch (state.tab) {
    case 'regi': return renderRegi()
    case 'spillere': return renderSpillere()
    case 'mistenkte': return renderMistenkte()
    case 'polaroider': return renderPolaroider()
    case 'avsloring': return renderAvsloring()
    case 'saboteur': return SABOTEUR_GAME_ENABLED ? renderSaboteur() : ''
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
            : `<button class="btn-quiet" data-phase="${phase.id}">${icon(I.next, { lead: true })}Gå hit</button>`
        }
      </div>`
  }).join('')

  // The kjøreplan contains the solution — host-only by design (it only ever
  // arrives via host_get_game) and folded shut in case the screen is visible.
  const runbook = (state.game.runbook || '').trim()

  return `
    <h2>${icon(I.tabRegi, { lead: true })}Kveldens regi</h2>
    <p class="lede">Spillernes skjermer følger fasen du velger her — de oppdateres i
    samme øyeblikk du bytter.</p>
    ${
      runbook
        ? `<details class="editor">
             <summary>${icon(I.locked, { lead: true })}Kjøreplan for kvelden — regi og rekvisitter (kun for deg)</summary>
             <div class="card runbook"><p>${escMultiline(runbook)}</p></div>
           </details>`
        : ''
    }
    ${steps}
    <details class="editor">
      <summary>${icon(I.briefing, { lead: true })}Åstedsrapporten (les høyt i fase 1)</summary>
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
    <h2>${icon(I.tabPlayers, { lead: true })}Gjestene</h2>
    ${
      state.players.length === 0
        ? `<p class="notice">Ingen har meldt seg inn ennå. Be gjestene gå til forsiden
           og taste inn koden <strong>${esc(state.game.code)}</strong>.</p>`
        : rows
    }
    <div class="btn-row">
      <button id="auto-assign-btn">${icon(I.shuffle, { lead: true })}Del ut ledige roller automatisk</button>
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
          ${state.showSolution && s.is_killer ? ` — <span class="stamp">${icon(I.reveal, { lead: true })}morderen</span>` : ''}
        </p>
        <h3>${esc(s.name)}</h3>
        <p class="lede">${esc(s.tagline)}</p>
        <p><strong>Dette vet alle:</strong> ${escMultiline(s.public_info)}</p>
        <p><strong>Hemmelighet:</strong> ${escMultiline(s.secret)}</p>
        <div class="alibi">«${escMultiline(s.alibi)}»</div>
        <details class="editor">
          <summary>${icon(I.edit, { lead: true })}Rediger denne mistenkte</summary>
          <form data-hold data-edit-suspect="${esc(s.id)}">
            <label>Navn <input name="name" value="${esc(s.name)}" maxlength="80" required /></label>
            <label>Kort beskrivelse <input name="tagline" value="${esc(s.tagline)}" maxlength="120" /></label>
            <label>Dette vet alle <textarea name="public_info">${esc(s.public_info)}</textarea></label>
            <label>Hemmelighet <textarea name="secret">${esc(s.secret)}</textarea></label>
            <label>Alibi <textarea name="alibi">${esc(s.alibi)}</textarea></label>
            <button>${icon(I.save, { lead: true })}Lagre endringene</button>
          </form>
        </details>
      </div>`
    )
    .join('')

  return `
    <h2>${icon(I.tabSuspects, { lead: true })}De mistenkte</h2>
    <p class="lede">Endringer lagres i databasen og dukker opp på gjestenes
    telefoner med en gang. Hvem som er morderen kan ikke endres.</p>
    <button class="btn-quiet" id="toggle-solution">
      ${state.showSolution
        ? `${icon(I.unlocked, { lead: true })}Skjul løsningen`
        : `${icon(I.locked, { lead: true })}Vis hvem morderen er (pass på hvem som ser skjermen)`}
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
            : `<div class="photo-area">${icon(I.evidence, { lead: true })}Bevisfoto</div>`
        }
        <div class="caption">
          <p class="p-title">${esc(p.title)}
            <span class="badge${p.revealed ? ' red' : ''}">${p.revealed ? `${icon(I.show, { lead: true })}Synlig for alle` : `${icon(I.hide, { lead: true })}Skjult`}</span>
          </p>
          <p>${escMultiline(p.caption)}</p>
          <div class="btn-row">
            <button class="btn-quiet" data-toggle-polaroid="${esc(p.id)}" data-revealed="${p.revealed}">
              ${p.revealed ? `${icon(I.hide, { lead: true })}Skjul for gjestene` : `${icon(I.show, { lead: true })}Avslør for gjestene`}
            </button>
            <button class="btn-quiet" data-delete-polaroid="${esc(p.id)}">${icon(I.del, { lead: true })}Slett</button>
          </div>
          <details class="editor">
            <summary>${icon(I.edit, { lead: true })}Rediger</summary>
            <form data-hold data-edit-polaroid="${esc(p.id)}">
              <label>Tittel <input name="title" value="${esc(p.title)}" maxlength="120" required /></label>
              <label>Bildetekst <textarea name="caption">${esc(p.caption)}</textarea></label>
              <label>Bilde-URL (valgfritt) <input name="image_url" value="${esc(p.image_url ?? '')}" placeholder="https://…" /></label>
              <button>${icon(I.save, { lead: true })}Lagre</button>
            </form>
          </details>
        </div>
      </div>`
    )
    .join('')

  return `
    <h2>${icon(I.tabPolaroids, { lead: true })}Bevis</h2>
    <p class="lede">Bevisene du avslører for gjestene, ett og ett i ledetråd-fasen.
    Les dem høyt. Skjulte bevis er usynlige for gjestene.</p>
    ${cards}
    <hr class="divider" />
    <h3>${icon(I.add, { lead: true })}Nytt bevis</h3>
    <form data-hold id="new-polaroid-form">
      <label>Tittel <input name="title" maxlength="120" required placeholder="F.eks. «Sigarettsneipen»" /></label>
      <label>Bildetekst <textarea name="caption" placeholder="Hva viser bildet, og hvorfor er det interessant?"></textarea></label>
      <label>Bilde-URL (valgfritt) <input name="image_url" placeholder="https://…" /></label>
      <button>${icon(I.add, { lead: true })}Legg til bevis</button>
    </form>`
}

// --- Avsløring: tally, the red button, and the solution -----------------------

function renderAvsloring() {
  const revealed = state.game.status === 'revealed'

  const tally = `
    <h3>${icon(I.tally, { lead: true })}Festens mistanker (live)</h3>
    <table class="tally">
      <thead><tr><th>Mistenkt</th><th>Lupepoeng</th><th>Hovedmistenkt-merker</th></tr></thead>
      <tbody>
        ${state.suspicions
          .map(
            (row) => `
          <tr>
            <td>${esc(row.name)}</td>
            <td>${row.total}</td>
            <td>${row.top_marks > 0 ? icon(I.clue).repeat(Math.min(row.top_marks, 8)) + ` (${row.top_marks})` : '—'}</td>
          </tr>`
          )
          .join('')}
      </tbody>
    </table>`

  if (revealed) {
    const killer = state.suspects.find((s) => s.is_killer)
    return `
      <h2>${icon(I.reveal, { lead: true })}Saken er oppklart</h2>
      ${tally}
      <div class="reveal-card">
        <span class="stamp">${icon(I.reveal, { lead: true })}Sak oppklart</span>
        <p class="kicker">Morderen er …</p>
        <p class="killer-name">${esc(killer?.name ?? '')}</p>
        <p class="lede">${esc(killer?.tagline ?? '')}</p>
        <div class="resolution">${escMultiline(state.game.resolution)}</div>
      </div>`
  }

  return `
    <h2>${icon(I.tabReveal, { lead: true })}Avsløringen</h2>
    ${tally}
    <div class="card">
      <p class="kicker">Punkt uten retur</p>
      <p>Når du trykker på knappen, får alle gjestene se hvem morderen er og hele
      oppklaringen — samtidig, på sin egen telefon. Les gjerne opp mistanke-tabellen
      over først.</p>
      ${
        state.confirmReveal
          ? `<button class="btn-reveal" id="reveal-btn">${icon(I.reveal, { lead: true })}ER DU SIKKER? Trykk igjen for å avsløre</button>
             <button class="btn-quiet" id="reveal-cancel">Avbryt</button>`
          : `<button class="btn-reveal" id="reveal-btn">${icon(I.reveal, { lead: true })}Avslør morderen</button>`
      }
    </div>
    <details class="editor">
      <summary>${icon(I.locked, { lead: true })}Kikk på oppklaringen (kun for dine øyne)</summary>
      <div class="card"><p>${escMultiline(state.game.resolution)}</p></div>
    </details>`
}

// --- Skjult agenda: hidden-identity social-deduction mode (opt-in) -----------
// Reuses the murder-mystery's own design system throughout (.card, .badge,
// .suspect-row, .tally, .editor) — no new visual language.

const SAB_STATUS_LABEL = {
  draft: 'Utkast', active: 'Aktivt', voting: 'Avstemning',
  paused: 'Pause', ended: 'Avsluttet', archived: 'Arkivert',
}
const SAB_ITEM_STATUS_LABEL = { assigned: 'Tildelt', claimed: 'Krevd', approved: 'Godkjent', rejected: 'Avslått' }

function renderSaboteur() {
  if (state.saboteurLoadError && !state.saboteurGame) {
    return `
      <h2>${icon(I.saboteur, { lead: true })}Skjult agenda</h2>
      <p class="error">${icon(I.warn, { lead: true })}${esc(state.saboteurLoadError)}</p>
      <p class="lede">Er databaseoppdateringene «00009_saboteur_game.sql» og
      «00010_saboteur_discovery.sql» kjørt i Supabase, og er funksjonen slått
      på (tabellen <code>app_feature_flags</code>, nøkkel
      <code>SABOTEUR_GAME_ENABLED</code>)?</p>`
  }

  if (!state.saboteurGame) {
    return `
      <h2>${icon(I.saboteur, { lead: true })}Skjult agenda</h2>
      <p class="lede">En egen, valgfri modus med skjulte roller: noen gjester blir
      hemmelige Sabotører med egne mål, resten er Lojale med egne oppgaver og hint.
      Kjøres inni denne festen og endrer ingenting ved selve mordmysteriet.</p>
      <div class="card">
        <button id="sab-create-btn" ${state.saboteurBusy ? 'disabled' : ''}>
          ${state.saboteurBusy ? 'Oppretter …' : `${icon(I.add, { lead: true })}Start Skjult agenda for denne festen`}
        </button>
      </div>`
  }

  const g = state.saboteurGame
  const draft = g.status === 'draft'
  const canPause = g.status === 'active'
  const canEnd = g.status === 'active' || g.status === 'paused'

  const parts = [`<h2>${icon(I.saboteur, { lead: true })}Skjult agenda</h2>`]

  parts.push(`
    <div class="card">
      <p class="kicker">Status</p>
      <p><span class="badge${g.status === 'active' || g.status === 'voting' ? ' red' : ''}">${esc(SAB_STATUS_LABEL[g.status] ?? g.status)}</span></p>
      <div class="btn-row">
        ${draft ? `<button data-sab-status="active">${icon(I.play, { lead: true })}Start spillet</button>` : ''}
        ${g.status === 'active' ? `<button class="btn-quiet" data-sab-status="draft">${icon(I.edit, { lead: true })}Åpne roller igjen</button>` : ''}
        ${canPause ? `<button class="btn-quiet" data-sab-status="paused">Sett på pause</button>` : ''}
        ${g.status === 'paused' ? `<button data-sab-status="active">Gjenoppta</button>` : ''}
        ${canEnd
          ? (state.confirmEndSaboteur
              ? `<button class="btn-danger" id="sab-end-btn">Sikker? Avslutt og vis roller</button>
                 <button class="btn-quiet" id="sab-end-cancel">Avbryt</button>`
              : `<button class="btn-danger" id="sab-end-btn">${icon(I.reveal, { lead: true })}Avslutt spillet</button>`)
          : ''}
        ${g.status === 'ended' ? `<button class="btn-quiet" data-sab-status="archived">Arkiver</button>` : ''}
      </div>
      <label style="display:flex; align-items:center; gap:8px; font-weight:400; margin-top:14px;">
        <input type="checkbox" id="sab-know-each-other" style="width:auto;" ${g.know_each_other ? 'checked' : ''} />
        Sabotørene kjenner hverandre
      </label>
      <label style="display:flex; align-items:center; gap:8px; font-weight:400;">
        <input type="checkbox" id="sab-show-leaderboard" style="width:auto;" ${g.show_leaderboard ? 'checked' : ''} />
        Vis full poengtavle ved avsluttet spill (ellers ser hver spiller kun egne poeng)
      </label>
    </div>`)

  parts.push(renderSaboteurParticipants(draft))
  parts.push(renderSaboteurObjectives())
  parts.push(renderSaboteurTasks())
  parts.push(renderSaboteurVoting())

  parts.push(`
    <details class="editor" id="sab-audit-details">
      <summary>${icon(I.locked, { lead: true })}Hendelseslogg (kun for deg)</summary>
      <div id="sab-audit-container"><p class="notice">Trykk for å laste …</p></div>
    </details>`)

  return parts.join('')
}

function renderSaboteurParticipants(draft) {
  const rows = (state.saboteurEligible || [])
    .map((p) => {
      if (draft) {
        return `
          <div class="suspect-row">
            <div class="who"><strong>${esc(p.display_name)}</strong></div>
            <select data-sab-role="${esc(p.player_id)}" style="max-width: 46%;">
              <option value="" ${!p.included ? 'selected' : ''}>— ikke med —</option>
              <option value="SABOTEUR" ${p.role === 'SABOTEUR' ? 'selected' : ''}>Sabotør</option>
              <option value="LOYAL" ${p.role === 'LOYAL' ? 'selected' : ''}>Lojal</option>
            </select>
          </div>`
      }
      if (!p.included) return ''
      return `
        <div class="suspect-row">
          <div class="who">
            <strong>${esc(p.display_name)}</strong>
            <div class="tagline">${p.role === 'SABOTEUR' ? 'Sabotør' : 'Lojal'}${p.active ? '' : ' · inaktiv'}</div>
          </div>
          <button class="btn-quiet" data-sab-toggle-active="${esc(p.player_id)}" data-active="${p.active}">
            ${p.active ? 'Sett inaktiv' : 'Sett aktiv'}
          </button>
        </div>`
    })
    .join('')

  return `
    <h3>${icon(I.guestsCount, { lead: true })}Deltakere</h3>
    ${draft
      ? `<p class="lede">Velg hvem som er med og hvilken rolle de får. Krever minst
         én Sabotør og én Lojal før spillet kan starte.</p>`
      : `<p class="lede">Roller kan bare endres mens spillet er i utkast — trykk
         «Åpne roller igjen» over om du må gjøre en endring.</p>`}
    ${rows || '<p class="notice">Ingen gjester har meldt seg inn på festen ennå.</p>'}`
}

function renderSaboteurObjectives() {
  const participants = state.saboteurGame.participants || []
  const saboteurs = participants.filter((p) => p.role === 'SABOTEUR')
  const objectives = state.saboteurGame.objectives || []

  const cards = objectives
    .map((o) => {
      const who = participants.find((p) => p.id === o.participant_id)
      return `
        <div class="card">
          <p class="kicker">${who ? esc(who.display_name) : '?'} · ${o.points} poeng
            ${o.status !== 'assigned' ? ` · <span class="badge${o.status === 'approved' ? ' ok' : o.status === 'rejected' ? ' red' : ''}">${esc(SAB_ITEM_STATUS_LABEL[o.status] ?? o.status)}</span>` : ''}
          </p>
          <h3>${esc(o.title)}</h3>
          ${o.description ? `<p>${escMultiline(o.description)}</p>` : ''}
          ${o.status === 'claimed' ? `
            <div class="btn-row">
              <button data-sab-decide-objective="${esc(o.id)}" data-approve="true">${icon(I.ok, { lead: true })}Godkjenn</button>
              <button class="btn-quiet" data-sab-decide-objective="${esc(o.id)}" data-approve="false">Avslå</button>
            </div>` : ''}
        </div>`
    })
    .join('')

  const saboteurOptions = saboteurs.map((p) => `<option value="${esc(p.id)}">${esc(p.display_name)}</option>`).join('')

  return `
    <h3>${icon(I.objective, { lead: true })}Mål til Sabotørene</h3>
    ${cards || '<p class="notice">Ingen mål lagt til ennå.</p>'}
    ${saboteurs.length > 0 ? `
      <details class="editor">
        <summary>${icon(I.add, { lead: true })}Nytt mål</summary>
        <form data-hold id="sab-new-objective-form">
          <label>Sabotør <select name="participant_id">${saboteurOptions}</select></label>
          <label>Tittel <input name="title" maxlength="160" required placeholder="F.eks. «Få gruppa til å spille tre selskapsleker»" /></label>
          <label>Beskrivelse (valgfritt) <textarea name="description"></textarea></label>
          <label>Poeng <input name="points" type="number" min="0" value="10" /></label>
          <button>${icon(I.add, { lead: true })}Legg til mål</button>
        </form>
      </details>` : '<p class="lede">Gi minst én deltaker rollen Sabotør for å kunne legge til mål.</p>'}`
}

function renderSaboteurTasks() {
  const participants = state.saboteurGame.participants || []
  const loyals = participants.filter((p) => p.role === 'LOYAL')
  const tasks = state.saboteurGame.tasks || []

  const cards = tasks
    .map((t) => {
      const who = participants.find((p) => p.id === t.participant_id)
      return `
        <div class="card">
          <p class="kicker">${who ? esc(who.display_name) : '?'}
            ${t.status !== 'assigned' ? ` · <span class="badge${t.status === 'approved' ? ' ok' : t.status === 'rejected' ? ' red' : ''}">${esc(SAB_ITEM_STATUS_LABEL[t.status] ?? t.status)}</span>` : ''}
          </p>
          <h3>${esc(t.title)}</h3>
          ${t.description ? `<p>${escMultiline(t.description)}</p>` : ''}
          <p class="hint">${icon(I.hint, { lead: true })}Hint ved godkjenning: ${esc(t.hint_text || '—')}
            (${t.hint_audience === 'all_loyal' ? 'alle Lojale' : 'kun denne spilleren'})</p>
          ${t.status === 'claimed' ? `
            <div class="btn-row">
              <button data-sab-decide-task="${esc(t.id)}" data-approve="true">${icon(I.ok, { lead: true })}Godkjenn</button>
              <button class="btn-quiet" data-sab-decide-task="${esc(t.id)}" data-approve="false">Avslå</button>
            </div>` : ''}
        </div>`
    })
    .join('')

  const loyalOptions = loyals.map((p) => `<option value="${esc(p.id)}">${esc(p.display_name)}</option>`).join('')

  return `
    <h3>${icon(I.task, { lead: true })}Oppgaver til de Lojale</h3>
    ${cards || '<p class="notice">Ingen oppgaver lagt til ennå.</p>'}
    ${loyals.length > 0 ? `
      <details class="editor">
        <summary>${icon(I.add, { lead: true })}Ny oppgave</summary>
        <form data-hold id="sab-new-task-form">
          <label>Lojal <select name="participant_id">${loyalOptions}</select></label>
          <label>Tittel <input name="title" maxlength="160" required placeholder="F.eks. «Få gruppa til å le uten å forklare hvorfor»" /></label>
          <label>Beskrivelse (valgfritt) <textarea name="description"></textarea></label>
          <label>Hint som låses opp <textarea name="hint_text" placeholder="Hintet spilleren (eller alle Lojale) får når du godkjenner"></textarea></label>
          <label>Hvem får hintet?
            <select name="hint_audience">
              <option value="assignee">Bare denne spilleren</option>
              <option value="all_loyal">Alle Lojale</option>
            </select>
          </label>
          <button>${icon(I.add, { lead: true })}Legg til oppgave</button>
        </form>
      </details>` : '<p class="lede">Gi minst én deltaker rollen Lojal for å kunne legge til oppgaver.</p>'}`
}

function renderSaboteurVoting() {
  const g = state.saboteurGame
  const round = g.current_round

  let body
  if (!round || round.status === 'revealed') {
    body = g.status === 'active'
      ? `<button id="sab-open-round-btn">${icon(I.ballot, { lead: true })}Åpne avstemning</button>`
      : `<p class="lede">Spillet må være aktivt (ikke i utkast eller pause) for å åpne en avstemning.</p>`
  } else if (round.status === 'open') {
    body = `
      <p>${icon(I.ballot, { lead: true })}${round.ballot_count} stemme(r) avgitt så langt.
      Stemmene er hemmelige til du lukker og avslører runden.</p>
      <button id="sab-close-round-btn" data-round-id="${esc(round.id)}">Lukk avstemningen</button>`
  } else {
    // closed, not yet revealed
    body = `
      <p>${icon(I.ballot, { lead: true })}Avstemningen er lukket (${round.ballot_count} stemmer). Ikke avslørt ennå.</p>
      <button id="sab-reveal-round-btn" data-round-id="${esc(round.id)}">${icon(I.reveal, { lead: true })}Avslør resultatet</button>`
  }

  const tally = round?.status === 'revealed' && round.tally?.length > 0
    ? `<table class="tally">
        <thead><tr><th>Deltaker</th><th>Stemmer</th></tr></thead>
        <tbody>${round.tally.map((t) => `<tr><td>${esc(t.display_name)}</td><td>${t.votes}</td></tr>`).join('')}</tbody>
      </table>`
    : ''

  return `
    <h3>${icon(I.ballot, { lead: true })}Avstemning</h3>
    <div class="card">${body}${tally}</div>`
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
      }, 'Lagret')
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
      }, 'Lagret')
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
      }, 'Bevis lagt til')
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

  wireSaboteurEvents()
}

// Skjult agenda: all selectors below only match elements that exist when the
// 'saboteur' tab is the one actually rendered into <main> — same idiom as
// every other tab's wiring in this function.
function wireSaboteurEvents() {
  const createBtn = app.querySelector('#sab-create-btn')
  if (createBtn) createBtn.addEventListener('click', createSaboteurGame)

  app.querySelectorAll('[data-sab-status]').forEach((btn) =>
    btn.addEventListener('click', () => hostAction('host_set_saboteur_status', saboteurParams({ p_status: btn.dataset.sabStatus })))
  )

  const endBtn = app.querySelector('#sab-end-btn')
  if (endBtn) {
    endBtn.addEventListener('click', () => {
      if (state.confirmEndSaboteur) {
        doEndSaboteur()
      } else {
        state.confirmEndSaboteur = true
        render()
      }
    })
  }
  const endCancel = app.querySelector('#sab-end-cancel')
  if (endCancel) endCancel.addEventListener('click', () => { state.confirmEndSaboteur = false; render() })

  const knowEachOther = app.querySelector('#sab-know-each-other')
  if (knowEachOther) {
    knowEachOther.addEventListener('change', () =>
      hostAction('host_set_know_each_other', saboteurParams({ p_enabled: knowEachOther.checked }))
    )
  }
  const showLeaderboard = app.querySelector('#sab-show-leaderboard')
  if (showLeaderboard) {
    showLeaderboard.addEventListener('change', () =>
      hostAction('host_set_show_leaderboard', saboteurParams({ p_enabled: showLeaderboard.checked }))
    )
  }

  app.querySelectorAll('[data-sab-role]').forEach((select) =>
    select.addEventListener('change', () =>
      hostAction('host_set_participants', saboteurParams({
        p_assignments: [{ player_id: select.dataset.sabRole, role: select.value || null }],
      }))
    )
  )
  app.querySelectorAll('[data-sab-toggle-active]').forEach((btn) =>
    btn.addEventListener('click', () =>
      hostAction('host_set_participant_active', saboteurParams({
        p_player_id: btn.dataset.sabToggleActive,
        p_active: btn.dataset.active !== 'true',
      }))
    )
  )

  const newObjectiveForm = app.querySelector('#sab-new-objective-form')
  if (newObjectiveForm) {
    newObjectiveForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      hostAction('host_upsert_objective', saboteurParams({
        p_participant_id: f.participant_id.value,
        p_title: f.title.value,
        p_description: f.description.value,
        p_points: Number(f.points.value) || 0,
      }), 'Mål lagt til')
    })
  }
  app.querySelectorAll('[data-sab-decide-objective]').forEach((btn) =>
    btn.addEventListener('click', () => {
      const approve = btn.dataset.approve === 'true'
      hostAction('host_decide_objective_claim', saboteurParams({
        p_objective_id: btn.dataset.sabDecideObjective, p_approve: approve,
      }), approve ? 'Godkjent' : 'Avslått')
    })
  )

  const newTaskForm = app.querySelector('#sab-new-task-form')
  if (newTaskForm) {
    newTaskForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      hostAction('host_upsert_task', saboteurParams({
        p_participant_id: f.participant_id.value,
        p_title: f.title.value,
        p_description: f.description.value,
        p_hint_text: f.hint_text.value,
        p_hint_audience: f.hint_audience.value,
      }), 'Oppgave lagt til')
    })
  }
  app.querySelectorAll('[data-sab-decide-task]').forEach((btn) =>
    btn.addEventListener('click', () => {
      const approve = btn.dataset.approve === 'true'
      hostAction('host_decide_task_claim', saboteurParams({
        p_task_id: btn.dataset.sabDecideTask, p_approve: approve,
      }), approve ? 'Godkjent' : 'Avslått')
    })
  )

  const openRoundBtn = app.querySelector('#sab-open-round-btn')
  if (openRoundBtn) openRoundBtn.addEventListener('click', () => hostAction('host_open_voting_round', saboteurParams(), 'Avstemning åpnet'))

  const closeRoundBtn = app.querySelector('#sab-close-round-btn')
  if (closeRoundBtn) {
    closeRoundBtn.addEventListener('click', () =>
      hostAction('host_close_voting_round', saboteurParams({ p_round_id: closeRoundBtn.dataset.roundId }), 'Avstemning lukket')
    )
  }
  const revealRoundBtn = app.querySelector('#sab-reveal-round-btn')
  if (revealRoundBtn) {
    revealRoundBtn.addEventListener('click', () =>
      hostAction('host_reveal_voting_round', saboteurParams({ p_round_id: revealRoundBtn.dataset.roundId }), 'Resultatet er avslørt')
    )
  }

  // Audit trail loads lazily the first time the <details> is opened, rather
  // than on every render/poke — it's rarely viewed.
  const auditDetails = app.querySelector('#sab-audit-details')
  if (auditDetails) {
    auditDetails.addEventListener('toggle', async () => {
      if (!auditDetails.open) return
      const container = app.querySelector('#sab-audit-container')
      try {
        const entries = await rpc('host_get_saboteur_audit', {
          p_host_token: token(), p_saboteur_game_id: loadHost()?.saboteur_game_id,
        })
        container.innerHTML = entries.length === 0
          ? '<p class="notice">Ingen hendelser ennå.</p>'
          : `<table class="tally"><thead><tr><th>Tid</th><th>Handling</th></tr></thead><tbody>
              ${entries.map((e) => `<tr><td>${esc(new Date(e.created_at).toLocaleString('nb-NO'))}</td><td>${esc(e.action)}</td></tr>`).join('')}
            </tbody></table>`
      } catch (err) {
        container.innerHTML = `<p class="error">${esc(err.message)}</p>`
      }
    })
  }
}
