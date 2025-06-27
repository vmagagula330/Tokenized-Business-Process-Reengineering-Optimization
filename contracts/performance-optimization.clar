;; Performance Optimization Contract
;; Optimizes and monitors process performance

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-METRIC-NOT-FOUND (err u501))
(define-constant ERR-OPTIMIZATION-NOT-FOUND (err u502))

;; Data Variables
(define-data-var next-metric-id uint u1)
(define-data-var next-optimization-id uint u1)

;; Data Maps
(define-map performance-metrics
  { metric-id: uint }
  {
    process-id: uint,
    metric-name: (string-ascii 50),
    baseline-value: uint,
    current-value: uint,
    target-value: uint,
    measurement-unit: (string-ascii 20),
    recorded-by: principal,
    last-updated: uint
  }
)

(define-map optimizations
  { optimization-id: uint }
  {
    process-id: uint,
    optimization-type: (string-ascii 50),
    description: (string-ascii 300),
    expected-impact: uint,
    actual-impact: (optional uint),
    implemented-by: principal,
    implementation-date: uint,
    status: (string-ascii 20)
  }
)

(define-map metric-history
  { metric-id: uint, timestamp: uint }
  {
    value: uint,
    recorded-by: principal
  }
)

;; Public Functions
(define-public (create-performance-metric
  (process-id uint)
  (metric-name (string-ascii 50))
  (baseline-value uint)
  (target-value uint)
  (measurement-unit (string-ascii 20))
)
  (let
    (
      (metric-id (var-get next-metric-id))
      (caller tx-sender)
    )

    (map-set performance-metrics
      { metric-id: metric-id }
      {
        process-id: process-id,
        metric-name: metric-name,
        baseline-value: baseline-value,
        current-value: baseline-value,
        target-value: target-value,
        measurement-unit: measurement-unit,
        recorded-by: caller,
        last-updated: block-height
      }
    )

    (map-set metric-history
      { metric-id: metric-id, timestamp: block-height }
      {
        value: baseline-value,
        recorded-by: caller
      }
    )

    (var-set next-metric-id (+ metric-id u1))
    (ok metric-id)
  )
)

(define-public (update-metric-value (metric-id uint) (new-value uint))
  (let
    (
      (metric (unwrap! (map-get? performance-metrics { metric-id: metric-id }) ERR-METRIC-NOT-FOUND))
      (caller tx-sender)
    )

    (map-set performance-metrics
      { metric-id: metric-id }
      (merge metric {
        current-value: new-value,
        last-updated: block-height
      })
    )

    (map-set metric-history
      { metric-id: metric-id, timestamp: block-height }
      {
        value: new-value,
        recorded-by: caller
      }
    )

    (ok true)
  )
)

(define-public (create-optimization
  (process-id uint)
  (optimization-type (string-ascii 50))
  (description (string-ascii 300))
  (expected-impact uint)
)
  (let
    (
      (optimization-id (var-get next-optimization-id))
      (caller tx-sender)
    )

    (map-set optimizations
      { optimization-id: optimization-id }
      {
        process-id: process-id,
        optimization-type: optimization-type,
        description: description,
        expected-impact: expected-impact,
        actual-impact: none,
        implemented-by: caller,
        implementation-date: block-height,
        status: "planned"
      }
    )

    (var-set next-optimization-id (+ optimization-id u1))
    (ok optimization-id)
  )
)

(define-public (update-optimization-impact (optimization-id uint) (actual-impact uint))
  (let
    (
      (optimization (unwrap! (map-get? optimizations { optimization-id: optimization-id }) ERR-OPTIMIZATION-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get implemented-by optimization)) ERR-NOT-AUTHORIZED)

    (map-set optimizations
      { optimization-id: optimization-id }
      (merge optimization {
        actual-impact: (some actual-impact),
        status: "completed"
      })
    )
    (ok true)
  )
)

(define-public (update-optimization-status (optimization-id uint) (new-status (string-ascii 20)))
  (let
    (
      (optimization (unwrap! (map-get? optimizations { optimization-id: optimization-id }) ERR-OPTIMIZATION-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get implemented-by optimization)) ERR-NOT-AUTHORIZED)

    (map-set optimizations
      { optimization-id: optimization-id }
      (merge optimization { status: new-status })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-performance-metric (metric-id uint))
  (map-get? performance-metrics { metric-id: metric-id })
)

(define-read-only (get-optimization (optimization-id uint))
  (map-get? optimizations { optimization-id: optimization-id })
)

(define-read-only (get-metric-history (metric-id uint) (timestamp uint))
  (map-get? metric-history { metric-id: metric-id, timestamp: timestamp })
)

(define-read-only (calculate-improvement-percentage (metric-id uint))
  (match (map-get? performance-metrics { metric-id: metric-id })
    metric
    (let
      (
        (baseline (get baseline-value metric))
        (current (get current-value metric))
      )
      (if (> baseline u0)
        (some (/ (* (- current baseline) u100) baseline))
        none
      )
    )
    none
  )
)

(define-read-only (get-next-metric-id)
  (var-get next-metric-id)
)

(define-read-only (get-next-optimization-id)
  (var-get next-optimization-id)
)
