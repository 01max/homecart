import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "homecart.workspaceNavCollapsed"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.toggleTarget.checked = this.collapsed
  }

  save() {
    this.collapsed = this.toggleTarget.checked
  }

  get collapsed() {
    try {
      return window.localStorage.getItem(STORAGE_KEY) === "true"
    } catch {
      return false
    }
  }

  set collapsed(value) {
    try {
      window.localStorage.setItem(STORAGE_KEY, value ? "true" : "false")
    } catch {
      // Ignore storage errors so navigation still works in restricted contexts.
    }
  }
}
