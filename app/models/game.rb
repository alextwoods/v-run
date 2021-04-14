require 'set'

class Game < ApplicationItem
  table_name :chaingame
  column :id, :data, :updated_at
  #   nplayers  2  3  4  5  6  7  8  9  10 11 12
  HAND_CARDS = [7, 6, 6, 6, 5, 5, 4, 4, 3, 3, 3]

  CPU_NAMES = %w[bender data chip hal marvin boilerplate cloud]

  def add_player(player)
    validate_data
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to add player to game in state: #{data[:state]}"
    end

    if data['players'].include? player
      raise "Unable to add duplicate player.  #{player} is already in the game"
    end

    data['players'] << player
    # assign a team to the player - pick the shortest
    green_len = data['teams']['green']['players'].size
    blue_len = data['teams']['blue']['players'].size
    if blue_len < green_len
      set_player_team(player, 'blue')
    else
      set_player_team(player, 'green')
    end
  end

  def add_cpu
    name = (CPU_NAMES - players).sample
    add_player(name)
    data["cpu_players"] << name
  end

  def set_player_team(player, team)
    # check if the player is in a team already, if so remove them first
    if (previous_team = player_team[player])
      data["teams"][previous_team]["players"] = data["teams"][previous_team]["players"].filter { |p| p != player }
    end
    player_team[player] = team
    data["teams"][team]["players"] << player
  end

  def update_settings(settings)
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to update settings for game in state: #{data[:state]}"
    end

    data['settings'] = data['settings'].merge(settings)
  end

  def start
    validate_data
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to start game in state: #{data['state']}"
    end

    data['state'] = 'WAITING_TO_PLAY'
    data['table_state'] = {}

    table_state['n_hand_cards'] = settings['custom_hand_cards'].blank?  ? HAND_CARDS[[0, players.size-2].max] : settings['custom_hand_cards']
    table_state['deck'] = deck = (0...Deck.size).to_a.shuffle

    table_state['hands'] = hands = {}
    players.each do |player|
      hands[player] = deck.pop(table_state['n_hand_cards'])
    end
    table_state['discard'] = []

    set_board(Board.load_board(settings['board']))

    # interleve all of the team arrays to ensure we alternate teams
    # TODO: settings for alternate play orders
    table_state['player_order'] = teams['blue']['players'].zip(teams['green']['players'], teams['red']['players']).zip.flatten.compact
    table_state['active_player'] = table_state['player_order'].sample
    table_state['turn_state'] = 'WAITING_TO_PLAY'
    table_state['turn'] = 1
  end

  def new_game
    validate_data
    if data['state'] != 'GAME_OVER'
      raise "Unable to start a NEW game in state: #{data['state']}"
    end
    # TODO: Implement me!
  end

  # play up to max_turns of CPU players
  # Returns instantly if active player is not a CPU
  def play_cpu(max_turns=nil)
    validate_data
    if data['state'] != 'WAITING_TO_PLAY'
      raise ArgumentError, "Invalid game state: #{data['state']}"
    end
    max_turns ||= data["cpu_players"].size
    t = 0
    while t < max_turns && data["cpu_players"].include?(active_player)
      _play_cpu
      t += 1
    end
  end

  # internal method.  Active player MUST already be a cpu
  # plays one round for the cpu
  # gets the score for every possible (non jack) play for the cpu,
  # picks the best and plays
  def _play_cpu
    scores = []
    board = get_board
    cpu = active_player
    team = player_team[cpu]
    hand = hand(cpu)
    hand.each_with_index do |cI, hI|
      # skip jacks... for now
      # TODO: Handle jacks
      c = Deck.card(cI)
      next if c[:number] == 11
      board.board_loc(c).each do |p_bI|
        if board.tokens[p_bI].nil?
          r, c = board.bI_to_rc(p_bI)
          scores << {hI: hI, cI: cI, bI: p_bI, row: r, col: c, score: board.score_move(r, c, team, settings['sequence_length'])}
        end
      end
    end
    play = (scores.sort_by { |s| s[:score] }).last
    play_card(cpu, play[:cI], play[:row], play[:col])
  end

  def play_card(player, cardI, row, col)
    validate_turn(player)

    cardI = cardI.to_i
    row = row.to_i
    col = col.to_i

    hand_i = hand(player).find_index(cardI)
    if hand_i.nil?
      raise "Cannot discard card: #{card} from hand: #{hand(player)}"
    end

    team = player_team[player]

    board = get_board
    board.play(cardI, row, col, team)
    new_sequences = board.new_sequences_at(row, col, team, settings['sequence_length']) # this also updates the board
    puts "NEW SEQUENCE: #{new_sequences}" if new_sequences.size > 0

    table_state['hands'][player].delete_at(hand_i)
    table_state['discard'] << cardI
    table_state['hands'][player] << table_state['deck'].pop
    next_turn(player)
  end


  def next_turn(player)
    np = next_player(player)
    table_state['turn'] = table_state['turn'].to_i + 1
    table_state['active_player'] = np
  end

  def table_state
    data['table_state']
  end

  def players
    data['players']
  end

  def player_team
    data['player_team']
  end

  def teams
    data['teams']
  end

  def settings
    data['settings']
  end

  def player_order
    table_state['player_order']
  end

  # map of player to index
  def p_i(player)
    player_order.find_index(player)
  end

  def next_player(player)
    player_order[(p_i(player) + 1) % player_order.size]
  end

  def hand(player)
    table_state['hands'][player].map {|cI| cI.to_i }
  end

  def active_player
    table_state['active_player']
  end

  def set_board(board)
    @board = board
    table_state['board'] = board.to_h
  end

  def get_board
    @board ||= Board.from_h(table_state['board'])
  end

  private

  # raise an exception if data is missing key fields
  def validate_data
    if data.blank? || data['players'].nil? || data['state'].nil? || data['table_state'].nil?
      raise "Invalid game data state: #{data}"
    end
  end

  def validate_turn(player)
    validate_data
    unless table_state['active_player'] == player
      raise "Cannot take turn.  Player #{player} is not the active_player: #{table_state['active_player']}"
    end
  end

  def self.create_fresh
    game = Game.new
    game.data = {
      'players' => [],
      'teams' => {
        'green' => {'color' => '0x00ff00', 'players' => []},
        'blue' => {'color' => '0x0000ff', 'players' => []},
        'red' => {'color' => '0xff0000', 'players' => []}
      },
      "player_team" => {

      },
      "cpu_players" => [],
      'state' => 'WAITING_FOR_PLAYERS',
      'turn' => 0,
      'table_state' => {},
      'settings' => {
        'sequences_to_win' => 2,
        'sequence_length' => 5,
        'board' => 'spiral',
        'custom_hand_cards' => nil
      }
    }
    game
  end
end

