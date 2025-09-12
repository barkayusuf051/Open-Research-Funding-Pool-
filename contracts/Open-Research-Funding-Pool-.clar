(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u404))
(define-constant ERR_VOTING_ENDED (err u405))
(define-constant ERR_INSUFFICIENT_FUNDS (err u406))
(define-constant ERR_MILESTONE_NOT_FOUND (err u407))
(define-constant ERR_MILESTONE_ALREADY_PAID (err u408))
(define-constant ERR_VOTING_NOT_ENDED (err u409))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u410))
(define-constant ERR_INVALID_MILESTONE (err u411))
(define-constant ERR_ALREADY_VOTED (err u412))
(define-constant ERR_DISPUTE_NOT_FOUND (err u413))
(define-constant ERR_DISPUTE_ALREADY_EXISTS (err u414))
(define-constant ERR_DISPUTE_VOTING_ENDED (err u415))
(define-constant ERR_MILESTONE_NOT_DISPUTED (err u416))

(define-data-var next-proposal-id uint u1)
(define-data-var treasury-balance uint u0)
(define-data-var voting-period uint u1000)
(define-data-var min-quorum uint u10)
(define-data-var dispute-voting-period uint u500)
(define-data-var next-dispute-id uint u1)

(define-map proposals
  uint
  {
    researcher: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-amount: uint,
    milestones: uint,
    votes-for: uint,
    votes-against: uint,
    voting-ends: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, amount: uint }
)

(define-map proposal-milestones
  { proposal-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    funding-amount: uint,
    completed: bool,
    paid: bool,
    completed-at: uint
  }
)

(define-map voter-weights principal uint)

(define-map milestone-disputes
  uint
  {
    proposal-id: uint,
    milestone-id: uint,
    challenger: principal,
    reason: (string-ascii 300),
    votes-uphold: uint,
    votes-overturn: uint,
    voting-ends: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map dispute-votes
  { dispute-id: uint, voter: principal }
  { vote: bool, amount: uint }
)

(define-public (deposit-funds (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (ok amount)
  )
)

(define-public (set-voter-weight (voter principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set voter-weights voter weight))
  )
)

(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (funding-amount uint)
  (milestones uint)
)
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (current-height stacks-block-height)
    )
    (asserts! (> milestones u0) ERR_INVALID_MILESTONE)
    (asserts! (> funding-amount u0) ERR_INSUFFICIENT_FUNDS)
    
    (map-set proposals proposal-id
      {
        researcher: tx-sender,
        title: title,
        description: description,
        funding-amount: funding-amount,
        milestones: milestones,
        votes-for: u0,
        votes-against: u0,
        voting-ends: (+ current-height (var-get voting-period)),
        status: "voting",
        created-at: current-height
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (support bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (voter-weight (default-to u1 (map-get? voter-weights tx-sender)))
      (current-height stacks-block-height)
      (existing-vote (map-get? proposal-votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    (asserts! (< current-height (get voting-ends proposal)) ERR_VOTING_ENDED)
    (asserts! (is-eq (get status proposal) "voting") ERR_VOTING_ENDED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    
    (map-set proposal-votes { proposal-id: proposal-id, voter: tx-sender }
      { vote: support, amount: voter-weight }
    )
    (if support
      (map-set proposals proposal-id
        (merge proposal { votes-for: (+ (get votes-for proposal) voter-weight) })
      )
      (map-set proposals proposal-id
        (merge proposal { votes-against: (+ (get votes-against proposal) voter-weight) })
      )
    )
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (current-height stacks-block-height)
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
    )
    (asserts! (>= current-height (get voting-ends proposal)) ERR_VOTING_NOT_ENDED)
    (asserts! (is-eq (get status proposal) "voting") ERR_VOTING_ENDED)
    (asserts! (>= total-votes (var-get min-quorum)) ERR_INSUFFICIENT_FUNDS)
    
    (if (> (get votes-for proposal) (get votes-against proposal))
      (begin
        (map-set proposals proposal-id
          (merge proposal { status: "approved" })
        )
        (ok "approved")
      )
      (begin
        (map-set proposals proposal-id
          (merge proposal { status: "rejected" })
        )
        (ok "rejected")
      )
    )
  )
)

(define-public (create-milestone 
  (proposal-id uint) 
  (milestone-id uint) 
  (description (string-ascii 200))
  (funding-amount uint)
)
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get researcher proposal)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "approved") ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (<= milestone-id (get milestones proposal)) ERR_INVALID_MILESTONE)
    (asserts! (> funding-amount u0) ERR_INSUFFICIENT_FUNDS)
    
    (map-set proposal-milestones 
      { proposal-id: proposal-id, milestone-id: milestone-id }
      {
        description: description,
        funding-amount: funding-amount,
        completed: false,
        paid: false,
        completed-at: u0
      }
    )
    (ok true)
  )
)

(define-public (complete-milestone (proposal-id uint) (milestone-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (milestone (unwrap! (map-get? proposal-milestones { proposal-id: proposal-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (current-height stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get researcher proposal)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "approved") ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (not (get completed milestone)) ERR_MILESTONE_ALREADY_PAID)
    
    (map-set proposal-milestones 
      { proposal-id: proposal-id, milestone-id: milestone-id }
      (merge milestone { 
        completed: true, 
        completed-at: current-height 
      })
    )
    (ok true)
  )
)

(define-public (release-milestone-payment (proposal-id uint) (milestone-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (milestone (unwrap! (map-get? proposal-milestones { proposal-id: proposal-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (funding-amount (get funding-amount milestone))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get completed milestone) ERR_INVALID_MILESTONE)
    (asserts! (not (get paid milestone)) ERR_MILESTONE_ALREADY_PAID)
    (asserts! (>= (var-get treasury-balance) funding-amount) ERR_INSUFFICIENT_FUNDS)
    
    (try! (as-contract (stx-transfer? funding-amount tx-sender (get researcher proposal))))
    (var-set treasury-balance (- (var-get treasury-balance) funding-amount))
    
    (map-set proposal-milestones 
      { proposal-id: proposal-id, milestone-id: milestone-id }
      (merge milestone { paid: true })
    )
    (ok funding-amount)
  )
)

(define-public (cancel-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get researcher proposal)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "voting") ERR_VOTING_ENDED)
    
    (map-set proposals proposal-id
      (merge proposal { status: "cancelled" })
    )
    (ok true)
  )
)

(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_MILESTONE)
    (var-set voting-period new-period)
    (ok new-period)
  )
)

(define-public (set-min-quorum (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set min-quorum new-quorum)
    (ok new-quorum)
  )
)

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= (var-get treasury-balance) amount) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    (ok amount)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-milestone (proposal-id uint) (milestone-id uint))
  (map-get? proposal-milestones { proposal-id: proposal-id, milestone-id: milestone-id })
)

(define-read-only (get-treasury-balance)
  (var-get treasury-balance)
)

(define-read-only (get-voter-weight (voter principal))
  (default-to u1 (map-get? voter-weights voter))
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)

(define-read-only (get-voting-period)
  (var-get voting-period)
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (ok (get status proposal))
    ERR_PROPOSAL_NOT_FOUND
  )
)

(define-read-only (get-min-quorum)
  (var-get min-quorum)
)

(define-public (create-milestone-dispute 
  (proposal-id uint) 
  (milestone-id uint) 
  (reason (string-ascii 300))
)
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (milestone (unwrap! (map-get? proposal-milestones { proposal-id: proposal-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (dispute-id (var-get next-dispute-id))
      (current-height stacks-block-height)
      (voter-weight (default-to u1 (map-get? voter-weights tx-sender)))
    )
    (asserts! (get completed milestone) ERR_INVALID_MILESTONE)
    (asserts! (not (get paid milestone)) ERR_MILESTONE_ALREADY_PAID)
    (asserts! (>= voter-weight u1) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq tx-sender (get researcher proposal))) ERR_UNAUTHORIZED)
    
    (map-set milestone-disputes dispute-id
      {
        proposal-id: proposal-id,
        milestone-id: milestone-id,
        challenger: tx-sender,
        reason: reason,
        votes-uphold: u0,
        votes-overturn: u0,
        voting-ends: (+ current-height (var-get dispute-voting-period)),
        status: "voting",
        created-at: current-height
      }
    )
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (uphold-completion bool))
  (let
    (
      (dispute (unwrap! (map-get? milestone-disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (voter-weight (default-to u1 (map-get? voter-weights tx-sender)))
      (current-height stacks-block-height)
      (existing-vote (map-get? dispute-votes { dispute-id: dispute-id, voter: tx-sender }))
    )
    (asserts! (< current-height (get voting-ends dispute)) ERR_DISPUTE_VOTING_ENDED)
    (asserts! (is-eq (get status dispute) "voting") ERR_DISPUTE_VOTING_ENDED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    
    (map-set dispute-votes { dispute-id: dispute-id, voter: tx-sender }
      { vote: uphold-completion, amount: voter-weight }
    )
    (if uphold-completion
      (map-set milestone-disputes dispute-id
        (merge dispute { votes-uphold: (+ (get votes-uphold dispute) voter-weight) })
      )
      (map-set milestone-disputes dispute-id
        (merge dispute { votes-overturn: (+ (get votes-overturn dispute) voter-weight) })
      )
    )
    (ok true)
  )
)

(define-public (resolve-milestone-dispute (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? milestone-disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (current-height stacks-block-height)
      (total-votes (+ (get votes-uphold dispute) (get votes-overturn dispute)))
      (proposal-id (get proposal-id dispute))
      (milestone-id (get milestone-id dispute))
      (milestone (unwrap! (map-get? proposal-milestones { proposal-id: proposal-id, milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
    )
    (asserts! (>= current-height (get voting-ends dispute)) ERR_VOTING_NOT_ENDED)
    (asserts! (is-eq (get status dispute) "voting") ERR_DISPUTE_VOTING_ENDED)
    (asserts! (>= total-votes (var-get min-quorum)) ERR_INSUFFICIENT_FUNDS)
    
    (if (> (get votes-uphold dispute) (get votes-overturn dispute))
      (begin
        (map-set milestone-disputes dispute-id
          (merge dispute { status: "upheld" })
        )
        (ok "milestone-upheld")
      )
      (begin
        (map-set milestone-disputes dispute-id
          (merge dispute { status: "overturned" })
        )
        (map-set proposal-milestones 
          { proposal-id: proposal-id, milestone-id: milestone-id }
          (merge milestone { 
            completed: false,
            completed-at: u0
          })
        )
        (ok "milestone-overturned")
      )
    )
  )
)

(define-public (set-dispute-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_MILESTONE)
    (var-set dispute-voting-period new-period)
    (ok new-period)
  )
)

(define-read-only (get-milestone-dispute (dispute-id uint))
  (map-get? milestone-disputes dispute-id)
)

(define-read-only (get-dispute-vote (dispute-id uint) (voter principal))
  (map-get? dispute-votes { dispute-id: dispute-id, voter: voter })
)

(define-read-only (get-next-dispute-id)
  (var-get next-dispute-id)
)

(define-read-only (get-dispute-voting-period)
  (var-get dispute-voting-period)
)
