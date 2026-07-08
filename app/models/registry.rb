# frozen_string_literal: true

class Registry < ActiveRecord::Base
  #  attr_accessible :country, :countryid, :deleted_at, :rate
  attr_accessor :clear_deleted
end
