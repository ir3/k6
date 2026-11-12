require "test_helper"

# Ｂ部品メンテナンス（旧 hiteijomente.asp）の、KE部品の1項目の登録
class KepartEditorTest < ActiveSupport::TestCase
  setup do
    @kepart = Kepart.create!(pcode: "E001~", form: "6L28HX", size: "10x20", jname: "和名", ename: "English",
                             itemno: "7", weightkg: 1.5, munit: 2, newprice: 2500, price: 1000, comment: "元の備考")
  end

  def edit(field, value)
    KepartEditor.new(@kepart, field, value).call
  end

  test "changes each text item and reports its label" do
    { size: "寸法", form: "形式", itemno: "ItemNo", jname: "和文名称", ename: "英文名称", comment: "備考" }.each do |field, label|
      result = edit(field, "新しい値")
      assert result.success?, field
      assert_equal label, result.label
      assert_equal "新しい値", @kepart.reload[field]
    end
  end

  test "text is trimmed including full-width spaces, and an empty value clears it" do
    assert edit(:comment, "　備考です　").success?
    assert_equal "備考です", @kepart.reload.comment
    assert edit(:comment, "  ").success?
    assert_nil @kepart.reload.comment
  end

  test "text longer than the old Access column is refused and nothing changes" do
    result = edit(:size, "あ" * 51)
    assert_not result.success?
    assert_equal "寸法は 50 文字以内で入力してください。", result.error
    assert_equal "10x20", @kepart.reload.size

    assert edit(:size, "あ" * 50).success?
    assert_not edit(:itemno, "1" * 13).success?
    assert edit(:itemno, "1" * 12).success?
  end

  test "the unit of measure and the reference price are integers, and full-width digits are accepted" do
    assert edit(:munit, "１０").success?
    assert_equal 10, @kepart.reload.munit
    result = edit(:newprice, "３,９５０")
    assert_not result.success?
    assert edit(:newprice, "3950").success?
    assert_equal 3950, @kepart.reload.newprice
  end

  test "the reference price changes only the new sale price, not the current price" do
    assert edit(:newprice, "4000").success?
    @kepart.reload
    assert_equal 4000, @kepart.newprice
    assert_equal 1000, @kepart.price
  end

  test "an integer item refuses text, decimals, negatives, an empty value and a value out of range" do
    [ "abc", "1.5", "-1", "", "  ", "100000" ].each do |bad|
      result = edit(:munit, bad)
      assert_not result.success?, bad.inspect
      assert_equal "計測単位は 0 から 99999 の整数で入力してください。", result.error
    end
    assert_equal 2, @kepart.reload.munit
    assert_not edit(:newprice, "2000000001").success?
    assert_equal 2500, @kepart.reload.newprice
  end

  test "the weight accepts decimals and full-width digits, and an empty value clears it" do
    assert edit(:weightkg, "２.５").success?
    assert_in_delta 2.5, @kepart.reload.weightkg
    assert edit(:weightkg, "0").success?
    assert_in_delta 0.0, @kepart.reload.weightkg
    assert edit(:weightkg, "").success?
    assert_nil @kepart.reload.weightkg
  end

  test "the weight refuses text, negatives and a value out of range" do
    [ "abc", "-1", "1.", ".5", "1,5", "1000001" ].each do |bad|
      result = edit(:weightkg, bad)
      assert_not result.success?, bad.inspect
      assert_match(/重量は 0 から 1000000 の数で入力してください/, result.error)
    end
    assert_in_delta 1.5, @kepart.reload.weightkg
  end

  test "only the registered items can be changed (the part code and the id cannot)" do
    [ "pcode", "id", "deleted_at", "created_at", "", nil, "unknown" ].each do |field|
      result = edit(field, "X")
      assert_not result.success?, field.inspect
      assert_equal "登録する項目がありません。", result.error
    end
    assert_equal "E001~", @kepart.reload.pcode
  end

  test "the item may be given as a string like the form sends it" do
    assert edit("comment", "文字列で来た").success?
    assert_equal "文字列で来た", @kepart.reload.comment
  end
end
