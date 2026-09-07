# frozen_string_literal: true

module XlsxReports
  # 「並び替え後表示」画面のボタンと帳票クラスの対応表。
  # klass が無いものはまだ未実装(ボタンは表示するが、押すと未実装メッセージを返す)。
  Registry = {
    "mitsumori_irai" => { label: "部品見積依頼出力" },
    "mitsumori_with_no" => { label: "部品番号あり見積出力" },
    "mitsumori_without_no" => { label: "部品番号なし見積出力" },
    "juchu_memo" => { label: "受注メモ出力" },
    "seikyu_a" => { label: "請求書A", klass: "XlsxReports::SeikyuReport" },
    "seikyu_a_hikae" => { label: "請求書A控" },
    "nohin_a" => { label: "納品書A" },
    "seikyu_b" => { label: "請求書B" },
    "seikyu_b_hikae" => { label: "請求書B控" },
    "nohin_b" => { label: "納品書B" },
    "syukka_annai" => { label: "出荷案内書" },
    "juryo" => { label: "物品受領書" }
  }.freeze
end
