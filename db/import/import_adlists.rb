# frozen_string_literal: true

# Access DB (客先3.mdb) 宛名名簿 → k6 adlists インポートスクリプト
# 使い方: bin/rails runner db/import/import_adlists.rb

require "csv"
require "open3"

MDB_FILE = Rails.root.join("db/access/客先3.mdb").to_s
TABLE    = "宛名名簿"

# CP932 特殊文字の文字化け修正マップ
# mdb-export が正しく変換できない NEC/IBM 拡張文字を置換する
# 新たな化けパターンを発見したらここに追加する
MOJIBAKE_MAP = {
  "?梶@"  => "㈱",  # 株式会社 (NEC特殊文字 0x8740)
  "?鞄?"  => "㈱",  # 株式会社 (IBM拡張 別コード)
  "?鰍ﾖ"  => "へ",  # へ (文脈: 〜へ請求, 〜へ統合)
  "?鰍ﾉ"  => "に",  # に (文脈: 〜に変更)
  "?ｱ"   => "﨑",  # 﨑 (IBM拡張文字 U+FA11)
}.freeze

def fix_mojibake(str)
  return str unless str
  MOJIBAKE_MAP.reduce(str) { |s, (bad, good)| s.gsub(bad, good) }
end

# 日本語カラム名 → k6 英語カラム名のマッピング（スキップは nil）
COLUMN_MAP = {
  "NO"         => "no",
  "分類"        => "kbn",
  "氏名"        => "name",
  "ﾌﾘｶﾞﾅ"      => "ruby",
  "宛名住所"     => nil,
  "〒"          => nil,
  "7桁〒"       => "zip7",
  "住所1"       => "address1",
  "住所2"       => "address2",
  "住所3"       => "address3",
  "電話"        => "tel",
  "FAX"        => "fax",
  "携帯電話"     => "mtel",
  "ポケベル"     => nil,
  "敬称"        => nil,
  "会社名"       => "company",
  "部署名"       => "section",
  "部署名2"      => "section2",
  "役職"        => "position",
  "役職印刷"     => nil,
  "会社〒"       => nil,
  "会社7桁〒"    => "cozip7",
  "会社住所1"    => "coad1",
  "会社住所2"    => "coad2",
  "会社住所3"    => "coad3",
  "会社電話"     => "cotel",
  "会社電子ﾒｰﾙ"  => "comail",
  "会社FAX"     => "cofax",
  "会社携帯電話"  => "comobile",
  "会社ﾎﾟｹﾍﾞﾙ"  => "copok",
  "差出人No"    => nil,
  "電子ﾒｰﾙ"    => "email",
  "出力先"      => nil,
  "所有者"      => nil,
  "ﾒﾓ"        => "memo",
  "URL"        => "url",
  "会社URL"     => "courl",
  "登録日"      => "created_at",
  "更新日"      => "updated_at",
  "生年月日"    => "birthday",
  "仮生年月日"   => "kbirthday",
  "年齢"       => nil,
  "性別"       => "gender",
  "ランク"      => nil
}.freeze

# mdb-export で CSV 取得
csv_data, stderr, status = Open3.capture3(
  { "LANG" => "ja_JP.UTF-8" },
  "mdb-export", MDB_FILE, TABLE
)

unless status.success?
  puts "ERROR: mdb-export failed: #{stderr}"
  exit 1
end

imported = 0
skipped  = 0

CSV.parse(csv_data, headers: true) do |row|
  attrs = {}

  row.each do |jp_col, value|
    en_col = COLUMN_MAP[jp_col]
    next if en_col.nil?  # スキップ対象

    # 空文字は nil に統一、文字化けを修正
    attrs[en_col] = fix_mojibake(value.presence)
  end

  # 日付フォーマット変換（Access: "12/15/99 00:00:00" → "1999-12-15"）
  %w[created_at updated_at birthday kbirthday].each do |col|
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

  adlist = Adlist.find_or_initialize_by(no: attrs["no"])
  adlist.assign_attributes(attrs)

  if adlist.save
    imported += 1
  else
    puts "SKIP id=#{attrs['no']}: #{adlist.errors.full_messages.join(', ')}"
    skipped += 1
  end
end

puts "完了: #{imported}件インポート, #{skipped}件スキップ"
