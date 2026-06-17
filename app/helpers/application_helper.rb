module ApplicationHelper
  def parser_status_label(parser_status)
    t("receipts.parser_statuses.#{parser_status}")
  end

  def parser_status_badge_class(parser_status)
    case parser_status
    when "parsed"
      "hc-badge--parsed"
    when "needs_review"
      "hc-badge--warning"
    when "reviewed"
      "hc-badge--success"
    else
      "hc-badge--neutral"
    end
  end

  def store_label(store)
    t(
      "receipts.store_label",
      brand: store.retail_brand.name,
      location: store.location_name,
      channel: store.channel
    )
  end

  def workspace_nav_link(label, path, icon:, active: current_page?(path))
    link_to path,
            class: class_names("hc-workspace-nav-link", "hc-workspace-nav-link--active": active),
            aria: (active ? { current: "page" } : {}) do
      safe_join(
        [
          content_tag(:span, icon, class: "hc-workspace-nav-icon", aria: { hidden: true }),
          content_tag(:span, label, class: "hc-workspace-nav-label")
        ]
      )
    end
  end

  def hc_pagy_nav(pagy)
    return if pagy.pages <= 1

    content_tag(:nav, class: "hc-filter-row mt-4", aria: { label: t("app.pagination.label") }) do
      safe_join(
        [
          hc_pagy_link(pagy.previous, t("app.pagination.previous"), disabled: pagy.previous.blank?),
          content_tag(:span,
            t("app.pagination.status", count: pagy.count, page: pagy.page, pages: pagy.pages),
            class: "hc-body text-sm"),
          hc_pagy_link(pagy.next, t("app.pagination.next"), disabled: pagy.next.blank?)
        ]
      )
    end
  end

  private

  def hc_pagy_link(page, label, disabled:)
    return content_tag(:span, label, class: "hc-button hc-button--subtle opacity-60", aria: { disabled: "true" }) if disabled

    link_to label, url_for(request.query_parameters.merge(page: page)), class: "hc-button hc-button--subtle"
  end
end
