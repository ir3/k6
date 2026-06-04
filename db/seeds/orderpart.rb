# frozen_string_literal: true

# require 'pry'
path = "#{Rails.root}/db/20250604orderpart.tab"

i = 0
open(path, 'r') do |fh|
  while line = fh.gets
    i += 1
    record = line.chomp!
    items = record.split(/\t/)
    #    binding.pry
    Orderpart.new do |z|
      z.id        = items[0] if items[0] && items[0].to_i > 0
      z.mno       = items[2] if items[2]
      z.sno       = items[3] if items[3]
      z.itemno    = items[5].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[5]
      z.cordno    = items[6].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[6]
      z.kzaiko    = items[7].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[7]
      z.partno    = items[8].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[8]
      z.info      = items[9].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[9]
      z.qty       = items[10] if items[10]
      z.bqty      = items[11] if items[11]
      z.unit      = items[12].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[12]
      z.unitpd    = items[13] if items[13]
      z.unitpi    = items[14] if items[14]
      z.unitpi2   = items[15] if items[15]
      z.irate     = items[16].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[16]
      z.totala    = items[17].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[17]
      z.total2    = items[18].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[18]
      z.ndate     = items[19] if items[19]
      z.unitweight = items[20] if items[20]
      z.totalweight = items[21] if items[21]
      z.updated_at = items[23] if items[23]
      z.created_at = items[23] if items[23]
      z.save
    end
  end
end
