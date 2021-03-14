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

  # Restarts the game as a new game
  def newgame
    @game.new_game
    @game.replace
    render json: @game
  end

  # start a new round
  def round
    @game.new_round
    @game.replace
    render json: @game
  end

  def draw
    draw_type = draw_params
    @game.draw(player_cookie, draw_type)
    @game.replace
    render json: @game
  end


  def discard
    card = discard_params
    @game.discard(player_cookie, card)
    @game.replace
    render json: @game
  end

  def laydown
    laid_down = laydown_params
    @game.laydown(player_cookie, laid_down)
    @game.replace
    render json: @game
  end

  def layingdown
    laying_down = laydown_params
    @game.laying_down(player_cookie, laying_down)
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

  def settings_params
    params.require(:settings).permit(:enable_bonus_words, :word_smith_bonus, :longest_word_bonus, :most_words_bonus, :bonus_words)
  end


  def draw_params
    params.require(:draw_type)
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
