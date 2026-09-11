# k.css の `!important` 運用メモ

`app/assets/stylesheets/k.css`で`row-compact`/`th-compact`など特定のテーブルだけ
余白を詰めるクラスに`!important`を付けている理由の記録。

## 通常のCSSの優先順位

同じ要素に複数のルールが競合したとき、ブラウザは

1. 詳細度(セレクタの強さ。IDやクラスの数)が高い方
2. 詳細度が同じなら、CSSファイル内で後に書かれた方

の順で勝敗を決める。

## k.cssの実例

```css
.center-table th, .center-table td {
  padding: 10px;                /* 全テーブル共通のデフォルト余白 */
}
.th-compact th {
  padding: 2px 10px !important; /* 見出し行の余白だけ詰めたい */
}
```

`.center-table`と`.th-compact`はどちらも「クラス1つ」で詳細度が同じ。この場合は
本来「後に書かれたルールが勝つ」という単純な理由だけで、`.th-compact`は
ファイル内で後ろにあるので**`!important`が無くても普通に勝てる**。

## それでも`!important`を付けている理由

1. 先にあった`row-compact`(同じ意図の既存ルール)が`!important`付きだったので、
   同種の`th-compact`もそれに合わせた(コードの一貫性)。
2. 詳細度が同じ者同士の「後勝ち」は、CSSファイル内の**記述順に依存する脆い
   勝ち方**。将来`.center-table`のルールを下に移動したり、`!important`付きの
   別ルールが追加されたりすると、順序が入れ替わって負ける可能性がある。
   `!important`を付けておくと、そうした「書く場所」の事故に強くなる。

## 注意点

`!important`同士がぶつかると、今度は`!important`が付いたルールの中で
「詳細度→記述順」の同じ勝敗ルールが再度働く。つまり`!important`は無敵の
上書きではなく、優先順位の土俵を一段上に引き上げるだけ。多用するとどのルールが
効いているか追いづらくなるため、`row-compact`/`th-compact`のような「絶対に
この見た目にしたい、汎用ルールに負けたくない」局所的な上書きに限定して使う。

## 実際に`!important`同士がぶつかった事例(mno-col vs th-compact)

上の「注意点」で書いた「`!important`同士がぶつかると詳細度比較に戻る」が、
実際に取引台帳の「取引No」列で起きた。

CSSの詳細度は`(インラインstyle, ID, クラス/属性/疑似クラス, 要素名/疑似要素)`
という4つの数字の組で決まり、左の桁から順に比較する(1つでも上の桁が多い方が
無条件で勝ち、同じなら次の桁で比較)。

```css
.mno-col {                     /* クラス1個            → 詳細度 (0,0,1,0) */
  padding-left: 2px !important;
  padding-right: 2px !important;
}
.th-compact th {                /* クラス1個+要素1個    → 詳細度 (0,0,1,1) */
  padding: 2px 10px !important;
}
```

`.mno-col`は`(0,0,1,0)`、`.th-compact th`は`(0,0,1,1)`。3桁目(クラス)は
同じ1個だが、4桁目(要素)が`.th-compact th`の方は1個、`.mno-col`は0個。
両方`!important`付きなので「`!important`の有無」では決着がつかず、通常の
詳細度比較に戻り、詳細度で勝る`.th-compact th`の`padding: 2px 10px`が
実際の見た目を決めていた(取引Noのヘッダセルだけ左右10pxパディングに戻って
しまい、列幅が意図した通りに縮まっていなかった)。

### 修正

```css
th.mno-col, td.mno-col {        /* クラス1個+要素1個 → 詳細度 (0,0,1,1) 、th-compact thと同点 */
  padding-left: 2px !important;
  padding-right: 2px !important;
}
```

`.mno-col`に`th`/`td`を付けて詳細度を`(0,0,1,1)`まで引き上げ、`.th-compact th`
と**同点**にした。同点になると次は「CSSファイル内で後に書かれた方が勝つ」という
記述順のルールに戻るため、この`th.mno-col, td.mno-col`を`.th-compact`より
**後ろの行**に配置し、順番でも確実に勝てるようにしている。

同点に頼る修正は「順番」という壊れやすい前提に依存する。より頑丈にしたい場合は
`.list-table th.mno-col`のようにクラスをもう1つ足して詳細度を`(0,0,2,1)`まで
引き上げ、記述順に関係なく確実に勝てるようにする手もある(今回は既存の
`row-compact`/`th-compact`と同じ「要素+クラス」のスタイルに揃えることを優先し、
採用しなかった)。
