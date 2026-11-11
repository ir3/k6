# frozen_string_literal: true

# Access DB 在庫台帳 → k6 stocks インポートスクリプト
# 使い方: bin/rails runner db/import/import_stocks.rb
#   DRY_RUN=1 bin/rails runner db/import/import_stocks.rb   … 何も変えずに、取り込みで消える行（と追加される行数）を表示する
#   MAX_DELETE=件数 bin/rails runner db/import/import_stocks.rb … Access に無い行を、既定の50件より多く消すとき
#
# Access に無い行（本番の旧システムで消された行）は、取り込みのあと k6 からも削除する（db/import/prune_missing.rb 参照）。
# 消すのは、Access の最大ID以下の行だけで、k6 で後から足した行は消さない。

require "csv"
require "open3"
require_relative "prune_missing"

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

i        = 0
access_ids = Set.new # Access にある行の ID（取り込みのあと、Access に無い行を消すのに使う）
dry_run    = ENV["DRY_RUN"].present?
max_delete = Integer(ENV.fetch("MAX_DELETE", ImportPrune::DEFAULT_MAX_DELETE))

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

  access_ids << attrs["id"].to_i
  Stock.upsert(attrs) unless dry_run
  imported += 1
end

if dry_run
  puts "DRY_RUN: Access 在庫台帳 #{imported}件のうち、k6 に無い行 #{(access_ids - Stock.unscoped.pluck(:id).to_set).size}件（何も変えていません）"
else
  puts "完了: #{imported}件インポート"
end

# Access に無い行を削除する（取り込みに成功して、Access から行が読めたときだけ）
begin
  ImportPrune.call(Stock, access_ids, label: "stocks", max_delete: max_delete, dry_run: dry_run)
rescue ImportPrune::TooMany => e
  puts "ERROR: #{e.message}"
  exit 1
end
