import { Controller } from "@hotwired/stimulus"

// 取引台帳修正画面の取引先選択モーダル。
// 50音ボタンで取引先一覧(Turbo Frame)を開き、行クリックで会社名・部署名・取引先Noを
// 編集中のフォームへ反映する。画面遷移しないので、入力途中の他の項目はそのまま保持される。
export default class extends Controller {
  static targets = ["dialog", "adlistId", "company", "section"]
  // 開いた時点の取引先。リセット時に元へ戻すために保持する
  static values = { adlistId: String, company: String, section: String }

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  select(event) {
    const { no, company, section } = event.currentTarget.dataset
    this.adlistIdTarget.value = no
    this.companyTarget.textContent = company
    this.sectionTarget.textContent = section
    this.close()
  }

  // リセットボタン。hidden と書き換えた表示は form.reset() では戻らないので、ここで元に戻す
  reset() {
    this.adlistIdTarget.value = this.adlistIdValue
    this.companyTarget.textContent = this.companyValue
    this.sectionTarget.textContent = this.sectionValue
  }
}
