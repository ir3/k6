# frozen_string_literal: true

# require 'pry'
path = "#{Rails.root}/db/20250604order.tab"

i = 0
open(path, 'r') do |fh|
  while line = fh.gets
    i += 1
    record = line.chomp!
    items = record.split(/\t/)
#    binding.pry

    Order.new do |z|
      z.id        = items[0] if items[0] && items[0].to_i > 0
      z.tvalid    = items[1] if items[1]
      z.mno       = items[2] if items[2]
      z.st        = items[3].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[3]
      z.adlist_id = items[4].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[4]
      z.rdate     = items[5].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[5]
      z.ncomment  = items[6].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[6]
      z.ndate     = items[7].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[7]
      z.nplase    = items[8].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[8]
      z.ldate     = items[9].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[9]
      z.tcondition = items[10].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[10]
      z.etype     = items[11].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[11]
      z.engno     = items[12].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[12]
      z.shipname  = items[13].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[13]
      z.country   = items[14].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[14]
      z.pnum      = items[15] if items[15]
      z.inspection = items[16].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[16]
      z.hno       = items[17].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[17]
      z.orderitem = items[18].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[18]
      z.memo      = items[19].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[19]
      z.tname     = items[20].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[20]
      z.idate     = items[21].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[21]
      z.odate     = items[22].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[22]
      z.mdate     = items[23].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[23]
      z.irate     = items[24] if items[24]
      z.nebiki    = items[25] if items[25]
      z.irate2    = items[26] if items[26]
      z.tc        = items[27].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[27]
      z.tcno      = items[28].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[28]
      z.zp        = items[29].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[29]
      z.zpno      = items[30].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[30]
      z.glc       = items[31].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[31]
      z.glcno     = items[32].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[32]
      z.mg        = items[33].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[33]
      z.mgno      = items[34].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[34]
      z.ono       = items[35].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[35]
      z.mitday    = items[36].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[36]
      z.syuday    = items[37].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[37]
      z.seiday    = items[38].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[38]
      z.updated_at = items[39] if items[39]
      if z.save!(validate: false) then
      else
        p z.id
      end
    end
  end
end
