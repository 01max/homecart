module ApplicationHelper
  def parser_status_label(parser_status)
    t("receipts.parser_statuses.#{parser_status}")
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
end
