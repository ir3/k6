# frozen_string_literal: true

path = "#{Rails.root}/db/registry.csv"

i = 0
open(path, 'r') do |fh|
  while line = fh.gets
    i += 1
    record = line.chomp!
    items = record.split(/,/)

    Registry.new do |z|
      z.countryid = items[0].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.country   = items[1].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.rate      = items[2].to_s.gsub(/^\"/, '').gsub(/\"$/, '')
      z.save
    end
  end
end
