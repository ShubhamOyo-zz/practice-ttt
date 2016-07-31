class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception


  def handle_move
    board = Board.setup_with_current_state(get_current_state)
    Board.flush(board)
    next_move, score, nth_step = board.get_best_move_and_score
    status = Board.setup_with_current_state(next_move).won ? 'Won' : Board.setup_with_current_state(next_move).draw ? 'Draw' : 'Game On!'
    render :json => {given_move: vv(board.game_board), suggested_move: vv(next_move), delta: board.delta(next_move), status: status}
  end

  def vv(str)
    arr = []
    str.each {|i|
      a = ""
      i.each {|el|
      a += (el.nil? ? '- ' : (el ? '1 ' : 'O ') )
      }
      arr << a
    }
    arr
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

    TOTAL_MOVES_TO_CHECK_COMPUTATIONS = 2000

    @@moves_and_scores = {}
    @@max_allowed_steps = nil #toggle to make the game unbeatable or efficient
    @game_board = nil

    def self.flush(board)
      @@moves_and_scores={}
      @@max_allowed_steps = board.allowed_steps
    end

    def game_board=(board) ; @game_board=board ; end
    def game_board ; @game_board ; end

    def self.setup_with_current_state(current_state)
      new_board = new()
      new_board.game_board = current_state
      new_board
    end

    def get_best_move_and_score(player_turn=false, nth_step = 1)
      return [nil, score, nth_step] if game_ended?
      return [nil, 0, nth_step] if (nth_step > @@max_allowed_steps)
      nth_step += 1
      possible_move_scores = {}
      all_moves = get_all_possible_moves(player_turn)
      all_moves.each {|move|
        score = get_move_score_if_needed(move, player_turn, nth_step)
        possible_move_scores[move] = score
        break if (score[0] ==( 10 * (player_turn ? -1 : 1)))
      }
      best_move, scores = possible_move_scores.max_by {|move, score| (score[0]/score[1]) * (player_turn ? -1 : 1) }
      [best_move, scores[0], scores[1]]
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

    def get_move_score_if_needed(move, player_turn, nth_step)
      move, @@moves_and_scores[move], nth_step = Board.setup_with_current_state(move).get_best_move_and_score(!player_turn, nth_step) if @@moves_and_scores[move].blank?
      [@@moves_and_scores[move], nth_step]
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

    def delta(board)
      @game_board.each_with_index {|row, r_ind|
        @game_board.each_with_index {|el, c_ind|
          return [r_ind, c_ind] if @game_board[r_ind][c_ind] != board[r_ind][c_ind]
        }
      }
    end

    def allowed_steps
      Math.log(TOTAL_MOVES_TO_CHECK_COMPUTATIONS, game_board.length**2).round
    end
  end

end
