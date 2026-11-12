# frozen_string_literal: true

# Ａ部品の部品コードの読み取りと検査。複製（PartDuplicator）と新規登録（PartRegistrar）で使う。
module PartCode
  # 旧Accessの部品コードの長さ
  MAX_LENGTH = 255

  module_function

  # 全角英数字は半角にし、前後の空白を除き、大文字にそろえる（部品台帳の部品コードは大文字）
  def normalize(raw)
    raw.to_s.unicode_normalize(:nfkc).strip.upcase
  end

  # 新しい部品コード（normalize 済み）として使えないときの理由。使えるなら nil
  def error_for(code)
    return "新しい部品コードを入力してください。" if code.empty?
    return "部品コードは #{MAX_LENGTH} 文字以内で入力してください。" if code.length > MAX_LENGTH
    return "部品コードは、英数字と記号だけで入力してください。" unless code.match?(/\A[!-~]+\z/)
    return "部品コード「#{code}」は、すでにＡ部品台帳にあります。" if Part.exists?([ "UPPER(pcode) = ?", code ])

    nil
  end
end
