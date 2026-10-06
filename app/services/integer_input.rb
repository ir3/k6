# frozen_string_literal: true

# 画面から入力された整数の読み取り。全角数字も受け付け、範囲外や数字以外は nil を返す
# （旧ASPは英数字入力枠でIME無効化していた）。
module IntegerInput
  module_function

  def parse(raw, range)
    text = raw.to_s.unicode_normalize(:nfkc).strip
    return nil unless text.match?(/\A-?\d+\z/)

    value = text.to_i
    range.cover?(value) ? value : nil
  end
end
