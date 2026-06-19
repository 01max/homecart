Rails.application.routes.draw do
  root "home#index"

  resources :source_documents, only: %i[new create show] do
    get :status, on: :member
  end
  resources :categories, only: %i[create update destroy]
  resources :receipts, only: %i[index show edit update destroy] do
    patch :mark_reviewed, on: :member
    patch :rerun_parser, on: :member
  end

  namespace :catalogue do
    root "dashboard#index"

    resources :categories, only: %i[index new create update destroy]
    resources :product_brands, only: %i[index show new create edit update]
    resources :manufacturers, only: %i[index show new create edit update]
    resources :comparison_units, only: %i[index show new create edit update]
    resources :products, only: %i[index show new create edit update]
    resources :product_variants, only: %i[index show new create edit update] do
      post :inline_product, on: :collection
    end
    resources :product_alternative_groups, only: %i[index show new create edit update] do
      resources :memberships, module: :product_alternative_groups, only: %i[create destroy]
    end
  end

  namespace :matching do
    root "queue#index"
    get "queue", to: "queue#index", as: :queue

    resources :bulk_confirmations, only: %i[create]
    resources :ignored_groups, only: %i[create]
    resources :receipt_lines, only: [] do
      post :confirm, on: :member
      post :create_variant, on: :member
      post :ignore, on: :member
      post :reject, on: :member
    end
    resources :receipts, only: %i[show]
  end

  post "hotwire/ping", to: "home#ping", as: :hotwire_ping

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
end
