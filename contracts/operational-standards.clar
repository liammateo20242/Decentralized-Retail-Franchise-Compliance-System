;; Operational Standards Contract
;; Version: 1.0.0
;; This contract defines required business practices

(define-data-var contract-version uint u100)

;; Data maps
(define-map standards
  { standard-id: (string-utf8 36) }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    required: bool,
    category: (string-utf8 50),
    version: uint,
    created-at: uint,
    updated-at: uint
  }
)

(define-map franchisee-standards
  {
    franchisee-id: (string-utf8 36),
    standard-id: (string-utf8 36)
  }
  {
    compliant: bool,
    last-checked: uint,
    notes: (string-utf8 500)
  }
)

(define-map authorized-managers principal bool)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-ALREADY-EXISTS u409)
(define-constant ERR-NOT-FOUND u404)

;; Initialize contract owner
(define-data-var contract-owner principal tx-sender)

;; Public functions

;; Add a new standard
(define-public (add-standard
    (standard-id (string-utf8 36))
    (name (string-utf8 100))
    (description (string-utf8 500))
    (required bool)
    (category (string-utf8 50)))
  (let (
    (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
    (existing-standard (map-get? standards { standard-id: standard-id }))
    (current-block-height block-height)
  )
    (asserts! (or is-authorized (is-eq tx-sender (var-get contract-owner))) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none existing-standard) (err ERR-ALREADY-EXISTS))
    (ok (map-set standards
      { standard-id: standard-id }
      {
        name: name,
        description: description,
        required: required,
        category: category,
        version: u1,
        created-at: current-block-height,
        updated-at: current-block-height
      }))))

;; Update an existing standard
(define-public (update-standard
    (standard-id (string-utf8 36))
    (name (string-utf8 100))
    (description (string-utf8 500))
    (required bool)
    (category (string-utf8 50)))
  (let (
    (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
    (existing-standard (map-get? standards { standard-id: standard-id }))
    (current-block-height block-height)
  )
    (asserts! (or is-authorized (is-eq tx-sender (var-get contract-owner))) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some existing-standard) (err ERR-NOT-FOUND))
    (ok (map-set standards
      { standard-id: standard-id }
      (merge (unwrap-panic existing-standard)
        {
          name: name,
          description: description,
          required: required,
          category: category,
          version: (+ (get version (unwrap-panic existing-standard)) u1),
          updated-at: current-block-height
        })))))

;; Set franchisee compliance with a standard
(define-public (set-franchisee-compliance
    (franchisee-id (string-utf8 36))
    (standard-id (string-utf8 36))
    (compliant bool)
    (notes (string-utf8 500)))
  (let (
    (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
    (existing-standard (map-get? standards { standard-id: standard-id }))
    (current-block-height block-height)
  )
    (asserts! (or is-authorized (is-eq tx-sender (var-get contract-owner))) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some existing-standard) (err ERR-NOT-FOUND))
    (ok (map-set franchisee-standards
      {
        franchisee-id: franchisee-id,
        standard-id: standard-id
      }
      {
        compliant: compliant,
        last-checked: current-block-height,
        notes: notes
      }))))

;; Read-only functions

;; Get a standard by ID
(define-read-only (get-standard (standard-id (string-utf8 36)))
  (map-get? standards { standard-id: standard-id }))

;; Get franchisee compliance with a standard
(define-read-only (get-franchisee-compliance (franchisee-id (string-utf8 36)) (standard-id (string-utf8 36)))
  (map-get? franchisee-standards { franchisee-id: franchisee-id, standard-id: standard-id }))

;; Check if franchisee is compliant with a standard
(define-read-only (is-compliant (franchisee-id (string-utf8 36)) (standard-id (string-utf8 36)))
  (let ((compliance (map-get? franchisee-standards { franchisee-id: franchisee-id, standard-id: standard-id })))
    (if (is-some compliance)
      (get compliant (unwrap-panic compliance))
      false)))

;; Admin functions

;; Add an authorized manager
(define-public (add-authorized-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (map-set authorized-managers manager true))))

;; Remove an authorized manager
(define-public (remove-authorized-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (map-delete authorized-managers manager))))

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

;; Version control
(define-public (upgrade-version (new-version uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set contract-version new-version)
    (ok true)))

(define-read-only (get-version)
  (var-get contract-version))
