require "test_helper"

# Ｂ部品在庫メンテナンス（旧 hzaikomente.asp）からの更新。Ａ部品の StockMaintainer と、台帳・日付の入れ方が違うところを確かめる
class StockbMaintainerTest < ActiveSupport::TestCase
  setup do
    @kepart = Kepart.create!(pcode: "E001~", form: "6L28HX", size: "10x20", jname: "和名", newprice: 2500)
    Stockb.create!(partno: "E001~", num: 10, irprice: 2500)
    Stockb.create!(partno: "E001~", num: -3, irprice: 2500)
    @maintainer = StockbMaintainer.new("e001~ ")
  end

  def receive(maintainer = @maintainer, **overrides)
    maintainer.receive(**{ num: "5", price: "2500", ikubun: "1" }.merge(overrides))
  end

  def issue(maintainer = @maintainer, **overrides)
    maintainer.issue(**{ num: "2", price: "2500", okubun: "2" }.merge(overrides))
  end

  def last_stockb
    Stockb.reorder(:id).last
  end

  def make_order(mno: 202611001)
    Adlist.create!(no: "9100", company: "出庫先海運株式会社", ruby: "しゅっこ")
    Order.create!(mno: mno, adlist_id: 9100, shipname: "注文の船")
  end

  test "the part is found in the KE part ledger and the number is normalized" do
    assert_equal "E001~", @maintainer.partno
    assert_equal @kepart, @maintainer.part
    assert_equal 7, @maintainer.on_hand
  end

  test "known? is true for a KE part or a part in the ledger B, not for others" do
    assert @maintainer.known?
    Kepart.create!(pcode: "KEONLY~")
    assert StockbMaintainer.new("KEONLY~").known?
    Stockb.create!(partno: "LEDGERONLY~", num: 1)
    assert StockbMaintainer.new("ledgeronly~").known?
    assert_not StockbMaintainer.new("NOWHERE").known?
  end

  test "a part that is only in the ledger A is not known to the B maintainer" do
    Stock.create!(partno: "ONLYA", num: 3)
    Part.create!(pcode: "ONLYA")
    assert_not StockbMaintainer.new("ONLYA").known?
  end

  test "the names of the ledgers are those of the B parts" do
    assert_equal "KE部品台帳", @maintainer.master_name
    assert_equal "在庫台帳B", @maintainer.ledger_name
    assert_equal "部品「NOWHERE」はKE部品台帳にも在庫台帳Bにも見つかりません。", StockbMaintainer.new("nowhere").unknown_message
    assert_equal "部品「NOWHERE」は部品台帳にも在庫台帳にも見つかりません。", StockMaintainer.new("nowhere").unknown_message
  end

  test "receive adds a line to the ledger B in the form of the old nyukoEntry2" do
    assert_no_difference -> { Stock.count } do
      assert_difference -> { Stockb.count }, 1 do
        assert receive(num: "5", ikubun: "3", memo: "返品です", ship: "五色丸", company: "テスト海運").success?
      end
    end
    row = last_stockb
    assert_equal [ "E001~", 5, 2500, 1, 3, 0 ], [ row.partno, row.num, row.irprice, row.kind, row.ikubun, row.okubun ]
    assert_nil row.indate
    assert_equal [ "返品です", "五色丸", "テスト海運" ], [ row.memo, row.sname, row.cname ]
    assert_equal [ 0, 0, 0, 0, 0, 0, 0 ], [ row.mno, row.onum, row.inprice, row.invalue, row.irvalue, row.orprice, row.orvalue ]
    assert_equal 12, Stockb.on_hand("E001~")
  end

  test "receive does not change the price of the part" do
    receive(price: "2800")
    assert_equal 2500, @kepart.reload.newprice
    assert_equal 2800, last_stockb.irprice
  end

  test "receive does not reduce the number on order, which the ledger B does not have" do
    Stock.create!(partno: "E001~", num: 0, onum: 8)
    result = receive(num: "5")
    assert_equal 0, last_stockb.onum
    assert_no_match(/発注中/, result.message)
    assert_equal 8, Stock.of_part("E001~").sum(:onum)
  end

  test "receive does not reduce a number on order even if the ledger B has one" do
    Stockb.create!(partno: "E001~", num: 0, onum: 8)
    result = receive(num: "5")
    assert_equal 0, last_stockb.onum
    assert_no_match(/発注中/, result.message)
    assert_equal 8, Stockb.of_part("E001~").sum(:onum)
  end

  test "receive tells the stock after it and the kind" do
    assert_equal "E001~ を 5 入庫登録しました（買取品。現在の在庫数 12）。", receive.message
  end

  test "receive refuses wrong input and an unknown part" do
    assert_no_difference -> { Stockb.count } do
      [ "", "abc", "0", "-1", "1000000" ].each { |raw| assert_match(/入庫数/, receive(num: raw).error, raw.inspect) }
      assert_match(/仕入時販売単価/, receive(price: "").error)
      assert_match(/入庫区分/, receive(ikubun: "9").error)
      assert_match(/備考/, receive(memo: "あ" * 256).error)
      assert_match(/KE部品台帳にも在庫台帳Bにも/, receive(StockbMaintainer.new("NOWHERE")).error)
    end
  end

  test "issue adds a line with a negative number in the form of the old syukoEntry2" do
    assert_no_difference -> { Stock.count } do
      assert_difference -> { Stockb.count }, 1 do
        assert issue(num: "2", okubun: "1", memo: "貸出です", ship: "出庫船", company: "出庫会社").success?
      end
    end
    row = last_stockb
    assert_equal [ "E001~", -2, 2500, 1, 0, 0 ], [ row.partno, row.num, row.irprice, row.okubun, row.ikubun, row.kind ]
    assert_equal Date.current, row.indate
    assert_nil row.outdate
    assert_equal [ 0, 0 ], [ row.mno, row.onum ]
    assert_equal 5, Stockb.on_hand("E001~")
  end

  test "issue links the line to an order, and refuses an order that is not in the ledger" do
    make_order
    assert issue(mno: "202611001").success?
    assert_equal 202611001, last_stockb.mno
    assert_no_difference -> { Stockb.count } do
      assert_match(/202699999/, issue(mno: "202699999").error)
      assert_match(/数字/, issue(mno: "abc").error)
    end
  end

  test "issue does not stop at more than the stock and tells it" do
    result = issue(num: "20")
    assert result.success?
    assert_match(/現在の在庫数 -13/, result.message)
  end

  test "issue refuses wrong input" do
    assert_no_difference -> { Stockb.count } do
      [ "", "abc", "0", "1000000" ].each { |raw| assert_match(/出庫数/, issue(num: raw).error, raw.inspect) }
      assert_match(/出庫区分/, issue(okubun: "3").error)
      assert_match(/KE部品台帳にも在庫台帳Bにも/, issue(StockbMaintainer.new("NOWHERE")).error)
    end
  end

  test "adjust_to with more than the stock adds a line like a receipt" do
    result = @maintainer.adjust_to("10")
    assert result.success?
    row = last_stockb
    assert_equal [ 3, "調整", 2500, 1, 1, 0, 0 ], [ row.num, row.memo, row.irprice, row.kind, row.ikubun, row.okubun, row.mno ]
    assert_nil row.indate
    assert_equal 10, Stockb.on_hand("E001~")
    assert_match(/実在庫 10 に一致化しました（計算在庫 7 に対して \+3 の調整を登録）/, result.message)
  end

  test "adjust_to with less than the stock adds a line like an issue" do
    @maintainer.adjust_to("4")
    row = last_stockb
    assert_equal [ -3, "調整", 0, 0, 2 ], [ row.num, row.memo, row.kind, row.ikubun, row.okubun ]
    assert_equal Date.current, row.indate
    assert_equal 4, Stockb.on_hand("E001~")
  end

  test "adjust_to with the same number adds nothing" do
    assert_no_difference -> { Stockb.count } do
      assert_match(/同じなので/, @maintainer.adjust_to("7").message)
      assert_match(/実在庫数/, @maintainer.adjust_to("abc").error)
    end
  end

  test "adjust_to does not touch the ledger A" do
    Stock.create!(partno: "E001~", num: 100)
    assert_no_difference -> { Stock.count } do
      @maintainer.adjust_to("1")
    end
  end

  test "set_hidden hides and shows the part in the settings of the B parts only" do
    assert @maintainer.set_hidden(true).success?
    assert StockbSetting.for_part("E001~").hidden?
    assert_equal 0, StockSetting.count
    assert @maintainer.set_hidden(false).success?
    assert_not StockbSetting.for_part("E001~").hidden?
  end

  test "the A part maintainer still writes to the ledger A with the old form" do
    Part.create!(pcode: "E001~", newprice: 100)
    Stock.create!(partno: "E001~", num: 5)
    assert_no_difference -> { Stockb.count } do
      assert StockMaintainer.new("E001~").receive(num: "2", price: "100", ikubun: "1").success?
    end
    row = Stock.reorder(:id).last
    assert_equal [ 0, Date.current ], [ row.kind, row.indate ]
  end
end
