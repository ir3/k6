require "test_helper"

# 掛け率を掛けた単価の丸め（asp/include/fsysfunc.asp の kmarume / smarume 相当）
class PriceRoundingTest < ActiveSupport::TestCase
  test "round_up goes up to the unit of the size of the price" do
    {
      0 => 0, 1 => 10, 10 => 10, 11 => 20, 9_999 => 10_000,
      10_000 => 10_000, 10_001 => 10_100, 99_999 => 100_000,
      100_000 => 100_000, 100_001 => 101_000, 999_999 => 1_000_000,
      1_000_000 => 1_000_000, 1_000_001 => 1_010_000
    }.each { |price, expected| assert_equal expected, PriceRounding.round_up(price), "round_up(#{price})" }
  end

  test "round_up drops the fraction before rounding up like the ASP did" do
    assert_equal 1_000, PriceRounding.round_up(1000.9)
    assert_equal 990, PriceRounding.round_up(982.4)
  end

  test "round_half_up rounds half up to the unit of the size of the price" do
    {
      0 => 0, 4 => 0, 5 => 10, 1_004 => 1_000, 1_005 => 1_010,
      12_345 => 12_300, 12_350 => 12_400, 123_456 => 123_000, 123_500 => 124_000,
      1_234_567 => 1_230_000, 1_235_000 => 1_240_000
    }.each { |price, expected| assert_equal expected, PriceRounding.round_half_up(price), "round_half_up(#{price})" }
  end

  test "round_half_up works on the fraction of a price times a rate" do
    assert_equal 980, PriceRounding.round_half_up(982.4)
    assert_equal 990, PriceRounding.round_half_up(985.0)
    # 切り上げた先の桁が変わる境目
    assert_equal 10_000, PriceRounding.round_half_up(9_999.7)
    # VBScriptでは 1009 になっていた癖を直して、1円の桁が常に 0 になる
    assert_equal 1_010, PriceRounding.round_half_up(1009.6)
  end

  test "the results are always a multiple of the unit" do
    [ 3, 99, 1_234.5, 56_789.9, 345_678.1, 7_654_321.7 ].each do |price|
      unit = PriceRounding.unit_for(price)
      assert_equal 0, PriceRounding.round_up(price) % unit, "round_up(#{price})"
      assert_equal 0, PriceRounding.round_half_up(price) % unit, "round_half_up(#{price})"
    end
  end
end
