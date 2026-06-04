# frozen_string_literal: true

# require 'pry'
path = "#{Rails.root}/db/20250604kepart.tab"

i = 0
open(path, 'r') do |fh|
  while line = fh.gets
    i += 1
    record = line.chomp!
    items = record.split(/\t/)

    Kepart.new do |z|
      z.id        = items[0] if items[0] && items[0].to_i > 0
      z.pcode     = items[1].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[1]
      z.form      = items[2].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[2]
      z.size      = items[3].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[3]
      z.jname     = items[4].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[4]
      z.ename     = items[5].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[5]
      z.newprice  = items[6] if items[6]
      z.price     = items[7] if items[7]
      z.stock     = items[8] if items[8]
      z.sel_unit  = items[9] if items[9]
      z.weightkg  = items[10] if items[10]
      z.munit     = items[11] if items[11]
      z.itemno    = items[12].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[12]
      z.cordno    = items[13].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[13]
      z.updated_at = items[14] if items[14]
      z.created_at = items[14] if items[14]
      z.comment = items[15].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[15]
      z.save
    end
  end
end
