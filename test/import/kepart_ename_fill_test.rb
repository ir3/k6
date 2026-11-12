require "test_helper"
require Rails.root.join("db/import/kepart_ename_fill").to_s

# Ｂ部品の英文名称が和文名称と同じものを、元のＡ部品の英文名称で埋める処理（db/import/kepart_ename_fill.rb）
class KepartEnameFillTest < ActiveSupport::TestCase
  setup do
    # Ａ部品 977120500 は英文名称あり。Ｂ部品 977120500~ は、和文と英文が同じ（Access の ke部品 の多くがこの形）
    Part.create!(pcode: "977120500", jname: "ﾎｺﾞｱｴﾝ", ename: "ANTI-CORROSION  ZINC")
    @same = Kepart.create!(pcode: "977120500~", jname: "ホゴアエン", ename: "ホゴアエン")
    @io = StringIO.new
  end

  def fill(**options)
    KepartEnameFill.call(io: @io, **options)
  end

  test "an English name that is the same as the Japanese name is replaced by the one of the A part" do
    result = fill
    assert_equal 1, result[:updated]
    assert_equal "ANTI-CORROSION  ZINC", @same.reload.ename
    assert_equal "ホゴアエン", @same.jname
    assert_match(/id=#{@same.id} 部品=977120500~ 英文名称 ホゴアエン → ANTI-CORROSION  ZINC/, @io.string)
    assert_match(/1 件直しました/, @io.string)
  end

  test "the updated_at is not changed" do
    Kepart.where(id: @same.id).update_all(updated_at: Time.zone.local(2020, 1, 2, 3, 4, 5))
    fill
    assert_equal Time.zone.local(2020, 1, 2, 3, 4, 5), @same.reload.updated_at
  end

  test "an English name that was already written is kept" do
    @same.update_columns(ename: "OWN NAME")
    assert_equal 0, fill[:updated]
    assert_equal "OWN NAME", @same.reload.ename
  end

  test "a part without the tilde is not touched even if the A part has the same code" do
    Part.create!(pcode: "AAA111", jname: "別の部品", ename: "OTHER THING")
    plain = Kepart.create!(pcode: "AAA111", jname: "ナット", ename: "ナット")
    assert_equal 1, fill[:updated]
    assert_equal "ナット", plain.reload.ename
  end

  test "without an A part the English name is kept" do
    lonely = Kepart.create!(pcode: "ZZZ999~", jname: "ボルト", ename: "ボルト")
    fill
    assert_equal "ボルト", lonely.reload.ename
  end

  test "an English name of the A part without letters is not copied" do
    Part.create!(pcode: "KANA01", jname: "ｶﾅ", ename: "ｶﾅﾀﾞｹ")
    Part.create!(pcode: "ZERO01", jname: "ゼロ", ename: "０")
    kana = Kepart.create!(pcode: "KANA01~", jname: "カナ", ename: "カナ")
    zero = Kepart.create!(pcode: "ZERO01~", jname: "ゼロ", ename: "ゼロ")
    assert_equal 1, fill[:updated]
    assert_equal "カナ", kana.reload.ename
    assert_equal "ゼロ", zero.reload.ename
  end

  test "spaces around the names are ignored when comparing and the A part's name is written without them" do
    Part.create!(pcode: "SP001", jname: "ｽﾍﾟ", ename: " GASKET ")
    sp = Kepart.create!(pcode: "SP001~", jname: "ガスケット ", ename: " ガスケット")
    fill
    assert_equal "GASKET", sp.reload.ename
  end

  test "an A part code with different English names is not decided" do
    Part.create!(pcode: "DUP01", jname: "ﾀﾞﾌﾞ1", ename: "FIRST")
    Part.create!(pcode: "DUP01", jname: "ﾀﾞﾌﾞ2", ename: "SECOND")
    dup = Kepart.create!(pcode: "DUP01~", jname: "ダブリ", ename: "ダブリ")
    fill
    assert_equal "ダブリ", dup.reload.ename
  end

  test "a deleted A part is not used" do
    Part.create!(pcode: "DEL01", jname: "ｹｽ", ename: "DELETED", deleted_at: Time.current)
    gone = Kepart.create!(pcode: "DEL01~", jname: "ケス", ename: "ケス")
    fill
    assert_equal "ケス", gone.reload.ename
  end

  test "DRY_RUN lists the rows and changes nothing" do
    result = fill(dry_run: true)
    assert_equal 0, result[:updated]
    assert_equal [ @same.id ], result[:rows].map { |row| row[:id] }
    assert_equal "ホゴアエン", @same.reload.ename
    assert_match(/DRY_RUN のため、1 件は変更しません/, @io.string)
  end

  test "running it again changes nothing more" do
    fill
    @io.truncate(0)
    assert_equal 0, fill[:updated]
    assert_match(/直す行はありません/, @io.string)
  end

  test "only the first rows are listed unless verbose" do
    (1..KepartEnameFill::LIST_LIMIT + 2).each do |n|
      Part.create!(pcode: "MANY#{n}", jname: "ﾏﾆｰ", ename: "MANY #{n}")
      Kepart.create!(pcode: "MANY#{n}~", jname: "マニー#{n}", ename: "マニー#{n}")
    end
    fill(dry_run: true)
    assert_equal KepartEnameFill::LIST_LIMIT, @io.string.scan(/^  id=/).size
    assert_match(/…ほか 3 件/, @io.string)

    @io.truncate(0)
    @io.rewind
    fill(dry_run: true, verbose: true)
    assert_equal KepartEnameFill::LIST_LIMIT + 3, @io.string.scan(/^  id=/).size
  end
end
