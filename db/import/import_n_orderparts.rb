# frozen_string_literal: true

# Access DB 部品番号無 → k6 n_orderparts インポートスクリプト
# 使い方: bin/rails runner db/import/import_n_orderparts.rb
#
# 「部品番号無」は工賃・宿泊費・交通費など、部品コードを持たない明細行を
# 記録する部品明細とは別のAccessテーブル(PartNoの代わりにPartsNameを持つ)。

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE    = "部品番号無"

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
  "ID"        => "id",
  "Valid"     => "tvalid",
  "MNo"       => "mno",
  "SNo"       => "sno",
  "PartsName" => "partsname",
  "Mark"      => "mark",
  "ItemNo"    => "itemno",
  "Info"      => "info",
  "Qty"       => "qty",
  "UnitPD"    => "unitpd",
  "rate"      => "rate",
  "TotalA"    => "totala",
  "Weight"    => "weight",
  "Updata"    => "updated_at",
  "etc"       => "etc",
}.freeze

DATETIME_COLS = %w[updated_at].freeze

def parse_datetime(str)
  return nil unless str
  begin
    DateTime.strptime("#{str} +0900", "%m/%d/%y %H:%M:%S %z")
  rescue ArgumentError
    begin
      Date.strptime(str, "%m/%d/%y")
    rescue ArgumentError
      nil
    end
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

  DATETIME_COLS.each { |col| attrs[col] = parse_datetime(attrs[col]) }

  attrs["updated_at"] ||= Time.current
  attrs["created_at"] = attrs["updated_at"]

  n_orderpart = NOrderpart.find_or_initialize_by(id: attrs["id"])
  n_orderpart.assign_attributes(attrs)

  if n_orderpart.save
    imported += 1
  else
    puts "SKIP row=#{i} id=#{attrs['id']}: #{n_orderpart.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
