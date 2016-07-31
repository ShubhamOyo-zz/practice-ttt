class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  
  def handle_move
    Board.flush
    board = Board.setup_with_current_state(get_current_state)
    next_move, score = board.get_best_move_and_score(player_turn = false)
    status = Board.setup_with_current_state(next_move).won ? 'Won' : Board.setup_with_current_state(next_move).draw ? 'Draw' : 'Game On!'
    render :json => {given_move: board.game_board, suggested_move: next_move, status: status}
  end

  private

  def get_current_state
    current_state = params[:current_state].split(',').map(&:strip)
    length = Math.sqrt(current_state.length).to_i
    board = [] ; length.times { board << Array.new(length) }
    current_state.each_with_index {|val, index| board[index/length][index%length] = (val=='1' ? true : (val=='0' ? false : nil)) }
    board
  end

  class Board

    @@moves_and_scores = {}
    @game_board = nil

    def self.flush ; @@moves_and_scores={} ; end
    def game_board=(board) ; @game_board=board ; end
    def game_board ; @game_board ; end

    def self.setup_with_current_state(current_state)
      new_board = new()
      new_board.game_board = current_state
      new_board
    end

    def get_best_move_and_score(player_turn)
      return [nil, score] if game_ended?
      possible_move_scores = {}
      all_moves = get_all_possible_moves(player_turn)
      all_moves.each {|move| next_move, possible_move_scores[move] = get_move_score_if_needed(move, player_turn)}
      possible_move_scores.max_by {|move, score| score * (player_turn ? -1 : 1) }
    end

    def game_ended?
      (won or lost or draw)
    end

    def score
      won ? 10 : (lost ? -10 : 0)
    end

    def get_all_possible_moves(player_turn)
      all_moves = []
      @game_board.each_with_index { |row, row_index|
        row.each_with_index { |el, col_index|
          if el.nil?
            new_board = @game_board.deep_dup
            new_board[row_index][col_index] = !player_turn
            all_moves << new_board
          end
        }
      }
      all_moves
    end

    def get_move_score_if_needed(move, player_turn)
      @@moves_and_scores[move] = Board.setup_with_current_state(move).get_best_move_and_score(!player_turn) if @@moves_and_scores[move].blank?
      @@moves_and_scores[move]
    end

    def won
      @game_board.each {|row| return true if (row.uniq == [true]) }
      @game_board.length.times {|i| return true if (@game_board.inject([]) {|arr, row| arr << row[i]}).uniq == [true] }
      diag_arr = [] ; @game_board.length.times {|i| diag_arr << @game_board[i][i]} ; return true if (diag_arr.uniq == [true])
      reverse_diag_arr = [] ; @game_board.length.times {|i| reverse_diag_arr << @game_board[i][@game_board.length-i-1]} ; return true if (reverse_diag_arr.uniq == [true])
      return false
    end

    def lost
      @game_board.each {|row| return true if (row.uniq == [false]) }
      @game_board.length.times {|i| return true if (@game_board.inject([]) {|arr, row| arr << row[i]}).uniq == [false] }
      diag_arr = [] ; @game_board.length.times {|i| diag_arr << @game_board[i][i]} ; return true if (diag_arr.uniq == [false])
      reverse_diag_arr = [] ; @game_board.length.times {|i| reverse_diag_arr << @game_board[i][@game_board.length-i-1]} ; return true if (reverse_diag_arr.uniq == [false])
      return false
    end

    def draw
      @game_board.each {|row| return false if row.include? nil}
      return true
    end

  end

end
