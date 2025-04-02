;; Continuing Education Contract
;; Tracks required ongoing training

(define-data-var admin principal tx-sender)

;; CE requirements by profession
(define-map ce-requirements
  { profession: (string-ascii 64) }
  {
    hours-required: uint,
    validity-period: uint  ;; in blocks (approximately days)
  }
)

;; CE credits earned by professionals
(define-map ce-credits
  { professional-id: principal, credit-id: (string-ascii 36) }
  {
    profession: (string-ascii 64),
    hours: uint,
    title: (string-ascii 100),
    provider: (string-ascii 100),
    completion-date: uint,
    verified: bool
  }
)

;; Track total CE hours by professional and profession
(define-map ce-hours-total
  { professional-id: principal, profession: (string-ascii 64) }
  { total-hours: uint }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (var-set admin new-admin))
  )
)

;; Set CE requirements for a profession
(define-public (set-ce-requirements
    (profession (string-ascii 64))
    (hours-required uint)
    (validity-period uint)
  )
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (ok (map-set ce-requirements
      { profession: profession }
      {
        hours-required: hours-required,
        validity-period: validity-period
      }
    ))
  )
)

;; Add CE credits (by professional)
(define-public (add-ce-credit
    (credit-id (string-ascii 36))
    (profession (string-ascii 64))
    (hours uint)
    (title (string-ascii 100))
    (provider (string-ascii 100))
    (completion-date uint)
  )
  (let (
    (professional-id tx-sender)
  )
    (asserts! (is-none (map-get? ce-credits {professional-id: professional-id, credit-id: credit-id}))
              (err ERR_ALREADY_EXISTS))

    ;; Add CE credit
    (map-set ce-credits
      {professional-id: professional-id, credit-id: credit-id}
      {
        profession: profession,
        hours: hours,
        title: title,
        provider: provider,
        completion-date: completion-date,
        verified: false
      }
    )

    ;; Update total hours (unverified)
    (ok true)
  )
)

;; Verify CE credit (by admin)
(define-public (verify-ce-credit
    (professional-id principal)
    (credit-id (string-ascii 36))
  )
  (let (
    (credit (map-get? ce-credits {professional-id: professional-id, credit-id: credit-id}))
  )
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-some credit) (err ERR_NOT_FOUND))

    ;; Mark credit as verified
    (map-set ce-credits
      {professional-id: professional-id, credit-id: credit-id}
      (merge (unwrap-panic credit) {verified: true})
    )

    ;; Update total verified hours
    (let (
      (profession (get profession (unwrap-panic credit)))
      (hours (get hours (unwrap-panic credit)))
      (current-total (default-to {total-hours: u0}
                      (map-get? ce-hours-total
                                {professional-id: professional-id, profession: profession})))
    )
      (map-set ce-hours-total
        {professional-id: professional-id, profession: profession}
        {total-hours: (+ (get total-hours current-total) hours)}
      )

      (ok true)
    )
  )
)

;; Get CE requirements for a profession
(define-read-only (get-ce-requirements (profession (string-ascii 64)))
  (map-get? ce-requirements {profession: profession})
)

;; Get CE credits for a professional
(define-read-only (get-ce-credits (professional-id principal))
  ;; In a real implementation, you would need pagination
  ;; This is a simplified version
  (ok {professional-id: professional-id})
)

;; Check if professional meets CE requirements
(define-read-only (check-ce-compliance (professional-id principal) (profession (string-ascii 64)))
  (let (
    (requirements (map-get? ce-requirements {profession: profession}))
    (total-hours (map-get? ce-hours-total {professional-id: professional-id, profession: profession}))
  )
    (if (and (is-some requirements) (is-some total-hours))
      (ok (>= (get total-hours (unwrap-panic total-hours))
              (get hours-required (unwrap-panic requirements))))
      (ok false)
    )
  )
)

