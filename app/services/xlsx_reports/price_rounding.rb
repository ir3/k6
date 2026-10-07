# frozen_string_literal: true

module XlsxReports
  # 旧ASP(asp/include/fsysfunc.asp)の価格丸め処理。
  module PriceRounding
    # smarume関数相当。四捨五入で丸めるが、桁数に応じて丸め幅が変わる
    # (1万未満:10の位、10万未満:100の位、100万未満:1000の位、100万以上:1万の位。
    # 100万以上は値がいくら大きくなっても1万の位で頭打ち)。
    def self.smarume(number)
      granularity =
        if number < 10_000
          10
        elsif number < 100_000
          100
        elsif number < 1_000_000
          1_000
        else
          10_000
        end
      (number / granularity.to_f).round * granularity
    end
  end
end
