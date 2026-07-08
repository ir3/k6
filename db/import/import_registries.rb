# frozen_string_literal: true

# fsdb.mdb 船籍テーブル → k6 registries インポートスクリプト
# 使い方: bin/rails runner db/import/import_registries.rb

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE    = "船籍"

COLUMN_MAP = {
  "countryID" => "countryid",
  "country"   => "country",
  "rate"      => "rate",
}.freeze

csv_data, stderr, status = Open3.capture3(
  { "LANG" => "ja_JP.UTF-8" },
  "mdb-export", MDB_FILE, TABLE
)

unless status.success?
  puts "ERROR: mdb-export failed: #{stderr}"
  exit 1
end

imported = 0
skipped  = 0

CSV.parse(csv_data, headers: true) do |row|
  attrs = {}
  row.each do |jp_col, value|
    en_col = COLUMN_MAP[jp_col]
    next if en_col.nil?
    attrs[en_col] = value.presence
  end

  registry = Registry.find_or_initialize_by(countryid: attrs["countryid"])
  registry.assign_attributes(attrs)

  if registry.save
    imported += 1
  else
    puts "SKIP countryid=#{attrs['countryid']}: #{registry.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
