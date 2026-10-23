Rails.application.routes.draw do
  root 'sessions#new'

  get 'signup', to: 'users#new'
  post 'signup', to: 'users#create'

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  resources :users, only: [:index] do
    collection do
      post :block_selected
      post :unblock_selected
      post :delete_selected
    end
  end
  resource :chat, only: [:show, :create]
end