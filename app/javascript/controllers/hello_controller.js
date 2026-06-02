import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String }

  connect() {
    if (this.hasMessageValue) this.element.textContent = this.messageValue
  }
}
