# ViewComponent 引き継ぎメモ（cod ちゃんへ）

Rails 8 + HAML + ViewComponent + DaisyUI + Tailwind CSS の k6 プロジェクトに、
以下の 3 つの ViewComponent を実装してください。

---

## 環境メモ

- Rails 8.1.3 / Ruby 4.0.2
- gem 'haml-rails'
- gem "view_component"
- DaisyUI（カスタムテーマ mytheme、data-theme="mytheme" で適用済み）
- Tailwind CSS v4（app/assets/stylesheets/application.tailwind.css）
- Stimulus（Hotwire）

### Tailwind の注意点

app/assets/stylesheets/application.tailwind.css の先頭に以下の @source を追加すること。
追加しないと app/components/ 内のクラスがビルドされない。

```css
@source "../../../app/components/**/*.{rb,haml}";
@source "../../../app/views/**/*.haml";
@import "tailwindcss";
```

ビルドは yarn build:css（Procfile.dev の css: コマンド）。

---

## 1. TextFieldComponent

### app/components/text_field_component.rb

```ruby
# frozen_string_literal: true

class TextFieldComponent < ViewComponent::Base
  TYPES = %w[text email password tel url number].freeze

  def initialize(
    form:,
    field:,
    label: nil,
    type: "text",
    placeholder: nil,
    hint: nil,
    required: false,
    autocomplete: nil
  )
    @form         = form
    @field        = field
    @label        = label || field.to_s.humanize
    @type         = TYPES.include?(type) ? type : "text"
    @placeholder  = placeholder
    @hint         = hint
    @required     = required
    @autocomplete = autocomplete
  end

  private

  def errors
    @form.object.errors[@field]
  end

  def error?
    errors.any?
  end

  def input_classes
    base = "input input-bordered w-full"
    error? ? "#{base} input-error" : base
  end
end
```

### app/components/text_field_component.html.haml

```haml
.form-control.mb-4
  %label.label
    %span.label-text.font-medium= @label
    - if @required
      %span.text-error.ml-1 *
  = @form.send(:text_field, @field, type: @type, class: input_classes, placeholder: @placeholder, required: @required, autocomplete: @autocomplete)
  - if error?
    = render(FormErrorComponent.new(errors: errors))
  - elsif @hint
    %p.text-xs.text-base-content\/60.mt-1= @hint
```

---

## 2. FormErrorComponent

### app/components/form_error_component.rb

```ruby
# frozen_string_literal: true

class FormErrorComponent < ViewComponent::Base
  def initialize(errors:)
    @errors = Array(errors)
  end

  def render?
    @errors.any?
  end
end
```

### app/components/form_error_component.html.haml

```haml
%ul.mt-1
  - @errors.each do |msg|
    %li.flex.items-center.gap-1.text-xs.text-error
      %svg{ xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 20 20", fill: "currentColor", width: "14", height: "14", aria: { hidden: "true" } }
        %path{ fill_rule: "evenodd", clip_rule: "evenodd", d: "M18 10A8 8 0 11 2 10a8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" }
      %span= msg
```

---

## 3. AlertComponent

### app/components/alert_component.rb

```ruby
# frozen_string_literal: true

class AlertComponent < ViewComponent::Base
  VARIANTS = {
    success: { css: "alert-success", icon: "check_circle" },
    error:   { css: "alert-error",   icon: "error" },
    warning: { css: "alert-warning", icon: "warning" },
    info:    { css: "alert-info",    icon: "info" }
  }.freeze

  FLASH_MAP = {
    notice:  :success,
    alert:   :error,
    warning: :warning,
    info:    :info
  }.freeze

  def initialize(
    message:,
    variant:      :info,
    title:        nil,
    dismissible:  true,
    auto_dismiss: false,
    delay:        4000
  )
    @message      = message
    @variant      = FLASH_MAP[variant.to_sym] || (VARIANTS.key?(variant.to_sym) ? variant.to_sym : :info)
    @title        = title
    @dismissible  = dismissible
    @auto_dismiss = auto_dismiss
    @delay        = delay
  end

  private

  def config = VARIANTS[@variant]
  def css    = config[:css]
  def icon   = config[:icon]
end
```

### app/components/alert_component.html.haml

```haml
.alert{ class: css, role: "alert", data: { controller: "alert", alert_auto_dismiss_value: @auto_dismiss, alert_delay_value: @delay } }
  %span.material-symbols-outlined.text-lg= icon
  .flex-1
    - if @title
      %p.font-medium.text-sm= @title
    %p.text-sm= @message
  - if @dismissible
    %button.btn.btn-ghost.btn-xs{ type: "button", data: { action: "click->alert#dismiss" }, aria: { label: "閉じる" } } ✕
```

### レイアウトでの flash 表示

app/views/layouts/application.html.haml の flash 部分を以下に置き換える：

```haml
- flash.each do |type, message|
  = render AlertComponent.new(message: message, variant: type.to_sym, auto_dismiss: true)
```

---

## 4. Stimulus alert_controller.js

### app/javascript/controllers/alert_controller.js

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismiss: { type: Boolean, default: false },
    delay:       { type: Number,  default: 4000 },
  }

  connect() {
    if (this.autoDismissValue) {
      this._timer = setTimeout(() => this.dismiss(), this.delayValue)
    }
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  dismiss() {
    this.element.classList.add("alert--dismissing")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
  }
}
```

登録は bin/rails stimulus:manifest:update で自動追加される。

### dismiss アニメーション CSS

app/assets/stylesheets/k.css に追加：

```css
.alert {
  overflow: hidden;
  transition:
    opacity 300ms ease,
    max-height 400ms ease,
    padding-top 300ms ease,
    padding-bottom 300ms ease;
  max-height: 120px;
}
.alert--dismissing {
  opacity: 0;
  max-height: 0 !important;
  padding-top: 0;
  padding-bottom: 0;
}
```

---

## 実装チェックリスト

- [ ] app/components/text_field_component.rb
- [ ] app/components/text_field_component.html.haml
- [ ] app/components/form_error_component.rb
- [ ] app/components/form_error_component.html.haml
- [ ] app/components/alert_component.rb
- [ ] app/components/alert_component.html.haml
- [ ] app/javascript/controllers/alert_controller.js
- [ ] bin/rails stimulus:manifest:update 実行
- [ ] application.tailwind.css に @source 追加
- [ ] k.css に dismiss CSS 追加
- [ ] layouts/application.html.haml の flash を AlertComponent に置き換え
- [ ] yarn build:css 実行
