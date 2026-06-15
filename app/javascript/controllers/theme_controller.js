import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "homecart.theme"
const DARK = "dark"
const LIGHT = "light"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.applyTheme(this.theme)
  }

  save(event) {
    this.theme = event.target.checked ? DARK : LIGHT
    this.applyTheme(this.theme)
  }

  applyTheme(theme) {
    document.documentElement.dataset.theme = theme
    document.documentElement.style.colorScheme = theme

    this.toggleTargets.forEach((toggle) => {
      toggle.checked = theme === DARK
    })
  }

  get theme() {
    try {
      const storedTheme = window.localStorage.getItem(STORAGE_KEY)

      if ([DARK, LIGHT].includes(storedTheme)) return storedTheme
    } catch {
      // Ignore storage errors so theme selection still follows the browser.
    }

    return window.matchMedia("(prefers-color-scheme: dark)").matches ? DARK : LIGHT
  }

  set theme(value) {
    try {
      window.localStorage.setItem(STORAGE_KEY, value)
    } catch {
      // Ignore storage errors so theme switching still works for the session.
    }
  }
}
