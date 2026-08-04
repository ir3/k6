import { Controller } from "@hotwired/stimulus"

const SIZE_CLASSES = ["text-[0.625rem]", "text-xs", "text-sm", "text-base"]
const STORAGE_KEY = "tableFontSize"
const TABLE_SELECTOR = ".list-table"

export default class extends Controller {
  connect() {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved && SIZE_CLASSES.includes(saved)) {
      this.apply(saved)
    }
  }

  setSize(event) {
    const size = event.params.size
    this.apply(size)
    localStorage.setItem(STORAGE_KEY, size)
  }

  apply(size) {
    document.querySelectorAll(TABLE_SELECTOR).forEach((table) => {
      table.classList.remove(...SIZE_CLASSES)
      table.classList.add(size)
    })
  }
}
