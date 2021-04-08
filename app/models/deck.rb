class Deck

  SUITES = %w[H S D C]

  # Only model a standard Deck
  # 2x [1-13 X H,S,D,C].

  #   0 1 2 3    4 5 6 7
  # H[0 1 2 3] S[0 1 2 3]

  def self.size
    return 104
  end

  def self.card(i)
    i = i % 52 # divide two decks into 2 of 52 cards
    suite = SUITES[i / 13] # divide deck into 4 suites of 13 cards each
    number = (i % 13) + 1 # get the card number (add 1 to fix zero index)
    {suite: suite, number: number}
  end

  # the inverse of the above
  # return the indecies (in the first 2 decks) for the card
  def self.i(card)
    card = s_to_card(card) if card.is_a?(String)
    suite = card[:suite]
    number = card[:number]
    s = SUITES.find_index(suite)
    cI = s*13 + (number-1)
    [cI, cI+52]
  end

  def self.s_to_card(s)
    m = /(\d+)([HSDC])/.match(s)
    {number: m[1].to_i, suite: m[2]}
  end
end
