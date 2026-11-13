require "test_helper"

# Ｂ部品の新規登録（旧 hpartsreg6.asp / partsreg44.asp）。KE部品台帳と在庫台帳Ｂに1行ずつ
class KepartRegistrarTest < ActiveSupport::TestCase
  def register(source, **input)
    KepartRegistrar.new({ pcode: "NEW1~" }.merge(input), source: source).call
  end

  test "from a part: the part and one stockb row are made like the old hpartsreg6" do
    result = register(:part, pcode: "977120500~", size: "10x20", jname: "ホゴアエン", ename: "ANTI-CORROSION ZINC",
                             munit: "2", num: "3", weightkg: "1.1", newprice: "4500", itemno: "0", ikubun: "2")
    assert result.success?
    kepart = Kepart.find_by!(pcode: "977120500~")
    assert_equal [ "10x20", "ホゴアエン", "ANTI-CORROSION ZINC", 2, 1.1, "0", "2" ],
                 [ kepart.size, kepart.jname, kepart.ename, kepart.munit, kepart.weightkg, kepart.itemno, kepart.cordno ]
    assert_nil kepart.form
    # 単価は、新単価と現行単価の両方
    assert_equal [ 4500, 4500 ], [ kepart.newprice, kepart.price ]

    stock = Stockb.find_by!(partno: "977120500~")
    assert_equal [ 0, 2, 3, 4500, Date.current ], [ stock.kind, stock.ikubun, stock.num, stock.irprice, stock.indate ]
    assert_equal 1, Stockb.where(partno: "977120500~").count
  end

  test "from a part: a zero quantity has no stock date" do
    register(:part, pcode: "ZERO~", num: "0")
    stock = Stockb.find_by!(partno: "ZERO~")
    assert_equal [ 0, nil ], [ stock.num, stock.indate ]
  end

  test "from nothing: an entered English name is written as it is, the stock row is kind 1 without a kind of receipt or a date" do
    result = register(:scratch, pcode: "x-100", jname: "新しい部品", ename: "NEW PART", munit: "1", num: "4", weightkg: "0.5", newprice: "1200",
                                itemno: "9", size: "無視される", ikubun: "3")
    assert result.success?
    kepart = Kepart.find_by!(pcode: "X-100")
    assert_equal [ "新しい部品", "NEW PART", "9", "2" ], [ kepart.jname, kepart.ename, kepart.itemno, kepart.cordno ]
    assert_nil kepart.size
    assert_equal [ 1200, 1200 ], [ kepart.newprice, kepart.price ]

    stock = Stockb.find_by!(partno: "X-100")
    assert_equal [ 1, 4, 1200, nil, nil ], [ stock.kind, stock.num, stock.irprice, stock.ikubun, stock.indate ]
  end

  test "from nothing: without an English name the Japanese name is copied to it like before" do
    kepart = register(:scratch, pcode: "COPY-1", jname: "和文のみ").kepart
    assert_equal [ "和文のみ", "和文のみ" ], [ kepart.jname, kepart.ename ]
    # 空白だけの英文名称も、入力なしと同じ
    kepart = register(:scratch, pcode: "COPY-2", jname: "和文のみ", ename: "　 ").kepart
    assert_equal "和文のみ", kepart.ename
  end

  test "from nothing: with an English name and no Japanese name only the English name is written" do
    kepart = register(:scratch, pcode: "ENG-ONLY", ename: "ENGLISH ONLY").kepart
    assert_nil kepart.jname
    assert_equal "ENGLISH ONLY", kepart.ename
  end

  test "from nothing: a too long English name is refused" do
    assert_no_difference [ -> { Kepart.count }, -> { Stockb.count } ] do
      assert_equal "英文名称は 255 文字以内で入力してください。", register(:scratch, jname: "和", ename: "E" * 256).error
    end
    assert register(:scratch, pcode: "LONG-OK", jname: "和", ename: "E" * 255).success?
  end

  test "from a part: an empty English name stays empty (it is not copied from the Japanese name)" do
    kepart = register(:part, pcode: "PART-1~", jname: "和文のみ").kepart
    assert_nil kepart.ename
  end

  test "empty unit is 1, empty weight is 0, empty price is 0 and empty quantity is 0 like the old screens" do
    kepart = register(:part, pcode: "EMPTY~").kepart
    assert_equal [ 1, 0.0, 0, 0 ], [ kepart.munit, kepart.weightkg, kepart.newprice, kepart.price ]
    assert_equal [ 0, 0 ], [ Stockb.find_by!(partno: "EMPTY~").num, Stockb.find_by!(partno: "EMPTY~").irprice ]
    assert_equal 1, Stockb.find_by!(partno: "EMPTY~").ikubun
  end

  test "full-width digits are accepted and the text is trimmed" do
    kepart = register(:part, jname: "　部品　", munit: "２", num: "３", weightkg: "１.５", newprice: "３９００").kepart
    assert_equal [ "部品", 2, 1.5, 3900 ], [ kepart.jname, kepart.munit, kepart.weightkg, kepart.newprice ]
    assert_equal 3, Stockb.find_by!(partno: "NEW1~").num
  end

  test "an empty or existing code is refused and nothing is made" do
    Kepart.create!(pcode: "HAVE1~")
    assert_no_difference [ -> { Kepart.count }, -> { Stockb.count } ] do
      assert_equal "部品コードを入力してください。", register(:part, pcode: " ").error
      assert_equal "部品コード「HAVE1~」は、すでにＢ部品台帳にあります。", register(:part, pcode: "have1~").error
      assert_equal "部品コード「HAVE1~」は、すでにＢ部品台帳にあります。", register(:scratch, pcode: "HAVE1~").error
      assert_not register(:part, pcode: "A 1~").success?
    end
  end

  test "a wrong value is refused with its item name and nothing is made" do
    assert_no_difference [ -> { Kepart.count }, -> { Stockb.count } ] do
      assert_match(/単価は 0 から 2000000000 の整数/, register(:part, newprice: "abc").error)
      assert_match(/重量は 0 から 1000000 の数/, register(:part, weightkg: "abc").error)
      assert_match(/計測単位は 0 から 99999 の整数/, register(:part, munit: "1.5").error)
      assert_match(/数量は 0 から 999999 の整数/, register(:part, num: "-1").error)
      assert_equal "入庫区分を選んでください。", register(:part, ikubun: "9").error
      assert_equal "寸法は 50 文字以内で入力してください。", register(:part, size: "あ" * 51).error
      assert_equal "ItemNoは 12 文字以内で入力してください。", register(:part, itemno: "1" * 13).error
      assert_equal "和文名称は 255 文字以内で入力してください。", register(:scratch, jname: "あ" * 256).error
    end
  end

  test "if the stock row cannot be made the part is not made either" do
    # 在庫台帳Ｂの登録を失敗させる（クラスメソッドを、このテストの間だけ差し替える）
    Stockb.define_singleton_method(:create!) { |*| raise ActiveRecord::RecordInvalid }
    begin
      assert_raises(ActiveRecord::RecordInvalid) { register(:part, pcode: "ROLL~") }
    ensure
      Stockb.singleton_class.send(:remove_method, :create!)
    end
    assert_not Kepart.exists?(pcode: "ROLL~")
  end

  test "defaults from a part: the code gets the tilde, a numeric sales unit is the unit of measure, the quantity is 1" do
    part = Part.create!(pcode: "A0001", jname: "和名", ename: "ENG", sel_unit: "10", weightkg: 2.5, newprice: 3000)
    assert_equal({ pcode: "A0001~", jname: "和名", ename: "ENG", munit: "10", num: "1", weightkg: 2.5, newprice: 3000, itemno: "0", ikubun: "1" },
                 KepartRegistrar.defaults_from(part))
    %w[SET ｸﾐ].push(nil).each do |unit|
      assert_equal "1", KepartRegistrar.defaults_from(Part.new(pcode: "A", sel_unit: unit))[:munit], unit.inspect
    end
  end

  test "an unknown source is refused" do
    assert_raises(ArgumentError) { KepartRegistrar.new({}, source: :other) }
  end
  # 注文から来たとき（旧 partsin32.asp → partsreg4.asp）
  def register_for(order, **input)
    KepartRegistrar.new({ pcode: "ORD1" }.merge(input), source: :scratch, order: order).call
  end

  def order_for_test
    Order.create!(mno: 202611060, adlist_id: 1, irate: 0.85)
  end

  test "from an order: the part and one order row are made, the stock row is not" do
    order = order_for_test
    assert_difference [ -> { Kepart.count }, -> { Orderpart.where(mno: order.mno).count } ], 1 do
      assert_no_difference -> { Stockb.count } do
        result = register_for(order, jname: "和", ename: "ENG", itemno: "7", munit: "2", num: "4", weightkg: "3", newprice: "1000")
        assert result.success?
        assert_equal result.kepart.pcode, result.orderpart.partno
      end
    end
    kepart = Kepart.find_by!(pcode: "ORD1")
    assert_equal [ "和", "ENG", "7", "2", 3.0, 1000, 1000, "2" ],
                 [ kepart.jname, kepart.ename, kepart.itemno, kepart.munit.to_s, kepart.weightkg, kepart.newprice, kepart.price, kepart.cordno ]
  end

  test "from an order: the row takes the entered quantity and price, and the total is the price times the quantity" do
    order = order_for_test
    row = register_for(order, num: "4", newprice: "1000", munit: "2", weightkg: "3", itemno: "7").orderpart
    assert_equal [ 4, 1000, 4000, "7", "2", 0.85 ], [ row.qty, row.unitpd, row.totala, row.itemno, row.cordno, row.irate ]
    # 1個あたりの重量は、重量を計測単位で割る（Ａ部品・Ｂ部品の明細と同じ）
    assert_equal [ 1.5, 6.0 ], [ row.unitweight, row.totalweight ]
  end

  test "from an order: an empty quantity is 1, an empty price is 0 and an empty weight is nothing" do
    order = order_for_test
    result = register_for(order)
    row = result.orderpart
    assert_equal [ 1, 0, 0 ], [ row.qty, row.unitpd, row.totala ]
    assert_nil result.kepart.weightkg
    assert_equal "1", row.itemno
  end

  test "from an order: the row continues the order of the rows of the order" do
    order = order_for_test
    Orderpart.create!(mno: order.mno, sno: 10, partno: "X")
    NOrderpart.create!(mno: order.mno, sno: 20)
    assert_equal 30, register_for(order).orderpart.sno
  end

  test "from an order: a wrong value is refused and nothing is made" do
    order = order_for_test
    assert_no_difference [ -> { Kepart.count }, -> { Orderpart.count } ] do
      assert_match(/数量は 0 から 999999 の整数/, register_for(order, num: "-1").error)
      assert_match(/単価は/, register_for(order, newprice: "abc").error)
      assert_equal "部品コードを入力してください。", register_for(order, pcode: " ").error
    end
  end

  test "from an order: a part code that is already a B part is refused and no row is added" do
    order = order_for_test
    Kepart.create!(pcode: "ORD1")
    assert_no_difference -> { Orderpart.count } do
      assert_equal "部品コード「ORD1」は、すでにＢ部品台帳にあります。", register_for(order).error
    end
  end

  test "from an order without a management number nothing is made" do
    order = Order.create!(mno: nil)
    assert_no_difference [ -> { Kepart.count }, -> { Orderpart.count } ] do
      assert_equal "管理番号がない注文には部品を追加できません。", register_for(order).error
    end
  end

  test "from an order: if the row cannot be made the part is not made either" do
    order = order_for_test
    Orderpart.define_singleton_method(:create!) { |*| raise ActiveRecord::RecordInvalid }
    begin
      assert_raises(ActiveRecord::RecordInvalid) { register_for(order, pcode: "ROLL2") }
    ensure
      Orderpart.singleton_class.send(:remove_method, :create!)
    end
    assert_not Kepart.exists?(pcode: "ROLL2")
  end
end
