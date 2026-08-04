// Skjult agenda — a STANDALONE hidden-identity party game.
//
// This is its own game, not part of a murder mystery: it has its own join
// code, its own host, and its own players. One page serves all three roles,
// picked by what's in localStorage:
//   landing -> no stored token: create a game (become host) or join with a code
//   host    -> a saboteur host_token: the control panel
//   player  -> a saboteur player_token: "my brief"
//
// Secrecy is enforced server-side, not here: every RPC hands back a payload
// built for that one viewer (see supabase/migrations/00011_saboteur_standalone.sql).
// This file never receives another participant's role, objectives or votes,
// so there is nothing here to accidentally leak.
import '../styles/main.css'
import { rpc } from '../lib/supabase.js'
import { esc, escMultiline } from '../lib/util.js'
import { icon, I } from '../lib/icons.js'
import { hero } from '../lib/hero.js'
import heroImg from '../assets/mood/parlor.webp'
import { SABOTEUR_GAME_ENABLED } from '../lib/flags.js'
import { topNav, wireTopNav } from '../lib/nav.js'
import { getSession } from '../lib/auth.js'
import { SABOTEUR_PHASES, saboteurPhaseIndex, saboteurPhase } from '../lib/saboteur-phases.js'
import {
  loadSaboteurHost, saveSaboteurHost, clearSaboteurHost,
  loadSaboteurPlayer, saveSaboteurPlayer, clearSaboteurPlayer,
} from '../lib/tokens.js'

const app = document.querySelector('#app')

const state = {
  screen: 'loading', // 'loading' | 'landing' | 'host' | 'player'
  busy: false,
  error: '',
  flash: '',
  game: null, // host_get_saboteur_game result
  brief: null, // get_my_saboteur_brief result
  voteStatus: null,
  ballotTargets: [],
  confirmEnd: false, // two-tap guard on ending the game

  // Account integration: when the host is logged in, their games follow the
  // account instead of only this device's localStorage.
  loggedIn: false,
  myGames: [], // owner_list_saboteur_games result

  library: [], // list_saboteur_objective_library — 30 ready-made objectives
  taskLibrary: [], // list_saboteur_task_library — 25 ready-made Lojal tasks
  hintLibrary: [], // host_list_saboteur_hint_library — the 10 hint cards
  hostTab: 'regi', // see HOST_TABS
  // Which form is mid-submit, so its button can say so immediately instead of
  // looking dead for the two round trips an action takes.
  pending: '',
}

let flashTimer = null
let pollTimer = null
let pendingRender = false
let lastSnapshot = '' // see dataChanged(): suppresses redraws that would change nothing

const hostToken = () => loadSaboteurHost()?.host_token ?? null
const playerToken = () => loadSaboteurPlayer()?.player_token ?? null

init()

async function init() {
  if (!SABOTEUR_GAME_ENABLED) {
    state.screen = 'disabled'
    render()
    return
  }
  await refreshAccount()

  if (hostToken()) {
    await refreshHost()
    await loadLibrary()
    // Started a game before signing in? Attach it now, so it shows up under
    // "Mine spill" from here on. Safe and idempotent: holding the host token
    // already grants full control of that game.
    await claimIfLoggedIn()
    state.screen = state.game ? 'host' : 'landing'
  } else if (playerToken()) {
    await refreshPlayer()
    state.screen = state.brief ? 'player' : 'landing'
  } else {
    state.screen = 'landing'
  }
  render()
  startPolling()
}

// If the host is signed in, load the games tied to their account so they can
// resume one from any device — the whole point of the account integration.
// Signed out, this is simply a no-op and everything works as before.
async function refreshAccount() {
  try {
    state.loggedIn = Boolean(await getSession())
  } catch {
    state.loggedIn = false
  }
  if (!state.loggedIn) {
    state.myGames = []
    return
  }
  try {
    state.myGames = await rpc('owner_list_saboteur_games')
  } catch {
    // Migration 00012 not applied yet, or flag off — degrade quietly to the
    // device-only behaviour rather than blocking the page.
    state.myGames = []
  }
}

async function claimIfLoggedIn() {
  if (!state.loggedIn || !state.game || !hostToken()) return
  try {
    await rpc('owner_claim_saboteur_game', { p_host_token: hostToken() })
    state.myGames = await rpc('owner_list_saboteur_games')
  } catch {
    // Already owned by this account, migration 00012 missing, or owned by
    // someone else — none of which should interrupt hosting.
  }
}

// Resume a game from the account list: adopt its host token on this device.
async function resumeGame(token) {
  state.error = ''
  saveSaboteurHost({ host_token: token })
  clearSaboteurPlayer()
  await refreshHost()
  state.screen = state.game ? 'host' : 'landing'
  render()
}

// The standalone game has no game_events/Realtime plumbing of its own, so it
// polls — cheap at party scale, and it also refreshes the moment a phone comes
// back from sleep, which is the common case at a real party.
//
// Crucially the poll only REDRAWS when the data actually changed. Rebuilding
// the DOM every 5 seconds regardless is what made the page visibly twitch and
// lose your scroll position; most polls return exactly what's already on
// screen, so the common case is now a no-op.
function startPolling() {
  stopPolling()
  const tick = async () => {
    if (state.screen === 'host') await refreshHost()
    else if (state.screen === 'player') await refreshPlayer()
    else return
    if (dataChanged()) pollRender()
  }
  pollTimer = setInterval(tick, 5000)
  document.addEventListener('visibilitychange', () => { if (!document.hidden) tick() })
}

// Snapshot of everything the current screen actually displays. Cheap enough at
// this size, and far simpler than diffing the DOM.
function snapshot() {
  return state.screen === 'host'
    ? JSON.stringify(state.game)
    : JSON.stringify([state.brief, state.voteStatus, state.ballotTargets])
}

function dataChanged() {
  const next = snapshot()
  if (next === lastSnapshot) return false
  lastSnapshot = next
  return true
}

function stopPolling() {
  if (pollTimer) clearInterval(pollTimer)
  pollTimer = null
}

// The ready-made objective library is shared by all games and never changes
// mid-party, so it's fetched once rather than on every poll.
async function loadLibrary() {
  if (state.library.length === 0) {
    try {
      state.library = await rpc('list_saboteur_objective_library')
    } catch {
      state.library = [] // migration 00016 not applied yet — the picker just hides
    }
  }
  if (state.taskLibrary.length === 0) {
    try {
      state.taskLibrary = await rpc('list_saboteur_task_library')
    } catch {
      state.taskLibrary = [] // migration 00019 not applied yet
    }
  }
  // Host-only: the hint cards are content the Lojale are meant to discover,
  // so they never travel to a player's browser.
  if (state.hintLibrary.length === 0 && hostToken()) {
    try {
      state.hintLibrary = await rpc('host_list_saboteur_hint_library', { p_host_token: hostToken() })
    } catch {
      state.hintLibrary = []
    }
  }
}

async function refreshHost() {
  try {
    state.game = await rpc('host_get_saboteur_game', { p_host_token: hostToken() })
  } catch {
    // Stale/invalid token (game archived, wiped database, old device) — forget
    // it rather than trapping the user on a broken screen.
    clearSaboteurHost()
    state.game = null
  }
}

async function refreshPlayer() {
  const t = playerToken()
  try {
    state.brief = await rpc('get_my_saboteur_brief', { p_player_token: t })
    state.voteStatus = await rpc('get_my_saboteur_vote_status', { p_player_token: t })
    state.ballotTargets = state.voteStatus.can_vote
      ? await rpc('get_saboteur_ballot_targets', { p_player_token: t })
      : []
  } catch {
    clearSaboteurPlayer()
    state.brief = null
  }
}

// --------------------------------------------------------------------------
// Actions
// --------------------------------------------------------------------------

function showFlash(text) {
  state.flash = text
  render()
  clearTimeout(flashTimer)
  flashTimer = setTimeout(() => { state.flash = ''; render() }, 1600)
}

// Wrapper for host actions: run, surface errors, refresh, optional toast.
// Which database update introduced each RPC. When the code is deployed but
// the migration hasn't been run in Supabase yet, PostgREST reports a bare
// "Could not find the function ..." — useless to a host mid-party. Map it to
// something actionable instead.
const RPC_MIGRATION = {
  host_upsert_announcement: '00015_announcement_drafts.sql',
  host_set_announcement_published: '00015_announcement_drafts.sql',
  host_delete_announcement: '00013_saboteur_pins_phases.sql',
  host_publish_announcement: '00013_saboteur_pins_phases.sql',
  host_set_saboteur_phase: '00013_saboteur_pins_phases.sql',
  rejoin_saboteur_game: '00013_saboteur_pins_phases.sql',
  owner_list_saboteur_games: '00012_saboteur_account.sql',
  owner_claim_saboteur_game: '00012_saboteur_account.sql',
}

function friendlyError(err, rpcName) {
  const msg = err?.message || 'Ukjent feil'
  const missingFunction = /could not find the function|schema cache|does not exist/i.test(msg)
  if (missingFunction) {
    const file = RPC_MIGRATION[rpcName]
    return file
      ? `Databasen mangler en oppdatering: kjør «${file}» i Supabase (SQL Editor), og deretter «NOTIFY pgrst, 'reload schema';». Teknisk melding: ${msg}`
      : `Databasen mangler en oppdatering for «${rpcName}». Kjør migrasjonene i supabase/migrations/ i Supabase. Teknisk melding: ${msg}`
  }
  return msg
}

// Same as hostAction, but flips a button into a "…" state and redraws BEFORE
// the request goes out. An add/save takes two round trips (the write, then the
// refresh), which is long enough that a silent button reads as broken.
async function hostActionPending(key, name, params = {}, flashText = '') {
  if (state.pending) return // already submitting — ignore the double-click
  state.pending = key
  render()
  try {
    await hostAction(name, params, flashText)
  } finally {
    state.pending = ''
    render()
  }
}

// Label helper: shows the busy text while this form is submitting.
function pendingLabel(key, idleLabel, busyText, iconName) {
  return state.pending === key
    ? esc(busyText)
    : `${icon(iconName, { lead: true })}${esc(idleLabel)}`
}

async function hostAction(name, params = {}, flashText = '') {
  state.error = ''
  try {
    await rpc(name, { p_host_token: hostToken(), ...params })
    await refreshHost()
    if (flashText) showFlash(flashText)
    else render()
  } catch (err) {
    state.error = friendlyError(err, name)
    render()
  }
}

async function playerAction(name, params = {}, flashText = '') {
  state.error = ''
  try {
    await rpc(name, { p_player_token: playerToken(), ...params })
    await refreshPlayer()
    if (flashText) showFlash(flashText)
    else render()
  } catch (err) {
    state.error = friendlyError(err, name)
    render()
  }
}

async function onCreateGame(e) {
  e.preventDefault()
  if (state.busy) return
  const f = e.target.elements
  state.busy = true
  state.error = ''
  render()
  try {
    const created = await rpc('create_saboteur_game', {
      p_title: f.title.value,
      p_know_each_other: f.know_each_other.checked,
    })
    saveSaboteurHost({ host_token: created.host_token, saboteur_game_id: created.saboteur_game_id, code: created.code })
    await refreshHost()
    await claimIfLoggedIn() // create_saboteur_game already stamps owner_id; this keeps "Mine spill" fresh
    state.screen = 'host'
  } catch (err) {
    state.error = err.message
  }
  state.busy = false
  render()
}

async function onJoinGame(e) {
  e.preventDefault()
  if (state.busy) return
  const f = e.target.elements
  state.busy = true
  state.error = ''
  render()
  try {
    const joined = await rpc('join_saboteur_game', { p_code: f.code.value, p_name: f.name.value })
    saveSaboteurPlayer({ player_token: joined.player_token, saboteur_game_id: joined.saboteur_game_id })
    await refreshPlayer()
    state.screen = 'player'
  } catch (err) {
    state.error = err.message
  }
  state.busy = false
  render()
}

// Recover a lost participant with game code + name + personal PIN. Returns the
// SAME participant, so role, objectives, tasks and hints are all still there.
async function onRejoinGame(e) {
  e.preventDefault()
  if (state.busy) return
  const f = e.target.elements
  state.busy = true
  state.error = ''
  render()
  try {
    const joined = await rpc('rejoin_saboteur_game', {
      p_code: f.code.value, p_name: f.name.value, p_pin: f.pin.value,
    })
    saveSaboteurPlayer({ player_token: joined.player_token, saboteur_game_id: joined.saboteur_game_id })
    clearSaboteurHost()
    await refreshPlayer()
    state.screen = state.brief ? 'player' : 'landing'
  } catch (err) {
    state.error = err.message
  }
  state.busy = false
  render()
}

async function doEndGame() {
  await hostAction('host_end_saboteur_game', {}, 'Spillet er avsluttet — rollene er nå synlige')
  state.confirmEnd = false
}

function leaveGame() {
  if (!confirm('Forlate spillet på denne enheten? Verten kan ikke se deg som borte automatisk.')) return
  clearSaboteurPlayer()
  clearSaboteurHost()
  location.reload()
}

// --------------------------------------------------------------------------
// Rendering
// --------------------------------------------------------------------------

const STATUS_LABEL = {
  draft: 'Utkast', active: 'Aktivt', voting: 'Avstemning',
  paused: 'Pause', ended: 'Avsluttet', archived: 'Arkivert',
}
const ITEM_STATUS_LABEL = {
  assigned: 'Tildelt', claimed: 'Krevd — venter på verten',
  approved: 'Godkjent', rejected: 'Avslått',
}

// Is focus currently inside a form we must not disturb?
function typingInForm() {
  const active = document.activeElement
  return Boolean(active && app.contains(active) && active.closest('[data-hold]'))
}

// Used ONLY by the background poll. A user-initiated change always goes
// through render() below and redraws immediately — deferring those was a bug:
// after clicking "Lagre" the submit button still has focus, and it sits inside
// the very [data-hold] form being protected, so the confirmation (and any
// error) was swallowed until the host happened to click somewhere else.
function pollRender() {
  if (typingInForm()) {
    pendingRender = true
    return
  }
  render()
}

function render() {
  pendingRender = false

  // Panels are collapsed <details>; remember which were open so a background
  // refresh doesn't snap them shut mid-task.
  const openPanels = new Set(
    [...app.querySelectorAll('details[data-panel][open]')].map((d) => d.dataset.panel)
  )

  let body
  if (state.screen === 'disabled') body = renderDisabled()
  else if (state.screen === 'loading') body = `<p class="notice">Laster …</p>`
  else if (state.screen === 'landing') body = renderLanding()
  else if (state.screen === 'host') body = renderHost()
  else body = renderPlayer()

  // Host-facing screens get the same top navigation as the rest of the app,
  // so running a Skjult agenda feels like part of the product rather than a
  // separate island. Guests (the player brief) don't get host navigation —
  // same convention as the murder-mystery player view.
  const withNav = state.screen === 'landing' || state.screen === 'host'
  const nav = withNav ? topNav({ active: 'skjult', cta: false }) : ''

  // Replacing the whole page briefly collapses its height, which makes the
  // browser scroll to the top. Restore the position so a refresh never yanks
  // the host away from what they were reading.
  const scrollY = window.scrollY

  app.innerHTML = `<div class="sheet">${nav}${body}</div>`
  if (withNav) wireTopNav(app)
  app.querySelectorAll('details[data-panel]').forEach((d) => {
    if (openPanels.has(d.dataset.panel)) d.open = true
  })
  if (scrollY > 0) window.scrollTo(0, scrollY)
  lastSnapshot = snapshot()

  if (state.flash) {
    app.insertAdjacentHTML('beforeend', `<div class="flash">${icon(I.ok, { lead: true })}${esc(state.flash)}</div>`)
  }
  wireEvents()
}

// Run the poll's suppressed redraw once focus actually leaves the form.
app.addEventListener('focusout', () => {
  // Wait a tick so document.activeElement points at the NEXT focused element
  // (moving from a field to the submit button must not count as leaving).
  setTimeout(() => {
    if (pendingRender && !typingInForm()) render()
  }, 60)
})

function renderDisabled() {
  return `
    ${hero({ image: heroImg, context: 'Skjult agenda', title: 'Skjult agenda', lede: 'Et selskapsspill med hemmelige roller.' })}
    <div class="card">
      <p>Denne funksjonen er ikke slått på.</p>
      <p class="hint">Skjult agenda er valgfri og av som standard. Se README-en for
      hvordan du skrur den på (både databaseflagget og miljøvariabelen må settes).</p>
    </div>
    <footer class="app-footer"><a href="/">${icon(I.back, { lead: true })}Til MurderMystery</a></footer>`
}

function errorBlock() {
  return state.error ? `<p class="error">${icon(I.warn, { lead: true })}${esc(state.error)}</p>` : ''
}

// Games tied to the signed-in account. This is what makes the host's games
// survive a cleared browser or a switch to another device.
function renderMyGames() {
  if (!state.loggedIn) {
    return `
      <p class="hint" style="margin-bottom:16px;">
        ${icon(I.account, { lead: true })}<a href="/konto.html">Logg inn</a> for å ta vare på
        spillene dine — da finner du dem igjen selv om du bytter enhet.
      </p>`
  }
  if (state.myGames.length === 0) return ''

  const rows = state.myGames
    .map((g) => `
      <div class="suspect-row">
        <div class="who">
          <strong>${esc(g.title)}</strong>
          <div class="tagline">Kode ${esc(g.code)} · ${esc(STATUS_LABEL[g.status] ?? g.status)} · ${g.participant_count} deltaker(e)</div>
        </div>
        <button class="btn-quiet" data-resume="${esc(g.host_token)}">${icon(I.play, { lead: true })}Fortsett</button>
      </div>`)
    .join('')

  return `
    <h2>${icon(I.host, { lead: true })}Mine spill</h2>
    <p class="lede">Spill du er vert for. De følger kontoen din, ikke enheten.</p>
    ${rows}`
}

function renderLanding() {
  return `
    ${hero({
      image: heroImg,
      context: 'Selskapsspill',
      title: 'Skjult agenda',
      lede: 'Noen av dere er hemmelige Sabotører med egne mål. Resten er Lojale. Klarer dere å avsløre hvem?',
    })}
    ${errorBlock()}
    ${renderMyGames()}

    <div class="card">
      <h2 style="margin-top:0;">${icon(I.host, { lead: true })}Start et spill</h2>
      <p class="lede">Du blir vert: du deler ut roller, godkjenner oppdrag og styrer avstemningen.</p>
      <form data-hold id="create-form">
        <label for="c-title">Navn på spillet (valgfritt)</label>
        <input id="c-title" name="title" maxlength="80" placeholder="F.eks. «Fredagsvorspiel»" />
        <label style="display:flex; align-items:center; gap:8px; font-weight:400;">
          <input type="checkbox" name="know_each_other" style="width:auto;" />
          Sabotørene skal kjenne hverandre
        </label>
        <button ${state.busy ? 'disabled' : ''}>${state.busy ? 'Oppretter …' : `${icon(I.add, { lead: true })}Opprett spill`}</button>
      </form>
    </div>

    <div class="card">
      <h2 style="margin-top:0;">${icon(I.join, { lead: true })}Bli med</h2>
      <form data-hold id="join-form">
        <label for="j-code">Spillkode</label>
        <input id="j-code" name="code" maxlength="4" autocapitalize="characters"
               autocomplete="off" spellcheck="false" required placeholder="F.eks. KX7M" />
        <label for="j-name">Navnet ditt</label>
        <input id="j-name" name="name" maxlength="40" required placeholder="Slik de andre kjenner deg" />
        <button ${state.busy ? 'disabled' : ''}>${state.busy ? 'Blir med …' : `${icon(I.join, { lead: true })}Bli med i spillet`}</button>
      </form>
    </div>

    <details class="editor" data-panel="rejoin">
      <summary>${icon(I.login, { lead: true })}Har du vært med før? Kom tilbake</summary>
      <div class="card">
        <p class="lede">Mistet tilgangen — ny telefon, tømt nettleser, eller trykket feil?
        Bruk navnet ditt og den personlige koden verten ser i deltakerlista.</p>
        <form data-hold id="rejoin-form">
          <label for="r-code">Spillkode</label>
          <input id="r-code" name="code" maxlength="4" autocapitalize="characters"
                 autocomplete="off" spellcheck="false" required placeholder="F.eks. KX7M" />
          <label for="r-name">Navnet ditt</label>
          <input id="r-name" name="name" maxlength="40" required />
          <label for="r-pin">Din personlige kode</label>
          <input id="r-pin" name="pin" inputmode="numeric" maxlength="4" required placeholder="F.eks. 4570" />
          <button ${state.busy ? 'disabled' : ''}>${state.busy ? 'Henter …' : `${icon(I.login, { lead: true })}Kom tilbake`}</button>
        </form>
      </div>
    </details>

    <footer class="app-footer">
      <a href="/">${icon(I.back, { lead: true })}Til MurderMystery</a>
    </footer>`
}

// --- Host control panel ------------------------------------------------------

// The host panel is split into tabs the same way the murder-mystery host view
// is — one long scrolling page was unmanageable mid-party. "Verksted" is the
// preparation bench (intro, objectives, tasks); the other tabs are for
// actually running the evening.
const HOST_TABS = [
  ['regi', 'Regi', I.tabRegi],
  ['deltakere', 'Deltakere', I.guestsCount],
  ['verksted', 'Verksted', I.studio],
  ['beskjeder', 'Beskjeder', I.hint],
  ['avstemning', 'Avstemning', I.ballot],
]

function renderHostTab(draft) {
  switch (state.hostTab) {
    case 'deltakere': return renderHostParticipants(draft)
    case 'verksted': return `${renderHostIntro()}${renderHostObjectives()}${renderHostTasks()}`
    case 'beskjeder': return renderHostAnnouncements()
    case 'avstemning': return renderHostVoting()
    default: return renderHostRegi()
  }
}

function renderHost() {
  const g = state.game
  const draft = g.status === 'draft'
  const canEnd = g.status === 'active' || g.status === 'paused'

  return `
    <header class="case-header">
      <div class="case-no">
        <span class="brand">${icon(I.saboteur, { lead: true })}Skjult agenda</span>
        <span>Vertskontroll</span>
      </div>
      <h1>${esc(g.title)}</h1>
      <p class="lede">Deltakerne blir med på <strong>/skjult-agenda.html</strong> med denne koden:</p>
      <div class="code-display">${esc(g.code)}</div>
    </header>

    ${errorBlock()}

    <div class="card">
      <p class="kicker">Status</p>
      <p><span class="badge${g.status === 'active' || g.status === 'voting' ? ' red' : ''}">${esc(STATUS_LABEL[g.status] ?? g.status)}</span></p>
      <div class="btn-row">
        ${draft ? `<button data-status="active">${icon(I.play, { lead: true })}Start spillet</button>` : ''}
        ${g.status === 'active' ? `<button class="btn-quiet" data-status="draft">${icon(I.edit, { lead: true })}Åpne roller igjen</button>` : ''}
        ${g.status === 'active' ? `<button class="btn-quiet" data-status="paused">Sett på pause</button>` : ''}
        ${g.status === 'paused' ? `<button data-status="active">Gjenoppta</button>` : ''}
        ${canEnd
          ? (state.confirmEnd
              ? `<button class="btn-danger" id="end-btn">Sikker? Avslutt og vis roller</button>
                 <button class="btn-quiet" id="end-cancel">Avbryt</button>`
              : `<button class="btn-danger" id="end-btn">${icon(I.reveal, { lead: true })}Avslutt spillet</button>`)
          : ''}
        ${g.status === 'ended' ? `<button class="btn-quiet" data-status="archived">Arkiver</button>` : ''}
      </div>
      <label style="display:flex; align-items:center; gap:8px; font-weight:400; margin-top:14px;">
        <input type="checkbox" id="know-each-other" style="width:auto;" ${g.know_each_other ? 'checked' : ''} />
        Sabotørene kjenner hverandre
      </label>
      <label style="display:flex; align-items:center; gap:8px; font-weight:400;">
        <input type="checkbox" id="show-leaderboard" style="width:auto;" ${g.show_leaderboard ? 'checked' : ''} />
        Vis full poengtavle når spillet avsluttes
      </label>
    </div>

    <nav class="tabnav">
      ${HOST_TABS.map(([id, label, iconName]) => `
        <button data-host-tab="${id}" class="${state.hostTab === id ? 'active' : ''}">
          ${icon(iconName, { lead: true })}${label}
        </button>`).join('')}
    </nav>

    <main>${renderHostTab(draft)}</main>

    <details class="editor" id="audit-details" data-panel="audit">
      <summary>${icon(I.locked, { lead: true })}Hendelseslogg (kun for deg)</summary>
      <div id="audit-container"><p class="notice">Åpne for å laste …</p></div>
    </details>

    <footer class="app-footer">
      <span>Kode ${esc(g.code)}</span>
      <a href="#" id="leave-link">${icon(I.leave, { lead: true })}Avslutt på denne enheten</a>
    </footer>`
}

// The framing every participant reads before play starts: don't show your
// screen, don't share your messages, trust no one. Stored on the game (not
// hardcoded), so the host can rewrite it here for their own group.
function renderHostIntro() {
  const intro = state.game.intro ?? ''
  return `
    <h2>${icon(I.briefing, { lead: true })}Introduksjon</h2>
    <p class="lede">Dette er rammen deltakerne leser på sin egen telefon før spillet
    starter. Endre den som du vil — teksten er ikke låst.</p>
    <div class="card">
      <p>${escMultiline(intro) || '<em>Ingen introduksjon satt.</em>'}</p>
      <details class="editor" data-panel="edit-intro">
        <summary>${icon(I.edit, { lead: true })}Rediger introduksjonen</summary>
        <form data-hold id="intro-form">
          <label>Introduksjonstekst
            <textarea name="intro" rows="12" maxlength="4000">${esc(intro)}</textarea>
          </label>
          <button>${icon(I.save, { lead: true })}Lagre introduksjon</button>
        </form>
      </details>
    </div>`
}

// Kveldens regi: the same step-by-step director the murder mystery has.
// Every guest's phone shows the matching line, so the whole room stays in sync.
function renderHostRegi() {
  const currentIdx = saboteurPhaseIndex(state.game.phase)

  const steps = SABOTEUR_PHASES.map((phase, i) => {
    const isCurrent = i === currentIdx
    return `
      <div class="phase-step${isCurrent ? ' current' : ''}">
        <span class="num">${i + 1}.</span>
        <div style="flex:1; min-width:0;">
          <strong>${esc(phase.label)}</strong>${isCurrent ? ' <span class="badge red">nå</span>' : ''}
          <p class="script">${esc(phase.script)}</p>
        </div>
        ${isCurrent ? '' : `<button class="btn-quiet" data-phase="${esc(phase.id)}">${icon(I.next, { lead: true })}Gå hit</button>`}
      </div>`
  }).join('')

  return `
    <h2>${icon(I.tabRegi, { lead: true })}Kveldens regi</h2>
    <p class="lede">Deltakernes skjermer følger fasen du velger her — de oppdateres
    med én gang du bytter.</p>
    ${steps}`
}

// Free-text messages the host pushes to everyone, regardless of role. Distinct
// from hints, which belong to a task and only reach selected Lojale.
//
// Full lifecycle: write a draft, edit it as often as you like, publish when
// you're ready, retract it again, delete it. Drafts are host-only — the
// database filters them out of every player payload, so a half-written
// message can't leak before it's sent.
function renderHostAnnouncements() {
  const list = state.game.announcements || []
  const drafts = list.filter((a) => !a.published)
  const published = list.filter((a) => a.published)

  const card = (a) => `
    <div class="card">
      <div class="title-row" style="display:flex; justify-content:space-between; align-items:center; gap:10px; flex-wrap:wrap;">
        <span class="badge${a.published ? ' ok' : ''}">
          ${a.published
            ? `${icon(I.show, { lead: true })}Publisert ${esc(formatTime(a.published_at ?? a.created_at))}`
            : `${icon(I.edit, { lead: true })}Utkast`}
        </span>
      </div>
      <p>${escMultiline(a.body)}</p>
      <div class="btn-row">
        ${a.published
          ? `<button class="btn-quiet" data-publish-announcement="${esc(a.id)}" data-published="true">${icon(I.hide, { lead: true })}Trekk tilbake</button>`
          : `<button data-publish-announcement="${esc(a.id)}" data-published="false">${icon(I.show, { lead: true })}Publiser</button>`}
        <button class="btn-quiet" data-delete-announcement="${esc(a.id)}">${icon(I.del, { lead: true })}Slett</button>
      </div>
      <details class="editor" data-panel="edit-announcement-${esc(a.id)}">
        <summary>${icon(I.edit, { lead: true })}Rediger</summary>
        <form data-hold data-edit-announcement="${esc(a.id)}">
          <label>Beskjed
            <textarea name="body" maxlength="500" required>${esc(a.body)}</textarea>
          </label>
          <p class="hint">${a.published
            ? 'Endringen vises hos alle med én gang, siden beskjeden er publisert.'
            : 'Utkastet er kun synlig for deg til du publiserer.'}</p>
          <button>${icon(I.save, { lead: true })}Lagre endring</button>
        </form>
      </details>
    </div>`

  return `
    <h2>${icon(I.hint, { lead: true })}Beskjeder til alle</h2>
    <p class="lede">Går til alle deltakere uansett rolle — felles hint, regler eller
    kunngjøringer. Skriv dem gjerne ferdig på forhånd som utkast, og publiser når
    du vil ha dem ut.</p>

    ${drafts.length > 0 ? `<h3>${icon(I.edit, { lead: true })}Utkast (kun du ser disse)</h3>${drafts.map(card).join('')}` : ''}
    ${published.length > 0 ? `<h3>${icon(I.show, { lead: true })}Publisert</h3>${published.map(card).join('')}` : ''}
    ${list.length === 0 ? '<p class="notice">Ingen beskjeder ennå.</p>' : ''}

    <details class="editor" data-panel="new-announcement">
      <summary>${icon(I.add, { lead: true })}Ny beskjed</summary>
      <form data-hold id="new-announcement-form">
        <label>Beskjed
          <textarea name="body" maxlength="500" required
            placeholder="F.eks. «Et av ryktene dere har hørt i kveld er plantet av en sabotør.»"></textarea>
        </label>
        <label style="display:flex; align-items:center; gap:8px; font-weight:400;">
          <input type="checkbox" name="publish_now" style="width:auto;" checked />
          Publiser med én gang
        </label>
        <button>${icon(I.add, { lead: true })}Lagre</button>
      </form>
    </details>`
}

function formatTime(iso) {
  try {
    return new Date(iso).toLocaleTimeString('nb-NO', { hour: '2-digit', minute: '2-digit' })
  } catch {
    return ''
  }
}

function renderHostParticipants(draft) {
  const list = state.game.participants || []
  const rows = list
    .map((p) => {
      if (draft) {
        return `
          <div class="suspect-row">
            <div class="who">
              <strong>${esc(p.display_name)}</strong>
              <div class="tagline">PIN ${esc(p.pin ?? '—')}</div>
            </div>
            <div style="display:flex; gap:6px; align-items:center;">
              <select data-role="${esc(p.id)}">
                <option value="" ${!p.role ? 'selected' : ''}>— ingen rolle —</option>
                <option value="SABOTEUR" ${p.role === 'SABOTEUR' ? 'selected' : ''}>Sabotør</option>
                <option value="LOYAL" ${p.role === 'LOYAL' ? 'selected' : ''}>Lojal</option>
              </select>
              <button class="btn-quiet" data-remove="${esc(p.id)}" aria-label="Fjern ${esc(p.display_name)}">${icon(I.del)}</button>
            </div>
          </div>`
      }
      return `
        <div class="suspect-row">
          <div class="who">
            <strong>${esc(p.display_name)}</strong>
            <div class="tagline">${p.role === 'SABOTEUR' ? 'Sabotør' : p.role === 'LOYAL' ? 'Lojal' : 'Ingen rolle'}${p.active ? '' : ' · inaktiv'} · ${p.points} poeng · PIN ${esc(p.pin ?? '—')}</div>
          </div>
          <button class="btn-quiet" data-active="${esc(p.id)}" data-is-active="${p.active}">
            ${p.active ? 'Sett inaktiv' : 'Sett aktiv'}
          </button>
        </div>`
    })
    .join('')

  return `
    <h2>${icon(I.guestsCount, { lead: true })}Deltakere (${list.length})</h2>
    ${draft
      ? `<p class="lede">Del ut roller før du starter. Det må være minst én Sabotør og én Lojal.</p>`
      : `<p class="lede">Roller kan bare endres i utkast — trykk «Åpne roller igjen» om du må rette noe.</p>`}
    ${rows || `<p class="notice">Ingen har blitt med ennå. Del koden <strong>${esc(state.game.code)}</strong>.</p>`}
    ${draft && list.length >= 2 ? `
      <div class="btn-row">
        <button id="auto-assign-btn">${icon(I.shuffle, { lead: true })}Del ut roller tilfeldig</button>
        <input id="auto-assign-count" type="number" min="1" value="1" style="width:5rem;"
               aria-label="Antall sabotører" />
        <span class="hint">sabotør(er)</span>
      </div>` : ''}`
}

function renderHostObjectives() {
  const participants = state.game.participants || []
  const saboteurs = participants.filter((p) => p.role === 'SABOTEUR')
  const objectives = state.game.objectives || []

  const cards = objectives
    .map((o) => {
      const who = participants.find((p) => p.id === o.participant_id)
      return `
        <div class="card">
          <p class="kicker">${who ? esc(who.display_name) : '?'} · ${o.points} poeng
            ${o.status !== 'assigned' ? ` · <span class="badge${o.status === 'approved' ? ' ok' : o.status === 'rejected' ? ' red' : ''}">${esc(ITEM_STATUS_LABEL[o.status] ?? o.status)}</span>` : ''}
          </p>
          <h3>${esc(o.title)}</h3>
          ${o.description ? `<p>${escMultiline(o.description)}</p>` : ''}
          ${o.status === 'claimed' ? `
            <div class="btn-row">
              <button data-decide-objective="${esc(o.id)}" data-approve="true">${icon(I.ok, { lead: true })}Godkjenn</button>
              <button class="btn-quiet" data-decide-objective="${esc(o.id)}" data-approve="false">Avslå</button>
            </div>` : ''}
          <details class="editor" data-panel="edit-objective-${esc(o.id)}">
            <summary>${icon(I.edit, { lead: true })}Rediger eller slett</summary>
            <form data-hold data-edit-objective="${esc(o.id)}">
              <label>Tittel
                <input name="title" value="${esc(o.title)}" maxlength="160" required
                       list="objective-examples" autocomplete="off" />
              </label>
              <label>Beskrivelse <textarea name="description">${esc(o.description ?? '')}</textarea></label>
              <label>Poeng <input name="points" type="number" min="0" value="${esc(o.points)}" /></label>
              <div class="btn-row">
                <button ${state.pending ? 'disabled' : ''}>
                  ${pendingLabel(`obj-edit-${o.id}`, 'Lagre endring', 'Lagrer …', I.save)}
                </button>
                <button type="button" class="btn-quiet" data-delete-objective="${esc(o.id)}">
                  ${icon(I.del, { lead: true })}Slett målet
                </button>
              </div>
              ${o.status === 'approved'
                ? '<p class="hint">Målet er godkjent — sletter du det, trekkes poengene tilbake.</p>'
                : ''}
            </form>
          </details>
        </div>`
    })
    .join('')

  return `
    <h2>${icon(I.objective, { lead: true })}Mål til Sabotørene</h2>
    ${cards || '<p class="notice">Ingen mål lagt til ennå.</p>'}
    ${saboteurs.length === 0
      ? '<p class="lede">Gi noen rollen Sabotør for å kunne legge til mål.</p>'
      : `
      ${state.library.length > 0 ? `
        <div class="card">
          <p class="kicker">${icon(I.shuffle, { lead: true })}Ferdige mål (${state.library.length})</p>
          <p class="lede">Slipp å finne på alt selv. Trekk et tilfeldig mål, eller velg
          ett fra lista — og bestem om det skal gå til en tilfeldig Sabotør eller en bestemt.</p>
          <form data-hold id="library-form">
            <label>Mål
              <select name="library_id">
                <option value="">🎲 Trekk et tilfeldig mål</option>
                ${state.library.map((l) => `<option value="${esc(l.id)}">${esc(l.title)} (${l.points} p)</option>`).join('')}
              </select>
            </label>
            <label>Til
              <select name="participant_id">${saboteurTargetOptions(saboteurs)}</select>
            </label>
            <button ${state.pending ? 'disabled' : ''}>
              ${pendingLabel('obj-library', 'Legg til fra biblioteket', 'Legger til …', I.add)}
            </button>
          </form>
        </div>` : ''}

      <details class="editor" data-panel="new-objective">
        <summary>${icon(I.add, { lead: true })}Skriv et eget mål</summary>
        <form data-hold id="new-objective-form">
          <label>Til
            <select name="participant_id">${saboteurTargetOptions(saboteurs)}</select>
          </label>
          <label>Tittel
            <input name="title" maxlength="160" required list="objective-examples"
                   autocomplete="off" placeholder="Skriv fritt, eller velg fra lista" />
          </label>
          <p class="hint">Klikk i feltet for å se de ${state.library.length} ferdige forslagene — du kan også skrive helt fritt.</p>
          <label>Beskrivelse (valgfritt) <textarea name="description"></textarea></label>
          <label>Poeng <input name="points" type="number" min="0" value="2" /></label>
          <button ${state.pending ? 'disabled' : ''}>
            ${pendingLabel('obj-new', 'Legg til mål', 'Legger til …', I.add)}
          </button>
        </form>
      </details>`}

    ${objectiveExamplesDatalist()}`
}

// A <datalist> gives the title field a dropdown of every ready-made objective
// while still accepting free text — exactly the "suggest, don't restrict"
// behaviour wanted here. Rendered once and shared by every title input.
function objectiveExamplesDatalist() {
  if (state.library.length === 0) return ''
  return `
    <datalist id="objective-examples">
      ${state.library.map((l) => `<option value="${esc(l.title)}"></option>`).join('')}
    </datalist>`
}

// An empty value means "let the database pick" — the draw happens server-side,
// so the client can't influence who is chosen.
function saboteurTargetOptions(saboteurs) {
  return `
    <option value="">🎲 Tilfeldig Sabotør</option>
    ${saboteurs.map((p) => `<option value="${esc(p.id)}">${esc(p.display_name)}</option>`).join('')}`
}

// Shows the optional link between a hint and a Sabotør objective, and — the
// part that matters mid-party — whether the hint has actually gone out or is
// still waiting for that sabotage to be approved.
function renderTaskTrigger(t) {
  if (!t.trigger_objective_id) return ''
  const done = t.trigger_objective_status === 'approved'
  return `
    <p class="hint">
      ${icon(done ? I.ok : I.locked, { lead: true })}
      Direkte hint, knyttet til målet «${esc(t.trigger_objective_title ?? '—')}».
      ${t.hint_released
        ? 'Sluppet.'
        : done
          ? 'Målet er godkjent — hintet slippes så snart oppgaven godkjennes.'
          : 'Venter: hintet slippes først når det målet er godkjent.'}
      <button class="btn-quiet" data-clear-trigger="${esc(t.id)}">Fjern koblingen</button>
    </p>`
}

// The hint cards the Lojale can be dealt. Host-only and folded away — it's
// content they're meant to earn, not read over your shoulder.
function renderHintLibraryReference() {
  if (state.hintLibrary.length === 0) return ''
  return `
    <details class="editor" data-panel="hint-library">
      <summary>${icon(I.locked, { lead: true })}Hintkortene (${state.hintLibrary.length}) — kun for deg</summary>
      <div class="card">
        <p class="lede">Disse deles ut tilfeldig når du godkjenner en oppgave uten
        egen hinttekst. Konkrete nok til å hjelpe, vage nok til ikke å avsløre noen.</p>
        <ul>${state.hintLibrary.map((h) => `<li>${esc(h.body)}</li>`).join('')}</ul>
      </div>
    </details>`
}

function renderHostTasks() {
  const participants = state.game.participants || []
  const loyals = participants.filter((p) => p.role === 'LOYAL')
  const tasks = state.game.tasks || []
  const objectives = state.game.objectives || []

  const cards = tasks
    .map((t) => {
      const who = participants.find((p) => p.id === t.participant_id)
      return `
        <div class="card">
          <p class="kicker">${who ? esc(who.display_name) : '?'}
            ${t.status !== 'assigned' ? ` · <span class="badge${t.status === 'approved' ? ' ok' : t.status === 'rejected' ? ' red' : ''}">${esc(ITEM_STATUS_LABEL[t.status] ?? t.status)}</span>` : ''}
          </p>
          <h3>${esc(t.title)}</h3>
          ${t.description ? `<p>${escMultiline(t.description)}</p>` : ''}
          <p class="hint">${icon(I.hint, { lead: true })}Hint: ${esc(t.hint_text || '—')}
            (${t.hint_audience === 'all_loyal' ? 'alle Lojale' : 'kun denne spilleren'})</p>
          ${renderTaskTrigger(t)}
          ${t.status === 'claimed' ? `
            <div class="btn-row">
              <button data-decide-task="${esc(t.id)}" data-approve="true">${icon(I.ok, { lead: true })}Godkjenn</button>
              <button class="btn-quiet" data-decide-task="${esc(t.id)}" data-approve="false">Avslå</button>
            </div>` : ''}
          <details class="editor" data-panel="edit-task-${esc(t.id)}">
            <summary>${icon(I.edit, { lead: true })}Rediger eller slett</summary>
            <form data-hold data-edit-task="${esc(t.id)}">
              <label>Tittel <input name="title" value="${esc(t.title)}" maxlength="160" required /></label>
              <label>Beskrivelse <textarea name="description">${esc(t.description ?? '')}</textarea></label>
              <label>Hint <textarea name="hint_text">${esc(t.hint_text ?? '')}</textarea></label>
              <label>Hvem får hintet?
                <select name="hint_audience">
                  <option value="assignee" ${t.hint_audience === 'assignee' ? 'selected' : ''}>Bare denne spilleren</option>
                  <option value="all_loyal" ${t.hint_audience === 'all_loyal' ? 'selected' : ''}>Alle Lojale</option>
                </select>
              </label>
              <div class="btn-row">
                <button ${state.pending ? 'disabled' : ''}>
                  ${pendingLabel(`task-edit-${t.id}`, 'Lagre endring', 'Lagrer …', I.save)}
                </button>
                <button type="button" class="btn-quiet" data-delete-task="${esc(t.id)}">
                  ${icon(I.del, { lead: true })}Slett oppgaven
                </button>
              </div>
              ${t.hint_released
                ? '<p class="hint">Hintet er allerede delt ut — sletter du oppgaven, forsvinner det fra spillerens kort.</p>'
                : ''}
            </form>
          </details>
        </div>`
    })
    .join('')

  return `
    <h2>${icon(I.task, { lead: true })}Oppgaver til de Lojale</h2>
    ${cards || '<p class="notice">Ingen oppgaver lagt til ennå.</p>'}
    ${loyals.length > 0 && state.taskLibrary.length > 0 ? `
      <div class="card">
        <p class="kicker">${icon(I.shuffle, { lead: true })}Ferdige oppgaver (${state.taskLibrary.length})</p>
        <p class="lede">Gi én oppgave av gangen. Når du godkjenner den, får spilleren
        et tilfeldig hintkort — så de lojale blir etterforskere, ikke bare mistenksomme.</p>
        <form data-hold id="task-library-form">
          <label>Oppgave
            <select name="library_id">
              <option value="">🎲 Trekk en tilfeldig oppgave</option>
              ${state.taskLibrary.map((l) => `<option value="${esc(l.id)}">${esc(l.title)}</option>`).join('')}
            </select>
          </label>
          <label>Til
            <select name="participant_id">
              <option value="">🎲 Tilfeldig Lojal</option>
              ${loyals.map((p) => `<option value="${esc(p.id)}">${esc(p.display_name)}</option>`).join('')}
            </select>
          </label>
          <button ${state.pending ? 'disabled' : ''}>
            ${pendingLabel('task-library', 'Legg til fra biblioteket', 'Legger til …', I.add)}
          </button>
        </form>
      </div>` : ''}
    ${renderHintLibraryReference()}
    ${loyals.length > 0 ? `
      <details class="editor" data-panel="new-task">
        <summary>${icon(I.add, { lead: true })}Skriv en egen oppgave</summary>
        <form data-hold id="new-task-form">
          <label>Til
            <select name="participant_id">
              <option value="">🎲 Tilfeldig Lojal</option>
              ${loyals.map((p) => `<option value="${esc(p.id)}">${esc(p.display_name)}</option>`).join('')}
            </select>
          </label>
          <label>Tittel <input name="title" maxlength="160" required placeholder="F.eks. «Få gruppa til å le uten å forklare hvorfor»" /></label>
          <label>Beskrivelse (valgfritt) <textarea name="description"></textarea></label>
          <label>Hint som låses opp
            <textarea name="hint_text"
              placeholder="La stå tom for å gi et tilfeldig hintkort ved godkjenning"></textarea>
          </label>
          <p class="hint">Tomt felt = spilleren får et tilfeldig kort fra hintbiblioteket,
          og aldri det samme kortet to ganger. Skriv du noe her, brukes din tekst i stedet.</p>
          <label>Hvem får hintet?
            <select name="hint_audience">
              <option value="assignee">Bare denne spilleren</option>
              <option value="all_loyal">Alle Lojale</option>
            </select>
          </label>
          <label>Utløses av et sabotørmål (valgfritt)
            <select name="trigger_objective_id">
              <option value="">Ingen — hintet slippes når du godkjenner oppgaven</option>
              ${objectives.map((o) => `
                <option value="${esc(o.id)}">${o.status === 'approved' ? '✓ ' : ''}${esc(o.title)}</option>`).join('')}
            </select>
          </label>
          <p class="hint">Kobler du hintet til et mål, blir det et <strong>direkte hint</strong>:
          det slippes først når den sabotasjen faktisk har skjedd og du har godkjent den.
          ✓ betyr at målet allerede er godkjent.</p>
          <button ${state.pending ? 'disabled' : ''}>
            ${pendingLabel('task-new', 'Legg til oppgave', 'Legger til …', I.add)}
          </button>
        </form>
      </details>`
      : '<p class="lede">Gi noen rollen Lojal for å kunne legge til oppgaver.</p>'}`
}

function renderHostVoting() {
  const g = state.game
  const round = g.current_round

  let body
  if (!round || round.status === 'revealed') {
    body = g.status === 'active'
      ? `<button id="open-round-btn">${icon(I.ballot, { lead: true })}Åpne avstemning</button>`
      : `<p class="lede">Spillet må være aktivt for å åpne en avstemning.</p>`
  } else if (round.status === 'open') {
    body = `
      <p>${icon(I.ballot, { lead: true })}${round.ballot_count} stemme(r) avgitt.
      Stemmene er hemmelige — også for deg — til du lukker og avslører runden.</p>
      <button id="close-round-btn" data-round="${esc(round.id)}">Lukk avstemningen</button>`
  } else {
    body = `
      <p>${icon(I.ballot, { lead: true })}Lukket med ${round.ballot_count} stemme(r). Ikke avslørt ennå.</p>
      <button id="reveal-round-btn" data-round="${esc(round.id)}">${icon(I.reveal, { lead: true })}Avslør resultatet</button>`
  }

  const tally = round?.status === 'revealed' && round.tally?.length > 0
    ? `<table class="tally">
        <thead><tr><th>Deltaker</th><th>Stemmer</th></tr></thead>
        <tbody>${round.tally.map((t) => `<tr><td>${esc(t.display_name)}</td><td>${t.votes}</td></tr>`).join('')}</tbody>
      </table>`
    : ''

  return `
    <h2>${icon(I.ballot, { lead: true })}Avstemning</h2>
    <div class="card">${body}${tally}</div>`
}

// --- Player "my brief" -------------------------------------------------------

function renderPlayer() {
  const b = state.brief

  if (b.status === 'ended' && b.reveal) return renderPlayerReveal(b)

  const parts = [`
    <header class="case-header">
      <div class="case-no">
        <span class="brand">${icon(I.saboteur, { lead: true })}Skjult agenda · ${esc(b.code)}</span>
        <span>${esc(b.my_name)}</span>
      </div>
      <h1>${esc(b.title)}</h1>
      <span class="badge${b.status === 'voting' ? ' red' : ''}">${esc(STATUS_LABEL[b.status] ?? b.status)}</span>
    </header>
    ${errorBlock()}

    <div class="phase-hint">
      <p class="kicker">Nå skjer det:</p>
      <p>${esc(saboteurPhase(b.phase).player)}</p>
    </div>

    ${renderPlayerAnnouncements(b)}
    ${renderPlayerIntro(b)}`]

  // The PIN is what gets a guest back in if they clear their browser or tap
  // "forlat" by mistake, so it's shown prominently while they're waiting and
  // stays available (folded) once the game is running.
  parts.push(
    b.status === 'draft'
      ? `<div class="card">
           <p class="kicker">${icon(I.locked, { lead: true })}Din personlige kode</p>
           <div class="code-display">${esc(b.my_pin ?? '····')}</div>
           <p class="hint">Skriv den ned. Mister du tilgangen, kommer du tilbake med
           spillkode, navnet ditt og denne koden.</p>
         </div>`
      : `<details class="editor" data-panel="my-pin">
           <summary>${icon(I.locked, { lead: true })}Din personlige kode (for å komme tilbake)</summary>
           <div class="card"><div class="code-display">${esc(b.my_pin ?? '····')}</div></div>
         </details>`
  )

  if (b.status === 'draft') {
    parts.push(`
      <div class="card">
        <p class="kicker">Venter</p>
        <h3>Du er med!</h3>
        <p>Verten deler ut roller snart. ${b.participant_count} deltaker(e) er med så langt.
        Hold telefonen for deg selv — rollen din er hemmelig.</p>
      </div>`)
  } else if (!b.my_role) {
    parts.push(`<div class="card"><p>Du har ikke fått en rolle i dette spillet.</p></div>`)
  } else {
    parts.push(`
      <div class="card">
        <p class="kicker">Din rolle — vis den ikke til noen</p>
        <h3>${b.my_role === 'SABOTEUR' ? `${icon(I.saboteur, { lead: true })}Sabotør` : `${icon(I.loyal, { lead: true })}Lojal`}</h3>
        <p class="lede">${b.my_role === 'SABOTEUR'
          ? 'Du har hemmelige mål. Få dem gjennomført uten å bli avslørt.'
          : 'Du er lojal. Gjør oppgavene dine, og finn ut hvem som saboterer.'}</p>
        ${b.my_role === 'SABOTEUR' && b.fellow_saboteurs.length > 0
          ? `<p><strong>Dine medsammensvorne:</strong> ${b.fellow_saboteurs.map((f) => esc(f.display_name)).join(', ')}</p>`
          : ''}
      </div>`)

    if (b.my_role === 'SABOTEUR') {
      parts.push(`<h2>${icon(I.objective, { lead: true })}Dine mål</h2>`)
      parts.push(b.objectives.length === 0
        ? '<p class="notice">Ingen mål ennå.</p>'
        : b.objectives.map((o) => `
            <div class="card">
              <p class="kicker">${o.points} poeng${o.status !== 'assigned' ? ` · ${esc(ITEM_STATUS_LABEL[o.status] ?? o.status)}` : ''}</p>
              <h3>${esc(o.title)}</h3>
              ${o.description ? `<p>${escMultiline(o.description)}</p>` : ''}
              ${o.status === 'assigned' ? `<button data-claim-objective="${esc(o.id)}">${icon(I.claim, { lead: true })}Jeg har gjort dette</button>` : ''}
            </div>`).join(''))
    } else {
      parts.push(`<h2>${icon(I.task, { lead: true })}Dine oppgaver</h2>`)
      parts.push(b.tasks.length === 0
        ? '<p class="notice">Ingen oppgaver ennå.</p>'
        : b.tasks.map((t) => `
            <div class="card">
              ${t.status !== 'assigned' ? `<p class="kicker">${esc(ITEM_STATUS_LABEL[t.status] ?? t.status)}</p>` : ''}
              <h3>${esc(t.title)}</h3>
              ${t.description ? `<p>${escMultiline(t.description)}</p>` : ''}
              ${t.status === 'assigned' ? `<button data-claim-task="${esc(t.id)}">${icon(I.claim, { lead: true })}Jeg har gjort dette</button>` : ''}
            </div>`).join(''))

      if (b.hints.length > 0) {
        parts.push(`
          <div class="card">
            <p class="kicker">${icon(I.hint, { lead: true })}Hint du har låst opp</p>
            ${b.hints.map((h) => `<p>${escMultiline(h.hint_text)}</p>`).join('')}
          </div>`)
      }
    }

    if (state.voteStatus?.can_vote) {
      parts.push(`
        <div class="card">
          <p class="kicker">${icon(I.ballot, { lead: true })}Avstemningen er åpen</p>
          <form data-hold id="vote-form">
            <label for="vote-target">Hvem mistenker du?</label>
            <select id="vote-target" name="target">
              ${state.ballotTargets.map((t) => `<option value="${esc(t.participant_id)}">${esc(t.display_name)}</option>`).join('')}
            </select>
            <button>${icon(I.ballot, { lead: true })}Stem</button>
          </form>
        </div>`)
    } else if (state.voteStatus?.round_open && state.voteStatus?.already_voted) {
      parts.push(`<div class="card"><p>${icon(I.ok, { lead: true })}Du har stemt. Vent på verten.</p></div>`)
    }
  }

  parts.push(`
    <footer class="app-footer">
      <span>Skjult agenda</span>
      <a href="#" id="leave-link">${icon(I.leave, { lead: true })}Forlat spillet</a>
    </footer>`)

  return parts.join('')
}

// The rules of engagement. Open by default while people are still waiting to
// start (that's when they need to read it), folded away once play is under way
// so it doesn't push the role card down the screen.
function renderPlayerIntro(b) {
  const intro = (b.intro || '').trim()
  if (!intro) return ''
  const openWhileWaiting = b.status === 'draft' ? ' open' : ''
  return `
    <details class="editor" data-panel="intro"${openWhileWaiting}>
      <summary>${icon(I.briefing, { lead: true })}Slik fungerer Skjult agenda</summary>
      <div class="card"><p>${escMultiline(intro)}</p></div>
    </details>`
}

// Host announcements — shown to every participant regardless of role.
function renderPlayerAnnouncements(b) {
  const list = b.announcements || []
  if (list.length === 0) return ''
  return `
    <div class="card">
      <p class="kicker">${icon(I.hint, { lead: true })}Beskjed fra verten</p>
      ${list.map((a) => `<p>${escMultiline(a.body)}</p>`).join('<hr class="divider" style="margin:12px 0;">')}
    </div>`
}

function renderPlayerReveal(b) {
  const rows = b.reveal.participants
    .map((p) => `
      <div class="suspect-row">
        <div class="who"><strong>${esc(p.display_name)}</strong></div>
        <span class="badge${p.role === 'SABOTEUR' ? ' red' : ' ok'}">${p.role === 'SABOTEUR' ? 'Sabotør' : p.role === 'LOYAL' ? 'Lojal' : 'Ingen rolle'}</span>
      </div>`)
    .join('')

  const score = b.reveal.leaderboard
    ? `<table class="tally">
        <thead><tr><th>Spiller</th><th>Poeng</th></tr></thead>
        <tbody>${b.reveal.leaderboard.map((x) => `<tr><td>${esc(x.display_name)}</td><td>${x.points}</td></tr>`).join('')}</tbody>
      </table>`
    : `<p class="lede">Dine poeng: <strong>${esc(b.reveal.my_points)}</strong></p>`

  return `
    <header class="case-header">
      <div class="case-no"><span class="brand">${icon(I.saboteur, { lead: true })}Skjult agenda</span><span>${esc(b.my_name)}</span></div>
      <h1>${esc(b.title)}</h1>
    </header>
    <div class="reveal-card">
      <span class="stamp">${icon(I.reveal, { lead: true })}Rollene er avslørt</span>
      ${rows}
    </div>
    ${score}
    <footer class="app-footer">
      <span>Skjult agenda</span>
      <a href="#" id="leave-link">${icon(I.leave, { lead: true })}Avslutt</a>
    </footer>`
}

// --------------------------------------------------------------------------
// Event wiring (selectors only match what the current screen rendered)
// --------------------------------------------------------------------------

function wireEvents() {
  const bind = (sel, ev, fn) => { const el = app.querySelector(sel); if (el) el.addEventListener(ev, fn) }

  bind('#create-form', 'submit', onCreateGame)
  bind('#join-form', 'submit', onJoinGame)
  bind('#rejoin-form', 'submit', onRejoinGame)
  app.querySelectorAll('[data-resume]').forEach((btn) =>
    btn.addEventListener('click', () => resumeGame(btn.dataset.resume))
  )

  const leave = app.querySelector('#leave-link')
  if (leave) leave.addEventListener('click', (e) => { e.preventDefault(); leaveGame() })

  // --- host ---
  app.querySelectorAll('[data-status]').forEach((btn) =>
    btn.addEventListener('click', () => hostAction('host_set_saboteur_status', { p_status: btn.dataset.status }))
  )
  app.querySelectorAll('[data-phase]').forEach((btn) =>
    btn.addEventListener('click', () => hostAction('host_set_saboteur_phase', { p_phase: btn.dataset.phase }))
  )
  bind('#new-announcement-form', 'submit', async (e) => {
    e.preventDefault()
    const f = e.target.elements
    const publishNow = f.publish_now ? f.publish_now.checked : true
    const body = f.body.value
    state.error = ''
    try {
      const created = await rpc('host_upsert_announcement', { p_host_token: hostToken(), p_body: body })
      if (publishNow) {
        await rpc('host_set_announcement_published', {
          p_host_token: hostToken(), p_announcement_id: created.id, p_published: true,
        })
      }
      await refreshHost()
      showFlash(publishNow ? 'Beskjed publisert' : 'Utkast lagret')
    } catch (err) {
      // If 00015 hasn't been run yet, the draft functions don't exist — but
      // the older publish-immediately function from 00013 might. Fall back to
      // it so the host can still get a message out mid-party; drafts simply
      // aren't available until the migration is applied.
      if (/could not find the function|schema cache|does not exist/i.test(err?.message || '')) {
        try {
          await rpc('host_publish_announcement', { p_host_token: hostToken(), p_body: body })
          await refreshHost()
          showFlash('Beskjed publisert')
          return
        } catch (fallbackErr) {
          state.error = friendlyError(fallbackErr, 'host_upsert_announcement')
          render()
          return
        }
      }
      state.error = friendlyError(err, 'host_upsert_announcement')
      render()
    }
  })
  app.querySelectorAll('[data-edit-announcement]').forEach((form) =>
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      hostAction('host_upsert_announcement', {
        p_announcement_id: form.dataset.editAnnouncement,
        p_body: e.target.elements.body.value,
      }, 'Lagret')
    })
  )
  app.querySelectorAll('[data-publish-announcement]').forEach((btn) =>
    btn.addEventListener('click', () => {
      const isPublished = btn.dataset.published === 'true'
      hostAction('host_set_announcement_published', {
        p_announcement_id: btn.dataset.publishAnnouncement,
        p_published: !isPublished,
      }, isPublished ? 'Trukket tilbake' : 'Publisert')
    })
  )
  app.querySelectorAll('[data-delete-announcement]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Slette denne beskjeden?')) {
        hostAction('host_delete_announcement', { p_announcement_id: btn.dataset.deleteAnnouncement }, 'Slettet')
      }
    })
  )
  bind('#end-btn', 'click', () => {
    if (state.confirmEnd) doEndGame()
    else { state.confirmEnd = true; render() }
  })
  bind('#end-cancel', 'click', () => { state.confirmEnd = false; render() })

  const knowEach = app.querySelector('#know-each-other')
  if (knowEach) knowEach.addEventListener('change', () => hostAction('host_set_know_each_other', { p_enabled: knowEach.checked }))
  const showLb = app.querySelector('#show-leaderboard')
  if (showLb) showLb.addEventListener('change', () => hostAction('host_set_show_leaderboard', { p_enabled: showLb.checked }))

  app.querySelectorAll('[data-role]').forEach((sel) =>
    sel.addEventListener('change', () =>
      hostAction('host_set_participant_role', { p_participant_id: sel.dataset.role, p_role: sel.value || null })
    )
  )
  app.querySelectorAll('[data-remove]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Fjerne denne deltakeren fra spillet?')) {
        hostAction('host_remove_participant', { p_participant_id: btn.dataset.remove }, 'Fjernet')
      }
    })
  )
  app.querySelectorAll('[data-active]').forEach((btn) =>
    btn.addEventListener('click', () =>
      hostAction('host_set_participant_active', {
        p_participant_id: btn.dataset.active,
        p_active: btn.dataset.isActive !== 'true',
      })
    )
  )
  bind('#auto-assign-btn', 'click', () => {
    const count = Number(app.querySelector('#auto-assign-count')?.value) || 1
    hostAction('host_auto_assign_roles', { p_saboteur_count: count }, 'Roller delt ut')
  })

  bind('#intro-form', 'submit', (e) => {
    e.preventDefault()
    hostAction('host_set_saboteur_intro', { p_intro: e.target.elements.intro.value }, 'Introduksjon lagret')
  })

  app.querySelectorAll('[data-host-tab]').forEach((btn) =>
    btn.addEventListener('click', () => {
      state.hostTab = btn.dataset.hostTab
      render()
    })
  )

  bind('#library-form', 'submit', (e) => {
    e.preventDefault()
    const f = e.target.elements
    // Empty select value -> null -> the database draws at random.
    hostActionPending('obj-library', 'host_add_objective_from_library', {
      p_library_id: f.library_id.value || null,
      p_participant_id: f.participant_id.value || null,
    }, 'Mål lagt til')
  })

  bind('#task-library-form', 'submit', (e) => {
    e.preventDefault()
    const f = e.target.elements
    hostActionPending('task-library', 'host_add_task_from_library', {
      p_library_id: f.library_id.value || null,
      p_participant_id: f.participant_id.value || null,
    }, 'Oppgave lagt til')
  })

  bind('#new-objective-form', 'submit', (e) => {
    e.preventDefault()
    const f = e.target.elements
    hostActionPending('obj-new', 'host_upsert_objective', {
      p_participant_id: f.participant_id.value || null, // null = random Sabotør
      p_title: f.title.value,
      p_description: f.description.value,
      p_points: Number(f.points.value) || 0,
    }, 'Mål lagt til')
  })

  app.querySelectorAll('[data-edit-objective]').forEach((form) =>
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      const id = form.dataset.editObjective
      hostActionPending(`obj-edit-${id}`, 'host_upsert_objective', {
        p_objective_id: id,
        p_title: f.title.value,
        p_description: f.description.value,
        p_points: Number(f.points.value) || 0,
      }, 'Lagret')
    })
  )
  app.querySelectorAll('[data-delete-objective]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Slette dette målet? Er det godkjent, trekkes poengene tilbake.')) {
        hostAction('host_delete_objective', { p_objective_id: btn.dataset.deleteObjective }, 'Målet er slettet')
      }
    })
  )

  app.querySelectorAll('[data-edit-task]').forEach((form) =>
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      const id = form.dataset.editTask
      hostActionPending(`task-edit-${id}`, 'host_upsert_task', {
        p_task_id: id,
        p_title: f.title.value,
        p_description: f.description.value,
        p_hint_text: f.hint_text.value,
        p_hint_audience: f.hint_audience.value,
      }, 'Lagret')
    })
  )
  app.querySelectorAll('[data-delete-task]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Slette denne oppgaven? Et hint som alt er delt ut forsvinner også.')) {
        hostAction('host_delete_task', { p_task_id: btn.dataset.deleteTask }, 'Oppgaven er slettet')
      }
    })
  )
  app.querySelectorAll('[data-decide-objective]').forEach((btn) =>
    btn.addEventListener('click', () => {
      const approve = btn.dataset.approve === 'true'
      hostAction('host_decide_objective_claim', {
        p_objective_id: btn.dataset.decideObjective, p_approve: approve,
      }, approve ? 'Godkjent' : 'Avslått')
    })
  )

  bind('#new-task-form', 'submit', (e) => {
    e.preventDefault()
    const f = e.target.elements
    hostActionPending('task-new', 'host_upsert_task', {
      p_participant_id: f.participant_id.value || null, // null = random Lojal
      p_title: f.title.value,
      p_description: f.description.value,
      p_hint_text: f.hint_text.value,
      p_hint_audience: f.hint_audience.value,
      p_trigger_objective_id: f.trigger_objective_id?.value || null,
    }, 'Oppgave lagt til')
  })
  app.querySelectorAll('[data-clear-trigger]').forEach((btn) =>
    btn.addEventListener('click', () =>
      hostAction('host_clear_task_trigger', { p_task_id: btn.dataset.clearTrigger }, 'Kobling fjernet')
    )
  )
  app.querySelectorAll('[data-decide-task]').forEach((btn) =>
    btn.addEventListener('click', () => {
      const approve = btn.dataset.approve === 'true'
      hostAction('host_decide_task_claim', {
        p_task_id: btn.dataset.decideTask, p_approve: approve,
      }, approve ? 'Godkjent' : 'Avslått')
    })
  )

  bind('#open-round-btn', 'click', () => hostAction('host_open_voting_round', {}, 'Avstemning åpnet'))
  const closeBtn = app.querySelector('#close-round-btn')
  if (closeBtn) closeBtn.addEventListener('click', () => hostAction('host_close_voting_round', { p_round_id: closeBtn.dataset.round }, 'Lukket'))
  const revealBtn = app.querySelector('#reveal-round-btn')
  if (revealBtn) revealBtn.addEventListener('click', () => hostAction('host_reveal_voting_round', { p_round_id: revealBtn.dataset.round }, 'Avslørt'))

  // Audit log loads lazily on first expand — it's rarely opened.
  const audit = app.querySelector('#audit-details')
  if (audit) {
    audit.addEventListener('toggle', async () => {
      if (!audit.open) return
      const box = app.querySelector('#audit-container')
      try {
        const entries = await rpc('host_get_saboteur_audit', { p_host_token: hostToken() })
        box.innerHTML = entries.length === 0
          ? '<p class="notice">Ingen hendelser ennå.</p>'
          : `<table class="tally"><thead><tr><th>Tid</th><th>Handling</th></tr></thead><tbody>
              ${entries.map((e) => `<tr><td>${esc(new Date(e.created_at).toLocaleString('nb-NO'))}</td><td>${esc(e.action)}</td></tr>`).join('')}
            </tbody></table>`
      } catch (err) {
        box.innerHTML = `<p class="error">${esc(err.message)}</p>`
      }
    })
  }

  // --- player ---
  app.querySelectorAll('[data-claim-objective]').forEach((btn) =>
    btn.addEventListener('click', () => playerAction('claim_saboteur_objective', { p_objective_id: btn.dataset.claimObjective }, 'Sendt til verten'))
  )
  app.querySelectorAll('[data-claim-task]').forEach((btn) =>
    btn.addEventListener('click', () => playerAction('claim_saboteur_task', { p_task_id: btn.dataset.claimTask }, 'Sendt til verten'))
  )
  bind('#vote-form', 'submit', (e) => {
    e.preventDefault()
    playerAction('cast_saboteur_ballot', {
      p_round_id: state.voteStatus?.round_id,
      p_target_participant_id: e.target.elements.target.value,
    }, 'Stemme avgitt')
  })
}
