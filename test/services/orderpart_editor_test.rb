require "test_helper"

# 注文部品詳細編集からの登録（asp/partseditA / partseditI / partseditB / partsreg2 相当）
class OrderpartEditorTest < ActiveSupport::TestCase
  setup do
    # 1個あたりの重量は 2.0kg ÷ 計測単位2 = 1.0kg
    @part = Part.create!(pcode: "A001", jname: "和名", ename: "English", newprice: 1000, weightkg: 2.0, munit: 2)
    @orderpart = Orderpart.create!(mno: 202610001, sno: 10, partno: "A001", itemno: "1", info: "元の備考",
                                   qty: 2, unitpd: 1000, irate: 1.0, totala: 2000, unitweight: 0.5, totalweight: 1.0)
  end

  def edit(input)
    OrderpartEditor.new(@orderpart, input).call
  end

  test "changes the sort order" do
    result = edit(sno: "25")
    assert result.success?
    assert_equal "順", result.label
    assert_equal 25, @orderpart.reload.sno
  end

  test "the sort order may be zero or negative like the existing data" do
    assert edit(sno: "-10").success?
    assert_equal(-10, @orderpart.reload.sno)
  end

  test "changes the item no and the remark, and an empty value clears them" do
    assert edit(itemno: " 7 ").success?
    assert_equal "7", @orderpart.reload.itemno
    assert edit(info: "新しい備考").success?
    assert_equal "新しい備考", @orderpart.reload.info
    assert edit(info: "　 ").success?
    assert_nil @orderpart.reload.info
  end

  test "changing the quantity recalculates the total amount and the total weight from the part master" do
    assert edit(qty: "5").success?
    @orderpart.reload
    assert_equal [ 5, 5000, 5.0 ], [ @orderpart.qty, @orderpart.totala, @orderpart.totalweight ]
  end

  test "the quantity may be 0" do
    assert edit(qty: "0").success?
    @orderpart.reload
    assert_equal [ 0, 0, 0.0 ], [ @orderpart.qty, @orderpart.totala, @orderpart.totalweight ]
  end

  test "full-width digits are accepted" do
    assert edit(qty: "１２").success?
    assert_equal 12, @orderpart.reload.qty
  end

  test "changes the loose quantity" do
    assert edit(bqty: "49").success?
    assert_equal 49, @orderpart.reload.bqty
  end

  test "an invalid number is refused and nothing changes" do
    {
      sno: [ "abc", "", "1.5", "100000" ], qty: [ "-1", "x", "", "1000000" ], bqty: [ "-3", "1e3", " " ]
    }.each do |field, values|
      values.each do |value|
        before = @orderpart.reload.attributes
        result = edit(field => value)
        assert_not result.success?, "#{field}=#{value.inspect}"
        assert_match(/整数で入力してください/, result.error)
        assert_equal before, @orderpart.reload.attributes
      end
    end
  end

  test "a too long text is refused" do
    assert_not edit(itemno: "あ" * 31).success?
    assert_not edit(info: "あ" * 101).success?
    assert edit(itemno: "あ" * 30).success?
    assert edit(info: "あ" * 100).success?
  end

  test "an empty input is refused" do
    result = edit({})
    assert_not result.success?
    assert_match(/登録する項目がありません/, result.error)
  end

  test "only the given field is changed" do
    edit(info: "だけ変える")
    @orderpart.reload
    assert_equal [ 10, "1", 2, 2000 ], [ @orderpart.sno, @orderpart.itemno, @orderpart.qty, @orderpart.totala ]
  end

  test "the weight uses the stored unit weight when the part is not in the master" do
    orderpart = Orderpart.create!(mno: 202610001, sno: 20, partno: "NOMASTER", qty: 1, unitpd: 10, totala: 10,
                                  unitweight: 0.53, totalweight: 0.53)
    OrderpartEditor.new(orderpart, qty: "7").call
    assert_equal 3.71, orderpart.reload.totalweight
  end

  test "the weight is taken from the total divided by the quantity when no unit weight is stored" do
    orderpart = Orderpart.create!(mno: 202610001, sno: 20, partno: "NOMASTER", qty: 4, unitpd: 10, totala: 40,
                                  unitweight: 0, totalweight: 2.0)
    OrderpartEditor.new(orderpart, qty: "6").call
    assert_equal 3.0, orderpart.reload.totalweight
  end

  test "the weight is 0 when the master has no weight" do
    @part.update!(weightkg: nil)
    edit(qty: "5")
    assert_equal 0.0, @orderpart.reload.totalweight
  end
end
