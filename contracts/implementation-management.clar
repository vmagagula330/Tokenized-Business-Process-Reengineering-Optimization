;; Implementation Management Contract
;; Manages process implementation phases

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-IMPLEMENTATION-EXISTS (err u401))
(define-constant ERR-IMPLEMENTATION-NOT-FOUND (err u402))
(define-constant ERR-MILESTONE-NOT-FOUND (err u403))

;; Data Variables
(define-data-var next-implementation-id uint u1)

;; Data Maps
(define-map implementations
  { implementation-id: uint }
  {
    proposal-id: uint,
    manager: principal,
    start-date: uint,
    target-completion: uint,
    actual-completion: (optional uint),
    budget-allocated: uint,
    budget-used: uint,
    status: (string-ascii 20),
    progress-percentage: uint
  }
)

(define-map milestones
  { implementation-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    target-date: uint,
    completion-date: (optional uint),
    status: (string-ascii 20),
    budget-portion: uint
  }
)

(define-map milestone-count
  { implementation-id: uint }
  { count: uint }
)

;; Public Functions
(define-public (create-implementation
  (proposal-id uint)
  (manager principal)
  (start-date uint)
  (target-completion uint)
  (budget-allocated uint)
)
  (let
    (
      (implementation-id (var-get next-implementation-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set implementations
      { implementation-id: implementation-id }
      {
        proposal-id: proposal-id,
        manager: manager,
        start-date: start-date,
        target-completion: target-completion,
        actual-completion: none,
        budget-allocated: budget-allocated,
        budget-used: u0,
        status: "planning",
        progress-percentage: u0
      }
    )

    (map-set milestone-count
      { implementation-id: implementation-id }
      { count: u0 }
    )

    (var-set next-implementation-id (+ implementation-id u1))
    (ok implementation-id)
  )
)

(define-public (add-milestone
  (implementation-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (target-date uint)
  (budget-portion uint)
)
  (let
    (
      (implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR-IMPLEMENTATION-NOT-FOUND))
      (milestone-count-data (unwrap! (map-get? milestone-count { implementation-id: implementation-id }) ERR-IMPLEMENTATION-NOT-FOUND))
      (current-count (get count milestone-count-data))
      (new-milestone-id (+ current-count u1))
    )
    (asserts! (is-eq tx-sender (get manager implementation)) ERR-NOT-AUTHORIZED)

    (map-set milestones
      { implementation-id: implementation-id, milestone-id: new-milestone-id }
      {
        title: title,
        description: description,
        target-date: target-date,
        completion-date: none,
        status: "pending",
        budget-portion: budget-portion
      }
    )

    (map-set milestone-count
      { implementation-id: implementation-id }
      { count: new-milestone-id }
    )

    (ok new-milestone-id)
  )
)

(define-public (complete-milestone (implementation-id uint) (milestone-id uint))
  (let
    (
      (implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR-IMPLEMENTATION-NOT-FOUND))
      (milestone (unwrap! (map-get? milestones { implementation-id: implementation-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get manager implementation)) ERR-NOT-AUTHORIZED)

    (map-set milestones
      { implementation-id: implementation-id, milestone-id: milestone-id }
      (merge milestone {
        completion-date: (some block-height),
        status: "completed"
      })
    )
    (ok true)
  )
)

(define-public (update-progress (implementation-id uint) (progress-percentage uint) (budget-used uint))
  (let
    (
      (implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR-IMPLEMENTATION-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get manager implementation)) ERR-NOT-AUTHORIZED)

    (map-set implementations
      { implementation-id: implementation-id }
      (merge implementation {
        progress-percentage: progress-percentage,
        budget-used: budget-used
      })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-implementation (implementation-id uint))
  (map-get? implementations { implementation-id: implementation-id })
)

(define-read-only (get-milestone (implementation-id uint) (milestone-id uint))
  (map-get? milestones { implementation-id: implementation-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count (implementation-id uint))
  (map-get? milestone-count { implementation-id: implementation-id })
)

(define-read-only (get-next-implementation-id)
  (var-get next-implementation-id)
)
