# frozen_string_literal: true

class TextFieldComponent < ViewComponent::Base
  TYPES = %w[text email password tel url number].freeze

  def initialize(
    form:,
    field:,
    label: nil,
    type: "text",
    placeholder: nil,
    hint: nil,
    required: false,
    autocomplete: nil
  )
    @form         = form
    @field        = field
    @label        = label || field.to_s.humanize
    @type         = TYPES.include?(type) ? type : "text"
    @placeholder  = placeholder
    @hint         = hint
    @required     = required
    @autocomplete = autocomplete
  end

  private

  def errors
    @form.object.errors[@field]
  end

  def error?
    errors.any?
  end

  def input_classes
    base = "input input-bordered w-full"
    error? ? "#{base} input-error" : base
  end
end
