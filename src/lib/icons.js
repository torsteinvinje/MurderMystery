// One icon system for the whole app: Phosphor's "regular" weight, loaded once
// here as an icon font (no inline SVG, no emojis). Every view imports this
// module, so the font loads on all three pages.
//
// Icons are referenced by SEMANTIC name via the `I` map below — so if we ever
// want a different glyph for "evidence", we change it in one place, not in
// twelve template strings. Render with icon(I.evidence).
import '@phosphor-icons/web/regular'

// Semantic role -> Phosphor icon name. Keep the domains visually distinct:
//   people/guests ....... users
//   suspect characters .. identification-card
//   evidence/photos ..... camera
//   investigate/suspect . magnifying-glass
//   locked/unlocked ..... lock-key / lock-key-open
//   verdict/reveal ...... gavel
export const I = {
  // brand + navigation
  brand: 'magnifying-glass',
  host: 'shield-check',
  studio: 'pen-nib',
  guests: 'users-three',
  join: 'sign-in',
  leave: 'sign-out',
  back: 'arrow-left',
  next: 'arrow-right',
  menu: 'list',
  account: 'user-circle',
  login: 'sign-in',
  logout: 'sign-out',
  mail: 'envelope-simple',
  password: 'lock-key',

  // content types / section anchors
  role: 'identification-card',
  suspects: 'identification-card',
  guestsCount: 'users',
  evidence: 'camera',
  clue: 'magnifying-glass',
  alibi: 'quotes',
  briefing: 'file-text',
  tally: 'chart-bar',
  code: 'ticket',
  builtin: 'bookmark-simple',

  // locked / unlocked / verdict
  locked: 'lock-key',
  unlocked: 'lock-key-open',
  reveal: 'gavel',

  // actions
  add: 'plus',
  edit: 'pencil-simple',
  del: 'trash',
  save: 'floppy-disk',
  play: 'play',
  newGame: 'plus-circle',
  shuffle: 'shuffle',
  show: 'eye',
  hide: 'eye-slash',

  // host tabs
  tabRegi: 'list-checks',
  tabPlayers: 'users',
  tabSuspects: 'identification-card',
  tabPolaroids: 'camera',
  tabEvidence: 'folder',
  tabReveal: 'gavel',
  time: 'clock',

  // status / messages
  ok: 'check-circle',
  warn: 'warning-circle',
  error: 'warning-circle',
  ready: 'check-circle',
  unfinished: 'wrench',
}

// Return the HTML for one icon.
//   - decorative (default): aria-hidden, so screen readers skip it and read
//     the adjacent text label instead.
//   - { label } : announce the icon itself (for icon-only controls).
//   - { lead }  : add right margin when the icon precedes a text label.
export function icon(name, { label, lead = false } = {}) {
  const cls = `ph ph-${name}${lead ? ' i-lead' : ''}`
  if (label) {
    const safe = String(label).replace(/"/g, '&quot;')
    return `<i class="${cls}" role="img" aria-label="${safe}"></i>`
  }
  return `<i class="${cls}" aria-hidden="true"></i>`
}
