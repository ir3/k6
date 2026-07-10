# frozen_string_literal: true

# menus/index.html.haml で %tr と同じ深さになっていた %td 群を1段インデントし直すスクリプト。
# kobeengineから移植した際、%td が %tr の子ではなく兄弟になっていた箇所を修正するために使用した。
# 実行: ruby script/reindent_menus_haml.rb

path = File.expand_path('../app/views/menus/index.html.haml', __dir__)
lines = File.readlines(path, encoding: 'UTF-8')

# インデント修正が必要な行範囲（1始まり、両端含む）
ranges = [(22..76), (86..119), (134..175), (177..179)]

ranges.each do |range|
  range.each do |i|
    idx = i - 1
    lines[idx] = "  #{lines[idx]}" unless lines[idx].strip.empty?
  end
end

File.write(path, lines.join, encoding: 'UTF-8')
puts "#{path} のインデントを修正しました"
