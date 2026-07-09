// Escape user-provided text before putting it in innerHTML. Names and edited
// content come from other people's phones — never trust them as HTML.
export function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]))
}

// Same, but preserves line breaks for multi-paragraph text fields.
export function escMultiline(value) {
  return esc(value).replaceAll('\n', '<br>')
}
