require "test_helper"

# Ａ部品詳細入力（旧 npartsr.asp → partsreg7.asp）の、Ａ部品台帳への新規登録
class PartRegistrarTest < ActiveSupport::TestCase
  def register(**input)
    PartRegistrar.new({ pcode: "N0001" }.merge(input)).call
  end

  test "registers a part with every item in the place the old partsreg7 put it" do
    result = register(pcode: "N0001", form: "6L28HX", jname: "新しい部品", ename: "NEW PART", munit: "3", weightkg: "1.25", newprice: "4500")
    assert result.success?
    part = Part.find_by!(pcode: "N0001")
    assert_equal result.part, part
    assert_equal [ "6L28HX", "新しい部品", "NEW PART", 3, 1.25 ], [ part.form, part.jname, part.ename, part.munit, part.weightkg ]
    # 単価は、新単価と現行単価の両方に入る
    assert_equal [ 4500, 4500 ], [ part.newprice, part.price ]
    assert_nil part.sel_unit
  end

  test "only the part code is needed, an empty price is 0 and an empty weight or unit is nothing" do
    part = register(pcode: "n0002").part
    assert_equal "N0002", part.pcode
    assert_equal [ 0, 0 ], [ part.newprice, part.price ]
    assert_nil part.weightkg
    assert_nil part.munit
    assert_nil part.jname
  end

  test "full-width digits are accepted and the text is trimmed" do
    part = register(jname: "　部品　", munit: "１", weightkg: "２.５", newprice: "３９００").part
    assert_equal [ "部品", 1, 2.5, 3900 ], [ part.jname, part.munit, part.weightkg, part.newprice ]
  end

  test "an empty or existing part code is refused and nothing is made" do
    Part.create!(pcode: "EXIST1")
    assert_no_difference -> { Part.count } do
      assert_equal "新しい部品コードを入力してください。", register(pcode: " ").error
      assert_equal "部品コード「EXIST1」は、すでにＡ部品台帳にあります。", register(pcode: "exist1").error
      assert_not register(pcode: "A 1").success?
    end
  end

  test "a wrong number is refused with its item name and nothing is made" do
    assert_no_difference -> { Part.count } do
      assert_match(/単価は 0 から 2000000000 の整数/, register(newprice: "abc").error)
      assert_match(/単価は/, register(newprice: "-1").error)
      assert_match(/重量は 0 から 1000000 の数/, register(weightkg: "abc").error)
      assert_match(/単位は 0 から 99999 の整数/, register(munit: "1.5").error)
    end
  end

  test "text longer than the old Access column is refused" do
    assert_no_difference -> { Part.count } do
      assert_equal "和文名称は 255 文字以内で入力してください。", register(jname: "あ" * 256).error
      assert_match(/形式は 255 文字以内/, register(form: "A" * 256).error)
    end
    assert register(jname: "あ" * 255).success?
  end

  test "it accepts ActionController::Parameters like the controller passes" do
    params = ActionController::Parameters.new(pcode: "P1", jname: "名称").permit(:pcode, :jname)
    assert PartRegistrar.new(params).call.success?
    assert_equal "名称", Part.find_by!(pcode: "P1").jname
  end
end
