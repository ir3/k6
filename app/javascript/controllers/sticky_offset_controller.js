import { Controller } from "@hotwired/stimulus"

// 固定表示のナビバーの直下に、一覧の項目名（固定表示の thead）をぴったり付ける。
// ナビバーの高さは、画面の幅（折り返し）や文字サイズで変わるので、固定値（4rem）ではずれる。
// 実際の高さを測って、CSS 変数に入れる（k.css の .center-table thead th が使う）。
//   --navbar-height : ナビバーの高さ。項目名の top に使う
// あわせて html の scroll-padding-top を「ナビバー + 項目名」の高さにして、
// Tab キーの移動やページ内検索・アンカーでデータ行へ飛んだとき、その行が項目名の下に隠れないようにする。
export default class extends Controller {
  connect() {
    this.navbar = document.querySelector(".navbar")
    if (!this.navbar) return

    this.update = this.update.bind(this)
    this.observer = new ResizeObserver(this.update)
    this.observer.observe(this.navbar)
    const thead = document.querySelector(".center-table thead")
    if (thead) this.observer.observe(thead)
    this.update()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  update() {
    const root = document.documentElement
    const navbarHeight = this.navbar.getBoundingClientRect().height
    const thead = document.querySelector(".center-table thead")
    const theadHeight = thead ? thead.getBoundingClientRect().height : 0

    root.style.setProperty("--navbar-height", `${navbarHeight}px`)
    root.style.scrollPaddingTop = `${navbarHeight + theadHeight}px`
  }
}
