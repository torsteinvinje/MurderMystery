// A cinematic hero banner for the entry / landing screens. A mood image with
// a dark gradient scrim and the page title overlaid in white — the "set the
// scene" moment. Working screens (dashboard, role cards, editors) deliberately
// stay on the clean light surface, so readability is never traded for mood.
//
// All hero logic lives here and in the `.hero*` CSS block, so the whole effect
// can be removed in one place if it isn't wanted.
import { esc } from './util.js'
import { icon, I } from './icons.js'

export function hero({ image, context = '', title, lede = '' }) {
  return `
    <header class="hero" style="background-image:url(${image})">
      <div class="hero-content">
        <div class="hero-top">
          <span class="hero-brand">${icon(I.brand, { lead: true })}MurderMystery</span>
          ${context ? `<span class="hero-chip">${esc(context)}</span>` : ''}
        </div>
        <div class="hero-titles">
          <h1>${esc(title)}</h1>
          ${lede ? `<p class="hero-lede">${esc(lede)}</p>` : ''}
        </div>
      </div>
    </header>`
}
