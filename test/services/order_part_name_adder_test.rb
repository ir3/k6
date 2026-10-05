require "test_helper"

# 部品番号が不明な分を部品名だけで仮登録する（asp/partsreg5.asp 相当）
class OrderPartNameAdderTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(mno: 202610001, adlist_id: 1)
  end

  def add(input, order: @order)
    OrderPartNameAdder.new(order, input).call
  end

  def rows_of(order = @order)
    NOrderpart.where(mno: order.mno).order(:id).to_a
  end

  test "adds one no-part-number row that shows and sums up without breaking" do
    result = add("ACﾊﾟﾂｷﾝ *Wｳｹｶﾊﾞ")
    assert result.success?

    row = rows_of.sole
    assert_equal [ 202610001, 10, "ACﾊﾟﾂｷﾝ *Wｳｹｶﾊﾞ" ], [ row.mno, row.sno, row.partsname ]
    # 有効(取り消し線にならず小計に入る)・数量1・単価と掛け率と重量は0
    assert_equal [ 1, 1.0, 0, 0.0, 0, 0.0 ], [ row.tvalid, row.qty, row.unitpd, row.rate, row.totala, row.weight ]
  end

  test "it is not added to the part number rows" do
    assert_no_difference -> { Orderpart.where(mno: @order.mno).reorder(nil).count } do
      add("部品名のみ")
    end
  end

  test "surrounding spaces including full-width ones are removed but the inside is kept" do
    add("　 ｱｲﾃﾑ  ﾒｲ　")
    assert_equal "ｱｲﾃﾑ  ﾒｲ", rows_of.sole.partsname
  end

  test "line breaks and tabs become a space" do
    add("上\r\n下\t端")
    assert_equal "上 下 端", rows_of.sole.partsname
  end

  test "a blank name adds nothing" do
    [ nil, "", "   ", "　", "\n\t" ].each do |input|
      result = add(input)
      assert_not result.success?, "input=#{input.inspect}"
      assert_match(/入力してください/, result.error)
    end
    assert_empty rows_of
  end

  test "a too long name adds nothing" do
    assert add("あ" * OrderPartNameAdder::MAX_LENGTH).success?
    result = add("あ" * (OrderPartNameAdder::MAX_LENGTH + 1))
    assert_not result.success?
    assert_match(/#{OrderPartNameAdder::MAX_LENGTH}文字以内/, result.error)
    assert_equal 1, rows_of.size
  end

  test "an order without a management number is refused" do
    order = Order.create!(adlist_id: 1)
    assert_not add("部品名", order: order).success?
    assert_equal 0, NOrderpart.where(mno: nil).count
  end

  test "sno shares the numbering with the part number rows" do
    Orderpart.create!(mno: @order.mno, sno: 30, partno: "X1")
    NOrderpart.create!(mno: @order.mno, sno: 50, partsname: "既存")
    add("追加")
    assert_equal 60, rows_of.last.sno

    add("もう1つ")
    assert_equal 70, rows_of.last.sno
  end

  test "a row added by the part number adder and then this one are numbered one after another" do
    Part.create!(pcode: "A00401252", newprice: 140)
    OrderPartAdder.new(@order, "A00401252").call
    add("部品名のみ")
    assert_equal [ 10, 20 ], [ Orderpart.where(mno: @order.mno).reorder(nil).first.sno, rows_of.last.sno ]
  end

  test "rows are added only to the given order" do
    other = Order.create!(mno: 202610002, adlist_id: 1)
    add("部品名")
    assert_equal 1, rows_of.size
    assert_empty rows_of(other)
  end
end
