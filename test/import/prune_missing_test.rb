require "test_helper"
require Rails.root.join("db/import/prune_missing").to_s

# 在庫台帳の取り込みで、Access に無くなった行を k6 からも取り除く処理（db/import/prune_missing.rb）
class PruneMissingTest < ActiveSupport::TestCase
  setup do
    # Access には ID 1〜5 の行がある。k6 には 1〜5 と、Access に無い 3（古い行）、k6 で後から足した 9 がある、という場面
    [ 1, 2, 4, 5, 9 ].each { |id| Stock.create!(id: id, partno: "P#{id}", num: id, mno: 100 + id, memo: "行#{id}") }
    Stock.create!(id: 3, partno: "P3", num: -12, mno: 202610041, memo: "消された行")
    @access_ids = Set[1, 2, 4, 5]
    @io = StringIO.new
  end

  def prune(model = Stock, access_ids = @access_ids, **options)
    ImportPrune.call(model, access_ids, label: "stocks", io: @io, **options)
  end

  test "stale_ids are the rows that are not in Access and not above the biggest id of Access" do
    assert_equal [ 3 ], ImportPrune.stale_ids(Stock, @access_ids)
  end

  test "the rows above the biggest id of Access are rows added in k6 and are kept" do
    prune
    assert Stock.exists?(9)
  end

  test "the rows that are not in Access are deleted and nothing else is" do
    result = prune
    assert_equal({ ids: [ 3 ], deleted: 1 }, result)
    assert_equal [ 1, 2, 4, 5, 9 ], Stock.unscoped.order(:id).pluck(:id)
  end

  test "the deleted rows are listed so that it is known afterwards which ones went" do
    prune
    output = @io.string
    assert_match(/id=3 部品=P3 数量=-12 取引=202610041 .*備考=消された行/, output)
    assert_match(/Access に無い行を 1 件削除しました/, output)
  end

  test "nothing to delete is said so" do
    Stock.where(id: 3).delete_all
    assert_equal({ ids: [], deleted: 0 }, prune)
    assert_match(/削除 0 件/, @io.string)
  end

  test "a soft deleted row that is not in Access is deleted too" do
    Stock.where(id: 3).update_all(deleted_at: Time.current)
    prune
    assert_not Stock.unscoped.exists?(3)
  end

  test "nothing is deleted if no rows were read from Access" do
    result = prune(Stock, Set.new)
    assert_equal 0, result[:deleted]
    assert_equal 6, Stock.unscoped.count
    assert_match(/1行も読めなかった/, @io.string)
    assert_equal 0, prune(Stock, []).fetch(:deleted)
  end

  test "more rows than the limit stops the deletion and deletes none" do
    Stock.create!(id: 6, partno: "P6", num: 1)
    Stock.create!(id: 7, partno: "P7", num: 1)
    error = assert_raises(ImportPrune::TooMany) { prune(Stock, Set[1, 2, 4, 5, 8], max_delete: 2) }
    assert_match(/3 件あり、上限 2 件を超える/, error.message)
    assert_match(/MAX_DELETE=3/, error.message)
    assert_equal 8, Stock.unscoped.count
  end

  test "the same number of rows as the limit is allowed" do
    assert_equal 1, prune(Stock, @access_ids, max_delete: 1)[:deleted]
  end

  test "dry run deletes nothing and says what would go" do
    result = prune(Stock, @access_ids, dry_run: true)
    assert_equal({ ids: [ 3 ], deleted: 0 }, result)
    assert Stock.exists?(3)
    assert_match(/DRY_RUN のため、1 件は削除しません/, @io.string)
    assert_match(/id=3/, @io.string)
  end

  test "many rows are deleted in batches" do
    now = Time.current
    Stock.insert_all((100..1_199).map { |id| { id: id, partno: "B#{id}", num: 1, created_at: now, updated_at: now } })
    result = prune(Stock, Set[1, 2, 4, 5, 2_000], max_delete: 2_000)
    assert_equal 1_100 + 1 + 1, result[:deleted] # 3 と 9 と 100..1199
    assert_equal [ 1, 2, 4, 5 ], Stock.unscoped.order(:id).pluck(:id)
  end

  test "the long list is cut and says how many more" do
    Stock.insert_all((100..170).map { |id| { id: id, partno: "L#{id}", num: 1, created_at: Time.current, updated_at: Time.current } })
    prune(Stock, Set[1, 2, 4, 5, 1_000], max_delete: 1_000)
    assert_match(/…ほか \d+ 件/, @io.string)
    assert_equal ImportPrune::LIST_LIMIT, @io.string.scan(/対象 id=/).size
  end

  test "it works for the ledger B too and does not touch the ledger A" do
    [ 1, 2, 3 ].each { |id| Stockb.create!(id: id, partno: "B#{id}", num: 1) }
    result = prune(Stockb, Set[1, 3])
    assert_equal [ 2 ], result[:ids]
    assert_equal [ 1, 3 ], Stockb.order(:id).pluck(:id)
    assert_equal 6, Stock.unscoped.count
  end
end
