class GamesController < ApplicationController

  class_iam_policy("dynamodb")

  before_action :set_game, except: [:index, :create, :delete]

  rescue_from StandardError, with: :error_handler

  def create
    game = Game.create_fresh
    game.replace
    redirect_to add_stage_name(play_game_path(game.id))
  end

  def index
    @games_path = add_stage_name(games_path)
  end

  # Used to render the SPA react app with various paths needed by the frontend.
  def play
    puts "Rendering SPA for play"
    @game_path = add_stage_name(game_path(@game.id))
    @root_path = add_stage_name(root_path)
    @game.replace # update the updated_at time
  end

  def show
    puts "Refreshing game state for: #{player_cookie}"
    render json: @game
  end

  # Add a player to the game
  # expect player=<name>
  def player
    player = player_params
    puts "Existing cookie: #{player_cookie}"
    puts "Adding player to game: #{player}"
    @game.add_player(player)

    # store player in a cookie - used for player action apis to identify the actor
    # TODO: Because we cant set http_only: false, let the front end set their own cookie
    # cookies[:player] = player
    @game.replace
    puts "Added player"
    render json: @game
  end

  # Add a CPU player to the game
  def cpu
    @game.add_cpu
    @game.replace
    puts "Added CPU"
    render json: @game
  end

  # Updates a players team
  def player_team
    player_team = player_team_params
    puts "Update team: #{player_team}"
    @game.set_player_team(player_team[:player], player_team[:team])

    @game.replace
    render json: @game
  end

  # update settings
  def settings
    puts "Got Params: #{params}"
    settings = settings_params
    puts "Updating settings to: #{settings}"
    puts "to_h=#{settings.to_h}"
    @game.update_settings(settings)

    @game.replace
    puts "Settings are now: #{@game.data['settings']}"
    render json: @game
  end

  # Starts the game
  def start
    @game.start
    @game.replace
    render json: @game
  end

  iam_policy "lambda" # required to run Jobs
  def play_card
    p = play_card_params
    puts "play_card: #{p}"
    bI = p["boardI"].to_i
    row = bI / 10
    col = bI % 10
    @game.play_card(player_cookie, p['cardI'], row, col)

    # the order of game.replace is sensitive (because in local, perform_later runs in the same thread
    # here, save it first, then run the cpu
    if @game.settings['cpu_wait_time'] && @game.settings['cpu_wait_time'] > 0
      @game.replace
      if @game.next_player_cpu?
        PlayCpuJob.perform_later(:play, {game_id: @game.id, sleep: @game.settings['cpu_wait_time'].to_i})
      end
    else
      @game.play_cpu
      @game.replace
    end

    render json: @game
  end

  # Restarts the game as a new game
  def newgame
    @game.new_game
    @game.replace
    render json: @game
  end

  def delete
    # For some reason this does not work.  Use the class method instead
    # @game.delete
    Game.delete(params[:game_id])
    render json: {}
  end

  private

  def player_cookie
    cookies["player_#{@game.id}"]
  end

  def set_game
    @game = Game.find(params[:game_id])
  end

  def player_params
    params.require(:player)
  end

  def player_team_params
    params.require(:player).permit(:player, :team)
  end

  def settings_params
    params.require(:settings).permit(:board, :sequence_length, :sequences_to_win, :custom_hand_cards)
  end


  def play_card_params
    params.require(:play).permit(:cardI, :boardI)
  end

  def discard_params
    params.require(:card)
  end

  def laydown_params
    # TODO: accept is not implemented in jets?
    params.require(:laydown) #.accept(:words, :leftover, :discard)
  end

  def error_handler(error)
    puts "Handling an error: #{error}"
    backtrace = error.backtrace.join("\n\t")
    puts "Backtrace:\n\t#{backtrace}"
    render json: {error: error}, status: 500
  end

end
