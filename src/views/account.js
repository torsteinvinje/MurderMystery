// Account view ("konto"): host authentication built on Supabase Auth.
// One page, several screens driven by a small state machine:
//   login | register | forgot | reset (recovery) | confirm-pending | account
//
// Security notes:
//   - All auth work goes through ../lib/auth.js (Supabase). No passwords or
//     tokens are ever stored, logged, or inserted into our own tables.
//   - Every dynamic value shown is escaped before it touches innerHTML.
//   - Login errors are generic to avoid revealing whether an email exists.
//   - Registration and password-reset always show a neutral "check your inbox"
//     message, so neither confirms whether an address is registered.
//   - Submit buttons disable while a request is in flight (no double submits).
import '../styles/main.css'
import { rpc } from '../lib/supabase.js'
import { esc } from '../lib/util.js'
import { icon, I } from '../lib/icons.js'
import { topNav, wireTopNav } from '../lib/nav.js'
import { hero } from '../lib/hero.js'
import heroAccount from '../assets/mood/hallway.webp'
import {
  PASSWORD_MIN, validEmail, getSession, onAuthChange,
  register, login, logout, requestPasswordReset, setNewPassword, safeNext,
} from '../lib/auth.js'

const app = document.querySelector('#app')

const state = {
  view: 'loading', // see list above
  busy: false,
  error: '',
  notice: '',
  email: '', // preserved across screens so a switch doesn't lose typing
  firstName: '',
  lastName: '',
  profile: null,
  next: '/host.html', // where to go after a successful login
}

init()

async function init() {
  const params = new URLSearchParams(location.search)
  state.next = safeNext(params.get('next'))
  const wantView = params.get('view')

  // A password-recovery link lands here with type=recovery in the URL hash.
  const isRecovery = location.hash.includes('type=recovery')

  // React to auth events for the whole lifetime of the page.
  onAuthChange((event, session) => {
    if (event === 'PASSWORD_RECOVERY') {
      state.view = 'reset'
      render()
    } else if (event === 'SIGNED_IN' && state.view !== 'reset') {
      goToAccount('Du er logget inn.')
    } else if (event === 'SIGNED_OUT') {
      state.profile = null
      state.view = 'login'
      render()
    }
  })

  const session = await getSession()
  if (isRecovery) {
    state.view = 'reset'
  } else if (session) {
    await loadProfile()
    state.view = 'account'
  } else {
    state.view = ['register', 'forgot'].includes(wantView) ? wantView : 'login'
  }
  render()
}

async function loadProfile() {
  try {
    state.profile = await rpc('get_my_profile')
  } catch {
    state.profile = null
  }
}

async function goToAccount(notice = '') {
  await loadProfile()
  // If the user was sent here from a protected page, return them there.
  const params = new URLSearchParams(location.search)
  const next = safeNext(params.get('next'))
  if (next && next !== '/konto.html' && params.get('next')) {
    location.assign(next)
    return
  }
  state.notice = notice
  state.error = ''
  state.view = 'account'
  render()
}

// --------------------------------------------------------------------------
// Actions
// --------------------------------------------------------------------------

function switchView(view) {
  state.view = view
  state.error = ''
  state.notice = ''
  render()
}

async function onRegister(e) {
  e.preventDefault()
  const f = e.target.elements
  const email = f.email.value
  const password = f.password.value
  const firstName = f.first_name.value
  const lastName = f.last_name.value

  state.firstName = firstName
  state.lastName = lastName
  if (!firstName.trim() || !lastName.trim()) return fail('Fyll inn både fornavn og etternavn.')
  if (!validEmail(email)) return fail('Skriv inn en gyldig e-postadresse.')
  if (password.length < PASSWORD_MIN) return fail(`Passordet må være minst ${PASSWORD_MIN} tegn.`)

  state.email = email
  await run(async () => {
    const { error } = await register({ email, password, firstName, lastName })
    // Do not reveal whether the address already exists: on any non-error,
    // show the same neutral "check your inbox" screen.
    if (error) {
      // Password-strength / compromised-password rejections are safe to show.
      if (/password/i.test(error.message)) return fail(passwordError(error))
      return fail('Kunne ikke registrere akkurat nå. Prøv igjen om litt.')
    }
    state.view = 'confirm-pending'
    render()
  })
}

async function onLogin(e) {
  e.preventDefault()
  const f = e.target.elements
  const email = f.email.value
  const password = f.password.value
  if (!validEmail(email)) return fail('Skriv inn en gyldig e-postadresse.')
  if (!password) return fail('Skriv inn passordet ditt.')

  state.email = email
  await run(async () => {
    const { error } = await login({ email, password })
    if (error) return fail(loginError(error))
    // SIGNED_IN handler takes over (redirect / account).
  })
}

async function onForgot(e) {
  e.preventDefault()
  const email = e.target.elements.email.value
  if (!validEmail(email)) return fail('Skriv inn en gyldig e-postadresse.')
  state.email = email
  await run(async () => {
    await requestPasswordReset(email) // ignore result on purpose (no enumeration)
    state.error = ''
    state.notice = 'Hvis det finnes en konto for denne e-posten, har vi sendt en lenke for å tilbakestille passordet.'
    render()
  })
}

async function onReset(e) {
  e.preventDefault()
  const f = e.target.elements
  const password = f.password.value
  const confirm = f.confirm.value
  if (password.length < PASSWORD_MIN) return fail(`Passordet må være minst ${PASSWORD_MIN} tegn.`)
  if (password !== confirm) return fail('Passordene er ikke like.')

  await run(async () => {
    const { error } = await setNewPassword(password)
    if (error) return fail(/password/i.test(error.message) ? passwordError(error) : 'Lenken er ugyldig eller utløpt. Be om en ny.')
    await goToAccount('Passordet er oppdatert.')
  })
}

async function onLogout() {
  await run(async () => {
    await logout()
    // SIGNED_OUT handler resets to the login screen.
  })
}

async function onProfileSave(e) {
  e.preventDefault()
  const f = e.target.elements
  const first = f.first_name.value
  const last = f.last_name.value
  if (!first.trim() || !last.trim()) return fail('Fyll inn både fornavn og etternavn.')
  await run(async () => {
    await rpc('update_my_profile', { p_first: first, p_last: last })
    await loadProfile()
    state.notice = 'Navnet er lagret.'
    render() // re-renders the nav too, so the top-right name updates
  })
}

// Run an async action with the busy flag (prevents duplicate submits).
async function run(fn) {
  if (state.busy) return
  state.busy = true
  state.error = ''
  render()
  try {
    await fn()
  } catch {
    state.error = 'Noe gikk galt. Prøv igjen.'
  } finally {
    state.busy = false
    render()
  }
}

function fail(message) {
  state.error = message
  state.busy = false
  render()
}

// Generic login error — only distinguishes the "email not confirmed" case,
// which Supabase returns only when the password is already correct (so it is
// not an account-enumeration vector).
function loginError(error) {
  const msg = (error?.message || '').toLowerCase()
  if (msg.includes('not confirmed')) {
    return 'Du må bekrefte e-postadressen din før du kan logge inn. Sjekk innboksen din.'
  }
  return 'E-posten eller passordet stemmer ikke.'
}

function passwordError(error) {
  const msg = (error?.message || '').toLowerCase()
  if (msg.includes('pwned') || msg.includes('compromised') || msg.includes('breach')) {
    return 'Dette passordet har lekket i kjente datalekkasjer. Velg et annet.'
  }
  return `Passordet er for svakt. Bruk minst ${PASSWORD_MIN} tegn, gjerne en lengre passordsetning.`
}

// --------------------------------------------------------------------------
// Rendering
// --------------------------------------------------------------------------

// Per-view hero titles, so the mood banner narrates the current step.
const HERO_META = {
  login: { title: 'Logg inn som vert', lede: 'Logg inn for å lage og styre dine egne mysterier.' },
  register: { title: 'Registrer vertskonto', lede: 'Opprett en konto for å lage egne mordmysterier.' },
  forgot: { title: 'Glemt passord', lede: 'Vi sender deg en lenke for å lage nytt passord.' },
  reset: { title: 'Lag nytt passord', lede: 'Velg et nytt passord for kontoen din.' },
  'confirm-pending': { title: 'Bekreft e-posten din', lede: '' },
  account: { title: 'Min konto', lede: '' },
}

function render() {
  const body =
    state.view === 'loading' ? `<p class="notice">Laster …</p>`
    : state.view === 'register' ? viewRegister()
    : state.view === 'forgot' ? viewForgot()
    : state.view === 'reset' ? viewReset()
    : state.view === 'confirm-pending' ? viewConfirmPending()
    : state.view === 'account' ? viewAccount()
    : viewLogin()

  const meta = HERO_META[state.view] || HERO_META.login
  const banner =
    state.view === 'loading'
      ? ''
      : hero({ image: heroAccount, context: 'Vertskonto', title: meta.title, lede: meta.lede })

  app.innerHTML = `
    <div class="sheet">
      ${topNav({ active: 'konto' })}
      ${banner}
      <main>${body}</main>
      <footer class="app-footer"><span>MurderMystery — Vertskonto</span></footer>
    </div>`

  wireTopNav(app)
  wireViewEvents()
}

// A status line that screen readers announce (aria-live).
function messages() {
  return `
    <div aria-live="polite">
      ${state.error ? `<p class="error">${icon(I.warn, { lead: true })}${esc(state.error)}</p>` : ''}
      ${state.notice ? `<p class="notice-ok">${icon(I.ok, { lead: true })}${esc(state.notice)}</p>` : ''}
    </div>`
}

const submitLabel = (busyText, label, iconName) =>
  state.busy ? esc(busyText) : `${icon(iconName, { lead: true })}${esc(label)}`

function viewLogin() {
  return `
    ${messages()}
    <div class="card">
      <form id="form-login" novalidate>
        <label for="login-email">E-post</label>
        <input id="login-email" name="email" type="email" autocomplete="email"
               required value="${esc(state.email)}" />
        <label for="login-password">Passord</label>
        <input id="login-password" name="password" type="password"
               autocomplete="current-password" required />
        <button ${state.busy ? 'disabled' : ''}>${submitLabel('Logger inn …', 'Logg inn', I.login)}</button>
      </form>
      <div class="auth-links">
        <button type="button" class="linkish" data-view="forgot">Glemt passord?</button>
        <button type="button" class="linkish" data-view="register">Ny vert? Registrer deg</button>
      </div>
    </div>`
}

function viewRegister() {
  return `
    ${messages()}
    <div class="card">
      <form id="form-register" novalidate>
        <label for="reg-first">Fornavn</label>
        <input id="reg-first" name="first_name" type="text" autocomplete="given-name" maxlength="60" required value="${esc(state.firstName)}" />
        <label for="reg-last">Etternavn</label>
        <input id="reg-last" name="last_name" type="text" autocomplete="family-name" maxlength="60" required value="${esc(state.lastName)}" />
        <label for="reg-email">E-post</label>
        <input id="reg-email" name="email" type="email" autocomplete="email"
               required value="${esc(state.email)}" />
        <label for="reg-password">Passord (minst ${PASSWORD_MIN} tegn)</label>
        <input id="reg-password" name="password" type="password"
               autocomplete="new-password" minlength="${PASSWORD_MIN}" required />
        <p class="hint">Bruk gjerne en lang passordsetning. Kjente lekkede passord blir avvist.</p>
        <button ${state.busy ? 'disabled' : ''}>${submitLabel('Registrerer …', 'Opprett konto', I.account)}</button>
      </form>
      <div class="auth-links">
        <button type="button" class="linkish" data-view="login">Har du allerede konto? Logg inn</button>
      </div>
    </div>`
}

function viewForgot() {
  return `
    ${messages()}
    <div class="card">
      <form id="form-forgot" novalidate>
        <label for="forgot-email">E-post</label>
        <input id="forgot-email" name="email" type="email" autocomplete="email"
               required value="${esc(state.email)}" />
        <button ${state.busy ? 'disabled' : ''}>${submitLabel('Sender …', 'Send lenke', I.mail)}</button>
      </form>
      <div class="auth-links">
        <button type="button" class="linkish" data-view="login">Tilbake til innlogging</button>
      </div>
    </div>`
}

function viewReset() {
  return `
    ${messages()}
    <div class="card">
      <form id="form-reset" novalidate>
        <label for="reset-password">Nytt passord (minst ${PASSWORD_MIN} tegn)</label>
        <input id="reset-password" name="password" type="password"
               autocomplete="new-password" minlength="${PASSWORD_MIN}" required />
        <label for="reset-confirm">Gjenta passord</label>
        <input id="reset-confirm" name="confirm" type="password"
               autocomplete="new-password" minlength="${PASSWORD_MIN}" required />
        <button ${state.busy ? 'disabled' : ''}>${submitLabel('Lagrer …', 'Lagre nytt passord', I.save)}</button>
      </form>
    </div>`
}

function viewConfirmPending() {
  return `
    ${messages()}
    <div class="card">
      <p>Vi har sendt en bekreftelseslenke til <strong>${esc(state.email)}</strong>.
      Åpne e-posten og trykk på lenken for å aktivere kontoen. Så kan du logge inn.</p>
      <p class="hint">Finner du den ikke? Sjekk søppelpost-mappa.</p>
      <div class="auth-links">
        <button type="button" class="linkish" data-view="login">Til innlogging</button>
      </div>
    </div>`
}

function viewAccount() {
  const p = state.profile || {}
  const name = (p.display_name || '').trim()
  return `
    ${messages()}
    <div class="card">
      <p class="kicker">Innlogget som</p>
      <h3 style="margin-top:2px;">${name ? esc(name) : 'Vert (uten navn ennå)'}</h3>
      <p class="lede">Kontoen din er bekreftet og aktiv.</p>

      <details class="editor" ${name ? '' : 'open'}>
        <summary>${icon(I.edit, { lead: true })}${name ? 'Endre navn' : 'Legg til navnet ditt'}</summary>
        <form id="form-profile" novalidate>
          <label for="pf-first">Fornavn</label>
          <input id="pf-first" name="first_name" type="text" autocomplete="given-name"
                 maxlength="60" required value="${esc(p.first_name || '')}" />
          <label for="pf-last">Etternavn</label>
          <input id="pf-last" name="last_name" type="text" autocomplete="family-name"
                 maxlength="60" required value="${esc(p.last_name || '')}" />
          <button ${state.busy ? 'disabled' : ''}>${submitLabel('Lagrer …', 'Lagre navn', I.save)}</button>
        </form>
      </details>

      <div class="btn-row">
        <a class="nav-cta" href="/host.html">${icon(I.play, { lead: true })}Start en fest</a>
        <a class="btn-quiet" href="/studio.html" style="display:inline-flex;align-items:center;text-decoration:none;">${icon(I.studio, { lead: true })}Verkstedet</a>
        <button type="button" class="btn-quiet" id="logout-btn" ${state.busy ? 'disabled' : ''}>
          ${submitLabel('Logger ut …', 'Logg ut', I.logout)}
        </button>
      </div>
    </div>`
}

function wireViewEvents() {
  app.querySelectorAll('[data-view]').forEach((btn) =>
    btn.addEventListener('click', () => switchView(btn.dataset.view))
  )
  bind('#form-login', onLogin)
  bind('#form-register', onRegister)
  bind('#form-forgot', onForgot)
  bind('#form-reset', onReset)
  bind('#form-profile', onProfileSave)
  const logoutBtn = app.querySelector('#logout-btn')
  if (logoutBtn) logoutBtn.addEventListener('click', onLogout)
}

function bind(selector, handler) {
  const form = app.querySelector(selector)
  if (form) form.addEventListener('submit', handler)
}
