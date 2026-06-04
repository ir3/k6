# frozen_string_literal: true

# Access DB ke部品 → k6 keparts インポートスクリプト
# 使い方: bin/rails runner db/import/import_keparts.rb

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE    = "ke部品"

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
  "ID"         => "id",
  "部品コード"  => "pcode",
  "形式"        => "form",
  "寸法"        => "size",
  "和文名称"    => "jname",
  "英文名称"    => "ename",
  "新販売単価"  => "newprice",
  "現行単価"    => "price",
  "在庫"        => "stock",
  "販売単位"    => "sel_unit",
  "重量(kg)"    => "weightkg",
  "計測単位"    => "munit",
  "ItemNo"      => "itemno",
  "CORDNo"      => "cordno",
  "Updata"      => "updated_at",
  "備考"        => "comment",
}.freeze

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

  row.each do |jp_col, value|
    en_col = COLUMN_MAP[jp_col]
    next if en_col.nil?
    attrs[en_col] = fix_mojibake(value.presence)
  end

  %w[updated_at].each do |col|
    next unless attrs[col]
    begin
      attrs[col] = DateTime.strptime("#{attrs[col]} +0900", "%m/%d/%y %H:%M:%S %z")
    rescue ArgumentError
      begin
        attrs[col] = Date.strptime(attrs[col], "%m/%d/%y")
      rescue ArgumentError
        attrs[col] = nil
      end
    end
  end

  attrs["updated_at"] ||= Time.current
  attrs["created_at"] = attrs["updated_at"]

  kepart = Kepart.find_or_initialize_by(id: attrs["id"])
  kepart.assign_attributes(attrs)

  if kepart.save
    imported += 1
  else
    puts "SKIP row=#{i} id=#{attrs['id']} pcode=#{attrs['pcode']}: #{kepart.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
