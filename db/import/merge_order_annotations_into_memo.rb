# frozen_string_literal: true

# 一時テーブルorder_annotations(旧Access 注文注釈)の内容をorders.memoへ統合する。
# 使い方: bin/rails runner db/import/merge_order_annotations_into_memo.rb
#
# 注釈は最大50文字程度と短く、専用テーブルを持つほどではないため、
# 既存のorders.memo(「内容」欄)へ追記する形に一本化する。
# memoに既存の値がある場合は上書きせず、改行で末尾に追記する。
# 実行後はorder_annotationsテーブルを削除する(別マイグレーションで対応)。

merged = 0
skipped = 0

OrderAnnotation.find_each do |annotation|
  comment = annotation.comment.presence
  next unless comment

  orders = Order.where(mno: annotation.mno)
  if orders.none?
    skipped += 1
    next
  end

  orders.each do |order|
    order.memo = order.memo.presence ? "#{order.memo}\n#{comment}" : comment
    order.save!
    merged += 1
  end
end

puts "完了: #{merged}件統合, #{skipped}件スキップ(該当Orderなし)"
