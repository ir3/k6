# frozen_string_literal: true

# require 'pry'
path = "#{Rails.root}/db/20250604stockb.tab"

i = 0
open(path, 'r') do |fh|
  while line = fh.gets
    i += 1
    record = line.chomp!
    items = record.split(/\t/)

    Stockb.new do |z|
      z.id        = items[0] if items[0] && items[0].to_i > 0
      z.partno    = items[1].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[1]
      z.kind      = items[2] if items[2]
      z.indate    = items[3] if items[3]
      z.num       = items[4] if items[4]
      z.inprice   = items[5] if items[5]
      z.irprice   = items[6] if items[6]
      z.invalue   = items[7] if items[7]
      z.irvalue   = items[8] if items[8]
      z.outdate   = items[9] if items[9]
      z.onum      = items[10] if items[10]
      z.mno       = items[11] if items[11]
      z.orprice   = items[12] if items[12]
      z.orvalue   = items[13] if items[13]
      z.memo      = items[17].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[17]
      z.cname     = items[18].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[18]
      z.sname     = items[19].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[19]
      z.cname     = items[20].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[20]
      z.ikubun    = items[21] if items[21]
      z.okubun    = items[22] if items[22]
      z.novalid   = items[23] if items[23]
      z.updated_at = items[16] if items[16]
      z.created_at = items[16] if items[16]
      z.save
    rescue ActiveRecord::RecordNotUnique
      # 重複IDはスキップ
    end
  end
end
