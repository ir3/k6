# ExcelファイルをRailsで作成

k6でExcel(.xlsx)帳票を出力する仕組みについてのメモ。`caxlsx`(旧axlsx)gemを使い、
細かい罫線(辺ごとに違うスタイル・二重罫線など)まで再現できることを検証した上で、
`XlsxReports`という共通基盤を作り、旧システム(ASP+Excel)の帳票12種類をすべて実装した。

## 使っているgem

```ruby
gem "caxlsx_rails"
```

`caxlsx`(Axlsx定数を提供する本体)は`caxlsx_rails`の依存として入るが、
**`*.xlsx.axlsx`テンプレート内でしか自動require されない**。サービスクラスから
直接`Axlsx::Package`を使う場合は、明示的に`require "caxlsx"`が必要。
(`app/services/xlsx_reports/base_report.rb`の先頭を参照)

## 罫線・見た目の再現度について

Excel(.xls/.xlsx)とLibreOffice等のレンダラーで、線の太さの見え方(アンチエイリアシング)は
多少違うことがあるが、OOXML仕様上のスタイル定義(`thin`/`medium`/`thick`/`dashed`/`dotted`/
`double`/`hair`など)自体はcaxlsxで過不足なく再現できる。**1つのセルの上下左右で別々の
罫線スタイルを指定できる**ので、「全辺thin、下だけdouble」のような合計欄の表現も可能。

検証は `db/access/` と同様に社外秘の原本xlsファイル(`excel/`、`.gitignore`対象)を、解析用のツール
(開発時のみ。Gemfileには入れない)で読み、罫線・結合セル・列幅・行高・塗りつぶし色をcaxlsxで
書き出し直して見た目を比較する形で行った。原本の読み方は後述の「原本xlsの読み方」を参照。
10種類の原本(請求書・受領書・出荷案内書・注文書・見積依頼票・受注台帳・在庫表など、
レイアウトの複雑さはさまざま)で問題なく再現できることを確認済み。

## ハマりどころ

- **`sheet.column_widths(*widths)`は行を追加した後に呼ばないと反映されない。**
  先に呼ぶと、セル内容から自動計算された幅で上書きされてしまう(axlsxのドキュメントに明記あり)。
- **Zeitwerkの命名規則**: `app/services/xlsx_reports/registry.rb`のようなファイルで
  `XlsxReports::REGISTRY`のような定数(ファイル名と一致しない名前)を定義すると
  autoloadされない。ファイル名`registry.rb`には`Registry`という定数(クラスでなくてOK)が対応する。
- **新規ディレクトリの追加は要再起動**: `app/services/`のように`app/`直下に新しいディレクトリを
  作った場合、起動済みのRailsサーバーはそれを自動読み込み対象として認識していないので
  再起動が必要(ビューやコントローラの中身を書き換えただけなら不要)。
- **開発環境でのPumaクラスターモード**: `config/puma.rb`の`workers`設定を本番限定にしていないと、
  開発中でもPumaが複数ワーカーで動いてしまい、コードの自動リロードが効かないことがある
  (`workers ENV.fetch("WEB_CONCURRENCY", 2) if ENV["RAILS_ENV"] == "production"`で対処済み)。

- **`BaseReport#style`のフォント指定は`font_name:`**: caxlsxの`add_style`が読むキーは`font_name`。
  以前`fn:`と書いていて、無視されて全帳票がArial(既定)になっていた。今は`font_name:`を渡したときだけ
  フォントを変える(省略時は既定のまま)。見積書は`MS PGothic`、部品見積依頼票は`MS PMincho`。
- **書式文字列に引用符(`"`)を入れない**: `number_format: "\"¥\"#,##0"`のように引用符を含む書式は、
  caxlsxが`styles.xml`の属性にエスケープせず書き出すため、XMLが壊れてExcelが「修復」して書式を失う。
  円記号は`[$¥-411]#,##0`のように引用符なしで書く。
- **検証は`styles.xml`も**: シートのXMLだけをスキーマ検証していると、`styles.xml`の壊れを見落とす。
  `xmllint --noout`で`xl/styles.xml`・`xl/drawings/*.xml`・`[Content_Types].xml`も確認する。
- **文字列に見える数字はcaxlsxが数値にする**: 「202610024」のような文字列は数値セルとして書かれる。
  列幅が狭いと`####`になるので、結合セルにして幅を確保する。
- **`ruby -e`に日本語を直接書かない**: ロケールがUS-ASCIIだと`invalid multibyte char`になる。
  スクリプトをファイルにして`LANG=ja_JP.UTF-8`を付けて実行する。

## 行を跨ぐ丸カッコを描く(図形/DrawingML)

SeikyuReportの「お届け先」欄で、A6:A8・C6:C8の3行に跨る丸カッコを描きたかった。
セルの値や罫線だけで表現しようとして何度も失敗し、最終的に実際のExcel図形
(オートシェイプ)を生成後のxlsxにXMLで直接注入する方式に落ち着いた。

### 失敗した方法

1. **Unicode括弧パーツ文字(U+239B/239C/239D等)を1行ずつ積む** —
   フォントによって曲線の繋がり方がバラバラで、小さいカギ括弧が
   3つ並んでいるだけの見た目になり、1本の大きなカッコに見えなかった。
2. **セル罫線で「[」「]」の箱を作る** — 上下の行に元々ある罫線
   (「殿」の太下線、次のラベル行の外枠上辺など)と繋がってしまい、
   意図した「隙間のある括弧」ではなく単なる四角い箱に見えた。
3. **縦に結合したセルに大きいフォントサイズの"("/")"文字を入れる**
   (`Axlsx::RichText`使用) — XML上はフォントサイズを大きく(54pt等)
   設定できているのに、プレビュー(QuickLook)でもExcelでも
   結合範囲の合計の高さではなく、**先頭行(アンカー行)自身の高さに
   クリップされてしまう**。複数行結合セル+オーバーサイズフォントの
   組み合わせは多くのレンダラーで正しく扱われない、という結論に至った。

### 最終的な解決策: 実際のExcel図形(leftBracket/rightBracket)を後からXML注入

`caxlsx`にはオートシェイプ(図形)を追加する高レベルAPIが無い
(`add_image`/`add_chart`はあるが汎用`add_shape`は無い)。そのため、
`Axlsx::Package`が生成した完成後のxlsx(zip)に対して、`rubyzip`で
`xl/drawings/drawing1.xml`を追加し、`xl/worksheets/sheet1.xml`に
`<drawing r:id="..."/>`を挿入、`[Content_Types].xml`にOverrideを足す、
という手順を後処理として行う(`app/services/xlsx_reports/seikyu_report.rb`の
`BracketShapePatchedPackage`/`inject_extra_shapes`を参照)。
`Axlsx::Package`を`SimpleDelegator`でラップし、`serialize`/`to_stream`
どちらの出力にも同じ後処理が効くようにしている。

図形の挿入は、その後、`ShapePatchedPackage.inject_drawing`(`xlsx_reports/shape_patched_package.rb`)に
共通化した。挿入先のシートと部品ファイルの番号(`sheet:`/`drawing:`)を指定できるので、1枚目だけでなく
何枚目のシートにも図形を足せる(物品受領書の受領印は全ページに入れている)。

図形自体は`<a:prstGeom prst="leftBracket">`/`"rightBracket"`という
OOXML標準のプリセット形状(角丸の大きな片カッコ)を使う。

```xml
<xdr:twoCellAnchor>
  <xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>5</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
  <xdr:to><xdr:col>0</xdr:col><xdr:colOff>127000</xdr:colOff><xdr:row>8</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>
  <xdr:sp macro="" textlink="">
    <xdr:nvSpPr><xdr:cNvPr id="1" name="LeftBracket"/><xdr:cNvSpPr/></xdr:nvSpPr>
    <xdr:spPr>
      <a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>
      <a:prstGeom prst="leftBracket"><a:avLst><a:gd name="adj" fmla="val 40000"/></a:avLst></a:prstGeom>
      <a:noFill/>
      <a:ln w="19050"><a:solidFill><a:srgbClr val="000000"/></a:solidFill></a:ln>
    </xdr:spPr>
    <xdr:txBody><a:bodyPr/><a:lstStyle/><a:p/></xdr:txBody>
  </xdr:sp>
  <xdr:clientData/>
</xdr:twoCellAnchor>
```

### ハマりどころ

- **列幅いっぱいに図形が伸びる**: `twoCellAnchor`の`from`/`to`を
  そのまま列の左端〜右端(colOff=0〜0)にすると、幅の広い列
  (品名列など)では図形が横長に引き伸ばされ「列を跨ぐカッコ」に
  見えてしまう。列幅に依存させず、`colOff`に固定のEMU値
  (`BRACKET_WIDTH_EMU = 127_000` ≒10pt)を使って太さを固定する。
- **「列の右端」は列幅に依存するので直接指定できない**: 列の実際の
  ピクセル幅は環境(フォント)依存で正確に計算できない。右端に
  ぴったり合わせたい場合は、その列自身ではなく**隣接する次の列の
  左端(colOff=0)**を起点にする(列境界は列幅に関わらず必ず一致するため)。
- **カッコの曲がり具合は`adj`ガイド値で調整**: `leftBracket`/`rightBracket`
  のデフォルト`adj`は16667(角ばって見える)。`<a:gd name="adj" fmla="val 40000"/>`
  のように上げると、直線部分が短く曲線が強い「カッコらしい」形になる
  (最大50000で直線部分がほぼ無くなる)。
- **QuickLook(macOS)は図形を一切描画しない**: セルの値・罫線・結合は
  QuickLookのExcelプレビューで確認できるが、DrawingMLの図形(オートシェイプ)は
  表示されない。図形の検証は見た目ではなく、`caxlsx`gem同梱のXSDスキーマ
  (`lib/schema/dml-spreadsheetDrawing.xsd`・`sml.xsd`)を`xmllint --noout --schema`で
  当てて構文的な正しさを確認し、最終的な見た目は実際にExcelで開いて
  ユーザーに確認してもらう、という2段構えの検証フローにした。

## 帳票の一覧

「並び替え後表示」画面(`orders#sorted`)のボタンから出力する。kindは`XlsxReports::Registry`のキー。

| kind | 帳票 | クラス | 旧ASP | 出力履歴(kubun) | 白黒印刷 |
|---|---|---|---|---|---|
| `mitsumori_irai` | 部品見積依頼出力 | `MitsumoriIraiReport` | `print211_.asp` | 1 | ○ |
| `mitsumori_with_no` | 部品番号あり見積出力 | `MitsumoriReport` | `print111r.asp` | 2 | ○ |
| `mitsumori_without_no` | 部品番号なし見積出力 | `MitsumoriNoPartReport` | `print311r.asp` | 2 | ○ |
| `juchu_memo` | 受注メモ出力 | `JuchuMemoReport` | `jutyu111.asp` | 3 | ○ |
| `seikyu_a` | 請求書A | `SeikyuReport` | `A4pseikyu.asp` | 5 | - |
| `seikyu_a_hikae` | 請求書A控 | `SeikyuHikaeReport` | `A4pseikyu2.asp` | 5 | - |
| `nohin_a` | 納品書A | `NohinReport` | `A4pnouhin.asp` | 7 | ○ |
| `seikyu_b` | 請求書B | `SeikyuBReport` | `A4pseikyuB.asp` | 5 | - |
| `seikyu_b_hikae` | 請求書B控 | `SeikyuBHikaeReport` | `A4pseikyuB2.asp` | 5 | - |
| `nohin_b` | 納品書B | `NohinBReport` | `A4pnouhinB.asp` | 5 | ○ |
| `syukka_annai` | 出荷案内書 | `ShukkaAnnaiReport` | `A4pshuka.asp` | 4 | ○ |
| `juryo` | 物品受領書 | `JuryoReport` | `A4pjuryo.asp` | なし | ○ |

様式の元(`excel/`の原本): 部品見積依頼=`print21_.xls`、見積書=`print11.xls`、請求書・納品書=`seikyu.xls`、
出荷案内書=`syukka.xls`、物品受領書=`juryo.xls`、受注メモ=`jutyu.xls`。

### クラスの継承関係

```
BaseReport
├─ TabularReport
│   ├─ SeikyuReport(請求書A。seikyu.xlsの見出し・2行1組の明細・小計/累計/値引/消費税/総合計・銀行欄)
│   │   ├─ SeikyuHikaeReport(表題を「(控)」にし、銀行欄を出さない)
│   │   ├─ NohinReport(表題を「納品書」にし、銀行欄を出さない。白黒印刷)
│   │   ├─ SeikyuBReport(消費税・値引きが入らない形式。最後は「消費税抜き価格」付きの合計)
│   │   │   ├─ SeikyuBHikaeReport(控)
│   │   │   └─ NohinBReport(納品書B。白黒印刷)
│   │   └─ ShukkaAnnaiReport(表が「摘要」の欄に変わり、集計なし。白黒印刷)
│   │       └─ JuryoReport(物品受領書。摘要は縦線だけ、受領印つき)
│   ├─ JuchuMemoReport(受注メモ)
│   └─ MitsumoriIraiReport(部品見積依頼票。単位の列を足した21列の専用Gridで組む)
└─ MitsumoriReport(見積書。7列のGridで組む)
    └─ MitsumoriNoPartReport(部品番号を出さない)
```

請求書系は、表題・見出し・銀行欄の有無を`cover_title`/`continuation_title`/`show_bank_footer?`で
子クラスが差し替える。

## アーキテクチャ

```
app/services/
  item_pricing.rb        # 明細の数量・単価・金額(画面と帳票で共通。後述)
  sales_unit.rb          # 販売単位の表記(数字→「袋」)
  price_rounding.rb      # 切り上げ(round_up=kmarume)・四捨五入(round_half_up=smarume)
  order_sorted_items.rb  # Orderpart+NOrderpartを「順」で一本化(並び替え後表示・帳票の明細)
  xlsx_reports/
    base_report.rb       # 共通基盤: Axlsx::Package生成、罫線/塗りつぶし/フォントのスタイルヘルパー
    tabular_report.rb    # 「見出し+明細テーブル+合計行」型の共通レイアウト
    grid.rb              # 座標指定で値・罫線・結合を組み立てる方眼(見積書で使用)
    registry.rb          # 帳票kind→ラベル・クラス・出力履歴の区分の対応表
    price_rounding.rb    # 部品見積依頼票だけが使う四捨五入(smarume)
    shape_patched_package.rb          # 図形(drawing)を生成後のxlsxへ挿入
    black_and_white_patched_package.rb # 「白黒印刷」(pageSetupのblackAndWhite)を挿入
    ※帳票クラスは上の一覧のとおり
app/models/order_log.rb  # 帳票の出力履歴(旧「取引管理」)
```

### BaseReport

- `#generate` — `Axlsx::Package`を作り`#build(workbook)`(サブクラス実装必須)を呼ぶ
- `#style(sheet, border:, top:, bottom:, left:, right:, bold:, size:, halign:, valign:, fill:, number_format:, font_name:, wrap:, rotation:, indent:)`
  — セル単位で辺ごとに罫線を指定できるヘルパー。同じ組み合わせは自動でキャッシュされる。
  `font_name`は指定したときだけ反映(省略時は既定フォント)
- `#set_column_widths(sheet, *widths)` — 前述の「行追加後に呼ぶ」制約を吸収するラッパー

### TabularReport

`Column`構造体(`key`/`label`/`width`/`halign`/`number_format`/`total`)で列を定義し、
`#build_item_table(sheet, items:, total:)`でヘッダー行(グレー背景)・明細行・合計行
(`total: true`の列だけ上下二重罫線)を組み立てる。請求書系・受注メモは明細を2行1組で
自前に組み立てている(旧様式が2行1組のため)。

### Grid

`Grid.new(行数, 列数, font_name:)`に`text(行, 列1, 列2, 値, rows:, **スタイル)`・`box`・`line`・`height`で
座標を指定して値・罫線・結合を貯め、`emit(sheet, report)`で一度に書き出す。旧様式を座標で
そのまま再現するときに使う(見積書)。部品見積依頼票は、数量の右に単位の列を1つ追加した21列の専用Gridを持つ
(列番号を「追加前の20列」で書き、実際の列へ直す`physical`を持つ)。

### Registry

```ruby
module XlsxReports
  Registry = {
    "seikyu_a" => { label: "請求書A", kubun: OrderLog::KUBUN_SEIKYU, klass: "XlsxReports::SeikyuReport" },
    ...
  }.freeze
end
```

`kubun`は出力時に`order_logs`へ記録する区分(旧ASPの値のまま。`nil`は記録しない)。
`klass`が無いkindは「並び替え後表示」画面上ではボタンとして表示されるが、押すと
「まだ未実装です」というフラッシュメッセージを出して元画面に戻る(今は全kindに`klass`がある)。

## 呼び出し側(コントローラ/ルーティング)

```ruby
# config/routes.rb
resources :orders do
  member do
    get :sorted
    get "report/:kind", to: "orders#report", as: :report
  end
end
```

```ruby
# app/controllers/orders_controller.rb
def report
  @order = Order.find(params[:id])
  entry = XlsxReports::Registry[params[:kind]]
  klass = entry&.dig(:klass)&.safe_constantize
  return redirect_to sorted_order_path(@order), alert: "未実装です" unless klass

  report = klass.new(@order)
  package = report.generate
  # 旧ASPが印刷時に取引管理へ書いていた出力履歴。生成に成功したときだけ記録する
  OrderLog.record(mno: @order.mno, kubun: entry[:kubun]) if entry[:kubun]
  send_data package.to_stream.read, filename: report.filename, type: Mime[:xlsx], disposition: "attachment"
end
```

ボタンのリンクは`data: { turbo: false }`にしている。Turbo経由だとファイル応答を取得した後にもう一度
リクエストされ、出力履歴が二重に記録されるため(`orders/sorted.html.haml`)。

## 数量・単価・金額の求め方(画面と帳票で共通)

`ItemPricing`(`app/services/item_pricing.rb`)が、旧`asp/partsin.asp`(注文部品詳細)と、
見積テーブルのNprice・TotalB(見積書・請求書・納品書・受注メモ)の計算を1か所にまとめている。
注文部品詳細の明細・小計・合計・並び替え後表示・全帳票(部品見積依頼票を除く)が同じ計算になる。

- **掛け率が1**: 単価は定価のまま、金額は定価×数量(丸めなし)。
- **掛け率が1以外**: 単価 = 定価×掛け率を**切り上げまるめ**(旧`fsysfunc.asp`の`kmarume`。上位3桁に、
  1円の桁は常に0)。丸める単位は、1万円未満=10円、10万円未満=100円、100万円未満=1,000円、それ以上=1万円。
  掛け率0は1扱い。金額は 切り上げ後の単価×数量。
- **バラ売り**(販売単位が数字でバラ数量がある): 数量はバラ数量、単価は上の単価÷販売単位、
  金額はバラ数量×その単価。単位欄は出さない。
- **部品番号無(NOrderpart)**: 明細の個別掛け率(0より大きいとき)、無ければ注文のB部品共通掛け率
  (`Order#irate2`)を使い、掛け率が0より大きければ掛ける(1は丸めなし、それ以外は切り上げ)。

**掛け率の取り方(`ItemPricing.effective_rate`)**: 旧ASPは、明細に持っている掛け率(`IRate`)を使わない。

| 部品 | 使う掛け率 |
|---|---|
| A部品(部品台帳にある部品) | 注文のA部品掛け率(`Order#irate`) |
| B部品(KE部品台帳にある部品) | 明細の個別掛け率が1より大きければそれ、無ければ注文のB部品共通掛け率(`irate2`。0は1扱い) |
| どちらにも無い部品 | 明細の掛け率 |

旧システムからの移行データでは、明細の掛け率が1.0のまま入っている注文がある(注文のA部品掛け率が
1.2でも、明細は1.0)。注文のA部品掛け率を使うのは、この理由とASPの仕様による。

**部品見積依頼票だけは例外**: 旧`print211_.asp`が明示的に四捨五入(`smarume`)を使うため、
`XlsxReports::PriceRounding.smarume`を使う(定価と、掛け率を掛けた単価の2つを出す)。

## 販売単位の表記(`SalesUnit`)

明細の単位欄は2段で、上段に販売単位そのもの、下段に単位の名前を出す。販売単位が数字(例: `10`)の部品は
「10個で1袋」なので、上段に「10」、下段に「袋」。`SET`・`ｸﾐ`・`PCS`などの文字のときは上段にその文字だけ。
バラ売りの明細は出さない。寄せは、上段の数字は左寄せ、文字と「袋」は右寄せ。

## 出荷日

請求書・納品書・出荷案内書・物品受領書の「(出荷日 ○年○月○日)」は、次の順で決める
(`SeikyuReport#shipping_date_label`)。
1. 出荷案内書を出力した履歴(取引管理 kubun=4)の、最後(最新)の出力日
2. 注文の指定出荷日(`syuday`)
3. 注文の受注日(`rdate`)
4. 今日

## 出力履歴(`order_logs`)

旧Accessの`取引管理`(MNo, datelog, kubun)を`order_logs`に持つ**追記専用の出力履歴**。帳票を出力するたびに
`OrdersController#report`が1行追加する(kubunはRegistryの値)。kubun: 1=部品見積依頼、2=見積書、
3=受注メモ、4=出荷案内書、5=請求書A/B・同控・納品書B、7=納品書A。Access→SQLite3変換のときの
取り込み手順は`CLAUDE.md`の「帳票出力履歴の`order_logs`」を参照。

## 営業担当(`ksystems`)

部品見積依頼票の「営業担当」は、`ksystems`テーブルの`sales_person`(`Ksystem.sales_person`)から読む。
行が無いときは「CS国内営業チーム 山口様」。メニュー画面から管理者が変更できる(税率の隣)。

## 白黒印刷

Excelの「ページ設定」→「シート」の「白黒印刷」は、`pageSetup`の`blackAndWhite="1"`で指定できるが、
caxlsxは未対応。そこで`BlackAndWhitePatchedPackage`(`xlsx_reports/black_and_white_patched_package.rb`)で、
生成後のxlsxの全シートの`pageSetup`へ書き足す。帳票クラスの`generate`で
`BlackAndWhitePatchedPackage.new(super)`のように使い、図形を入れる`ShapePatchedPackage`とも重ねられる。
請求書A・B・各控以外の帳票(上の一覧で「○」)に指定してある。プリンターのカラー/白黒(ドライバー側の設定)は
xlsxからは指定できない。

## 原本xlsの読み方

旧様式(`excel/*.xls`)の列幅・行の高さ・結合・フォント・罫線・印刷設定は、画面コピーだけでなく
ファイルから直接読むと正確に再現できる。Pythonの`xlrd`(2.x、`formatting_info=True`)が使える
(開発時のみ。例: `python3 -m pip install --target /tmp/xl xlrd`)。

- `sheet.colinfo_map`(列幅)、`sheet.rowinfo_map`(行の高さ)、`sheet.merged_cells`(結合)、
  `workbook.xf_list`と`sheet.cell_xf_index`(フォント・罫線・揃え・表示形式)
- **セルの罫線に出てこない線は、図形(線・長方形など)で描かれている**。見積書の下線や承認の枠、
  物品受領書の受領印がそう。図形は`xlrd`では読めないので、見た目(PDF出力など)を見て
  セルの下線や図形(`ShapePatchedPackage`)で置き換える。
- 印刷設定(用紙・倍率・余白・改ページ)はBIFFの`SETUP`レコードなどを直接読むと分かる。
- ASPのExcel出力の仕様は、`asp/*.asp`(CP932)を`iconv -f CP932 -t UTF-8`で読む。ASPが参照する
  `見積`テーブルは作業用で、アプリでは`OrderSortedItems`が代わりに明細を一本化する。

## 動作確認のしかた(サーバー起動なしでもOK)

```bash
bin/rails runner '
order = Order.find(42269)
report = XlsxReports::SeikyuReport.new(order)
path = File.expand_path("~/Desktop/#{report.filename}")
report.generate.serialize(path)
puts "書き出し: #{path}"
'
```

`bin/rails console`で対話的に`report.send(:build_items)`などを呼んで中身を覗くのも便利。

生成したxlsxは、`xmllint`で壊れていないかを確認するとよい。

```bash
SCHEMA=$(gem contents caxlsx | grep sml.xsd$)
unzip -p file.xlsx xl/worksheets/sheet1.xml | xmllint --noout --schema "$SCHEMA" -
unzip -p file.xlsx xl/styles.xml | xmllint --noout -
unzip -p file.xlsx xl/drawings/drawing1.xml | xmllint --noout -
```

QuickLook(macOS)は図形・縦書き・回転を描画しないので、最終的な見た目は実際にExcelで確認する。

## 実データ接続で分かった注意点

- `order.adlist_id`は`adlists.id`ではなく`adlists.no`列を指す
  (`Adlist.find_by(no: order.adlist_id.to_s)`という既存の`orders/show.html.haml`の慣習に合わせる)
- 明細の品番は`Part`台帳に無く`Kepart`(KE部品)台帳にしかないことがある。品名は両方フォールバックする
  (`OrderSortedItems`が`part_source`として`:part`/`:kepart`を持つ)
- 明細の数量が0のとき、見積書は旧ASPどおり枠だけ残して空欄にする。請求書系・受注メモは行を出す
- 重量の`999`は「不明」を表す値で、見積書・部品見積依頼票では空欄にする
- Item Noの`1`・`0`は初期値で意味がないので、見積書・部品見積依頼票では出さない
