require File.join(File.dirname(__FILE__), 'Players')
require File.join(File.dirname(__FILE__), 'Card')

# Container class for all of th players and the logic of them all playing
class Table
	# Index in @players at which the dealer lies
	DEALER_INDEX = 0
	attr_reader :deck, :numPlayers, :players, :playing

	# Initializes a table instance with a deck of cards, a list of players (the zero-th of which is a dealer),
	# and an instance of an input and an output (mainly used for testing purposes)
	def initialize(numPlayers, input=$stdin, out=$stdout, deck=Deck.new)
		@in = input
		@out = out
		@deck = deck
		@playing = true
		@players = [Dealer.new(@in, @out)]
		@numPlayers = numPlayers
		@players << (1..numPlayers).map{ |index| Player.new(@in, @out)}
		@players.flatten!
	end

	# Returns the player at playerIndex
	def getPlayer(playerIndex)
		return @players[playerIndex]
	end

	# Asks player in @players at playerIndex the amount s/he is betting this round.
	def getBet(player, playerIndex)
		@out.puts "Player #{playerIndex}, you have $#{player.cash} left. How much do you want to bet this round?"
		loop do
			response = @in.gets.chomp
			if /\d/.match(response) # fix this
				bet = player.makeBet(response.to_i) # Could change make bet to accept anything and have the /\d/.match check there
				if bet
					@out.puts "Your bet has been counted. Good luck!"
					break
				end
			end
			@out.puts "Please enter a valid amount to bet."
		end
	end

	# Asks every player in @players for their bet for this round
	def getBets
		@players.each.with_index do |player, i|
			if i != DEALER_INDEX
				getBet(player, i)
			end
		end
	end

	# Gives each player two cards from the deck to start out.
	def dealInitialCards
		@players.each.with_index do |player, playerIndex|
			(0..1).each do |i|
				card = @deck.getNextCard
				player.dealCard(card, 0, false)
				if playerIndex != DEALER_INDEX
					@out.puts "Player #{playerIndex} drew a #{card}"
				end
			end
		end
	end

	# Executes game logic for player's moves
	def makeMoves # fix this
		@players.each.with_index do |player,i|
			(0..player.numHands-1).each do |handIndex|
				makeMove(player, handIndex, i)
			end
		end
	end

	# Prompt's PLAYER for his/her moves for HANDINDEX and executes the game
	# logic associated with the player's moves. Uses PLAYERINDEX in the
	# commentary to the current @out.
	def makeMove(player, handIndex, playerIndex)
		doubled, promptSplit = false, false
		loop do
			move = player.getMove(playerIndex, handIndex)
			#puts "move is #{move}"
			case move
			when 'hit'
				shouldBreak = hit(player, handIndex, doubled)
				if shouldBreak
					break
				end
			when 'split'
				promptSplit = player.split(handIndex)
			when 'quit'
				@playing = false
				return
			when 'double down'
				doubled = player.doubleDown(handIndex)
				if doubled
					hit(player, handIndex, doubled)
					break
				end
			when 'stay'
				if promptSplit
					handIndex = player.numHands - 1
					promptSplit = false
				end
				break
			else
				puts 'Please enter a valid command'
				break
			end
		end
	end

	# Gives PLAYER'S hand located at HANDINDEX a card. Returns true
	# if after this hit the player should stop being prompted for more
	# moves with this hand. Returns false otherwise.
	def hit(player, handIndex, doubled)
		card = @deck.getNextCard
		player.dealCard(card, handIndex)
		if doubled or player.isBusted(handIndex)
			return true
		end
		return false
	end

	# Gets bets back / gives out money to all players based on dealerScore
	def collectBets(dealerScore)
		@players.each.with_index do |player, i|
			if i != DEALER_INDEX
				player.collectBets(dealerScore, i, dealer.blackjack)
			else
				@out.puts "The dealer's hand was #{player.getHand(0).to_s}"
				player.clearHand
			end
		end
	end

	# returns the dealer
	def dealer
		return @players[DEALER_INDEX]
	end

	# Calls all methods necessary for the game to actually run
	def play
		loop do
			getBets
			dealInitialCards
			makeMoves
			if not @playing
				break
			end
			dealerScore = @players[DEALER_INDEX].value
			collectBets(dealerScore)
		end
		@out.puts "Thank you for playing."
	end
end

if __FILE__ == $0
	puts "Welcome to blackjack. Everyone starts with $1000."
	puts "You can decide to end the game at any time by typing 'quit' rather than chosing a move when prompted for one."
	puts "How many players are interested in playing?"
	response = 0
	loop do
		response = gets.chomp
		if /\d/.match(response)
			break
		end
		puts "Please enter a valid number."
	end
	t = Table.new(response.to_i)
	t.play
end