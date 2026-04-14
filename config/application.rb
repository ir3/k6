require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module K6
  class Application < Rails::Application
    config.autoload_paths << Rails.root.join("app", "frontend", "components")
    #config.view_component.preview_paths << Rails.root.join("app", "frontend", "components")

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks generators])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # タイムゾーンをTokyo（日本）にする
    config.time_zone = "Tokyo"
    # デフォルトのロケールを日本にする
    config.i18n.default_locale = :ja
    # config.eager_load_paths << Rails.root.join("extras")
    config.generators do |g|
      g.template_engine :haml
    end

    # authenticity_token と commit はフォーム送信時の標準パラメータのため許可
    config.action_controller.always_permitted_parameters = %w[controller action authenticity_token commit]
  end
end
