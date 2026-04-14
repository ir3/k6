# frozen_string_literal: true

class FormErrorComponent < ViewComponent::Base
  def initialize(errors:)
    @errors = Array(errors)
  end

  def render?
    @errors.any?
  end
end
