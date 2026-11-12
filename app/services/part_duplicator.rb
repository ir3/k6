# frozen_string_literal: true

# Ａ部品メンテナンス（旧 partsmente.asp）の「新部品を複製」。
# 元の部品の情報を保持して、新しい部品コードの部品を作る（旧 npartsreg2 相当）。
# 部品コード以外（形式・名称・販売単位・単価・重量・備考など）は、元の部品のままコピーする。
class PartDuplicator
  Result = Data.define(:part, :error) do
    def success? = error.nil?
  end

  COPIED = %i[form jname ename stock sel_unit price newprice weightkg munit itemno cordno comment].freeze

  def initialize(part, new_code)
    @part = part
    @code = PartCode.normalize(new_code)
  end

  def call
    # 元と同じコードは「すでにある」ではなく、専用のメッセージで断る
    return failure("元の部品と同じ部品コードです。新しい部品コードに修正してください。") if @code == @part.pcode.to_s.upcase

    error = PartCode.error_for(@code)
    return failure(error) if error

    copy = Part.create!(@part.slice(*COPIED).merge(pcode: @code))
    Result.new(part: copy, error: nil)
  end

  private

  def failure(message) = Result.new(part: nil, error: message)
end
