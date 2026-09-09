# ExcelファイルをRailsで作成

k6でExcel(.xlsx)帳票を出力する仕組みについてのメモ。`caxlsx`(旧axlsx)gemを使い、
細かい罫線(辺ごとに違うスタイル・二重罫線など)まで再現できることを検証した上で、
`XlsxReports`という共通基盤を作った。

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

検証は `db/access/` と同様に社外秘の原本xlsファイル(`excel/`、`.gitignore`対象)を
`spreadsheet` gem(開発時のみ`gem install spreadsheet`で解析用に使用、Gemfileには入れない)
で読み、罫線・結合セル・列幅・行高・塗りつぶし色をcaxlsxで書き出し直して見た目を比較する形で行った。
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

## アーキテクチャ

```
app/services/xlsx_reports/
  base_report.rb      # 共通基盤: Axlsx::Package生成、罫線/塗りつぶし/フォントのスタイルヘルパー
  tabular_report.rb    # 「見出し+明細テーブル+合計行」型帳票の共通レイアウト(BaseReport継承)
  registry.rb            # 帳票kind(文字列)→ラベル・実装クラスの対応表
  seikyu_report.rb         # 請求書A(TabularReport継承、実装済み第1号)
```

### BaseReport

- `#generate` — `Axlsx::Package`を作り`#build(workbook)`(サブクラス実装必須)を呼ぶ
- `#style(sheet, border: :thin, top: :thin, bottom: :double, bold:, size:, halign:, valign:, fill:, number_format:, font_name:)`
  — セル単位で辺ごとに罫線を指定できるヘルパー。同じ組み合わせは自動でキャッシュされる
- `#set_column_widths(sheet, *widths)` — 前述の「行追加後に呼ぶ」制約を吸収するラッパー

### TabularReport

`Column`構造体(`key`/`label`/`width`/`halign`/`number_format`/`total`)で列を定義し、
`#build_item_table(sheet, items:, total:)`でヘッダー行(グレー背景)・明細行・合計行
(`total: true`の列だけ上下二重罫線)を組み立てる。

原本xlsでは「1明細=4行(手書きで複数行の説明を書けるように)」という設計だったが、
今のTabularReportでは「1明細=1行+セル内折り返し」に簡略化している。

### Registry

```ruby
module XlsxReports
  Registry = {
    "seikyu_a" => { label: "請求書A", klass: "XlsxReports::SeikyuReport" },
    "nohin_a"  => { label: "納品書A" },  # klass未設定=未実装
    ...
  }.freeze
end
```

`klass`が無いkindは「並び替え後表示」画面上ではボタンとして表示されるが、押すと
「まだ未実装です」というフラッシュメッセージを出して元画面に戻る(壊れたリンクにしない)。

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
  send_data package.to_stream.read, filename: report.filename, type: Mime[:xlsx], disposition: "attachment"
end
```

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

## 実データ接続で分かった注意点(SeikyuReport)

- `order.adlist_id`は`adlists.id`ではなく`adlists.no`列を指す
  (`Adlist.find_by(no: order.adlist_id.to_s)`という既存の`orders/show.html.haml`の慣習に合わせる)
- 明細の品番は`Part`台帳に無く`Kepart`(KE部品)台帳にしかないことがあるため、
  品名表示は両方フォールバックして見る必要がある
- 金額 = `irate(掛率) × 数量 × 単価` という既存ビューの計算式をそのまま踏襲している。
  掛率が0の行は金額も0になる(実データに複数該当あり、業務的に正しいか要確認)

## 未実装の帳票(Registry参照)

部品見積依頼出力・部品番号あり見積出力・部品番号なし見積出力・受注メモ出力・請求書A控・
納品書A・請求書B・請求書B控・納品書B・出荷案内書・物品受領書の11種類。
`SeikyuReport`と同じパターン(`TabularReport`継承 + 実データ接続)で1つずつ実装していく。
