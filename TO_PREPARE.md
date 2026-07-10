# `Rails.application.config.to_prepare` について

k6独自の機能を、k2（ベースリポジトリ）と共有しているファイルを直接編集せずに追加するためのパターンとして、`to_prepare`を使っている。実例: [config/initializers/sign_up_email_restriction.rb](config/initializers/sign_up_email_restriction.rb)。

## 背景: なぜ共有ファイルを直接編集したくないか

`app/controllers/sign_ups_controller.rb`のようなファイルはk2側でも継続的に更新される。k6側で直接編集してしまうと、次に`git merge k2/main`でk2の更新を取り込むときに同じ箇所でコンフリクトする可能性がある。

そこで、共有ファイルには一切手を加えず、`config/initializers/`配下の**k6専用ファイル**から外側にパッチを当てる方式にした。これなら`sign_ups_controller.rb`はk2と完全に同一のまま保たれ、将来のマージが常にコンフリクトなく通る。

## 何が起きているか

```ruby
Rails.application.config.to_prepare do
  SignUpsController.class_eval do
    before_action :restrict_sign_up_email_domain, only: :create
    # ...
  end
end
```

- `config/initializers/sign_up_email_restriction.rb`自体は、**起動時に1回だけ読み込まれる**（他のinitializerと同じ）
- その読み込みの中で行っているのは「`to_prepare`にブロックを**登録する**」ことだけ
- 登録されたブロックの中身（`SignUpsController.class_eval do ... end`）は、**起動時1回 + それ以降のコードリロードのたびに何度も実行される**

## なぜ「実行し直す」必要があるのか

開発環境（`config.cache_classes = false`）では、Railsは`app/`配下のコードを毎リクエストではなく**変更検知のたびに**リロードする。このときZeitwerk（オートローダ）は古いクラス定義を破棄して、新しいクラスオブジェクトを作り直す。

つまり、`SignUpsController`というクラスは開発中に何度も「別物」に作り替えられる。もし普通のinitializerで起動時に1回だけ`class_eval`していたら、その1回のパッチは**次にコードがリロードされた瞬間に消えてしまう**（パッチが当たっていない、真っさらな新しい`SignUpsController`に差し替わるため）。

`to_prepare`はこの「クラスが作り直されるタイミング」ごとに自動で再実行されるので、リロードのたびにパッチが当たり直し、常に有効な状態を保てる。本番環境（`config.cache_classes = true`）ではそもそもクラスがリロードされないので、起動時の1回だけで済む。

## initializerファイルを編集したときの注意

`to_prepare`のブロックの**中身**が再実行されるのは、あくまでオートロード対象のクラス（`SignUpsController`など）がリロードされたときの話であって、`config/initializers/*.rb`という**ファイル自体の読み込み**は起動時1回きり。

そのため、`config/initializers/sign_up_email_restriction.rb`の中身を編集した場合、**サーバーを再起動しないと変更が反映されない**（`app/controllers/*.rb`のような普通のオートロード対象ファイルを編集した場合は自動でリロード・再パッチされるのと対照的）。

## まとめ

| 仕組み | 起動時 | 開発中のコード変更検知時 |
|---|---|---|
| 普通のinitializer本体 | 1回実行 | 再実行されない |
| `to_prepare`のブロック中身 | 1回実行 | **毎回再実行される** |
| initializerファイル自体の読み込み | 1回 | されない（要再起動） |

「他ファイル（`SignUpsController`など）を外側から安全に拡張し続ける」ための定番パターンとして`to_prepare`を使う。k6でk2由来の共有ファイルにコンフリクトを持ち込まずに機能追加したいときは、このパターンを踏襲する。
