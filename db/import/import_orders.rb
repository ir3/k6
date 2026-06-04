# frozen_string_literal: true

# Access DB 注文台帳 → k6 orders インポートスクリプト
# 使い方: bin/rails runner db/import/import_orders.rb

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE    = "注文台帳"

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
  "ID"          => "id",
  "Valid"       => "tvalid",
  "MNo"         => "mno",
  "ST"          => "st",
  "NO"          => "adlist_id",
  "Rdate"       => "rdate",
  "Ncomment"    => "ncomment",
  "Ndate"       => "ndate",
  "Nplase"      => "nplase",
  "Ldate"       => "ldate",
  "Tcondition"  => "tcondition",
  "Type"        => "etype",
  "ENGNo"       => "engno",
  "ShipName"    => "shipname",
  "Country"     => "country",
  "Pnum"        => "pnum",
  "Inspection"  => "inspection",
  "HNo"         => "hno",
  "OrderItem"   => "orderitem",
  "Memo"        => "memo",
  "Tname"       => "tname",
  "Idate"       => "idate",
  "Odate"       => "odate",
  "Mdate"       => "mdate",
  "Irate"       => "irate",
  "nebiki"      => "nebiki",
  "Irate2"      => "irate2",
  "TC"          => "tc",
  "TCNo"        => "tcno",
  "ZP"          => "zp",
  "ZPNo"        => "zpno",
  "GLC"         => "glc",
  "GLCNo"       => "glcno",
  "MG"          => "mg",
  "MGNo"        => "mgno",
  "ONo"         => "ono",
  "mitday"      => "mitday",
  "syuday"      => "syuday",
  "seiday"      => "seiday",
  "updata"      => "updated_at",
}.freeze

DATE_COLS     = %w[rdate mitday syuday seiday].freeze
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

  order = Order.find_or_initialize_by(id: attrs["id"])
  order.assign_attributes(attrs)

  if order.save
    imported += 1
  else
    puts "SKIP row=#{i} id=#{attrs['id']}: #{order.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
