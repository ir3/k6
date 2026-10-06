# frozen_string_literal: true

# Access DB 注文注釈 → k6 order_annotations インポートスクリプト
# 使い方: bin/rails runner db/import/import_order_annotations.rb

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE    = "注文注釈"

MOJIBAKE_MAP = {
  "?梶@"  => "㈱",
  "?鞄?"  => "㈱",
  "?鰍ﾖ"  => "へ",
  "?鰍ﾉ"  => "に",
  "?ｱ"   => "﨑",
}.freeze

def fix_mojibake(str)
  return str unless str
  MOJIBAKE_MAP.reduce(str) { |s, (bad, good)| s.gsub(bad, good) }
end

COLUMN_MAP = {
  "ID"      => "id",
  "Valid"   => "tvalid",
  "MNo"     => "mno",
  "Comment" => "comment",
  "updata"  => "updated_at",
}.freeze

def parse_datetime(str)
  return nil unless str
  begin
    DateTime.strptime("#{str} +0900", "%m/%d/%y %H:%M:%S %z")
  rescue ArgumentError
    nil
  end
end

csv_data, stderr, status = Open3.capture3(
  { "LANG" => "ja_JP.UTF-8" },
  "mdb-export", MDB_FILE, TABLE
)

unless status.success?
  puts "ERROR: mdb-export 失敗: #{stderr}"
  exit 1
end

imported = 0
skipped  = 0
i        = 0

CSV.parse(csv_data, headers: true) do |row|
  i += 1
  attrs = {}

  row.each do |col, value|
    en_col = COLUMN_MAP[col]
    next if en_col.nil?
    attrs[en_col] = fix_mojibake(value.presence)
  end

  attrs["updated_at"] = parse_datetime(attrs["updated_at"]) || Time.current
  attrs["created_at"] = attrs["updated_at"]

  record = OrderAnnotation.find_or_initialize_by(id: attrs["id"])
  record.assign_attributes(attrs)

  if record.save
    imported += 1
  else
    puts "SKIP row=#{i} id=#{attrs['id']}: #{record.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
