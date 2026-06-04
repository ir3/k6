# frozen_string_literal: true

# require 'pry'
path = "#{Rails.root}/db/20240327.txt"

i = 0
open(path, 'r') do |fh|
  while line = fh.gets
    i += 1
    record = line.chomp!
    items = record.split(/\t/)

    Part.new do |z|
      z.id        = i
      z.pcode     = items[0].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[0]
      z.form      = items[1].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[1]
      z.jname     = items[2].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[2]
      z.ename     = items[3].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[3]
      z.stock     = items[4].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[4]
      z.sel_unit  = items[5].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[5]
      z.price     = items[6] if items[6]
      z.newprice  = items[7] if items[7]
      z.weightkg  = items[8] if items[8]
      z.munit     = items[9].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[9]
      z.itemno    = items[10].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[10]
      z.cordno    = items[11].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[11]
      z.updated_at = items[12] if items[12]
      z.created_at = items[12] if items[12]
      z.comment = items[13].to_s.gsub(/^\"/, '').gsub(/\"$/, '') if items[13]
      z.save
    end
  end
end
