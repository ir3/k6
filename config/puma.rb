threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# クラスターモード(workers>0)だと開発環境でのコード自動リロードが効かなくなるため、本番限定にする
workers ENV.fetch("WEB_CONCURRENCY", 2) if ENV["RAILS_ENV"] == "production"

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

app_root = File.expand_path("..", __dir__)

if ENV["RAILS_ENV"] == "production"
  # Nginx と Unix ソケットで通信
  bind "unix://#{app_root}/tmp/sockets/puma.sock"
  pidfile "#{app_root}/tmp/pids/server.pid"
  state_path "#{app_root}/tmp/pids/server.state"
  stdout_redirect "#{app_root}/log/puma.stdout.log",
                  "#{app_root}/log/puma.stderr.log", true
else
  port ENV.fetch("PORT", 3000)
end
