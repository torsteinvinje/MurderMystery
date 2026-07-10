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
import { PHASES, phaseIndex } from '../lib/phases.js'
import { loadHost, saveHost, clearHost } from '../lib/tokens.js'

const app = document.querySelector('#app')

// The host dashboard's tabs; also the valid values for the URL hash.
const TAB_IDS = ['regi', 'spillere', 'mistenkte', 'polaroider', 'bevis', 'avsloring']

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
  evidence: [],
  evidenceError: '',
  showSolution: false, // host may be projecting the screen — keep it hidden by default
  confirmReveal: false, // two-tap guard on the big red button
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

  // Evidence is loaded separately and defensively: if migration 00004 hasn't
  // been run yet, a missing RPC must NOT break the rest of the dashboard —
  // the Bevis tab shows a guiding error instead.
  try {
    state.evidence = await rpc('host_list_evidence', { p_host_token: t })
    state.evidenceError = ''
  } catch (err) {
    state.evidence = []
    state.evidenceError = err.message
  }
  render()
}

// Norwegian date/time for evidence timestamps.
function formatDate(iso) {
  try {
    return new Date(iso).toLocaleString('nb-NO', { dateStyle: 'medium', timeStyle: 'short' })
  } catch {
    return ''
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
      <header class="case-header">
        <div class="case-no"><span class="brand">${icon(I.brand, { lead: true })}MurderMystery</span><span>Vertskontroll</span></div>
        <h1>Start en fest</h1>
        <p class="lede">Du er verten: du styrer kvelden, deler ut roller, legger fram
        bevis — og du er den eneste som vet hvem morderen er. Velg et mysterium og
        trykk på knappen, så får du en firetegns festkode gjestene bruker for å bli med.</p>
      </header>

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
    ['polaroider', 'Polaroider', I.tabPolaroids],
    ['bevis', 'Bevis', I.tabEvidence],
    ['avsloring', 'Avsløring', I.tabReveal],
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
    case 'bevis': return renderBevis()
    case 'avsloring': return renderAvsloring()
    default: return ''
  }
}

// --- Bevis: the host's private, party-scoped evidence locker -----------------

function renderBevis() {
  const list = state.evidence || []
  let body
  if (state.evidenceError) {
    body = `<p class="error">${icon(I.warn, { lead: true })}Kunne ikke laste bevis. Er databaseoppdateringen «00004_evidence.sql» kjørt i Supabase?</p>`
  } else if (list.length === 0) {
    body = `<p class="notice">Ingen bevis lagt til ennå. Bruk skjemaet under for å legge
      til det første — bevisene vises bare her hos deg, aldri til gjestene.</p>`
  } else {
    body = list
      .map(
        (e) => `
      <div class="card">
        ${e.image_url ? `<img src="${esc(e.image_url)}" alt="${esc(e.title)}" style="max-width:100%;border-radius:var(--radius-sm);display:block;margin-bottom:10px;" />` : ''}
        <div class="title-row" style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;">
          <h3 style="margin:0;">${esc(e.title)}</h3>
          <button class="btn-quiet" data-delete-evidence="${esc(e.id)}">${icon(I.del, { lead: true })}Slett</button>
        </div>
        ${e.description ? `<p>${escMultiline(e.description)}</p>` : ''}
        <p class="hint">${icon(I.time, { lead: true })}Lagt til ${esc(formatDate(e.created_at))}</p>
      </div>`
      )
      .join('')
  }

  return `
    <h2>${icon(I.tabEvidence, { lead: true })}Bevis</h2>
    <p class="lede">Din private saksmappe for denne festen — bilder, notater og spor.
    Kun du ser dem; de vises aldri til gjestene.</p>
    ${body}
    <hr class="divider" />
    <h3>${icon(I.add, { lead: true })}Nytt bevis</h3>
    <form data-hold id="new-evidence-form">
      <label>Tittel <input name="title" maxlength="160" required placeholder="F.eks. «Blodig serviett»" /></label>
      <label>Beskrivelse (valgfritt) <textarea name="description" placeholder="Hva er dette, og hvorfor er det interessant?"></textarea></label>
      <label>Bilde-URL (valgfritt) <input name="image_url" placeholder="https://…" /></label>
      <button>${icon(I.add, { lead: true })}Legg til bevis</button>
    </form>`
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

  return `
    <h2>${icon(I.tabRegi, { lead: true })}Kveldens regi</h2>
    <p class="lede">Spillernes skjermer følger fasen du velger her — de oppdateres i
    samme øyeblikk du bytter.</p>
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
    <h2>${icon(I.tabPolaroids, { lead: true })}Polaroider — bevisene</h2>
    <p class="lede">Avslør dem ett og ett i ledetråd-fasen, og les dem høyt.
    Skjulte polaroider er usynlige for gjestene.</p>
    ${cards}
    <hr class="divider" />
    <h3>${icon(I.add, { lead: true })}Nytt polaroid</h3>
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

  // Bevis: add / delete evidence.
  const newEvidenceForm = app.querySelector('#new-evidence-form')
  if (newEvidenceForm) {
    newEvidenceForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      hostAction('host_add_evidence', {
        p_title: f.title.value,
        p_description: f.description.value,
        p_image_url: f.image_url.value || null,
      }, 'Bevis lagt til')
    })
  }
  app.querySelectorAll('[data-delete-evidence]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Slette dette beviset for godt?')) {
        hostAction('host_delete_evidence', { p_evidence_id: btn.dataset.deleteEvidence }, 'Slettet')
      }
    })
  )

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
