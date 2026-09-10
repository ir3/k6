# frozen_string_literal: true

# 画面から変更できるシステム全体の設定値(key-value)を保持する。
class Ksystem < ActiveRecord::Base
  def self.get(key, default: nil)
    find_by(key: key.to_s)&.value || default
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key.to_s)
    record.update!(value: value.to_s)
  end
end
