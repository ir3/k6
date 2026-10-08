# frozen_string_literal: true

module XlsxReports
  # 「並び替え後表示」画面のボタンと帳票クラスの対応表。
  # klass が無いものはまだ未実装(ボタンは表示するが、押すと未実装メッセージを返す)。
  # kubun は出力時に order_logs(旧「取引管理」)へ記録する区分。旧ASPの値のまま。nil は記録しない。
  Registry = {
    "mitsumori_irai" => { label: "部品見積依頼出力", kubun: OrderLog::KUBUN_MITSUMORI_IRAI, klass: "XlsxReports::MitsumoriIraiReport" },
    "mitsumori_with_no" => { label: "部品番号あり見積出力", kubun: OrderLog::KUBUN_MITSUMORI, klass: "XlsxReports::MitsumoriReport" },
    "mitsumori_without_no" => { label: "部品番号なし見積出力", kubun: OrderLog::KUBUN_MITSUMORI, klass: "XlsxReports::MitsumoriNoPartReport" },
    "juchu_memo" => { label: "受注メモ出力", kubun: OrderLog::KUBUN_JUCHU_MEMO, klass: "XlsxReports::JuchuMemoReport" },
    "seikyu_a" => { label: "請求書A", kubun: OrderLog::KUBUN_SEIKYU, klass: "XlsxReports::SeikyuReport" },
    "seikyu_a_hikae" => { label: "請求書A控", kubun: OrderLog::KUBUN_SEIKYU, klass: "XlsxReports::SeikyuHikaeReport" },
    "nohin_a" => { label: "納品書A", kubun: OrderLog::KUBUN_NOHIN_A, klass: "XlsxReports::NohinReport" },
    "seikyu_b" => { label: "請求書B", kubun: OrderLog::KUBUN_SEIKYU, klass: "XlsxReports::SeikyuBReport" },
    "seikyu_b_hikae" => { label: "請求書B控", kubun: OrderLog::KUBUN_SEIKYU, klass: "XlsxReports::SeikyuBHikaeReport" },
    "nohin_b" => { label: "納品書B", kubun: OrderLog::KUBUN_SEIKYU, klass: "XlsxReports::NohinBReport" },
    "syukka_annai" => { label: "出荷案内書", kubun: OrderLog::KUBUN_SYUKKA_ANNAI },
    "juryo" => { label: "物品受領書", kubun: nil }
  }.freeze
end
