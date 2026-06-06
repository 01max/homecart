import { Controller } from "@hotwired/stimulus"

const MONETARY_TOLERANCE_CENTS = 1

export default class extends Controller {
  static targets = [
    "articleCountCard",
    "articleCountDetail",
    "articleCountStatus",
    "declaredArticleCount",
    "line",
    "payment",
    "paymentsSumCard",
    "paymentsSumDetail",
    "paymentsSumStatus",
    "receiptTotal",
    "totalsSumCard",
    "totalsSumDetail",
    "totalsSumStatus"
  ]

  static values = {
    articleFailDetailTemplate: String,
    articlePassDetail: String,
    articleSkippedDetail: String,
    failLabel: String,
    passLabel: String,
    paymentsFailDetailTemplate: String,
    paymentsPassDetail: String,
    skippedLabel: String,
    totalsFailDetailTemplate: String,
    totalsPassDetail: String
  }

  connect() {
    this.recompute()
  }

  recompute() {
    const receiptTotal = this.integerValue(this.receiptTotalTarget.value)
    const declaredArticleCount = this.integerValue(this.declaredArticleCountTarget.value)
    const lineTotal = this.activeLines.reduce((sum, line) => sum + this.lineTotal(line), 0)
    const articleCount = this.activeLines.reduce((sum, line) => sum + this.articleCountFor(line), 0)
    const paymentTotal = this.activePayments.reduce((sum, payment) => sum + this.integerValue(this.paymentAmount(payment)?.value), 0)

    this.renderMonetaryValidator({
      card: this.totalsSumCardTarget,
      status: this.totalsSumStatusTarget,
      detail: this.totalsSumDetailTarget,
      computed: lineTotal,
      declared: receiptTotal,
      passDetail: this.totalsPassDetailValue,
      failTemplate: this.totalsFailDetailTemplateValue
    })
    this.renderArticleCountValidator(articleCount, declaredArticleCount)
    this.renderMonetaryValidator({
      card: this.paymentsSumCardTarget,
      status: this.paymentsSumStatusTarget,
      detail: this.paymentsSumDetailTarget,
      computed: paymentTotal,
      declared: receiptTotal,
      passDetail: this.paymentsPassDetailValue,
      failTemplate: this.paymentsFailDetailTemplateValue
    })
  }

  renderArticleCountValidator(computed, declared) {
    if (this.declaredArticleCountTarget.value.trim() === "") {
      this.renderValidator(this.articleCountCardTarget, this.articleCountStatusTarget, this.articleCountDetailTarget, {
        state: "skipped",
        label: this.skippedLabelValue,
        detail: this.articleSkippedDetailValue
      })
      return
    }

    const discrepancy = computed - declared
    const passed = discrepancy === 0
    this.renderValidator(this.articleCountCardTarget, this.articleCountStatusTarget, this.articleCountDetailTarget, {
      state: passed ? "pass" : "fail",
      label: passed ? this.passLabelValue : this.failLabelValue,
      detail: passed ? this.articlePassDetailValue : this.interpolate(this.articleFailDetailTemplateValue, { computed, declared, discrepancy })
    })
  }

  renderMonetaryValidator({ card, status, detail, computed, declared, passDetail, failTemplate }) {
    const discrepancy = computed - declared
    const passed = Math.abs(discrepancy) <= MONETARY_TOLERANCE_CENTS
    this.renderValidator(card, status, detail, {
      state: passed ? "pass" : "fail",
      label: passed ? this.passLabelValue : this.failLabelValue,
      detail: passed ? passDetail : this.interpolate(failTemplate, { computed, declared, discrepancy })
    })
  }

  renderValidator(card, status, detail, { state, label, detail: detailText }) {
    const stateClasses = {
      fail: {
        card: "hc-validator-card hc-validator-card--fail",
        status: "hc-badge hc-badge--fail",
        detail: "hc-validator-detail"
      },
      pass: {
        card: "hc-validator-card hc-validator-card--pass",
        status: "hc-badge hc-badge--pass",
        detail: "hc-validator-detail"
      },
      skipped: {
        card: "hc-validator-card hc-validator-card--skipped",
        status: "hc-badge hc-badge--skipped",
        detail: "hc-validator-detail"
      }
    }
    const classes = stateClasses[state]

    card.className = classes.card
    status.className = classes.status
    detail.className = classes.detail
    status.textContent = label
    detail.textContent = detailText
  }

  get activeLines() {
    return this.lineTargets.filter((line) => !this.rowMarkedForDestruction(line) && !this.blankLine(line))
  }

  get activePayments() {
    return this.paymentTargets.filter((payment) => !this.rowMarkedForDestruction(payment) && !this.blankPayment(payment))
  }

  articleCountFor(line) {
    if (this.lineKind(line)?.value !== "item") return 0
    if (this.lineUnit(line)?.value !== "piece") return 1

    return this.decimalValue(this.lineQuantity(line)?.value)
  }

  blankLine(line) {
    return [
      this.lineLabel(line),
      this.lineRawText(line),
      this.lineSectionLabel(line),
      this.lineTotalInput(line),
      this.lineUnitPrice(line)
    ].every((input) => input?.value.trim() === "")
  }

  blankPayment(payment) {
    return [this.paymentRawLabel(payment), this.paymentAmount(payment)].every((input) => input?.value.trim() === "")
  }

  lineTotal(line) {
    return this.integerValue(this.lineTotalInput(line)?.value)
  }

  rowMarkedForDestruction(row) {
    return row.querySelector('[data-receipt-validators-target~="lineDestroy"], [data-receipt-validators-target~="paymentDestroy"]')?.checked
  }

  integerValue(value) {
    const parsed = Number.parseInt(value, 10)
    return Number.isNaN(parsed) ? 0 : parsed
  }

  decimalValue(value) {
    const parsed = Number.parseFloat(value)
    return Number.isNaN(parsed) ? 0 : parsed
  }

  interpolate(template, values) {
    return template.replace(/%\{(\w+)\}/g, (_match, key) => values[key])
  }

  lineKind(line) {
    return line.querySelector('[data-receipt-validators-target~="lineKind"]')
  }

  lineLabel(line) {
    return line.querySelector('[data-receipt-validators-target~="lineLabel"]')
  }

  lineQuantity(line) {
    return line.querySelector('[data-receipt-validators-target~="lineQuantity"]')
  }

  lineRawText(line) {
    return line.querySelector('[data-receipt-validators-target~="lineRawText"]')
  }

  lineSectionLabel(line) {
    return line.querySelector('[data-receipt-validators-target~="lineSectionLabel"]')
  }

  lineTotalInput(line) {
    return line.querySelector('[data-receipt-validators-target~="lineTotal"]')
  }

  lineUnit(line) {
    return line.querySelector('[data-receipt-validators-target~="lineUnit"]')
  }

  lineUnitPrice(line) {
    return line.querySelector('[data-receipt-validators-target~="lineUnitPrice"]')
  }

  paymentAmount(payment) {
    return payment.querySelector('[data-receipt-validators-target~="paymentAmount"]')
  }

  paymentRawLabel(payment) {
    return payment.querySelector('[data-receipt-validators-target~="paymentRawLabel"]')
  }
}
