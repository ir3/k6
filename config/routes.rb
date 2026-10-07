Rails.application.routes.draw do
  get "welcom/index"
  get "ruby_wasm", to: "pages#ruby_wasm"
  resource :pages
  resources :passwords, param: :token
  resource :session
  resource :sign_up
  resources :users
  resources :user_profiles
  #root to: 'welcom#index'

  get "menu" => "menus#index", as: "menu"
  patch "menu/tax_rate" => "menus#update_tax_rate", as: "menu_tax_rate"
  patch "menu/sales_person" => "menus#update_sales_person", as: "menu_sales_person"

  # kobeengine
  # 取引台帳修正の取引先選択モーダル用（resources :adlists より前に置かないと :id に取られる）
  get  'adlists/picker'   => 'adlists#picker',   as: 'adlists_picker'
  resources :adlists
  get  'search'           => 'adlists#search',   as: 'search'
  post 'adlists/out/'     => 'adlists#out'
  post 'adlists/select/'  => 'adlists#select'

  resources :keparts
  post 'keparts/search/'  => 'keparts#search'

  match 'orders/search'  => 'orders#search',  via: %i[get post], as: 'orders_search'
  match 'orders/alllist' => 'orders#alllist', via: %i[get post], as: 'orders_alllist'
  resources :orders do
    member do
      get :sorted
      post :add_part
      post :add_part_name
      get "report/:kind", to: "orders#report", as: :report
    end
  end
  post 'orders/copy/'     => 'orders#copy'
  post 'orders/ocopy/'    => 'orders#ocopy'
  post 'orders/keycopy/'  => 'orders#keycopy'

  resources :orderparts
  post 'orderparts/search/'  => 'orderparts#search'
  post 'orderparts/select/'  => 'orderparts#select'

  resources :parts
  post 'parts/search/'    => 'parts#search'
  post 'parts/select/'    => 'parts#select'

  resources :registries do
    member do
      patch :soft_delete
    end
  end
  # 在庫メンテナンス（旧 zaikomente.asp）。部品番号は ?partno= で渡す
  get  'stock_maintenance'          => 'stock_maintenance#show',     as: :stock_maintenance
  post 'stock_maintenance/price'    => 'stock_maintenance#price',    as: :stock_maintenance_price
  post 'stock_maintenance/hide'     => 'stock_maintenance#hide',     as: :stock_maintenance_hide
  post 'stock_maintenance/reveal'   => 'stock_maintenance#reveal',   as: :stock_maintenance_reveal
  post 'stock_maintenance/adjust'   => 'stock_maintenance#adjust',   as: :stock_maintenance_adjust
  post 'stock_maintenance/standard' => 'stock_maintenance#standard', as: :stock_maintenance_standard
  post 'stock_maintenance/forecast' => 'stock_maintenance#forecast', as: :stock_maintenance_forecast
  resources :stocks
  resources :stockbs

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "sign_ups#show"
end
