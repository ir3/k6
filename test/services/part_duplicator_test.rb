require "test_helper"

# Ａ部品メンテナンス（旧 partsmente.asp）の「新部品を複製」
class PartDuplicatorTest < ActiveSupport::TestCase
  setup do
    @part = Part.create!(pcode: "A0001", form: "6L28HX", jname: "和名", ename: "English", stock: "S", sel_unit: "10",
                         weightkg: 1.5, munit: 2, newprice: 2500, price: 1000, itemno: "7", cordno: "C9", comment: "元の備考")
  end

  def duplicate(code)
    PartDuplicator.new(@part, code).call
  end

  test "makes a new part with the new code and the same information" do
    assert_difference -> { Part.count }, 1 do
      result = duplicate("A0002")
      assert result.success?
      copy = result.part
      assert_not_equal @part.id, copy.id
      assert_equal "A0002", copy.pcode
      %i[form jname ename stock sel_unit weightkg munit newprice price itemno cordno comment].each do |column|
        assert_equal @part[column], copy[column], column
      end
    end
    assert_equal "A0001", @part.reload.pcode
  end

  test "the code is normalized to half-width upper case without surrounding spaces" do
    assert_equal "AB-12", duplicate("　ａｂ-１２ ").part.pcode
  end

  test "an empty code, the same code and an existing code are refused and nothing is made" do
    Part.create!(pcode: "A0003")
    assert_no_difference -> { Part.count } do
      assert_equal "新しい部品コードを入力してください。", duplicate("  ").error
      assert_match(/元の部品と同じ部品コードです/, duplicate("A0001").error)
      assert_match(/元の部品と同じ部品コードです/, duplicate("a0001").error)
      assert_equal "部品コード「A0003」は、すでにＡ部品台帳にあります。", duplicate("a0003").error
    end
  end

  test "a code with spaces or Japanese characters, or a too long code, is refused" do
    assert_no_difference -> { Part.count } do
      [ "A 0004", "部品", "A" * 256 ].each { |bad| assert_not duplicate(bad).success?, bad }
    end
  end
end
