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
end
