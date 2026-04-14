# frozen_string_literal: true

class AlertComponent < ViewComponent::Base
  VARIANTS = {
    success: { css: "alert-success", icon: "check_circle" },
    error:   { css: "alert-error",   icon: "error" },
    warning: { css: "alert-warning", icon: "warning" },
    info:    { css: "alert-info",    icon: "info" }
  }.freeze

  FLASH_MAP = {
    notice:  :success,
    alert:   :error,
    warning: :warning,
    info:    :info
  }.freeze

  def initialize(
    message:,
    variant:      :info,
    title:        nil,
    dismissible:  true,
    auto_dismiss: false,
    delay:        4000
  )
    @message      = message
    @variant      = FLASH_MAP[variant.to_sym] || (VARIANTS.key?(variant.to_sym) ? variant.to_sym : :info)
    @title        = title
    @dismissible  = dismissible
    @auto_dismiss = auto_dismiss
    @delay        = delay
  end

  private

  def config = VARIANTS[@variant]
  def css    = config[:css]
  def icon   = config[:icon]
end
