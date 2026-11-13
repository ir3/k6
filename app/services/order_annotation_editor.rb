# frozen_string_literal: true

# 注文部品詳細の「注釈」の更新（旧 partsin.asp → updcom.asp「注釈登録」）。
# 注文ごとに1件。旧ASPと同じく、その取引管理No の注釈があれば更新し、無ければ追加する。
# 旧ASPは、空にすると空白1文字を入れたが（Access の入力必須のため）、k6 では、空のまま持つ。
class OrderAnnotationEditor
  Result = Data.define(:label, :error) do
    def success? = error.nil?
  end

  LABEL = "注釈"
  # 旧Accessの注釈の列の長さ
  MAX_LENGTH = 255

  def initialize(order, text)
    @order = order
    @text = text
  end

  def call
    return failure("管理番号がない注文には、注釈を登録できません。") if @order.mno.blank?

    # 注釈は1行。前後の空白（全角を含む）を除き、途中の改行は空白にする
    text = @text.to_s.gsub(/[\r\n]+/, " ").gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    return failure("#{LABEL}は #{MAX_LENGTH} 文字以内で入力してください。") if text.length > MAX_LENGTH

    OrderAnnotation.transaction do
      rows = OrderAnnotation.where(mno: @order.mno)
      if rows.exists?
        # 旧 updcom.asp の UPDATE ... WHERE MNo と同じく、その取引管理No のすべての行を更新する
        rows.update_all(comment: text, updated_at: Time.current)
      else
        OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: text)
      end
    end
    Result.new(label: LABEL, error: nil)
  end

  private

  def failure(message) = Result.new(label: LABEL, error: message)
end
