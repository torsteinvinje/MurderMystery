// Shared top navigation for the host-facing pages (host control + studio).
// Replaces the old low-contrast links tucked into the footer: the primary
// action ("Start ny fest") is a prominent accent button, the sections are
// clearly-interactive links, and the current page is highlighted. Semantic
// <nav>, real <a>/<button> elements (keyboard-accessible), and a collapsible
// menu on narrow phones. Guests (player view) don't see this.
import { icon, I } from './icons.js'
import { esc } from './util.js'
import { currentAccount } from './auth.js'

// active: 'host' | 'studio' | 'player' — which page is current.
// newFestInPage: when true, the CTA is an in-page button (host dashboard,
//   where starting a new party ends the current one) instead of a plain link.
export function topNav({ active = '', newFestInPage = false } = {}) {
  const link = (href, id, iconName, label) => {
    const current = active === id
    return `<a class="nav-link${current ? ' active' : ''}" href="${href}"${
      current ? ' aria-current="page"' : ''
    }>${icon(iconName, { lead: true })}${label}</a>`
  }

  const cta = newFestInPage
    ? `<button type="button" class="nav-cta" data-nav="new-fest">${icon(I.newGame, { lead: true })}Start ny fest</button>`
    : `<a class="nav-cta" href="/host.html">${icon(I.newGame, { lead: true })}Start ny fest</a>`

  return `
    <nav class="topnav" aria-label="Hovedmeny">
      <a class="nav-brand" href="/host.html">${icon(I.brand, { lead: true })}MurderMystery</a>
      <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="nav-links" aria-label="Åpne meny">
        ${icon(I.menu)}
      </button>
      <div class="nav-links" id="nav-links">
        ${link('/host.html', 'host', I.host, 'Vertskontroll')}
        ${link('/studio.html', 'studio', I.studio, 'Verkstedet')}
        ${link('/', 'player', I.guests, 'Til festen')}
        ${cta}
        <span id="nav-account" class="nav-account-slot">${link('/konto.html', 'konto', I.account, 'Konto')}</span>
      </div>
    </nav>`
}

// Wire the hamburger toggle and (on the host dashboard) the in-page CTA.
// Call after the nav's HTML is in the DOM.
export function wireTopNav(root, { onNewFest } = {}) {
  const toggle = root.querySelector('.nav-toggle')
  const links = root.querySelector('.nav-links')
  if (toggle && links) {
    toggle.addEventListener('click', () => {
      const open = links.classList.toggle('open')
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false')
      toggle.setAttribute('aria-label', open ? 'Lukk meny' : 'Åpne meny')
    })
  }
  const newFestBtn = root.querySelector('[data-nav="new-fest"]')
  if (newFestBtn && onNewFest) newFestBtn.addEventListener('click', onNewFest)

  hydrateAccount(root)
}

// Fill the account slot with the logged-in name (a distinct pill with a
// "logged in" dot) or a "Logg inn" link. Runs async so the nav renders
// immediately; the slot starts as a neutral "Konto" link to avoid a flash.
async function hydrateAccount(root) {
  const slot = root.querySelector('#nav-account')
  if (!slot) return
  let acct
  try {
    acct = await currentAccount()
  } catch {
    return // leave the neutral "Konto" placeholder
  }
  const onKonto = window.location.pathname.replace(/\/$/, '').endsWith('konto.html')
  if (acct.loggedIn) {
    const name = acct.displayName || acct.email || 'Min konto'
    slot.innerHTML = `<a class="nav-account${onKonto ? ' active' : ''}" href="/konto.html"${onKonto ? ' aria-current="page"' : ''}>
      <span class="nav-dot" aria-hidden="true"></span>${icon(I.account, { lead: true })}${esc(name)}</a>`
  } else {
    slot.innerHTML = `<a class="nav-link${onKonto ? ' active' : ''}" href="/konto.html"${onKonto ? ' aria-current="page"' : ''}>${icon(I.login, { lead: true })}Logg inn</a>`
  }
}
