
describe Deck do
  describe '.card' do
    it 'returns cards in order' do
      expect(Deck.card(0)).to eq({number: 1, suite: 'H'})
      expect(Deck.card(1)).to eq({number: 2, suite: 'H'})
    end

    it 'returns 4 suites of 13' do
      expect(Deck.card(0)).to eq({number: 1, suite: 'H'})
      expect(Deck.card(13)).to eq({number: 1, suite: 'S'})
      expect(Deck.card(26)).to eq({number: 1, suite: 'D'})
      expect(Deck.card(39)).to eq({number: 1, suite: 'C'})
    end

    it 'supports multiple decks' do
      expect(Deck.card(52 + 0)).to eq({number: 1, suite: 'H'})
      expect(Deck.card(52 + 1)).to eq({number: 2, suite: 'H'})
      expect(Deck.card(52 + 13)).to eq({number: 1, suite: 'S'})
      expect(Deck.card(52 + 39)).to eq({number: 1, suite: 'C'})
    end
  end

  describe '.i' do
    it 'returns the index in the first two decks' do
      expect(Deck.i(Deck.card(0))).to eq([0,52])
      expect(Deck.i(Deck.card(1))).to eq([1,53])
      expect(Deck.i(Deck.card(39))).to eq([39,91])
    end

    it 'converts strings and returns the index' do
      expect(Deck.i('8D')).to eq(Deck.i(number: 8, suite: 'D'))
    end

    i
  end
end