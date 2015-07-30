#!/usr/bin/ruby
/regexp/
require File.join(File.dirname(__FILE__), 'Players')
require File.join(File.dirname(__FILE__), 'Blackjack')
# Keeps track of the suit and rank of a card
class Card
	attr_reader :suit, :rank

	def initialize(rank, suit)
		@suit = suit
		@rank = rank
		@blackjack = false
	end

	# Takes in another instance of a CARD and returns true if CARD and self are the same suit and rank.
	def equals(card)
		if @suit == card.suit and @rank == card.rank
			return true
		else
			return false
		end
	end

	# returns a string representation of this card.
	def to_s
		return "#{@rank} of #{@suit}"
	end
end


# A collection of cards representing a hand. This class keeps track of the value
# of the hand and busts. Hands accept and store cards, updating their value accordingly,  
class Hand
	attr_reader :cards, :value, :blackjack
	attr_accessor :currentBet

	# hasAce used to keep track of multiple values of aces (1 or 11).
	# blackjack used to keep track of superior 21-valued hands
	def initialize
		@cards = []
		@value = 0
		@currentBet = 0
		@hasAce = false
		@blackjack = false
	end


	# Setter for @currentBet. Called makeBet for clarity's sake.
	def makeBet(bet)
		@currentBet = bet
	end

	# number of cards in this hand
	def length
		return @cards.length
	end

	# simply a more specific setter again, for clarity's sake
	def clearBet
		@currentBet = 0
	end

	# adds a CARD to the hand and updates the value of the hand accordingly.
	def addCard(card)
		@cards << card
		@value += getValue(card.rank)
		if card.rank == 'Ace'
			@hasAce = true
		end
		if @cards.length == 2 and @value == 21 and @hasAce # updates should be in different method
			@blackjack = true
		end
		if @value > 21 and @hasAce
			@value -= 10
			@hasAce = false
		end
	end

	def to_s
		str = ""
		@cards.each do |card|
			str += card.to_s + ', '
		end
		str = str[0, str.length-2] # trim last comma
		return str
	end

	# returns true if splitting is allowed on this hand.
	def splittable
		if @cards.length == 2 and @cards[0].rank == @cards[1].rank
			return true
		else
			return false
		end
	end

	# Called from Player class if this hand is splittable. Sets this 
	# hand to one of the cards in it and returns the other card.
	def split
		card = @cards[1]
		@cards = [@cards[0]]
		@value -= getValue(card.rank)
		return card
	end

	# Returns true if the value of this hand is over 21
	# and false otherwise
	def isBusted
		if @value > 21
			return true
		end
		return false
	end
end

# 52 cards. 4 suits of 13 ranks. Uses an index (@currIndex) to get the next card
# rather than popping elements off of the list of cards. Reshuffles at every
# reset of that index
class Deck
	# shouldShuffle is true for all instances other than testing situations
	def initialize(shouldShuffle=true)
		@deck = newDeck
		@shouldShuffle = shouldShuffle
		@currIndex = 0
		shuffle
	end

	def newDeck
		ranks = %w(2 3 4 5 6 7 8 9 10 Jack Queen King Ace)
		suits = %w(Hearts Spades Diamonds Clubs)
		deck = []
		ranks.each do |rank|
			suits.each do |suit|
				card = Card.new(rank, suit)
				deck << card
			end
		end
		return deck
	end
	# Fisher-Yates algorithm for shuffling cards
	def shuffle
		if @shouldShuffle
			(0..@deck.length-1).each do |i|
				j = rand(i..@deck.length-1)
				temp = @deck[j]
				@deck[j] = @deck[i]
				@deck[i] = temp
			end
		end
	end

	# uses @currIndex to return the next card in the deck
	def getNextCard
		if @currIndex == 52
			shuffle
			@currIndex = 0
		end
		card = @deck[@currIndex]
		@currIndex += 1
		return card
	end

	# used for testing
	def length
		return @deck.length
	end
end

# Takes a string RANK as an input and returns the associated value
def getValue(rank)
	if /\d/.match(rank)
		return rank.to_i
	elsif rank == 'Ace'
		return 11
	else
		return 10
	end
end