# frozen_string_literal: true

# Access DB 取引管理 → k6 order_logs インポートスクリプト
# 使い方: bin/rails runner db/import/import_order_logs.rb
# 13万件超あるので、1000件ずつ upsert_all で取り込む。何度実行してもよい(IDで上書き)。

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s
TABLE    = "取引管理"
BATCH    = 1000

def parse_datetime(str)
  return nil unless str
  DateTime.strptime("#{str} +0900", "%m/%d/%y %H:%M:%S %z")
rescue ArgumentError
  nil
end

csv_data, stderr, status = Open3.capture3(
  { "LANG" => "ja_JP.UTF-8" },
  "mdb-export", MDB_FILE, TABLE
)

unless status.success?
  puts "ERROR: mdb-export 失敗: #{stderr}"
  exit 1
end

now = Time.current
rows = []
skipped = 0

CSV.parse(csv_data, headers: true) do |row|
  logged_at = parse_datetime(row["datelog"])
  if row["ID"].blank? || logged_at.nil?
    skipped += 1
    next
  end

  rows << {
    id: row["ID"].to_i,
    tvalid: row["Valid"].presence&.to_i,
    mno: row["MNo"].presence&.to_i,
    datelog: logged_at.to_date,
    kubun: row["kubun"].presence&.to_i,
    created_at: parse_datetime(row["regdate"]) || now,
    updated_at: parse_datetime(row["updata"]) || now
  }
end

rows.each_slice(BATCH) { |batch| OrderLog.upsert_all(batch) }

puts "完了: #{rows.size}件インポート, #{skipped}件スキップ"
