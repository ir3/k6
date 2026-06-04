# frozen_string_literal: true

# Access DB 新潟部品 → k6 parts インポートスクリプト
# 使い方: bin/rails runner db/import/import_parts.rb
#
# 事前確認:
#   mdb-tables db/access/ファイル名.mdb          # テーブル名確認
#   mdb-export db/access/ファイル名.mdb 部品台帳 | head -2  # カラム名確認

require "csv"
require "open3"

MDB_FILE   = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE      = "新潟部品"

# CP932 特殊文字の文字化け修正マップ
MOJIBAKE_MAP = {
  "?梶@"  => "㈱",
  "?鞄?"  => "㈱",
  "?鰍ﾖ"  => "へ",
  "?鰍ﾉ"  => "に",
  "?ｱ"   => "﨑"
}.freeze

def fix_mojibake(str)
  return str unless str
  MOJIBAKE_MAP.reduce(str) { |s, (bad, good)| s.gsub(bad, good) }
end

# 日本語カラム名 → k6 英語カラム名（nil はスキップ）
# ※ 実際の mdb-export ヘッダ行に合わせて修正すること
COLUMN_MAP = {
  "部品コード"   => "pcode",
  "形式"         => "form",
  "和文名称"     => "jname",
  "英文名称"     => "ename",
  "在庫"         => "stock",
  "販売単位"     => "sel_unit",
  "現行単価"     => "price",
  "新販売単価"   => "newprice",
  "重量(kg)"     => "weightkg",
  "計測単位"     => "munit",
  "ItemNo"       => "itemno",
  "CORDNo"       => "cordno",
  "updata"       => "updated_at",
  "備考"         => "comment",
  "ID"           => "id"
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

  # Access の ID をそのまま使い、id で既存レコードを特定（重複インポート時は上書き）
  part = Part.find_or_initialize_by(id: attrs["id"])
  part.assign_attributes(attrs)

  if part.save
    imported += 1
  else
    puts "SKIP row=#{i} pcode=#{attrs['pcode']}: #{part.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
