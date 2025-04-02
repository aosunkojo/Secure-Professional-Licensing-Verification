;; License Issuance Contract
;; Records professional qualifications and approvals

(define-data-var admin principal tx-sender)

;; License data structure
(define-map licenses
  { license-id: (string-ascii 36) }
  {
    professional-id: principal,
    profession: (string-ascii 64),
    issue-date: uint,
    expiry-date: uint,
    status: (string-ascii 20)
  }
)

;; Professional data structure
(define-map professionals
  { professional-id: principal }
  {
    name: (string-ascii 64),
    email: (string-ascii 64),
    licenses: (list 10 (string-ascii 36))
  }
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

;; Issue a new license
(define-public (issue-license
    (license-id (string-ascii 36))
    (professional-id principal)
    (profession (string-ascii 64))
    (issue-date uint)
    (expiry-date uint)
  )
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? licenses {license-id: license-id})) (err ERR_ALREADY_EXISTS))

    ;; Add license
    (map-set licenses
      {license-id: license-id}
      {
        professional-id: professional-id,
        profession: profession,
        issue-date: issue-date,
        expiry-date: expiry-date,
        status: "active"
      }
    )

    ;; Update professional's licenses
    (match (map-get? professionals {professional-id: professional-id})
      existing-professional (map-set professionals
        {professional-id: professional-id}
        (merge existing-professional
          {licenses: (unwrap! (as-max-len?
                                (append (get licenses existing-professional) license-id)
                                u10)
                              (err u4))}
        )
      )
      ;; If professional doesn't exist yet, create new entry
      (map-set professionals
        {professional-id: professional-id}
        {
          name: "",
          email: "",
          licenses: (list license-id)
        }
      )
    )

    (ok true)
  )
)

;; Get license details
(define-read-only (get-license (license-id (string-ascii 36)))
  (map-get? licenses {license-id: license-id})
)

;; Get professional details
(define-read-only (get-professional (professional-id principal))
  (map-get? professionals {professional-id: professional-id})
)

;; Update professional information
(define-public (update-professional-info
    (name (string-ascii 64))
    (email (string-ascii 64))
  )
  (let (
    (professional-id tx-sender)
    (existing-professional (map-get? professionals {professional-id: professional-id}))
  )
    (asserts! (is-some existing-professional) (err ERR_NOT_FOUND))
    (ok (map-set professionals
      {professional-id: professional-id}
      (merge (unwrap-panic existing-professional)
        {
          name: name,
          email: email
        }
      )
    ))
  )
)

