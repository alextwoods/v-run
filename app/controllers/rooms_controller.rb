include BCrypt

class RoomsController < ApplicationController

  class_iam_policy("dynamodb")

  before_action :set_room, only: %i[ show destroy]

  # GET /rooms
  def index
    redirect_to add_stage_name("/rooms/#{session[:room]}") if session[:room]
  end

  # GET /rooms/1
  def show
    if !@room || session[:room] != @room.id
      puts "Invalid room session, clearing and redirecting to index"
      session[:room] = nil
      redirect_to add_stage_name("/rooms")
      return
    end

    @chain_games = Game.where_room(@room.id)
    @chain_games_joinable, @chain_games_other = @chain_games.partition { |g| g.data['state'] == 'WAITING_FOR_PLAYERS' }
  end

  # POST /rooms/join
  def join
    puts "Trying to join: #{room_params}"
    @room = Room.find(room_params[:id])
    if @room && Password.new(@room.passphrase) == room_params[:passphrase].downcase
      puts "Joined room: #{@room.id}"
      session[:room] = @room.id
      redirect_to add_stage_name("/rooms/#{@room.id}")
    else
      puts "Room doesn't exist or passhprase mismatch: #{@room&.passphrase} -> #{room_params[:passphrase].downcase}"
      redirect_to add_stage_name("/rooms")
    end
  end

  # GET /rooms/leave
  def leave
    puts "Leaving room: #{session[:room]}"
    session[:room] = nil
    redirect_to add_stage_name("/rooms")
  end

  # GET /rooms/new
  def new
    @room = Room.new
    puts @room
  end

  # GET /rooms/1/edit
  def edit
  end

  # POST /rooms or /rooms.json
  def create
    p = room_params.to_h
    @room = Room.new # unclear why, but new with the attributes below does not work.  just use setters.
    @room.id = p[:id]
    @room.passphrase = Password.create(room_params[:passphrase].downcase)
    puts @room.inspect
    puts "Passphrase: #{@room.passphrase}"
    @room.replace
    session[:room] = @room.id
    redirect_to add_stage_name("/rooms/#{@room.id}")
  end


  # DELETE /rooms/1 or /rooms/1.json
  def destroy
    # TODO
  end

  # todo: not sure what this route is used for, but jets requires it...
  def delete
    # TODO
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_room
    @room = Room.find(params[:room_id])
  end

  # Only allow a list of trusted parameters through.
  def room_params
    params.require(:room).permit(:id, :passphrase)
  end
end
