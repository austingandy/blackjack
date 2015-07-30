#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), 'Card')
require File.join(File.dirname(__FILE__), 'Blackjack')

# Class that keeps track of players hands. Used to split hands,
# keep track of multiple bets, and keep track of player money left
class Player
	attr_reader :hands, :cash

	def initialize(input=$stdin, out=$stdout)
		@hands = [Hand.new]
		@playing = true
		@cash = 1000
		@in = input
		@out = out
	end

	# returns the player's hand at a give handIndex
	def getHand(handIndex=0)
		return @hands[handIndex]
	end

	# Prompts user for input. Executes game logic for each possible instruction.
	# I'm changing this so that hands/players no longer have to have a deck attribute.
	def getMove(playerIndex, handIndex=0)
		validMoves = %w(hit split stay double\ down quit) #move this
		hand = @hands[handIndex] # different method from here to loop
		@out.puts "Player #{playerIndex} it's your turn." 
		@out.puts "Your current hand is #{hand.to_s}"
		@out.puts "Would you like to hit,#{hand.splittable ? ' split, ' : ''} double down, or stay?"
		loop do
			move = @in.gets.chomp.downcase 
			if validMoves.include? move
				return move
			end
			@out.puts "Please enter a valid move. Either hit #{hand.splittable ? ', split, ' : ''}double down, or stay?"
		end
	end

	# puts card in the hand at handIndex and comments on it
	# if commentary is set to true.
	def dealCard(card, handIndex=0, commentary=true)
		hand = @hands[handIndex]
		hand.addCard(card)
		if commentary
			describe(card, hand)
		end
	end

	def describe(card, hand)
		@out.puts "You drew a #{card}."
		@out.puts "Your hand is now #{hand.to_s}"
		if hand.isBusted
			@out.puts "You've busted."
		end
	end

	# Ensures current bet is legal. If so, places bet on the hand at handIndex
	# and returns true. Otherwise, returns false.
	def makeBet(bet, handIndex=0)
		if @cash >= bet
			@cash -= bet
			if @cash <= 0
				@playing = false
			end
			@hands[handIndex].makeBet(bet)
			return true
		else
			return false
		end
	end

	# Compares hand values to dealerScore. Pays this player the money
	# s/he has earned or takes money off the table depending on the 
	# player's hands' values and the dealerScore.
	def collectBets(dealerScore, playerIndex, dealerBlackjack)
		@hands.each do |hand|
			if isWin(hand, dealerScore, dealerBlackjack)
				@cash += hand.blackjack ? 2.5 * hand.currentBet : 2 * hand.currentBet
				@out.puts "Player #{playerIndex} you beat the dealer's hand! You won $#{hand.currentBet}."
			elsif isTie(hand, dealerScore, dealerBlackjack)
				@cash += hand.currentBet
				@out.puts "Player #{playerIndex} you tied the dealer's hand. You won your bet back."
			else
				@out.puts "Player #{playerIndex} you lost your bet."
			end
			hand.currentBet = 0
		end
		@hands = [Hand.new]
	end

	# Returns true if hand beats dealerScore. Takes blackjacks for this player and the dealer into account.
	def isWin(hand, dealerScore, dealerBlackjack)
		if (hand.blackjack or ((hand.value > dealerScore or dealerScore > 21) and hand.value <= 21)) and not dealerBlackjack
			return true
		end
		return false
	end

	# Returns true if hand ties dealerScore. Takes blackjacks for this player and the dealer into account.
	def isTie(hand, dealerScore, dealerBlackjack)
		if ((hand.value == dealerScore) and (hand.blackjack == dealerBlackjack)) or (hand.value > 21 and dealerScore > 21)
			return true
		end
		return false
	end

	# Determines whether or not this player's given hand is
	# at a value over 21.
	def isBusted(handIndex=0)
		return @hands[handIndex].isBusted
	end

	# The number of hands this player currently has
	def numHands
		return @hands.length
	end

	# Splits the hand located at handIndex into two separate hands if it is legal to do so.
	# Returns true if the split was successful and false otherwise.
	def split(handIndex=0)
		hand = @hands[handIndex]
		if hand.splittable and @hands.length < 4 and hand.currentBet <= @cash # this should all be one method
			card = hand.split
			newHand = Hand.new
			newHand.addCard(card)
			@hands << newHand
			makeBet(hand.currentBet, @hands.length-1)
			@out.puts "Your bet has been doubled. You can hit one more time."
			return true
		else
			return false
		end
	end

	# Executes the logic for doubling down a player's hand
	# and returns true if the hand and player can double down.
	# Otherwise returns false.
	def doubleDown(handIndex=0)
		hand = @hands[handIndex]
		bet = hand.currentBet
		if @cash >= hand.currentBet
			hand.currentBet *= 2
			@cash -= bet
			@out.puts "Your bet is now #{hand.currentBet}"
			return true
		else
			@out.puts "You do not have enough money to double down."
			return false
		end
	end
end

class Dealer < Player

	# Implements house dealer rules for making moves.
	def getMove(playerIndex=0, handIndex=0)
		loop do
			val = self.getHand(handIndex).value
			if val >= 17
				return 'pass'
				break
			else
				return 'hit'
			end
		end
	end

	# Returns the current value of the dealer's hand 
	def value
		return self.getHand.value
	end

	# Gives the dealer a new hand
	def clearHand
		@hands = [Hand.new]
	end

	# Dealers are not allowed to split.
	def split(handIndex)
		raise NotImplementedError
	end

	# Puts a card in the dealer's hand. Tells the user(s) about the first (and only the first) card in the dealer's hand.
	def dealCard(card, handIndex=0, commentary=false) #consider index out of bounds error and handling for this
		hand = self.getHand
		hand.addCard(card)
		if hand.length == 1
			@out.puts "The dealer has a #{card} showing."
		end
	end

	# True if the dealer has a blackjack
	def blackjack
		return self.getHand.blackjack
	end
end