require "test_helper"

# 在庫メンテナンスからの更新（旧 zaikomente.asp の各ボタン）
class StockMaintainerTest < ActiveSupport::TestCase
  setup do
    @part = Part.create!(pcode: "A001", jname: "和名", newprice: 2500)
    Stock.create!(partno: "A001", num: 10, irprice: 2500)
    Stock.create!(partno: "A001", num: -3, irprice: 2500)
    @maintainer = StockMaintainer.new("a001 ")
  end

  test "the part number is normalized and the part is found" do
    assert_equal "A001", @maintainer.partno
    assert_equal @part, @maintainer.part
  end

  test "change_price updates the new sale price of the part" do
    result = @maintainer.change_price("3,000")
    assert_not result.success?
    result = @maintainer.change_price("３０００")
    assert result.success?
    assert_equal 3000, @part.reload.newprice
    assert_match(/3,000 円/, result.message)
  end

  test "change_price refuses invalid input and a part that is not in the master" do
    %w[abc -1 1.5 10000000].push("").each do |raw|
      assert_not @maintainer.change_price(raw).success?, raw.inspect
    end
    assert_equal 2500, @part.reload.newprice
    result = StockMaintainer.new("NOMASTER").change_price("100")
    assert_not result.success?
    assert_match(/部品台帳に登録がない/, result.error)
  end

  test "adjust_to adds a positive adjustment row as an in-stock row" do
    result = nil
    travel_to Time.zone.local(2026, 10, 6, 12) do
      result = @maintainer.adjust_to("12")
    end
    assert result.success?
    row = Stock.reorder(:id).last
    assert_equal [ "A001", 5, "調整", 0, 2500, 1, 0, Date.new(2026, 10, 6) ],
                 [ row.partno, row.num, row.memo, row.mno, row.irprice, row.ikubun, row.okubun, row.indate ]
    assert_equal [ 0, 0, 0, 0, 0 ], [ row.novalid, row.kind, row.onum, row.inprice, row.invalue ]
    assert_equal 12, Stock.on_hand("A001")
    assert_match(/実在庫 12 に一致化/, result.message)
    assert_match(/\+5/, result.message)
  end

  test "adjust_to adds a negative adjustment row as an out-of-stock row" do
    assert @maintainer.adjust_to("4").success?
    row = Stock.reorder(:id).last
    assert_equal [ -3, 0, 2 ], [ row.num, row.ikubun, row.okubun ]
    assert_equal 4, Stock.on_hand("A001")
  end

  test "adjust_to to the same number adds nothing" do
    assert_no_difference -> { Stock.count } do
      result = @maintainer.adjust_to("7")
      assert result.success?
      assert_match(/調整は登録しませんでした/, result.message)
    end
  end

  test "adjust_to may bring the stock to 0" do
    assert @maintainer.adjust_to("0").success?
    assert_equal 0, Stock.on_hand("A001")
  end

  test "adjust_to refuses invalid input and adds nothing" do
    %w[abc -1 1.5 1000000].push("").each do |raw|
      assert_no_difference -> { Stock.count } do
        assert_not @maintainer.adjust_to(raw).success?, raw.inspect
      end
    end
  end

  test "adjust_to uses the latest ledger price when the part is not in the master" do
    Stock.create!(partno: "ONLYLEDGER", num: 1, irprice: 111)
    Stock.create!(partno: "ONLYLEDGER", num: 1, irprice: 222)
    StockMaintainer.new("ONLYLEDGER").adjust_to("5")
    row = Stock.reorder(:id).last
    assert_equal [ "ONLYLEDGER", 3, 222 ], [ row.partno, row.num, row.irprice ]
  end

  test "change_standard and change_forecast create and update the setting" do
    assert @maintainer.change_standard("4").success?
    assert @maintainer.change_forecast("９").success?
    setting = StockSetting.find_by!(partno: "A001")
    assert_equal [ 4, 9 ], [ setting.snum, setting.znum ]
    assert @maintainer.change_standard("6").success?
    assert_equal [ 6, 9 ], StockSetting.find_by!(partno: "A001").then { [ it.snum, it.znum ] }
    assert_equal 1, StockSetting.where(partno: "A001").count
  end

  test "change_standard and change_forecast refuse invalid input" do
    [ :change_standard, :change_forecast ].each do |action|
      %w[abc -1 100000 1.5].push("").each do |raw|
        assert_not @maintainer.public_send(action, raw).success?, "#{action} #{raw.inspect}"
      end
    end
    assert_equal 0, StockSetting.count
  end

  test "set_hidden toggles the nonview flag and keeps the other values" do
    @maintainer.change_standard("4")
    assert @maintainer.set_hidden(true).success?
    setting = StockSetting.find_by!(partno: "A001")
    assert setting.hidden?
    assert_equal 4, setting.snum
    assert @maintainer.set_hidden(false).success?
    assert_not StockSetting.find_by!(partno: "A001").hidden?
  end

  # --- 入庫登録（旧 zaikoin.asp → nyukoEntry.asp） ---

  def receive(maintainer = @maintainer, **overrides)
    maintainer.receive(**{ num: "5", price: "2500", ikubun: "1" }.merge(overrides))
  end

  def last_stock
    Stock.reorder(:id).last
  end

  test "known? is true for a part in the part ledger or in the stock ledger, not for others" do
    assert @maintainer.known?
    Part.create!(pcode: "PARTONLY")
    assert StockMaintainer.new("partonly").known?
    Stock.create!(partno: "LEDGERONLY", num: 1)
    assert StockMaintainer.new("ledgeronly").known?
    assert_not StockMaintainer.new("NOWHERE").known?
    Stock.create!(partno: "GONE", num: 1, deleted_at: Time.current)
    assert_not StockMaintainer.new("GONE").known?
  end

  test "receive adds one in-stock row written the way the old entry screen did" do
    result = nil
    travel_to Time.zone.local(2026, 11, 11, 10) do
      assert_difference -> { Stock.count }, 1 do
        result = receive(num: "5")
      end
    end
    assert result.success?
    row = last_stock
    assert_equal "A001", row.partno
    assert_equal Date.new(2026, 11, 11), row.indate
    assert_equal [ 5, 2500, 1, 0 ], [ row.num, row.irprice, row.ikubun, row.okubun ]
    assert_equal [ 0, 0, 0, 0, 0, 0, 0, 0 ], row.values_at(:kind, :inprice, :invalue, :irvalue, :orprice, :orvalue, :mno, :onum)
    assert_equal 0, row.novalid
    assert_nil row.memo
    assert_nil row.sname
    assert_nil row.cname
    assert_equal 12, Stock.on_hand("A001") # 10 - 3 + 5
    assert_match(/A001/, result.message)
    assert_match(/5/, result.message)
    assert_match(/買取品/, result.message)
    assert_match(/12/, result.message)
  end

  test "receive keeps the memo, the ship name and the company name, and drops the blank ones" do
    receive(memo: "  返品の事情  ", ship: "五色丸", company: "テスト海運")
    row = last_stock
    assert_equal [ "返品の事情", "五色丸", "テスト海運" ], [ row.memo, row.sname, row.cname ]

    receive(memo: "  ", ship: "", company: nil)
    row = last_stock
    assert_nil row.memo
    assert_nil row.sname
    assert_nil row.cname
  end

  test "receive records the entered price on the row and does not change the price of the part" do
    assert receive(price: "2800").success?
    assert_equal 2800, last_stock.irprice
    assert_equal 2500, @part.reload.newprice
  end

  test "receive accepts full-width numbers" do
    assert receive(num: "１２", price: "３０００").success?
    assert_equal [ 12, 3000 ], [ last_stock.num, last_stock.irprice ]
  end

  test "receive records each of the four kinds of the receipt" do
    Stock::INBOUND_KINDS.each_key do |kind|
      assert receive(ikubun: kind.to_s).success?, kind
      assert_equal kind, last_stock.ikubun
      assert_equal 0, last_stock.okubun
    end
  end

  test "receive refuses wrong input and adds nothing" do
    bad = [
      { num: "0" }, { num: "-1" }, { num: "abc" }, { num: "" }, { num: "1.5" }, { num: "1000000" },
      { price: "abc" }, { price: "-1" }, { price: "" }, { price: "10000000" },
      { ikubun: "0" }, { ikubun: "5" }, { ikubun: "" }, { ikubun: nil }, { ikubun: "abc" },
      { memo: "あ" * 256 }, { ship: "あ" * 51 }, { company: "あ" * 51 }
    ]
    assert_no_difference -> { Stock.count } do
      bad.each do |overrides|
        result = receive(**overrides)
        assert_not result.success?, overrides.inspect
        assert_not_nil result.error
      end
    end
  end

  test "receive accepts the longest values the old database could hold" do
    assert receive(memo: "あ" * 255, ship: "あ" * 50, company: "あ" * 50, num: "999999", price: "9999999").success?
  end

  test "receive says which input is wrong" do
    assert_match(/入庫数/, receive(num: "0").error)
    assert_match(/仕入時販売単価/, receive(price: "x").error)
    assert_match(/入庫区分/, receive(ikubun: "9").error)
    assert_match(/備考/, receive(memo: "あ" * 256).error)
    assert_match(/船名/, receive(ship: "あ" * 51).error)
    assert_match(/会社名/, receive(company: "あ" * 51).error)
  end

  test "receive refuses a part that is neither in the part ledger nor in the stock ledger" do
    assert_no_difference -> { Stock.count } do
      result = receive(StockMaintainer.new("NOWHERE"))
      assert_not result.success?
      assert_match(/見つかりません/, result.error)
    end
  end

  test "receive works for a part that is only in the stock ledger, and the price is then required" do
    Stock.create!(partno: "LEDGERONLY", num: 2)
    maintainer = StockMaintainer.new("ledgeronly")
    assert receive(maintainer, price: "100").success?
    row = last_stock
    assert_equal [ "LEDGERONLY", 100 ], [ row.partno, row.irprice ]
    assert_equal 7, Stock.on_hand("LEDGERONLY")
  end

  test "receive writes the spelling of the part ledger, even when the ledger lines are in lower case" do
    Stock.create!(partno: "b002", num: 1)
    Part.create!(pcode: "B002", newprice: 10)
    receive(StockMaintainer.new("b002"))
    assert_equal "B002", last_stock.partno
    assert_equal 6, Stock.on_hand("B002")
  end

  test "receive reduces the number on order by the received number" do
    Stock.create!(partno: "A001", num: 0, onum: 8)
    receive(num: "5")
    assert_equal(-5, last_stock.onum)
    assert_equal 3, Stock.of_part("A001").sum(:onum)
  end

  test "receive does not reduce the number on order below zero" do
    Stock.create!(partno: "A001", num: 0, onum: 3)
    receive(num: "5")
    assert_equal(-3, last_stock.onum)
    assert_equal 0, Stock.of_part("A001").sum(:onum)

    receive(num: "5")
    assert_equal 0, last_stock.onum
    assert_equal 0, Stock.of_part("A001").sum(:onum)
  end

  test "receive reduces the number on order the same way for the returns" do
    Stock.create!(partno: "A001", num: 0, onum: 4)
    receive(num: "1", ikubun: "3")
    assert_equal(-1, last_stock.onum)
  end

  test "receive tells how much the number on order was reduced only when it was" do
    assert_no_match(/発注中/, receive(num: "1").message)
    Stock.create!(partno: "A001", num: 0, onum: 4)
    assert_match(/発注中を 2 減らしました/, receive(num: "2").message)
  end

  test "receive does not count the deleted or invalid lines as the number on order" do
    Stock.create!(partno: "A001", num: 0, onum: 8, deleted_at: Time.current)
    Stock.create!(partno: "A001", num: 0, onum: 8, novalid: 1)
    receive(num: "5")
    assert_equal 0, last_stock.onum
  end

  test "the number on order of other parts is not touched" do
    Stock.create!(partno: "OTHER", num: 0, onum: 9)
    receive(num: "5")
    assert_equal 0, last_stock.onum
    assert_equal 9, Stock.of_part("OTHER").sum(:onum)
  end
end
