Rails.application.routes.draw do
  devise_for :users

  root "dashboard#index"

  get "dashboard", to: "dashboard#index", as: :dashboard

  resources :resumes, only: [:index, :new, :create, :show, :destroy]
  resources :folders, only: [:index, :new, :create, :destroy]

  resources :jobs, only: [:index, :new, :create, :show, :update, :destroy] do
    resources :attachments, only: [:create, :destroy]
  end

  # Token usage summary for the current user
  get "usage", to: "dashboard#usage", as: :usage
end
