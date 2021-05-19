Jets.application.routes.draw do
  root "rooms#index"

  resources :games, except: [:edit, :update] do
    get "play", on: :member
    post "player", on: :member
    post "cpu", on: :member
    post "player_team", on: :member
    post "settings", on: :member
    post "start", on: :member
    post "play_card", on: :member
    post "newgame", on: :member

    post "play", on: :member
  end

  # unclear why the below doesn't define this
  get '/rooms/new', to: 'rooms#new'
  post "/rooms/join", to: 'rooms#join'
  get '/rooms/leave', to: 'rooms#leave'

  resources :rooms, except: [:edit, :update, :destroy] do
  end


  # The jets/public#show controller can serve static utf8 content out of the public folder.
  # Note, as part of the deploy process Jets uploads files in the public folder to s3
  # and serves them out of s3 directly. S3 is well suited to serve static assets.
  # More info here: https://rubyonjets.com/docs/extras/assets-serving/
  any "*catchall", to: "jets/public#show"
end
