require 'set'

class Game < ApplicationItem
  column :id, :data, :updated_at

  def add_player(player)
    validate_data
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to add player to game in state: #{data[:state]}"
    end

    if data['players'].include? player
      raise "Unable to add duplicate player.  #{player} is already in the game"
    end

    data['players'] << player
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

    data['state'] = 'PLAYING'
    data['deck'] = Deck.standard_deck
    data['score'] = players.map { |p| [p, 0] }.to_h
    table_state['dealer'] = players.first
    start_round(data['round'])
  end

  def new_game
    validate_data
    if data['state'] != 'GAME_OVER'
      raise "Unable to start a NEW game in state: #{data['state']}"
    end

    data['round'] = 0
    data['table_state'] = {}
    data['round_summaries'] = []
    data['state'] = 'PLAYING'
    data['deck'] = Deck.standard_deck
    data['score'] = players.map { |p| [p, 0] }.to_h
    table_state['dealer'] = players.first
    start_round(data['round'])
  end

  def new_round
    data['round'] = data['round'].to_i + 1
    data['state'] = 'PLAYING'
    start_round(data['round'])
  end

  def start_round(round)
    # determine new dealer
    table_state['dealer'] = next_player(table_state['dealer'])
    table_state['deck'] = deck = (0...data['deck'].size).to_a.shuffle
    table_state['hands'] = hands = {}
    players.each do |player|
      hands[player] = deck.pop(round + 3)
    end
    table_state['discard'] = [deck.pop, deck.pop]

    table_state['laid_down'] = {}
    table_state['laying_down'] = nil

    table_state['active_player'] = next_player(table_state['dealer'])
    table_state['turn_state'] = 'WAITING_TO_DRAW'
    table_state['turn'] = 1
  end

  # draw_type can be DECK, DISCARD
  def draw(player, draw_type)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DRAW'
      raise "Cannot draw, turn state: #{table_state['turn_state']}"
    end

    case draw_type
    when 'DECK'
      card = table_state['deck'].pop
    when 'DISCARD'
      card = table_state['discard'].pop
    else
      raise 'Invalid draw_type'
    end

    table_state['hands'][player] << card
    table_state['turn_state'] = 'WAITING_TO_DISCARD'
  end

  # draw_type can be DECK, DISCARD
  def discard(player, card)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DISCARD'
      raise "Cannot discard, turn state: #{table_state['turn_state']}"
    end

    unless table_state['laid_down'].blank?
      raise "Last turn - must lay down"
    end

    hand_i = hand(player).find_index(card.to_i)
    if hand_i.nil?
      raise "Cannot discard card: #{card} from hand: #{hand(player)}"
    end

    table_state['hands'][player].delete_at(hand_i)
    table_state['discard'] << card

    if players.size == 1
      # put a random card on the discard
      table_state['discard'] << table_state['deck'].pop
    end

    next_turn(player)
  end

  #laid_down:
  #     {
  #       words: [ [cid, cid], [cid] ]
  #       leftover: [ cids ]
  #       discard: cid  #required single card
  #     }
  def laydown(player, laid_down)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DISCARD'
      raise "Cannot laydown, turn state: #{table_state['turn_state']}"
    end

    # remove zero card words
    laid_down['words'] = laid_down['words'].select{ |w| w && w.length > 0 }

    # TODO: validate all cards played were in the hand
    words = laid_down[:words].map do |cards|
      points = 0
      word = ""
      cards.each do |card|
        deck_card = data['deck'][card.to_i]
        points += deck_card[1].to_i
        word << deck_card[0]
      end
      {'word' => word, 'points' => points}
    end
    word_score = words.map { |w| w['points'] }.sum
    leftover_score = laid_down[:leftover].map { |c| data['deck'][c.to_i][1].to_i }.sum
    score = [word_score - leftover_score, 0].max

    table_state['laid_down'][player] = {
      'cards' => laid_down[:words],
      'words' => words,
      'leftover' => laid_down[:leftover],
      'score' => [score, 0].max
    }

    table_state['hands'][player] = []
    table_state['discard'] << laid_down[:discard]

    next_turn(player)
  end

  def laying_down(player, laid_down)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DISCARD'
      raise "Cannot laydown, turn state: #{table_state['turn_state']}"
    end

    if laid_down['words'].blank?
      table_state['laying_down'] = nil
      return
    end

    # remove zero card words
    laid_down['words'] = laid_down['words'].select{ |w| w && w.length > 0 }

    # TODO: validate all cards played were in the hand
    words = laid_down['words'].map do |cards|
      points = 0
      word = ""
      cards.each do |card|
        card = card.to_i
        points += data['deck'][card][1].to_i
        word << data['deck'][card][0]
      end
      {word: word, points: points}
    end
    word_score = words.map { |w| w[:points] }.sum
    leftover_score = laid_down[:leftover].map { |c| data['deck'][c.to_i][1].to_i }.sum
    score = [word_score - leftover_score, 0].max

    table_state['laying_down'] = {
      'cards' => laid_down[:words],
      'words' => words,
      'leftover' => laid_down[:leftover],
      'score' => score
    }
  end

  def next_turn(player)
    np = next_player(player)
    table_state['laying_down'] = nil
    if table_state["laid_down"].include? np
      # end of the round - this player has already laid down
      end_round
    else
      if player == table_state['dealer']
        table_state['turn'] = table_state['turn'].to_i + 1
      end
      table_state['active_player'] = np
      table_state['turn_state'] = 'WAITING_TO_DRAW'
    end
  end

  def table_state
    data['table_state']
  end

  def players
    data['players']
  end

  # map of player to index
  def p_i(player)
    players.find_index(player)
  end

  def next_player(player)
    players[(p_i(player) + 1) % players.size]
  end

  def hand(player)
    table_state['hands'][player].map {|cI| cI.to_i }
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

  def end_round
    table_state['turn_state'] = 'ROUND_COMPLETE'
    data['state'] = 'WAITING_FOR_NEXT_ROUND'
    if data['round'].to_i >= 7
      data['state'] = 'GAME_OVER'
    end

    # compute longest word and most word bonuses (2+ players only)
    longest_words = longest_words(table_state["laid_down"])
    if players.size >= 2 && data['settings'] && data['settings']['most_words_bonus']
      if (longest_words[0][1] > longest_words[1][1])
        player = longest_words[0][0]
        puts "Longest Word: #{player}"
        table_state["laid_down"][player]['longest_word_bonus'] = 10
        table_state['laid_down'][player]['score'] += 10
      end
    end

    # compute 7+ letter bonus
    if data['settings'] && data['settings']['word_smith_bonus']
      longest_words.each do |player, size|
        if size >= 7
          table_state["laid_down"][player]['word_smith_bonus'] = 10
          table_state['laid_down'][player]['score'] += 10
        end
      end
    end

    if players.size >= 2 && data['settings'] && data['settings']['most_words_bonus']
      n_words = table_state["laid_down"].map {|p,x| [p, x['words'].size] }.sort_by { |x| x[1] }.reverse!
      if (n_words[0][1] > n_words[1][1])
        player = n_words[0][0]
        table_state["laid_down"][player]['most_words_bonus'] = 10
        table_state['laid_down'][player]['score'] += 10
      end
    end

    # compute word list bonuses (if in settings)
    if (bonus_words = wordlist) #returns nil unless configured
      table_state["laid_down"].each do |player, x|
        words = x['words'].map { |w| w['word'] }.select { |w| bonus_words.include? w }
        if words.length > 0
          puts "PLAYER BONUS! #{player} : #{words.join(', ')}"
          bw_score = 10 * words.size
          table_state["laid_down"][player]['bonus_words_score'] = bw_score
          table_state['laid_down'][player]['score'] += 10
          table_state["laid_down"][player]['bonus_words'] = words.join(', ')
        end
      end
    end

    data['round_summaries'] << table_state['laid_down']
    compute_stats

    players.each do |player|
      data['score'][player] = data['score'][player].to_i + table_state['laid_down'][player]['score'].to_i
    end
  end

  # compute stats from round summaries
  def compute_stats
    rounds = data['round_summaries']
    stats = {}

    # list of best (highest score) words by player
    # goal: flat map to [player, word, score]
    best_words = rounds.each_with_index.map { |summary, round_i| summary.map { |p, x| x['words'].map { |w| [p, w['word'], w['points'].to_i, round_i] }}}.flatten(2).sort_by { |x| x[2] }.reverse
    stats['best_words'] = best_words

    longest_words = rounds.each_with_index.map { |summary, round_i| summary.map { |p, x| x['words'].map { |w| [p, w['word'], w['word'].length, round_i] }}}.flatten(2).sort_by { |x| x[2] }.reverse
    stats['longest_words'] = longest_words

    n_words = {}
    rounds.each { |summary| summary.each { |p, x| n_words[p] = n_words.fetch(p, 0) + x['words'].length } }
    n_words = n_words.to_a.sort_by { |x| x[1] }.reverse
    stats['n_words'] = n_words

    leftovers = {}
    rounds.each { |summary| summary.each { |p, x| leftovers[p] = leftovers.fetch(p, 0) + x['leftover'].length } }
    leftovers = leftovers.to_a.sort_by { |x| x[1] }
    stats['leftover_letters'] = leftovers

    data['stats'] = stats
  end

  def self.create_fresh
    game = Game.new
    game.data = {
      'players' => [],
      'state' => 'WAITING_FOR_PLAYERS',
      'round' => 0,
      'table_state' => {},
      'round_summaries' => [],
      'settings' => {
        'enable_bonus_words' => true,
        'bonus_words' => 'animals_wordlist',
        'longest_word_bonus' => true,
        'most_words_bonus' => false,
        'word_smith_bonus' => true
      }
    }
    game
  end

  # return Set<String>
  def wordlist
    if data['settings'] &&
      data['settings']['enable_bonus_words'] &&
      (wl_name = data['settings']['bonus_words'])

      @wordlists ||= {}
      @wordlists[wl_name] ||= load_wordlist(wl_name)
    end
  end

  def load_wordlist(wl_name)
    puts "Loading wordlist: #{wl_name}"
    words = File.open("public/assets/#{wl_name}.txt").readlines.map(&:chomp).map(&:upcase)
    puts "Loaded: #{words.length} words"
    Set.new(words)
  end
end

def longest_words(laid_down)
  laid_down.map(&method(:player_longest_word)).sort_by { |x| x[1] }.reverse
end

def player_longest_word(p,x)
  puts "Computing player longest word: #{p}, #{x}"
  [p, longest_word(x['words'])]
end

def longest_word(words)
  words.map{ |y| y['word']&.size || 0 }.max || 0
end
