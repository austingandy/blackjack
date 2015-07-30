require 'minitest/autorun'
# note: relative_require definition and everything surrounding it is not my code.
# Source: http://stackoverflow.com/questions/4333286/ruby-require-vs-require-relative-best-practice-to-workaround-running-in-both
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'Card'

class TestBlackjack < MiniTest::Unit::TestCase
	def setup
		@deck = Deck.new
		@input, @myOutput = IO.pipe
		@myInput, @output = IO.pipe
		@player = Player.new(@input, @output)
		@hand = Hand.new
		@fiveOfHearts = Card.new('5', 'Hearts')
		@fiveOfClubs = Card.new('5', 'Clubs')
		numPlayers = 2
		@table = Table.new(numPlayers, @input, @output)
	end

	def test_cards
		card = Card.new('10', 'Hearts')
		assert_equal('10 of Hearts', card.to_s)
		assert_equal('Hearts', card.suit)
		assert_equal('10', card.rank)
		ace = Card.new('Ace', 'Spades')
		assert_equal(11, getValue(ace.rank))
		sameCard = Card.new('10', 'Hearts')
		assert_equal(true, card.equals(sameCard))
		assert_equal(false, card.equals(ace))
	end

	def test_hand_init
		assert_equal(0, @hand.value, 'Hand value initialized incorrectly')
		assert_equal(0, @hand.cards.length, 'Cards in hand initialized incorrectly')
		assert_equal(0, @hand.currentBet, 'Current bet initialized incorrectly')
	end

	def test_hand_betting_and_value_updates
		@hand.makeBet(20)
		assert_equal(20, @hand.currentBet, "Hand.makeBet failed. Expected 20 but got #{@hand.currentBet}")
		@hand.addCard(Card.new('Queen', 'Hearts'))
		assert_equal(10, @hand.value, "Value being calculated incorrectly. Expected value to be 10 but was #{@hand.value}")
		@hand.addCard(Card.new('2', 'Spades'))
		@hand.addCard(Card.new('Ace', 'Hearts'))
		assert_equal(13, @hand.value, "Value does not handle aces correctly. Value should be 13 but was #{@hand.value}")
		@hand.clearBet
		assert_equal(0, @hand.currentBet, "clearBet method did not set the @hand's bet to zero")
	end
		
	def test_hand_busts_and_splitting
		assert_equal(false, @hand.isBusted)
		@hand.addCard(Card.new('Jack', 'Diamonds'))
		@hand.addCard(Card.new('Queen', 'Hearts'))
		@hand.addCard(Card.new('4', 'Spades'))
		assert_equal(true, @hand.isBusted, "@hand does not indicate whether value is over 21 correctly. Value is currently #{@hand.value}")
		@hand = Hand.new
		@hand.addCard(Card.new('5', 'Diamonds'))
		@hand.addCard(Card.new('5', 'Hearts'))
		assert_equal(true, @hand.splittable, "@hand.splittable should currently be true but it's #{@hand.splittable}")
		otherCard = @hand.split
		assert_equal(5, @hand.value, "Split method did not split the @hand.")
		assert_equal('5', otherCard.rank, "Split method did not return the correct card")
	end

	def test_deck
		assert_equal(52, @deck.length)
		suits = %w(Hearts Spades Diamonds Clubs)
		cards = Hash[suits.map{|suit| [suit, %w(2 3 4 5 6 7 8 9 10 Jack Queen King Ace)]}]
		(0..51).each do |i|
			card = @deck.getNextCard
			suit = card.suit
			rank = card.rank
			assert_equal(true, cards.keys.include?(suit), "failed on iteration #{i} with #{card.to_s}")
			assert_equal(true, cards[suit].include?(rank), "failed on iteration #{i} with #{card.to_s}")
			index = cards[suit].index(rank)
			cards[suit].delete_at(index)
		end
		card = @deck.getNextCard
		assert_equal(true, suits.include?(card.suit))
	end

	def test_player_init
		# testing init
		assert_equal(1, @player.hands.length, "Player's hands are initialized incorrectly")
		assert_equal(0, @player.getHand.length, "Cards in player's hands are initialized incorrectly")
		assert_equal(1000, @player.cash, "Player should start with $1000")
	end

	def test_player_dealing
		# testing card dealing functionality
		@player.dealCard(@fiveOfHearts, 0, false)
		hand = @player.getHand
		assert_equal(1, hand.length, "Card was not added to player's hand correctly")
		assert_equal(5, hand.value, "Incorrect card added to player's hand")
		@player.dealCard(@fiveOfClubs)
		assert_equal(2, hand.length, "Second card was not added to player's hand correctly")
		assert_equal(false, @player.isBusted, "Player's hand is not being tracked as busted correctly")
	end

	def test_player_betting
		# testing betting logic
		bet = @player.makeBet(1001)
		@player.dealCard(@fiveOfHearts)
		@player.dealCard(@fiveOfClubs)
		hand = @player.getHand
		assert_equal(false, bet, "Bet was made when player didn't have enough money to do so")
		assert_equal(1000, @player.cash)
		assert_equal(0, @player.getHand.currentBet, "Bet was made to hand when player didn't have enough money to do so")
		bet = @player.makeBet(100)
		assert_equal(true, bet, "Player was disallowed from making a bet she should have been able to make.")
		assert_equal(900, @player.cash, "Betting did not take money out of player's @cash attribute.")
		assert_equal(100, hand.currentBet, "Bet not made correctly to hand")
		# winning case
		dealerScore = 9
		dealerBlackjack = false
		playerIndex = 1
		@player.collectBets(dealerScore, playerIndex, dealerBlackjack)
		assert_equal(1100, @player.cash, "Player should have won bet but cash was not updated as such")
		assert_equal(0, hand.currentBet, "Bet wasn't cleared from hand")
		hand = @player.getHand
		assert_equal(0, hand.cards.length, "Hand was not cleared of cards")
		@player.dealCard(@fiveOfHearts)
		@player.dealCard(@fiveOfClubs)
		bet = 100
		@player.makeBet(bet)
		prevCash = @player.cash
		# losing case
		dealerScore = 11
		@player.collectBets(dealerScore, playerIndex, dealerBlackjack)
		assert_equal(prevCash, @player.cash, "Losing to the dealer did not result in losing the money bet in this round")
	end

	def test_player_betting_with_blackjacks
		# player blackjack
		@player.dealCard(Card.new('Ace', 'Spades'))
		@player.dealCard(Card.new('Jack', 'Hearts'))
		assert_equal(21, @player.getHand.value, 'Player value at 21')
		assert_equal(true, @player.getHand.blackjack)
		bet = 100
		@player.makeBet(bet)
		dealerScore = 21
		assert_equal(dealerScore, @player.getHand.value, "player score counted incorrectly")
		playerCash = @player.cash
		playerIndex = 1
		dealerBlackjack = false
		@player.collectBets(dealerScore, playerIndex, dealerBlackjack)
		assert_equal(playerCash + 2.5 * bet, @player.cash, "Player blackjack not counted as beating dealer score of 21 without a blackjack")
		# dealer blackjack
		@player.dealCard(@fiveOfHearts)
		@player.dealCard(@fiveOfClubs)
		@player.dealCard(Card.new('Ace', 'Hearts'))
		dealerBlackjack = true
		@player.collectBets(dealerScore, playerIndex, dealerBlackjack)
	end

	def test_player_splitting
		# testing splitting
		@player.dealCard(@fiveOfHearts)
		@player.dealCard(@fiveOfClubs)
		@player.makeBet(300)
		splitWorked = @player.split
		firstHand = @player.getHand(0)
		secondHand = @player.getHand(1)
		assert_equal(true, splitWorked, "Split operation should have worked and .split reported that it didn't")
		assert_equal(firstHand.value, secondHand.value, "Split operation created new hands incorrectly")
		assert_equal(firstHand.currentBet, secondHand.currentBet,
			"Split operation didn't carry bet over to the other hand correctly")
		# testing getMove
		@myOutput.puts 'huh?'
		@myOutput.puts 'hit'
		move = @player.getMove(1)
		assert_equal('hit', move, "Player did not retrieve move from user correctly")
		@player.dealCard(Card.new('Queen', 'Spades'))
		@player.dealCard(Card.new('King', 'Hearts'))
		assert_equal(true, @player.isBusted, "Player is determining busted hands incorrectly")
		assert_equal(false, @player.isBusted(1), "Second hand determined bust incorrectly")
		# testing doubling down
	end

	def test_player_double_down
		@player = Player.new(@input, @output)
		@player.dealCard(@fiveOfClubs)
		@player.dealCard(@fiveOfHearts)
		@player.makeBet(100)
		@player.doubleDown
		assert_equal(800, @player.cash, "Player's cash should have decreased once again after doubling down")
		dealerScore = 9
		playerIndex = 1
		dealerBlackjack = false
		@player.collectBets(dealerScore, playerIndex, dealerBlackjack)
		assert_equal(1200, @player.cash, "Player's bet should have paid back double after doubling down.")
	end

	def test_dealer
		dealer = Dealer.new(@input, @output)
		assert_equal(1, dealer.hands.length, "Player's hands are initialized incorrectly")
		assert_equal(0, dealer.getHand.length, "Cards in player's hands are initialized incorrectly")
		
		dealer.dealCard(@fiveOfHearts)
		assert_equal(5, dealer.getHand.value, "Card added incorrectly to dealer's hand")
		dealer.dealCard(@fiveOfClubs)
		assert_equal(false, dealer.blackjack, "Dealer should not have a blackjack with this hand")
		move = dealer.getMove
		assert_equal('hit', move, "Dealer should be hitting when dealer's hand's value is below 17")
		dealer.dealCard(Card.new('7', 'Spades'))
		move = dealer.getMove
		assert_equal('pass', move, "Dealer should be passing when dealer's hand's value is at or above 17")
	end

	def test_table_init
		# test initialization
		numPlayers = 2
		assert_equal(52, @table.deck.length, "Deck within Table initialized incorrectly")
		assert_equal(3, @table.players.length, "Table does not contain the right amount of players (2 players + 1 dealer)")
		assert_equal(numPlayers, @table.numPlayers, "numPlayers should keep track of the number of human players at the table")
	end

	def test_table_bet_getting
		#test getBet
		@myOutput.puts '45'
		@player = @table.getPlayer(1)
		playerHand = @player.getHand
		@table.getBet(@player, 1)
		assert_equal(45, playerHand.currentBet, "Bet not made correctly")
		@myOutput.puts '95'
		@player = @table.getPlayer(2)
		playerHand = @player.getHand
		@table.getBet(@player, 2)
		assert_equal(95, playerHand.currentBet, "Player 2 bet not made correctly")
	end

	def test_table_deal_initial_cards
		# test dealInitial Cards
		@table.dealInitialCards
		@table.players.each.with_index do |player, index|
			hand = player.getHand

			assert_equal(2, hand.length, "Player #{index} was not dealt the correct number of cards")
		end
		# collectBets also clears player's hands
		@table.collectBets(12)
	end

	def test_table_make_moves
		@table.players.each do |player|
			player.getHand.cards << @fiveOfHearts
			player.getHand.cards << Card.new('6', 'Spades')
		end
		# first player's move sequence
		@myOutput.puts "I don't understand."
		@myOutput.puts 'hit'
		@myOutput.puts 'stay'
		# second player's move sequence
		@myOutput.puts 'what?'
		@myOutput.puts 'split' # split should not be an option here as the cards are not splittable
		@myOutput.puts 'stay'
		playerOneHand = @table.getPlayer(1).getHand
		#test makeMoves
		@table.makeMoves
		assert_equal(3, playerOneHand.length, "Player 1 attempted to hit on her turn and was unable to do so")
		playerTwoHand = @table.getPlayer(2).getHand
		assert_equal(2, playerTwoHand.length, "Player 2 attempted to stay on his turn and was unable to do so")
		@table.collectBets(12)
	end

	def test_table_make_split_and_quit
		@table = Table.new(3, @input, @output, Deck.new(false))
		# all player's bets, respectively
		pushStrings %w(10 20 30)
		# first player's moves for first
		pushStrings %w(split hit stay)
		# first player's moves for second hand
		pushStrings %w(stay)
		# second player's moves
		pushStrings %w(double\ down hit)
		# third player's moves
		pushStrings %w(hit quit)
		@table.play
		playerOneHands = (0..1).map{ |i| @table.getPlayer(1).getHand(i) }
		assert_equal(2, playerOneHands.length, "Split did not work properly")
		assert_equal(2, playerOneHands[0].cards.length, "Split did not update first hand correctly")
		assert_equal(1, playerOneHands[1].cards.length, "Split did not update second hand correctly")
		assert_equal(false, @table.playing, "player 2 quitting did not result in the table updating as such")
		assert_equal(960, @table.getPlayer(2).cash, "Doubling down did not result in winning the right amount")
		playerThreeHand = @table.getPlayer(3).getHand
		assert_equal(3, playerThreeHand.cards.length, "Player three was unable to add a card")
		assert_equal(false, @table.playing, "Quitting should stop the table from playing")
	end

	def pushStrings(strings)
		strings.each do |string|
			@myOutput.puts string
		end
	end
end