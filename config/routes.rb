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

  # kobeengine
  resources :adlists
  get  'search'           => 'adlists#search',   as: 'search'
  post 'adlists/out/'     => 'adlists#out'
  post 'adlists/select/'  => 'adlists#select'

  resources :keparts
  post 'keparts/search/'  => 'keparts#search'

  match 'orders/search' => 'orders#search', via: %i[get post], as: 'orders_search'
  resources :orders
  post 'orders/copy/'     => 'orders#copy'
  post 'orders/ocopy/'    => 'orders#ocopy'
  post 'orders/keycopy/'  => 'orders#keycopy'

  resources :orderparts
  post 'orderparts/search/'  => 'orderparts#search'
  post 'orderparts/select/'  => 'orderparts#select'

  resources :parts
  post 'parts/search/'    => 'parts#search'
  post 'parts/select/'    => 'parts#select'

  resources :registries
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
