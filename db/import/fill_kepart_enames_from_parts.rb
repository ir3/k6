# frozen_string_literal: true

# Ｂ部品の英文名称が和文名称と同じものを、同じ部品コードのＡ部品の英文名称で埋める。
# Access から取り込んだ（import_keparts.rb と import_parts.rb）あとに実行する。
# 使い方:
#   DRY_RUN=1 bin/rails runner db/import/fill_kepart_enames_from_parts.rb   # 変えずに、直す行を見る
#   bin/rails runner db/import/fill_kepart_enames_from_parts.rb             # 直す（何度実行してもよい）
#   VERBOSE=1 ...                                                           # 直す行を全件表示する
# 詳しい決まりは db/import/kepart_ename_fill.rb の先頭を参照。

require Rails.root.join("db/import/kepart_ename_fill").to_s

KepartEnameFill.call(dry_run: ENV["DRY_RUN"].present?, verbose: ENV["VERBOSE"].present?)
