import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "store", "parserFormat" ]

  connect() {
    this.userSelectedParserFormat = this.parserFormatTarget.value !== ""
    this.suggest()
  }

  suggest() {
    if (this.userSelectedParserFormat) return

    const parserFormat = this.selectedStoreDefaultParserFormat
    if (parserFormat === "") return

    this.parserFormatTarget.value = parserFormat
  }

  markManualSelection() {
    this.userSelectedParserFormat = this.parserFormatTarget.value !== ""
  }

  get selectedStoreDefaultParserFormat() {
    return this.storeTarget.selectedOptions[0]?.dataset.defaultParserFormat || ""
  }
}
