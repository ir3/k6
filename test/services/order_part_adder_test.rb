require "test_helper"

# 部品番号を入力して注文に部品明細を追加する（asp/partsreg3.asp 相当）
class OrderPartAdderTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(mno: 202610001, adlist_id: 1, irate: 0.85)
    @part = Part.create!(pcode: "A00401252", jname: "テスト部品", newprice: 140, price: 120,
                         weightkg: 0.5, munit: 1, itemno: "7", cordno: "9")
  end

  def add(input, order: @order)
    OrderPartAdder.new(order, input).call
  end

  def rows_of(order = @order)
    Orderpart.where(mno: order.mno).reorder(:id).to_a
  end

  test "adds one normal row filled the way partsreg3.asp does" do
    result = add("A00401252")
    assert result.success?
    assert_equal "A00401252", result.partno
    assert_equal 1, result.rows.size

    row = rows_of.first
    assert_equal [ 202610001, 10, "A00401252", nil ], [ row.mno, row.sno, row.partno, row.kzaiko ]
    assert_equal [ "7", "9", 1 ], [ row.itemno, row.cordno, row.qty ]
    assert_equal [ 140, 0.85, 140 ], [ row.unitpd, row.irate, row.totala ]
    assert_equal [ 0.5, 0.5 ], [ row.unitweight, row.totalweight ]
  end

  test "a part in the stock ledger adds a stock row marked ^ and then a normal row" do
    Stock.create!(partno: "A00401252", num: 0)
    result = add("A00401252")

    assert_equal 2, result.rows.size
    stock_row, normal_row = rows_of
    assert_equal [ "^", 10 ], [ stock_row.kzaiko, stock_row.sno ]
    assert_equal [ nil, 20 ], [ normal_row.kzaiko, normal_row.sno ]
    assert_equal [ 140, 140 ], [ stock_row.unitpd, normal_row.unitpd ]
    assert_equal [ 0.85, 0.85 ], [ stock_row.irate, normal_row.irate ]
  end

  test "a deleted stock ledger row does not count as in stock" do
    Stock.create!(partno: "A00401252", num: 5, deleted_at: Time.current)
    assert_equal 1, add("A00401252").rows.size
    assert_nil rows_of.first.kzaiko
  end

  test "finds the part with lower case, full-width characters and surrounding spaces" do
    [ "a00401252", " A00401252 ", "ａ００４０１２５２", "　Ａ00401252　" ].each do |input|
      assert add(input).success?, "input=#{input.inspect}"
    end
    assert_equal 4, rows_of.size
  end

  test "a lower case partno in the stock ledger is still recognized" do
    Stock.create!(partno: "a00401252", num: 1)
    assert_equal 2, add("A00401252").rows.size
  end

  test "an unknown part number adds nothing" do
    result = add("ZZZ999")
    assert_not result.success?
    assert_match(/見つかりません/, result.error)
    assert_empty rows_of
  end

  test "a blank input adds nothing" do
    [ nil, "", "   ", "　" ].each do |input|
      result = add(input)
      assert_not result.success?, "input=#{input.inspect}"
      assert_match(/入力してください/, result.error)
    end
    assert_empty rows_of
  end

  test "a deleted part is not found" do
    @part.update!(deleted_at: Time.current)
    assert_not add("A00401252").success?
    assert_empty rows_of
  end

  test "an order without a management number is refused" do
    order = Order.create!(adlist_id: 1)
    assert_not add("A00401252", order: order).success?
    assert_equal 0, Orderpart.where(mno: nil).count
  end

  test "an unset new price adds the row at 0 with a warning" do
    [ 0, nil ].each do |price|
      @part.update!(newprice: price)
      result = add("A00401252")
      assert result.success?
      assert_equal [ "新販売単価が未設定のため、単価0で追加しました。" ], result.warnings
      assert_equal [ 0, 0 ], [ rows_of.last.unitpd, rows_of.last.totala ]
    end
  end

  test "a set new price gives no warning" do
    assert_empty add("A00401252").warnings
  end

  test "the weight is divided by the measuring unit and rounded to 3 decimals" do
    { [ 10, 100 ] => 0.1, [ 1, 3 ] => 0.333, [ 2.5, 0 ] => 2.5, [ 2.5, nil ] => 2.5, [ nil, 5 ] => 0.0, [ -1, 1 ] => 0.0, [ 0.0001, 1 ] => 0.0 }
      .each do |(weightkg, munit), expected|
      @part.update!(weightkg: weightkg, munit: munit)
      add("A00401252")
      row = rows_of.last
      assert_equal [ expected, expected ], [ row.unitweight, row.totalweight ], "weightkg=#{weightkg.inspect} munit=#{munit.inspect}"
    end
  end

  test "itemno and cordno fall back to 1 and 2 when the part has none" do
    @part.update!(itemno: nil, cordno: "")
    add("A00401252")
    assert_equal [ "1", "2" ], [ rows_of.last.itemno, rows_of.last.cordno ]
  end

  test "an order without a rate adds the row at an equal rate" do
    @order.update!(irate: nil)
    add("A00401252")
    assert_equal 1.0, rows_of.last.irate
  end

  test "sno continues from the largest of the parts and the no-part-number rows" do
    Orderpart.create!(mno: @order.mno, sno: 30, partno: "X1")
    NOrderpart.create!(mno: @order.mno, sno: 50, partsname: "部品名のみ")
    Orderpart.create!(mno: @order.mno, sno: 100, partno: "X2", deleted_at: Time.current)

    add("A00401252")
    assert_equal 60, rows_of.last.sno
  end

  test "rows are added only to the given order" do
    other = Order.create!(mno: 202610002, adlist_id: 1)
    add("A00401252")
    assert_equal 1, rows_of.size
    assert_empty rows_of(other)
  end

  test "nothing is half added when a row fails" do
    Stock.create!(partno: "A00401252", num: 1)
    calls = 0
    original = Orderpart.method(:create!)
    Orderpart.define_singleton_method(:create!) do |*args, **kwargs|
      calls += 1
      raise ActiveRecord::StatementInvalid, "boom" if calls == 2
      original.call(*args, **kwargs)
    end

    assert_raises(ActiveRecord::StatementInvalid) { add("A00401252") }
    assert_empty rows_of
  ensure
    Orderpart.singleton_class.send(:remove_method, :create!)
  end
end
