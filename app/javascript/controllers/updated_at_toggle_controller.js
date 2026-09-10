import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="updated-at-toggle"
// ページ内の「更新日時」表示(.updated-at-col、部品詳細テーブルの列に限らず
// 納入期日行の更新日時なども含む)をまとめて表示/非表示切り替える。
// 選択状態はlocalStorageに保存し、次回表示時も引き継ぐ。
const STORAGE_KEY = "showUpdatedAtColumn"
const HIDE_CLASS = "hide-updated-at-col"

export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    const visible = localStorage.getItem(STORAGE_KEY) !== "false"
    this.apply(visible)
    if (this.hasCheckboxTarget) this.checkboxTarget.checked = visible
  }

  toggle(event) {
    const visible = event.target.checked
    this.apply(visible)
    localStorage.setItem(STORAGE_KEY, String(visible))
  }

  apply(visible) {
    document.body.classList.toggle(HIDE_CLASS, !visible)
  }
}
