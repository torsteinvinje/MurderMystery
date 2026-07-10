// Studio view ("verkstedet"): create and edit your own mysteries — story,
// suspects (including who the murderer is), and polaroid evidence. Every
// change is written straight to Supabase through the owner_* RPCs, guarded
// by a secret owner_token per mystery (kept in localStorage, like the host
// and player tokens).

import '../styles/main.css'
import { rpc } from '../lib/supabase.js'
import { esc, escMultiline } from '../lib/util.js'
import { icon, I } from '../lib/icons.js'
import { topNav, wireTopNav } from '../lib/nav.js'
import { loadStudioList, saveStudioList } from '../lib/tokens.js'

const app = document.querySelector('#app')

const state = {
  screen: 'loading', // 'loading' | 'list' | 'editor'
  error: '',
  busy: false,
  flash: '',
  mine: [], // [{ mystery_id, owner_token, title, suspect_count, ready }]
  catalog: [], // list_mysteries() — used to find the builtin to copy from
  currentToken: null,
  data: null, // owner_get_mystery result: { mystery, suspects, polaroids }
}

let flashTimer = null

init()

async function init() {
  await refreshList()
  state.screen = 'list'
  render()
}

// Validate every saved owner token and hydrate titles/counts. Tokens whose
// mystery is gone (deleted elsewhere) are silently dropped.
async function refreshList() {
  const saved = loadStudioList()
  const results = await Promise.allSettled(
    saved.map((entry) => rpc('owner_get_mystery', { p_owner_token: entry.owner_token }))
  )

  const alive = []
  state.mine = []
  results.forEach((result, i) => {
    if (result.status !== 'fulfilled') return
    const { mystery, suspects } = result.value
    alive.push(saved[i])
    state.mine.push({
      ...saved[i],
      title: mystery.title,
      suspect_count: suspects.length,
      ready: suspects.length >= 2 && suspects.filter((s) => s.is_killer).length === 1,
    })
  })
  if (alive.length !== saved.length) saveStudioList(alive)

  try {
    state.catalog = await rpc('list_mysteries')
  } catch {
    state.catalog = []
  }
}

// --------------------------------------------------------------------------
// Actions
// --------------------------------------------------------------------------

function showFlash(text) {
  state.flash = text
  render()
  clearTimeout(flashTimer)
  flashTimer = setTimeout(() => {
    state.flash = ''
    render()
  }, 1600)
}

// Run an owner RPC against the open mystery, then re-fetch it.
async function ownerAction(name, params = {}, flashText = 'Lagret') {
  state.error = ''
  try {
    await rpc(name, { p_owner_token: state.currentToken, ...params })
    state.data = await rpc('owner_get_mystery', { p_owner_token: state.currentToken })
    showFlash(flashText)
  } catch (err) {
    state.error = err.message
    render()
  }
}

async function createMystery(title, copyFromBuiltin) {
  state.busy = true
  state.error = ''
  render()
  try {
    const builtin = state.catalog.find((m) => m.is_builtin)
    const created = await rpc('create_mystery', {
      p_title: title,
      p_copy_from: copyFromBuiltin && builtin ? builtin.id : null,
    })
    saveStudioList([...loadStudioList(), { mystery_id: created.mystery_id, owner_token: created.owner_token }])
    await openEditor(created.owner_token)
  } catch (err) {
    state.error = err.message
    state.busy = false
    render()
  }
}

async function openEditor(ownerToken) {
  state.busy = false
  state.error = ''
  state.currentToken = ownerToken
  state.screen = 'loading'
  render()
  try {
    state.data = await rpc('owner_get_mystery', { p_owner_token: ownerToken })
    state.screen = 'editor'
  } catch (err) {
    state.error = err.message
    state.currentToken = null
    state.screen = 'list'
    await refreshList()
  }
  render()
}

async function backToList() {
  state.currentToken = null
  state.data = null
  state.screen = 'loading'
  render()
  await refreshList()
  state.screen = 'list'
  render()
}

async function deleteMystery() {
  if (!confirm('Slette hele mysteriet for godt? Fester som allerede er startet, beholder sin kopi.')) return
  state.error = ''
  try {
    await rpc('owner_delete_mystery', { p_owner_token: state.currentToken })
    saveStudioList(loadStudioList().filter((e) => e.owner_token !== state.currentToken))
    await backToList()
  } catch (err) {
    state.error = err.message
    render()
  }
}

// --------------------------------------------------------------------------
// Rendering
// --------------------------------------------------------------------------

function render() {
  if (state.screen === 'loading') {
    app.innerHTML = `<div class="sheet"><p class="notice">Åpner verkstedet …</p></div>`
    return
  }
  if (state.screen === 'list') renderList()
  else renderEditor()
  if (state.flash) {
    app.insertAdjacentHTML('beforeend', `<div class="flash">${icon(I.ok, { lead: true })}${esc(state.flash)}</div>`)
  }
}

function renderList() {
  const mineCards = state.mine
    .map(
      (m) => `
      <div class="mystery-card">
        <div class="title-row">
          <strong>${esc(m.title)}</strong>
          <span class="badge${m.ready ? ' ok' : ''}">${m.ready ? `${icon(I.ready, { lead: true })}Klart til å spilles` : `${icon(I.unfinished, { lead: true })}Uferdig`}</span>
        </div>
        <p class="meta">${icon(I.guestsCount, { lead: true })}${m.suspect_count} mistenkte</p>
        <button class="btn-quiet" data-open="${esc(m.owner_token)}">${icon(I.edit, { lead: true })}Rediger</button>
      </div>`
    )
    .join('')

  app.innerHTML = `
    <div class="sheet">
      ${topNav({ active: 'studio' })}
      <header class="case-header">
        <div class="case-no"><span class="brand">${icon(I.brand, { lead: true })}MurderMystery</span><span>Verkstedet</span></div>
        <h1>Lag ditt eget mysterium</h1>
        <p class="lede">Skriv historien, dikt opp de mistenkte, pek ut morderen og legg
        inn bevis. Alt lagres i databasen — og mysteriet dukker opp som valg når en
        vert starter en ny fest.</p>
      </header>

      ${state.error ? `<p class="error">${icon(I.error, { lead: true })}${esc(state.error)}</p>` : ''}

      <h2>${icon(I.studio, { lead: true })}Mine mysterier</h2>
      ${mineCards || `<p class="notice">Du har ingen egne mysterier på denne enheten ennå.</p>`}

      <h2>${icon(I.add, { lead: true })}Nytt mysterium</h2>
      <div class="card">
        <form id="new-mystery-form">
          <label for="nm-title">Tittel</label>
          <input id="nm-title" name="title" maxlength="120" required
                 placeholder="F.eks. «Giftmordet på julebordet»" />
          <label style="display:flex; align-items:center; gap:8px; font-weight:400;">
            <input type="checkbox" name="copy" style="width:auto;" />
            Start med en kopi av «Ljåmordet på grillfesten» (lettere å tilpasse enn å starte blankt)
          </label>
          <button ${state.busy ? 'disabled' : ''}>${state.busy ? 'Oppretter …' : `${icon(I.add, { lead: true })}Opprett mysterium`}</button>
        </form>
      </div>

      <footer class="app-footer">
        <span>MurderMystery — Verkstedet</span>
      </footer>
    </div>`

  wireTopNav(app)
  app.querySelectorAll('[data-open]').forEach((btn) =>
    btn.addEventListener('click', () => openEditor(btn.dataset.open))
  )
  app.querySelector('#new-mystery-form').addEventListener('submit', (e) => {
    e.preventDefault()
    createMystery(e.target.elements.title.value, e.target.elements.copy.checked)
  })
}

function renderEditor() {
  const { mystery, suspects, polaroids } = state.data
  const killerCount = suspects.filter((s) => s.is_killer).length
  const ready = suspects.length >= 2 && killerCount === 1

  app.innerHTML = `
    <div class="sheet">
      ${topNav({ active: 'studio' })}
      <header class="case-header">
        <div class="case-no"><span class="brand">${icon(I.brand, { lead: true })}MurderMystery</span><span>Verkstedet</span></div>
        <h1>${esc(mystery.title)}</h1>
        <p>
          <span class="badge${ready ? ' ok' : ' red'}">
            ${ready
              ? `${icon(I.ready, { lead: true })}Klart til å spilles`
              : `${icon(I.unfinished, { lead: true })}${killerCount === 0 ? 'Mangler morder' : killerCount > 1 ? 'Flere mordere valgt' : 'Trenger minst to mistenkte'}`}
          </span>
        </p>
      </header>

      ${state.error ? `<p class="error">${icon(I.error, { lead: true })}${esc(state.error)}</p>` : ''}

      <h2>${icon(I.briefing, { lead: true })}Historien</h2>
      <div class="card">
        <form id="story-form">
          <label>Tittel</label>
          <input name="title" value="${esc(mystery.title)}" maxlength="120" required />
          <label>Introduksjon (åstedsrapporten verten leser høyt)</label>
          <textarea name="intro" rows="5">${esc(mystery.intro)}</textarea>
          <label>Oppklaringen (leses høyt ved avsløringen — hold den hemmelig!)</label>
          <textarea name="resolution" rows="5">${esc(mystery.resolution)}</textarea>
          <button>${icon(I.save, { lead: true })}Lagre historien</button>
        </form>
      </div>

      <h2>${icon(I.suspects, { lead: true })}Mistenkte (${suspects.length})</h2>
      <p class="lede">Kryss av «Morderen» på nøyaktig én. Spillerne får aldri vite hvem
      det er før verten avslører.</p>
      ${suspects.map(renderSuspectEditor).join('')}

      <h3>${icon(I.add, { lead: true })}Ny mistenkt</h3>
      <div class="card">
        <form id="new-suspect-form">
          <label>Navn</label>
          <input name="name" maxlength="80" required placeholder="F.eks. «Kokken»" />
          <label>Kort beskrivelse</label>
          <input name="tagline" maxlength="120" placeholder="F.eks. «Kjøkkensjefen med kort lunte»" />
          <button>${icon(I.add, { lead: true })}Legg til mistenkt</button>
        </form>
      </div>

      <h2>${icon(I.evidence, { lead: true })}Polaroider — bevisene (${polaroids.length})</h2>
      ${polaroids.map(renderPolaroidEditor).join('')}

      <h3>${icon(I.add, { lead: true })}Nytt bevis</h3>
      <div class="card">
        <form id="new-polaroid-form">
          <label>Tittel</label>
          <input name="title" maxlength="120" required placeholder="F.eks. «Sigarettsneipen»" />
          <label>Bildetekst</label>
          <textarea name="caption" placeholder="Hva viser bildet, og hvorfor er det interessant?"></textarea>
          <button>${icon(I.add, { lead: true })}Legg til bevis</button>
        </form>
      </div>

      <hr class="divider" />
      <div class="btn-row">
        <button class="btn-quiet" id="back-btn">${icon(I.back, { lead: true })}Mine mysterier</button>
        ${ready ? `<button id="host-btn">${icon(I.play, { lead: true })}Start fest med dette mysteriet</button>` : ''}
        <button class="btn-danger" id="delete-mystery-btn">${icon(I.del, { lead: true })}Slett mysteriet</button>
      </div>

      <footer class="app-footer">
        <span>MurderMystery — Verkstedet</span>
      </footer>
    </div>`

  wireEditorEvents()
}

function renderSuspectEditor(suspect) {
  return `
    <div class="card">
      <div class="title-row" style="display:flex; justify-content:space-between; align-items:center; gap:10px; flex-wrap:wrap;">
        <h3 style="margin:0;">${esc(suspect.name)}</h3>
        ${suspect.is_killer ? `<span class="badge red">${icon(I.reveal, { lead: true })}Morderen</span>` : ''}
      </div>
      <form data-suspect-form="${esc(suspect.id)}">
        <label>Navn</label>
        <input name="name" value="${esc(suspect.name)}" maxlength="80" required />
        <label>Kort beskrivelse</label>
        <input name="tagline" value="${esc(suspect.tagline)}" maxlength="120" />
        <label>Dette vet alle</label>
        <textarea name="public_info" rows="3">${esc(suspect.public_info)}</textarea>
        <label>Hemmelighet (bare spilleren med rollen ser denne)</label>
        <textarea name="secret" rows="3">${esc(suspect.secret)}</textarea>
        <label>Alibi</label>
        <textarea name="alibi" rows="3">${esc(suspect.alibi)}</textarea>
        <label style="display:flex; align-items:center; gap:8px; font-weight:400;">
          <input type="radio" name="mm-killer" style="width:auto;"
                 data-killer="${esc(suspect.id)}" ${suspect.is_killer ? 'checked' : ''} />
          Morderen
        </label>
        <div class="btn-row">
          <button>${icon(I.save, { lead: true })}Lagre</button>
          <button type="button" class="btn-quiet" data-delete-suspect="${esc(suspect.id)}">${icon(I.del, { lead: true })}Slett</button>
        </div>
      </form>
    </div>`
}

function renderPolaroidEditor(polaroid) {
  return `
    <div class="card">
      <form data-polaroid-form="${esc(polaroid.id)}">
        <label>Tittel</label>
        <input name="title" value="${esc(polaroid.title)}" maxlength="120" required />
        <label>Bildetekst</label>
        <textarea name="caption" rows="3">${esc(polaroid.caption)}</textarea>
        <label>Bilde-URL (valgfritt)</label>
        <input name="image_url" value="${esc(polaroid.image_url ?? '')}" placeholder="https://…" />
        <div class="btn-row">
          <button>${icon(I.save, { lead: true })}Lagre</button>
          <button type="button" class="btn-quiet" data-delete-polaroid="${esc(polaroid.id)}">${icon(I.del, { lead: true })}Slett</button>
        </div>
      </form>
    </div>`
}

function wireEditorEvents() {
  wireTopNav(app)
  app.querySelector('#back-btn').addEventListener('click', backToList)
  app.querySelector('#delete-mystery-btn').addEventListener('click', deleteMystery)
  const hostBtn = app.querySelector('#host-btn')
  if (hostBtn) {
    hostBtn.addEventListener('click', () => {
      location.href = `/host.html?mystery=${encodeURIComponent(state.data.mystery.id)}`
    })
  }

  app.querySelector('#story-form').addEventListener('submit', (e) => {
    e.preventDefault()
    const f = e.target.elements
    ownerAction('owner_update_mystery', {
      p_title: f.title.value,
      p_intro: f.intro.value,
      p_resolution: f.resolution.value,
    })
  })

  app.querySelectorAll('[data-suspect-form]').forEach((form) =>
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      ownerAction('owner_upsert_suspect', {
        p_suspect_id: form.dataset.suspectForm,
        p_name: f.name.value,
        p_tagline: f.tagline.value,
        p_public_info: f.public_info.value,
        p_secret: f.secret.value,
        p_alibi: f.alibi.value,
      })
    })
  )

  app.querySelectorAll('[data-killer]').forEach((radio) =>
    radio.addEventListener('change', () => {
      if (radio.checked) {
        ownerAction('owner_set_killer', { p_suspect_id: radio.dataset.killer }, 'Morder valgt')
      }
    })
  )

  app.querySelectorAll('[data-delete-suspect]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Slette denne mistenkte?')) {
        ownerAction('owner_delete_suspect', { p_suspect_id: btn.dataset.deleteSuspect }, 'Slettet')
      }
    })
  )

  app.querySelector('#new-suspect-form').addEventListener('submit', (e) => {
    e.preventDefault()
    const f = e.target.elements
    ownerAction('owner_upsert_suspect', {
      p_name: f.name.value,
      p_tagline: f.tagline.value,
    }, 'Mistenkt lagt til')
  })

  app.querySelectorAll('[data-polaroid-form]').forEach((form) =>
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      const f = e.target.elements
      ownerAction('owner_upsert_polaroid', {
        p_polaroid_id: form.dataset.polaroidForm,
        p_title: f.title.value,
        p_caption: f.caption.value,
        p_image_url: f.image_url.value || null,
      })
    })
  )

  app.querySelectorAll('[data-delete-polaroid]').forEach((btn) =>
    btn.addEventListener('click', () => {
      if (confirm('Slette dette beviset?')) {
        ownerAction('owner_delete_polaroid', { p_polaroid_id: btn.dataset.deletePolaroid }, 'Slettet')
      }
    })
  )

  app.querySelector('#new-polaroid-form').addEventListener('submit', (e) => {
    e.preventDefault()
    const f = e.target.elements
    ownerAction('owner_upsert_polaroid', {
      p_title: f.title.value,
      p_caption: f.caption.value,
    }, 'Bevis lagt til')
  })
}
