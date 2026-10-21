// Existing LiveView dialogs share focus management without changing server events.
let activeModal = null
let returnFocus = null
let overlayFrame = null
const focusable = modal => [...modal.querySelectorAll('button, a[href], input:not([type="hidden"]), select, textarea, [tabindex]:not([tabindex="-1"])')]
  .filter(el => !el.disabled && el.getClientRects().length > 0)

const syncModal = () => {
  const modals = [...document.querySelectorAll('[role="dialog"][aria-modal="true"]')]
  const modal = modals.filter(el => el.getClientRects().length > 0).at(-1) || null
  if (modal === activeModal) return
  if (activeModal && !modal) {
    if (returnFocus?.isConnected) returnFocus.focus({preventScroll: true})
    returnFocus = null
  }
  if (modal) {
    returnFocus = document.activeElement
    const heading = modal.querySelector("h2, h3")
    if (heading && !modal.hasAttribute("aria-label") && !modal.hasAttribute("aria-labelledby")) {
      if (!heading.id) heading.id = `dialog-heading-${modal.querySelector("form")?.id || "active"}`
      modal.setAttribute("aria-labelledby", heading.id)
    }
    if (!modal.contains(document.activeElement)) {
      const target = modal.querySelector('input:not([type="hidden"]):not([disabled]), textarea, select') || focusable(modal)[0]
      target?.focus({preventScroll: true})
    }
  }
  activeModal = modal
}

new MutationObserver(() => {
  if (overlayFrame !== null) return
  overlayFrame = requestAnimationFrame(() => { overlayFrame = null; syncModal() })
}).observe(document.body, {childList: true, subtree: true})

document.addEventListener("keydown", event => {
  if (event.key === "Escape") {
    const dropdown = document.activeElement.closest("details.ui-dropdown[open]")
    if (dropdown) { dropdown.open = false; dropdown.querySelector("summary")?.focus(); event.preventDefault(); return }
  }
  if (!activeModal) return
  if (event.key === "Escape") {
    const close = activeModal.querySelector('[phx-click^="close_"]')
    if (close) { event.preventDefault(); close.click() }
  }
  if (event.key === "Tab") {
    const targets = focusable(activeModal)
    const first = targets[0], last = targets.at(-1)
    if (!first) { event.preventDefault(); return }
    if (event.shiftKey && (document.activeElement === first || !activeModal.contains(document.activeElement))) {
      event.preventDefault(); last.focus()
    } else if (!event.shiftKey && (document.activeElement === last || !activeModal.contains(document.activeElement))) {
      event.preventDefault(); first.focus()
    }
  }
})
