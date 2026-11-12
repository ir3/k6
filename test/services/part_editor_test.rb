require "test_helper"

# Ａ部品メンテナンス（旧 partsmente.asp）の、Ａ部品の1項目の登録
class PartEditorTest < ActiveSupport::TestCase
  setup do
    @part = Part.create!(pcode: "A0001", form: "6L28HX", jname: "和名", ename: "English", sel_unit: "10",
                         weightkg: 1.5, munit: 2, newprice: 2500, price: 1000, itemno: "7", comment: "元の備考")
  end

  def edit(field, value)
    PartEditor.new(@part, field, value).call
  end

  test "changes each text item and reports its label" do
    { form: "形式", jname: "和文名称", ename: "英文名称", sel_unit: "販売単位", comment: "備考" }.each do |field, label|
      result = edit(field, "新しい値")
      assert result.success?, field
      assert_equal label, result.label
      assert_equal "新しい値", @part.reload[field]
    end
  end

  test "text is trimmed including full-width spaces, and an empty value clears it" do
    assert edit(:comment, "　備考です　").success?
    assert_equal "備考です", @part.reload.comment
    assert edit(:comment, "  ").success?
    assert_nil @part.reload.comment
  end

  test "text longer than the old Access column is refused and nothing changes" do
    result = edit(:jname, "あ" * 256)
    assert_not result.success?
    assert_equal "和文名称は 255 文字以内で入力してください。", result.error
    assert_equal "和名", @part.reload.jname
    assert edit(:jname, "あ" * 255).success?
  end

  test "the new price and the current price are separate integers, and full-width digits are accepted" do
    assert_not edit(:newprice, "４,０００").success?
    assert edit(:newprice, "４０００").success?
    assert_equal [ 4000, 1000 ], [ @part.reload.newprice, @part.price ]
    assert edit(:price, "900").success?
    assert_equal [ 4000, 900 ], [ @part.reload.newprice, @part.price ]
  end

  test "a price refuses text, decimals, negatives, an empty value and a value out of range" do
    [ "abc", "1.5", "-1", "", "  ", "2000000001" ].each do |bad|
      result = edit(:newprice, bad)
      assert_not result.success?, bad.inspect
      assert_equal "新単価は 0 から 2000000000 の整数で入力してください。", result.error
    end
    assert_equal 2500, @part.reload.newprice
  end

  test "the weight accepts decimals, and an empty value clears it" do
    assert edit(:weightkg, "２.５").success?
    assert_in_delta 2.5, @part.reload.weightkg
    assert edit(:weightkg, "").success?
    assert_nil @part.reload.weightkg
    [ "abc", "-1", "1.", "1,5", "1000001" ].each { |bad| assert_not edit(:weightkg, bad).success?, bad }
  end

  test "the old part number is kept in the stock setting, not in the part" do
    result = edit(:opartno, "OLD-123")
    assert result.success?
    assert_equal "旧部品番号", result.label
    assert_equal "OLD-123", StockSetting.find_by(partno: "A0001").opartno
    assert_equal "元の備考", @part.reload.comment
  end

  test "the old part number is changed in the existing stock setting and can be cleared" do
    StockSetting.create!(partno: "A0001", snum: 3, opartno: "OLD-1", memo: "補足")
    assert edit(:opartno, "OLD-2").success?
    setting = StockSetting.find_by(partno: "A0001")
    assert_equal [ "OLD-2", 3, "補足" ], [ setting.opartno, setting.snum, setting.memo ]
    assert edit(:opartno, "").success?
    assert_nil setting.reload.opartno
    assert_equal 1, StockSetting.where(partno: "A0001").count
  end

  test "clearing the old part number of a part without a stock setting does not create one" do
    assert edit(:opartno, "").success?
    assert_equal 0, StockSetting.where(partno: "A0001").count
  end

  test "the old part number is limited to the 16 characters of the old Access column" do
    assert_not edit(:opartno, "1" * 17).success?
    assert_equal 0, StockSetting.where(partno: "A0001").count
    assert edit(:opartno, "1" * 16).success?
  end

  test "a lower-case part code finds its stock setting in upper case" do
    @part.update_columns(pcode: "a0001")
    assert edit(:opartno, "OLD").success?
    assert_equal "OLD", StockSetting.find_by(partno: "A0001").opartno
  end

  test "only the registered items can be changed (the part code, the unit of measure and the id cannot)" do
    [ "pcode", "id", "munit", "itemno", "deleted_at", "", nil, "unknown" ].each do |field|
      result = edit(field, "X")
      assert_not result.success?, field.inspect
      assert_equal "登録する項目がありません。", result.error
    end
    assert_equal "A0001", @part.reload.pcode
    assert_equal 2, @part.munit
  end
end
