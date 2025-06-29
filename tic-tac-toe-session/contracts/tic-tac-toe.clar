;; to have a track of game crerated in the platform
(define-data-var latest-game-id uint u0)

(define-map games uint
  (tuple
    (player-one principal)
    (player-two (optional principal))
    (is-player-one-turn bool)
    (bet-amount uint)
    (board (list 9 uint))
    (winner (optional principal))
  )
)

(define-private (validate-move (board (list 9 uint)) (move-index uint) (move uint))
 (let (
    (index-in-range (and (>= move-index u0) (< move-index u9))) ;; if condition satisfied returns true else false
    (x-or-0 (or (is-eq move u0) (is-eq move u1))) ;; if move is 0 or 1
    (empty-spot (is-eq (unwrap! (element-at? board move-index) false) u0)) ;; check if the spot is empty
  )

(and (is-eq  index-in-range true)
  ( is-eq x-or-0 true)
   (is-eq empty-spot true)
  ))
 )


;; Creating some constants for the contract address itself and for error codes:
(define-constant THIS_CONTRACT (as-contract tx-sender)) ;; The address of this contract itself
(define-constant ERR_MIN_BET_AMOUNT u100) ;; Error thrown when a player tries to create a game with a bet amount less than the minimum (0.0001 STX)
(define-constant ERR_INVALID_MOVE u101) ;; Error thrown when a move is invalid, i.e. not within range of the board or not an X or an O
(define-constant ERR_GAME_NOT_FOUND u102) ;; Error thrown when a game cannot be found given a Game ID, i.e. invalid Game ID
(define-constant ERR_GAME_CANNOT_BE_JOINED u103) ;; Error thrown when a game cannot be joined, usually because it already has two players
(define-constant ERR_NOT_YOUR_TURN u104) ;; Error thrown when a player tries to make a move when it is not their turn






;; Creading a new game:
(define-public (create-game (bet-amount uint) (move-index uint) (move uint))
    (let (
        ;; Get the Game ID to use for creation of this new game
        (game-id (var-get latest-game-id)) ;; 0
        ;; The initial starting board for the game with all cells empty
        (starting-board (list u0 u0 u0 u0 u0 u0 u0 u0 u0))
        ;; Updated board with the starting move played by the game creator (X)
        (game-board (unwrap! (replace-at? starting-board move-index move) (err ERR_INVALID_MOVE)))

        ;; Create the game data tuple (player one address, bet amount, game board, and mark next turn to be player two's turn)
        (game-data {
            player-one: contract-caller, ;; here contract-collar is a global constant
            player-two: none,
            is-player-one-turn: false,
            bet-amount: bet-amount,
            board: game-board,
            winner: none
        })
    )
      ;; Ensure that user has put up a bet amount greater than the minimum
    (asserts! (> bet-amount u0) (err ERR_MIN_BET_AMOUNT)) ;; if true then move to next line , else will return the erro-code
    ;; Ensure that the move being played is an `X`, not an `O`
    (asserts! (is-eq move u1) (err ERR_INVALID_MOVE))
    ;; Ensure that the move meets validity requirements
    (asserts! (validate-move starting-board move-index move) (err ERR_INVALID_MOVE))

    ;; Transfer the bet amount STX from user to this contract
    (try! (stx-transfer? bet-amount contract-caller THIS_CONTRACT)) ;; uses try! to handle potential failure.
    ;; Update the games map with the new game data
    (map-set games game-id game-data)
    ;; Increment the Game ID counter
    (var-set latest-game-id (+ game-id u1))

    ;; Log the creation of the new game
    (print { action: "create-game", data: game-data})
    ;; Return the Game ID of the new game
    (ok game-id)
))







;; function to joing a game:
(define-public (join-game (game-id uint) (move-index uint) (move uint))
    (let (
        ;; Load the game data for the game being joined, throw an error if Game ID is invalid
        (original-game-data (unwrap! (map-get? games game-id) (err ERR_GAME_NOT_FOUND)))
        ;; Get the original board from the game data
        (original-board (get board original-game-data))

        ;; Update the game board by placing the player's move at the specified index
        (game-board (unwrap! (replace-at? original-board move-index move) (err ERR_INVALID_MOVE)))
        ;; Update the copy of the game data with the updated board and marking the next turn to be player two's turn
        (game-data (merge original-game-data {
            board: game-board,
            player-two: (some contract-caller), ;; In Clarity, some wraps a value in an optional type, creating (some value).
            is-player-one-turn: true
        }))
    )

;; Ensure that the game being joined is able to be joined
    ;; i.e. player-two is currently empty
    (asserts! (is-none (get player-two original-game-data)) (err ERR_GAME_CANNOT_BE_JOINED)) 
    ;; Ensure that the move being played is an `O`, not an `X`
    (asserts! (is-eq move u2) (err ERR_INVALID_MOVE))
    ;; Ensure that the move meets validity requirements
    (asserts! (validate-move original-board move-index move) (err ERR_INVALID_MOVE))

    ;; Transfer the bet amount STX from user to this contract
    (try! (stx-transfer? (get bet-amount original-game-data) contract-caller THIS_CONTRACT))
    ;; Update the games map with the new game data
    (map-set games game-id game-data)

    ;; Log the joining of the game
    (print { action: "join-game", data: game-data})
    ;; Return the Game ID of the game
    (ok game-id)
))




;; Given a board and three cells to look at on the board : 0-0-0 or x-x-x
;; Return true if all three are not empty and are the same value (all X or all O)
;; Return false if any of the three is empty or a different value

(define-private (is-line (board (list 9 uint)) (a uint) (b uint) (c uint)) 
    (let (
        (a-val (unwrap! (element-at? board a) false));; Value of cell at index a

        
        (b-val (unwrap! (element-at? board b) false)) ;; Value of cell at index b
        
        (c-val (unwrap! (element-at? board c) false));; Value of cell at index c
    )

    ;; a-val must equal b-val and must also equal c-val while not being empty (non-zero)
    (and (is-eq a-val b-val) (is-eq a-val c-val) (not (is-eq a-val u0)))
))


;; Given a board, return true if any possible three-in-a-row line has been completed
(define-private (has-won (board (list 9 uint))) 
    (or ;; if any position combination is in a line then it will return "true" and we can now know that someone is the winner.
        (is-line board u0 u1 u2) ;; Row 1
        (is-line board u3 u4 u5) ;; Row 2
        (is-line board u6 u7 u8) ;; Row 3
        (is-line board u0 u3 u6) ;; Column 1
        (is-line board u1 u4 u7) ;; Column 2
        (is-line board u2 u5 u8) ;; Column 3
        (is-line board u0 u4 u8) ;; Left to Right Diagonal
        (is-line board u2 u4 u6) ;; Right to Left Diagonal
    )
)







(define-public (play (game-id uint) (move-index uint) (move uint))
    (let (
        ;; Load the game data for the game being joined, throw an error if Game ID is invalid
        (original-game-data (unwrap! (map-get? games game-id) (err ERR_GAME_NOT_FOUND)))
        ;; Get the original board from the game data
        (original-board (get board original-game-data))

        ;; Is it player one's turn?
        (is-player-one-turn (get is-player-one-turn original-game-data))
        ;; Get the player whose turn it is(currently) based on the is-player-one-turn flag. If it's player-one turn then it will return player-one address else palyer-two address
        (player-turn (if is-player-one-turn (get player-one original-game-data) (unwrap! (get player-two original-game-data) (err ERR_GAME_NOT_FOUND))))
        ;; Get the expected move based on whose turn it is (X or O?)
        (expected-move (if is-player-one-turn u1 u2))

        ;; Update the game board by placing the player's move at the specified index
        (game-board (unwrap! (replace-at? original-board move-index move ) (err ERR_INVALID_MOVE)))
        ;; Check if the game has been won now with this modified board
        (is-now-winner (has-won game-board))
        ;; Merge the game data with the updated board and marking the next turn to be player two's turn
        ;; Also mark the winner if the game has been won
        (game-data (merge original-game-data {
            board: game-board,
            is-player-one-turn: (not is-player-one-turn), ;; will be false if player-one just played or called this "play" funtion
            winner: (if is-now-winner (some player-turn) none)
        }))
    )

    ;; Ensure that the function is being called by the player whose turn it is
    (asserts! (is-eq player-turn contract-caller) (err ERR_NOT_YOUR_TURN))
    ;; Ensure that the move being played is the correct move based on the current turn (X or O)
    (asserts! (is-eq move expected-move) (err ERR_INVALID_MOVE))
    ;; Ensure that the move meets validity requirements
    (asserts! (validate-move original-board move-index move) (err ERR_INVALID_MOVE))

    ;; if the game has been won, transfer the (bet amount * 2 = both players bets) STX to the winner. "as-contract" tells Clarity to Run the transfer as if its coming from the contract itself.
    (if is-now-winner (try! (as-contract (stx-transfer? (* u2 (get bet-amount game-data)) tx-sender player-turn))) false)

    ;; Update the games map with the new game data
    (map-set games game-id game-data)

    ;; Log the action of a move being made
    (print {action: "play", data: game-data})
    ;; Return the Game ID of the game
    (ok game-id)
))


(define-read-only (get-latest-game-id)
  (ok (var-get latest-game-id))
)
