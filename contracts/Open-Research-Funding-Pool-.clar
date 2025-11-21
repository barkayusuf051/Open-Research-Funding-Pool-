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
(define-constant ERR_CATEGORY_NOT_FOUND (err u417))
(define-constant ERR_CATEGORY_ALREADY_EXISTS (err u418))
(define-constant ERR_INSUFFICIENT_CATEGORY_FUNDS (err u419))
(define-constant ERR_EXCEEDS_CATEGORY_MAX_AMOUNT (err u420))
(define-constant ERR_INVALID_CATEGORY_ALLOCATION (err u421))
(define-constant ERR_AMENDMENT_NOT_FOUND (err u422))
(define-constant ERR_AMENDMENT_VOTING_ENDED (err u423))
(define-constant ERR_AMENDMENT_ALREADY_APPLIED (err u424))
(define-constant ERR_CANNOT_AMEND_PROPOSAL (err u425))
(define-constant ERR_AMENDMENT_ALREADY_VOTED (err u426))

(define-data-var next-proposal-id uint u1)
(define-data-var treasury-balance uint u0)
(define-data-var voting-period uint u1000)
(define-data-var min-quorum uint u10)
(define-data-var dispute-voting-period uint u500)
(define-data-var next-dispute-id uint u1)
(define-data-var category-counter uint u1)
(define-data-var total-category-allocations uint u0)
(define-data-var default-category-id uint u1)
(define-data-var next-amendment-id uint u1)
(define-data-var amendment-voting-period uint u200)

(define-map research-categories
  uint
  {
    name: (string-ascii 50),
    allocated-funds: uint,
    max-proposal-amount: uint,
    min-quorum: uint,
    active: bool,
    created-at: uint
  }
)

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
    created-at: uint,
    category-id: uint
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

(define-map proposal-amendments
  uint
  {
    proposal-id: uint,
    proposer: principal,
    new-title: (optional (string-ascii 100)),
    new-description: (optional (string-ascii 500)),
    new-funding-amount: (optional uint),
    new-milestones: (optional uint),
    votes-for: uint,
    votes-against: uint,
    voting-ends: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map amendment-votes
  { amendment-id: uint, voter: principal }
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

(define-public (create-research-category 
  (name (string-ascii 50))
  (allocated-funds uint)
  (max-proposal-amount uint)
  (category-quorum uint)
)
  (let
    (
      (category-id (var-get category-counter))
      (current-height stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> allocated-funds u0) ERR_INVALID_CATEGORY_ALLOCATION)
    (asserts! (> max-proposal-amount u0) ERR_INVALID_CATEGORY_ALLOCATION)
    (asserts! (> category-quorum u0) ERR_INVALID_CATEGORY_ALLOCATION)
    
    (map-set research-categories category-id
      {
        name: name,
        allocated-funds: allocated-funds,
        max-proposal-amount: max-proposal-amount,
        min-quorum: category-quorum,
        active: true,
        created-at: current-height
      }
    )
    (var-set category-counter (+ category-id u1))
    (var-set total-category-allocations (+ (var-get total-category-allocations) allocated-funds))
    (ok category-id)
  )
)

(define-public (allocate-category-funds (category-id uint) (amount uint))
  (let
    (
      (category (unwrap! (map-get? research-categories category-id) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get active category) ERR_CATEGORY_NOT_FOUND)
    (asserts! (> amount u0) ERR_INVALID_CATEGORY_ALLOCATION)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set research-categories category-id
      (merge category { 
        allocated-funds: (+ (get allocated-funds category) amount)
      })
    )
    (var-set total-category-allocations (+ (var-get total-category-allocations) amount))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (ok amount)
  )
)

(define-public (update-category-allocation 
  (category-id uint) 
  (max-proposal-amount uint)
  (category-quorum uint)
)
  (let
    (
      (category (unwrap! (map-get? research-categories category-id) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get active category) ERR_CATEGORY_NOT_FOUND)
    (asserts! (> max-proposal-amount u0) ERR_INVALID_CATEGORY_ALLOCATION)
    (asserts! (> category-quorum u0) ERR_INVALID_CATEGORY_ALLOCATION)
    
    (map-set research-categories category-id
      (merge category { 
        max-proposal-amount: max-proposal-amount,
        min-quorum: category-quorum
      })
    )
    (ok true)
  )
)

(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (funding-amount uint)
  (milestones uint)
  (category-id uint)
)
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (current-height stacks-block-height)
      (category (unwrap! (map-get? research-categories category-id) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (> milestones u0) ERR_INVALID_MILESTONE)
    (asserts! (> funding-amount u0) ERR_INSUFFICIENT_FUNDS)
    (asserts! (get active category) ERR_CATEGORY_NOT_FOUND)
    (asserts! (<= funding-amount (get max-proposal-amount category)) ERR_EXCEEDS_CATEGORY_MAX_AMOUNT)
    (asserts! (<= funding-amount (get allocated-funds category)) ERR_INSUFFICIENT_CATEGORY_FUNDS)
    
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
        created-at: current-height,
        category-id: category-id
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
      (category (unwrap! (map-get? research-categories (get category-id proposal)) ERR_CATEGORY_NOT_FOUND))
      (required-quorum (get min-quorum category))
    )
    (asserts! (>= current-height (get voting-ends proposal)) ERR_VOTING_NOT_ENDED)
    (asserts! (is-eq (get status proposal) "voting") ERR_VOTING_ENDED)
    (asserts! (>= total-votes required-quorum) ERR_INSUFFICIENT_FUNDS)
    
    (if (> (get votes-for proposal) (get votes-against proposal))
      (begin
        (map-set proposals proposal-id
          (merge proposal { status: "approved" })
        )
        (map-set research-categories (get category-id proposal)
          (merge category {
            allocated-funds: (- (get allocated-funds category) (get funding-amount proposal))
          })
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

(define-read-only (get-category-info (category-id uint))
  (map-get? research-categories category-id)
)

(define-read-only (get-category-available-funds (category-id uint))
  (match (map-get? research-categories category-id)
    category (ok (get allocated-funds category))
    ERR_CATEGORY_NOT_FOUND
  )
)

(define-read-only (get-category-counter)
  (var-get category-counter)
)

(define-read-only (get-total-category-allocations)
  (var-get total-category-allocations)
)

(define-read-only (get-default-category-id)
  (var-get default-category-id)
)

(define-public (propose-amendment
  (proposal-id uint)
  (new-title (optional (string-ascii 100)))
  (new-description (optional (string-ascii 500)))
  (new-funding-amount (optional uint))
  (new-milestones (optional uint))
)
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (amendment-id (var-get next-amendment-id))
      (current-height stacks-block-height)
      (category (unwrap! (map-get? research-categories (get category-id proposal)) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get researcher proposal)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "voting") ERR_CANNOT_AMEND_PROPOSAL)
    (asserts! (< current-height (get voting-ends proposal)) ERR_VOTING_ENDED)
    (asserts! 
      (or 
        (is-some new-title) 
        (is-some new-description) 
        (is-some new-funding-amount) 
        (is-some new-milestones)
      ) 
      ERR_INVALID_MILESTONE
    )
    (match new-funding-amount
      amount (asserts! (<= amount (get max-proposal-amount category)) ERR_EXCEEDS_CATEGORY_MAX_AMOUNT)
      true
    )
    
    (map-set proposal-amendments amendment-id
      {
        proposal-id: proposal-id,
        proposer: tx-sender,
        new-title: new-title,
        new-description: new-description,
        new-funding-amount: new-funding-amount,
        new-milestones: new-milestones,
        votes-for: u0,
        votes-against: u0,
        voting-ends: (+ current-height (var-get amendment-voting-period)),
        status: "voting",
        created-at: current-height
      }
    )
    (var-set next-amendment-id (+ amendment-id u1))
    (ok amendment-id)
  )
)

(define-public (vote-on-amendment (amendment-id uint) (support bool))
  (let
    (
      (amendment (unwrap! (map-get? proposal-amendments amendment-id) ERR_AMENDMENT_NOT_FOUND))
      (proposal (unwrap! (map-get? proposals (get proposal-id amendment)) ERR_PROPOSAL_NOT_FOUND))
      (voter-weight (default-to u1 (map-get? voter-weights tx-sender)))
      (current-height stacks-block-height)
      (existing-vote (map-get? amendment-votes { amendment-id: amendment-id, voter: tx-sender }))
    )
    (asserts! (< current-height (get voting-ends amendment)) ERR_AMENDMENT_VOTING_ENDED)
    (asserts! (is-eq (get status amendment) "voting") ERR_AMENDMENT_VOTING_ENDED)
    (asserts! (is-none existing-vote) ERR_AMENDMENT_ALREADY_VOTED)
    (asserts! (is-eq (get status proposal) "voting") ERR_CANNOT_AMEND_PROPOSAL)
    
    (map-set amendment-votes { amendment-id: amendment-id, voter: tx-sender }
      { vote: support, amount: voter-weight }
    )
    (if support
      (map-set proposal-amendments amendment-id
        (merge amendment { votes-for: (+ (get votes-for amendment) voter-weight) })
      )
      (map-set proposal-amendments amendment-id
        (merge amendment { votes-against: (+ (get votes-against amendment) voter-weight) })
      )
    )
    (ok true)
  )
)

(define-public (apply-amendment (amendment-id uint))
  (let
    (
      (amendment (unwrap! (map-get? proposal-amendments amendment-id) ERR_AMENDMENT_NOT_FOUND))
      (proposal-id (get proposal-id amendment))
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (current-height stacks-block-height)
      (total-votes (+ (get votes-for amendment) (get votes-against amendment)))
      (category (unwrap! (map-get? research-categories (get category-id proposal)) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (>= current-height (get voting-ends amendment)) ERR_VOTING_NOT_ENDED)
    (asserts! (is-eq (get status amendment) "voting") ERR_AMENDMENT_ALREADY_APPLIED)
    (asserts! (is-eq (get status proposal) "voting") ERR_CANNOT_AMEND_PROPOSAL)
    (asserts! (>= total-votes (get min-quorum category)) ERR_INSUFFICIENT_FUNDS)
    
    (if (> (get votes-for amendment) (get votes-against amendment))
      (begin
        (map-set proposals proposal-id
          (merge proposal {
            title: (default-to (get title proposal) (get new-title amendment)),
            description: (default-to (get description proposal) (get new-description amendment)),
            funding-amount: (default-to (get funding-amount proposal) (get new-funding-amount amendment)),
            milestones: (default-to (get milestones proposal) (get new-milestones amendment))
          })
        )
        (map-set proposal-amendments amendment-id
          (merge amendment { status: "applied" })
        )
        (ok "amendment-applied")
      )
      (begin
        (map-set proposal-amendments amendment-id
          (merge amendment { status: "rejected" })
        )
        (ok "amendment-rejected")
      )
    )
  )
)

(define-public (set-amendment-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_MILESTONE)
    (var-set amendment-voting-period new-period)
    (ok new-period)
  )
)

(define-read-only (get-amendment (amendment-id uint))
  (map-get? proposal-amendments amendment-id)
)

(define-read-only (get-amendment-vote (amendment-id uint) (voter principal))
  (map-get? amendment-votes { amendment-id: amendment-id, voter: voter })
)

(define-read-only (get-next-amendment-id)
  (var-get next-amendment-id)
)

(define-read-only (get-amendment-voting-period)
  (var-get amendment-voting-period)
)
