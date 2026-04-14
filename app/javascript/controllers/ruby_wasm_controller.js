import { Controller } from "@hotwired/stimulus"
import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/browser"

export default class extends Controller {
  static targets = ["code", "output", "runBtn", "status", "canvas"]

  async connect() {
    this.vm = null
    await this.#loadRuby()
  }

  disconnect() {
    this.#removeP5()
  }

  async #loadRuby() {
    this.#setStatus("Ruby 4.0 (wasm) を読み込み中...")
    this.runBtnTarget.disabled = true
    try {
      const [wasmResponse, p5rbText] = await Promise.all([
        fetch("https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi@2.9.3-2.9.4/dist/ruby.wasm"),
        fetch("/p5.rb").then(r => r.text())
      ])
      const mod = await WebAssembly.compileStreaming(wasmResponse)
      const { vm } = await DefaultRubyVM(mod, { consolePrint: false })
      this.vm = vm
      vm.eval(p5rbText)
      this.#setStatus("準備完了 — Ruby 4.0 (wasm) + p5.js")
      this.runBtnTarget.disabled = false
    } catch (e) {
      this.#setStatus(`読み込み失敗: ${e.message}`)
    }
  }

  run() {
    if (!this.vm) return

    this.#removeP5()
    window.__p5_container = this.canvasTarget
    this.canvasTarget.innerHTML = ""

    const code = this.codeTarget.value
    try {
      this.vm.eval("require 'stringio'; $stdout = StringIO.new; $stderr = StringIO.new")
      this.vm.eval(code)

      const out = this.vm.eval("$stdout.string").toString()
      const err = this.vm.eval("$stderr.string").toString()

      this.canvasTarget.style.display = window.__p5_instance ? "block" : "none"
      this.outputTarget.textContent = (out + err) || "(出力なし)"
      this.outputTarget.classList.remove("text-error")
    } catch (e) {
      this.canvasTarget.style.display = "none"
      this.outputTarget.textContent = e.message
      this.outputTarget.classList.add("text-error")
    } finally {
      try { this.vm.eval("$stdout = STDOUT; $stderr = STDERR") } catch (_) {}
    }
  }

  clear() {
    this.#removeP5()
    this.canvasTarget.style.display = "none"
    this.canvasTarget.innerHTML = ""
    this.outputTarget.textContent = ""
    this.outputTarget.classList.remove("text-error")
  }

  #removeP5() {
    if (window.__p5_instance) {
      window.__p5_instance.remove()
      window.__p5_instance = null
    }
  }

  #setStatus(msg) {
    this.statusTarget.textContent = msg
  }
}
