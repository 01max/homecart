import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["status"]
  static values = {
    interval: { type: Number, default: 1500 },
    url: String
  }

  connect() {
    if (this.processingComplete) return

    this.refresh()
    this.poller = window.setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    this.stop()
  }

  async refresh() {
    if (this.refreshing || this.processingComplete) {
      this.stopIfComplete()
      return
    }

    this.refreshing = true

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })

      if (response.ok) Turbo.renderStreamMessage(await response.text())
    } finally {
      this.refreshing = false
      this.stopIfComplete()
    }
  }

  stopIfComplete() {
    if (this.processingComplete) this.stop()
  }

  stop() {
    if (!this.poller) return

    window.clearInterval(this.poller)
    this.poller = null
  }

  get processingComplete() {
    return this.hasStatusTarget && this.statusTarget.dataset.processingComplete === "true"
  }
}
