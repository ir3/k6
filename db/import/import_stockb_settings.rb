# frozen_string_literal: true

# Access DB の 在庫非表示B → k6 stockb_settings インポートスクリプト
# 使い方: bin/rails db:migrate && bin/rails runner db/import/import_stockb_settings.rb
#
# 旧ASPは、在庫非表示B に行があればその部品を非表示にし、「表示設定」で行を消していた。
# なので、Access に行がある部品は、nonview の値によらず非表示(nonview=1)として取り込む。
# 何度実行してもよい（部品番号ごとに1行）。Access に無い、k6 で非表示にした部品は変えない。

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/fsdb.mdb").to_s

csv_data, stderr, status = Open3.capture3({ "LANG" => "ja_JP.UTF-8" }, "mdb-export", MDB_FILE, "在庫非表示B")
abort "ERROR: mdb-export(在庫非表示B) 失敗: #{stderr}" unless status.success?

partnos = CSV.parse(csv_data, headers: true).filter_map { |row| row["PartNo"].to_s.strip.upcase.presence }.uniq
partnos.each do |partno|
  setting = StockbSetting.find_or_initialize_by(partno: partno)
  setting.nonview = 1
  setting.save!
end
puts "非表示のＢ部品: #{partnos.size} 件を取り込みました（stockb_settings 合計 #{StockbSetting.count} 件）"
