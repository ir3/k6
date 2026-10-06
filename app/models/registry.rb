# frozen_string_literal: true

class Registry < ActiveRecord::Base
  #  attr_accessible :country, :countryid, :deleted_at, :rate
  attr_accessor :clear_deleted

  # 船籍の選択肢（国名）。国別コード順。先頭が新規登録の既定の船籍になる。
  def self.country_names
    where(deleted_at: nil).order(Arel.sql("CAST(countryid AS INTEGER)")).pluck(:country)
  end
end
