# frozen_string_literal: true

# Ａ部品メンテナンス（旧 partsmente.asp）の「新部品を複製」。
# 元の部品の情報を保持して、新しい部品コードの部品を作る（旧 npartsreg2 相当）。
# 部品コード以外（形式・名称・販売単位・単価・重量・備考など）は、元の部品のままコピーする。
class PartDuplicator
  Result = Data.define(:part, :error) do
    def success? = error.nil?
  end

  # 旧Accessの部品コードの長さ
  CODE_MAX_LENGTH = 255
  COPIED = %i[form jname ename stock sel_unit price newprice weightkg munit itemno cordno comment].freeze

  def initialize(part, new_code)
    @part = part
    # 全角英数字は半角にし、前後の空白を除き、大文字にそろえる（部品台帳の部品コードは大文字）
    @code = new_code.to_s.unicode_normalize(:nfkc).strip.upcase
  end

  def call
    return failure("新しい部品コードを入力してください。") if @code.empty?
    return failure("部品コードは #{CODE_MAX_LENGTH} 文字以内で入力してください。") if @code.length > CODE_MAX_LENGTH
    return failure("部品コードは、英数字と記号だけで入力してください。") unless @code.match?(/\A[!-~]+\z/)
    return failure("元の部品と同じ部品コードです。新しい部品コードに修正してください。") if @code == @part.pcode.to_s.upcase
    return failure("部品コード「#{@code}」は、すでにＡ部品台帳にあります。") if Part.exists?([ "UPPER(pcode) = ?", @code ])

    copy = Part.create!(@part.slice(*COPIED).merge(pcode: @code))
    Result.new(part: copy, error: nil)
  end

  private

  def failure(message) = Result.new(part: nil, error: message)
end
