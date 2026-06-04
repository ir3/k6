# frozen_string_literal: true

# sql1 = ''
# sql1 = "INSERT INTO 'adlists'   VALUES ('2','ｱ',NULL,'あかしないねんきせいさくしょ','1',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'様','有限会社明石内燃機製作所',NULL,NULL,NULL,'False','673','673-0894','明石市港町6-3',NULL,NULL,'078-911-3824',NULL,NULL,NULL,NULL,'1',NULL,'0','0',NULL,NULL,NULL,'1999/12/15 0:00:00','2009/02/20 12:45:18',NULL,NULL,'-1','-1','2');"
# open File.join(Rails.root, 'db', 'adlists2.sql') do |f|
# open File.join(Rails.root, 'db', 'adlists2.ins') do |f|
# open File.join(Rails.root, 'db', 'adlists.ins') do |f|
# open File.join(Rails.root, 'db', 'adlists3.sql'),"r:utf-8" do |f|
#   sql1 = f.read("r:utf-8")
# binding.pry
#   h_ids = ActiveRecord::Base.connection.execute sql1
# end
# "NO"  "分類"  "氏名"  "ﾌﾘｶﾞﾅ" "宛名住所"  "〒" "7桁〒" "住所1" "住所2" "住所3" "電話"  "FAX" "携帯電話"  "ポケベル"  "敬称"  "会社名" "部署名" "部署名2"  "役職"  "役職印刷"  "会社〒" "会社7桁〒" "会社住所1" "会社住所2" "会社住所3" "会社電話"  "会社電子ﾒｰﾙ" "会社FAX" "会社携帯電話"  "会社ﾎﾟｹﾍﾞﾙ"  "差出人No" "電子ﾒｰﾙ" "出力先" "所有者" "ﾒﾓ"  "URL" "会社URL" "登録日" "更新日" "生年月日"  "仮生年月日" "年齢"  "性別"  "ランク"

# require 'nkf'
# path = "#{Rails.root}/db/seeds/atena.csv"
path = "#{Rails.root}/db/20250604adlist.tab"

# i = 2
# open(path, "r:SJIS") do |fh|
open(path, 'r') do |fh|
  while line = fh.gets
    #    i = i + 1
    #    if i < 3
    #    if i < 1315
    # Shift_JIS→utf-8変換、半角→全角変換
    #        record = NKF.nkf('-Sw -m0',line.chomp!)
    #        record = line.chomp!.encode("utf-8", "sjis")
    #        record = line.chomp!.encode("sjis")
    record = line.chomp!
    items = record.split(/\t/)

    # ('2','ｱ',NULL,'あかしないねんきせいさくしょ','1',NULL,NULL,NULL,NULL,NULL
    # ,NULL,NULL,NULL,NULL,'様','有限会社明石内燃機製作所',NULL,NULL,NULL,'False'
    # ,'673','673-0894','明石市港町6-3',NULL,NULL,'078-911-3824',NULL,NULL,NULL,NULL
    # ,'1',NULL,'0','0',NULL,NULL,NULL,'1999/12/15 0:00:00','2009/02/20 12:45:18',NULL
    # ,NULL,'-1','-1','2');"
    # 2 "ｱ"   "あかしないねんきせいさくしょ"  1                   "様" "有限会社明石内燃機製作所"        0 "673" "673-0894"  "明石市港町6-3"      "078-911-3824"          1   0 0       1999/12/15 0:00:00  2009/2/20 12:45:18      -1  -1  2
    Adlist.new do |z|
      #          z.id       = i
      z.id       = items[0]
      z.no       = items[0].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.kbn      = items[1].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.name     = items[2].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.ruby     = items[3].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.zip7     = items[6].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.address1 = items[7].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.address2 = items[8].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.address3 = items[9].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.tel      = items[10].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.fax      = items[11].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.mtel     = items[12].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.company  = items[15].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.section  = items[16].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.section2 = items[17].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.position = items[18].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.cozip7   = items[21].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.coad1    = items[22].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.coad2    = items[23].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.coad3    = items[24].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.cotel    = items[25].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.comail   = items[26].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.cofax    = items[27].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.comobile = items[28].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.copok    = items[29].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.email    = items[31].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.memo     = items[34].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.url      = items[35].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.courl    = items[36].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.created_at = items[37].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.updated_at = items[38].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.save
    end
    #    end
  end
end
