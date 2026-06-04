# frozen_string_literal: true

# Access DB 在庫台帳 → k6 stocks インポートスクリプト
# 使い方: bin/rails runner db/import/import_stocks.rb

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE    = "在庫台帳"

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
  "ZID"     => "id",
  "PartNo"  => "partno",
  "kind"    => "kind",
  "Indate"  => "indate",
  "Num"     => "num",
  "Inprice" => "inprice",
  "IRprice" => "irprice",
  "Invalue" => "invalue",
  "IRvalue" => "irvalue",
  "Outdate" => "outdate",
  "Onum"    => "onum",
  "MNo"     => "mno",
  "ORprice" => "orprice",
  "ORvalue" => "orvalue",
  "ItemNo"  => "itemno",
  "CORDNo"  => "cordno",
  "Updata"  => "updated_at",
  "Memo"    => "memo",
  "cname"   => "cname",
  "sname"   => "sname",
  "invalid" => "novalid",
  "ikubun"  => "ikubun",
  "okubun"  => "okubun",
}.freeze

DATE_COLS     = %w[indate outdate].freeze
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
  DATE_COLS.each     { |col| attrs[col] = parse_datetime(attrs[col])&.to_date }

  attrs["updated_at"] ||= Time.current
  attrs["created_at"] = attrs["updated_at"]

  stock = Stock.find_or_initialize_by(id: attrs["id"])
  stock.assign_attributes(attrs)

  if stock.save
    imported += 1
  else
    puts "SKIP row=#{i} id=#{attrs['id']}: #{stock.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
