const media = window.matchMedia("(prefers-color-scheme: dark)")
const validTheme = theme => ["light", "dark", "system"].includes(theme) ? theme : "system"
let preference = "system"
try { preference = validTheme(localStorage.getItem("phx:theme")) } catch { /* Storage can be unavailable in embedded views. */ }

const syncThemeButtons = () => {
  document.querySelectorAll("[data-phx-theme]").forEach(button => {
    button.setAttribute("aria-pressed", String(button.dataset.phxTheme === preference))
  })
}

const setTheme = (theme, persist = false) => {
  preference = validTheme(theme)
  document.documentElement.dataset.theme = preference === "system" ? (media.matches ? "dark" : "light") : preference
  document.documentElement.dataset.themePreference = preference
  if (persist) {
    try {
      if (preference === "system") localStorage.removeItem("phx:theme")
      else localStorage.setItem("phx:theme", preference)
    } catch { /* Theme selection still works without persistent storage. */ }
  }
  syncThemeButtons()
  window.dispatchEvent(new CustomEvent("onesqlx:theme-changed"))
}

setTheme(preference)
document.addEventListener("click", event => {
  const button = event.target.closest("[data-phx-theme]")
  if (button) setTheme(button.dataset.phxTheme, true)
})
window.addEventListener("storage", event => {
  if (event.key === "phx:theme") setTheme(event.newValue)
})
media.addEventListener("change", () => { if (preference === "system") setTheme("system") })
window.addEventListener("phx:page-loading-stop", syncThemeButtons)

const locations = {
  "/sql-editor": "SQL Editor", "/saved-queries": "Saved Queries", "/dashboards": "Dashboards",
  "/data-sources": "Data Sources", "/schedules": "Schedules", "/analytics": "Usage Analytics",
  "/lineage": "Data Lineage", "/audit": "Audit Log", "/workspace/settings": "Workspace Settings",
  "/settings/api-tokens": "API Tokens", "/users/settings": "Account Settings", "/search": "Search"
}
const syncNavigation = () => {
  const path = window.location.pathname
  document.querySelectorAll("[data-nav-path]").forEach(link => {
    const active = path === link.dataset.navPath || path.startsWith(`${link.dataset.navPath}/`)
    if (active) link.setAttribute("aria-current", "page")
    else link.removeAttribute("aria-current")
  })
  const location = Object.entries(locations).find(([prefix]) => path === prefix || path.startsWith(`${prefix}/`))
  document.querySelectorAll("[data-section-title]").forEach(node => {
    const title = location?.[1] || "Workspace"
    if (node.textContent !== title) node.textContent = title
  })
  if (location && document.title !== `${location[1]} · OneSQLx`) document.title = `${location[1]} · OneSQLx`
  syncThemeButtons()
}

syncNavigation()
window.addEventListener("phx:page-loading-stop", syncNavigation)
document.addEventListener("click", event => {
  const drawer = document.getElementById("mobile-menu")
  if (event.target.closest("[data-open-menu]")) drawer?.showModal()
  if (event.target.closest("[data-close-menu], [data-nav-path], .workspace-selector, .account-link")) drawer?.close()
  if (event.target === drawer) {
    const bounds = drawer.getBoundingClientRect()
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) drawer.close()
  }
})
document.addEventListener("keydown", event => {
  if (event.key !== "/" || event.ctrlKey || event.metaKey || event.altKey || event.target.closest("input, textarea, select, [contenteditable=true]")) return
  const search = document.querySelector(".app-sidebar .sidebar-search")
  if (search) { event.preventDefault(); search.click() }
})

// Reconcile the location after LiveView replaces server-rendered navigation.
let navigationFrame = null
const navigationObserver = new MutationObserver(() => {
  if (navigationFrame !== null) return
  navigationFrame = requestAnimationFrame(() => {
    navigationFrame = null
    syncNavigation()
  })
})
navigationObserver.observe(document.body, {childList: true, subtree: true})
