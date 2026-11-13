require "test_helper"

# 注文部品詳細の「注釈」の更新（旧 partsin.asp → updcom.asp「注釈登録」）
class OrderAnnotationEditorTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(mno: 202611090)
  end

  def edit(text, order = @order)
    OrderAnnotationEditor.new(order, text).call
  end

  def annotations(mno = @order.mno)
    OrderAnnotation.where(mno: mno).order(:id).pluck(:comment)
  end

  test "adds the annotation of an order that has none" do
    result = edit("清水仕様")
    assert result.success?
    assert_equal "注釈", result.label
    assert_equal [ "清水仕様" ], annotations
    assert_equal [ 1 ], OrderAnnotation.where(mno: @order.mno).pluck(:tvalid)
  end

  test "updates the annotation that the order already has, without adding another" do
    OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: "元の注釈")
    assert_no_difference -> { OrderAnnotation.count } do
      assert edit("新しい注釈").success?
    end
    assert_equal [ "新しい注釈" ], annotations
  end

  test "updates every row of the order like the old UPDATE WHERE MNo, and no row of another order" do
    OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: "古い1")
    OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: "古い2")
    OrderAnnotation.create!(tvalid: 1, mno: 202611091, comment: "別の注文")
    edit("そろえる")
    assert_equal [ "そろえる", "そろえる" ], annotations
    assert_equal [ "別の注文" ], annotations(202611091)
  end

  test "the text is trimmed including full-width spaces and a line break becomes a space" do
    edit("　前後の空白　")
    assert_equal [ "前後の空白" ], annotations
    OrderAnnotation.delete_all
    edit("1行目\r\n2行目")
    assert_equal [ "1行目 2行目" ], annotations
  end

  test "an empty annotation clears the text and keeps one row" do
    OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: "消す")
    assert edit("  ").success?
    assert_equal [ "" ], annotations
    OrderAnnotation.delete_all
    assert edit(nil).success?
    assert_equal [ "" ], annotations
  end

  test "a too long annotation is refused and nothing changes" do
    OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: "そのまま")
    result = edit("あ" * 256)
    assert_not result.success?
    assert_equal "注釈は 255 文字以内で入力してください。", result.error
    assert_equal [ "そのまま" ], annotations
    assert edit("あ" * 255).success?
  end

  test "an order without a management number is refused" do
    order = Order.create!(mno: nil)
    assert_no_difference -> { OrderAnnotation.count } do
      assert_equal "管理番号がない注文には、注釈を登録できません。", edit("x", order).error
    end
  end

  test "the report reads the annotation that was just written" do
    edit("報告書に出る注釈")
    assert_equal "報告書に出る注釈", OrderAnnotation.where(mno: @order.mno).order(:id).last&.comment.presence
  end
end
