# frozen_string_literal: true

# Access DB の 標準在庫・必要在庫・在庫部品備考・在庫非表示 → k6 stock_settings インポートスクリプト
# 使い方: bin/rails runner db/import/import_stock_settings.rb
#
# 部品番号ごとに1行にまとめる。同じ部品番号が複数あれば更新日(updata)が最新のものを使う。
# 何度実行してもよいが、Access にある項目は k6 で更新した値を上書きする
# （Access に無い項目は変えない）。

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s

def export_table(table)
  csv_data, stderr, status = Open3.capture3({ "LANG" => "ja_JP.UTF-8" }, "mdb-export", MDB_FILE, table)
  abort "ERROR: mdb-export(#{table}) 失敗: #{stderr}" unless status.success?

  CSV.parse(csv_data, headers: true)
end

def parse_time(str)
  DateTime.strptime("#{str} +0900", "%m/%d/%y %H:%M:%S %z")
rescue ArgumentError, TypeError
  nil
end

# 部品番号ごとに、更新日が最新の行を選ぶ（更新日が読めない行は古いものとして扱う）
def latest_by_partno(rows)
  rows.group_by { |row| row["PartNo"].to_s.strip.upcase }.except("").transform_values do |same|
    same.max_by { |row| parse_time(row["updata"])&.to_time || Time.at(0) }
  end
end

def integer_or_nil(value)
  Integer(value.to_s.strip, 10)
rescue ArgumentError
  nil
end

attrs_by_partno = Hash.new { |hash, key| hash[key] = {} }

latest_by_partno(export_table("標準在庫")).each { |partno, row| attrs_by_partno[partno][:snum] = integer_or_nil(row["snum"]) }
latest_by_partno(export_table("必要在庫")).each { |partno, row| attrs_by_partno[partno][:znum] = integer_or_nil(row["znum"]) }
latest_by_partno(export_table("在庫部品備考")).each do |partno, row|
  attrs_by_partno[partno][:opartno] = row["OPartsNo"].presence
  attrs_by_partno[partno][:memo] = row["Memo"].presence
end
latest_by_partno(export_table("在庫非表示")).each { |partno, row| attrs_by_partno[partno][:nonview] = (row["nonview"].to_s.strip == "1" ? 1 : nil) }

imported = 0
skipped = 0
attrs_by_partno.each do |partno, attrs|
  setting = StockSetting.find_or_initialize_by(partno: partno)
  setting.assign_attributes(attrs)
  if setting.save
    imported += 1
  else
    puts "SKIP partno=#{partno}: #{setting.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ（部品番号 #{attrs_by_partno.size}種）"
