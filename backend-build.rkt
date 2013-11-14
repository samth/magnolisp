#lang racket

#|

Routines for parsing and collecting 'build annotations, and generating
code for them.

|#

(require "compiler-util.rkt" "util.rkt" "util/order.rkt"
         data/order data/splay-tree)

;;; 
;;; parsing
;;; 

(define (valid-opt-name? s)
  (regexp-match? #rx"^[a-z][a-z0-9-]*$" s))

(define (valid-opt-value? v)
  (any-pred-holds boolean? exact-integer? string? symbol? v))

(define (opt-value-pred v)
  (ormap
   (lambda (p?)
     (and (p? v) p?))
   (list boolean? exact-integer? string? symbol?)))

(define (make-order-for-value v)
  (cond
   ((boolean? v) boolean-order)
   ((exact-integer? v) number-order)
   ((string? v) string-order)
   ((symbol? v) symbol-order)
   (else (assert #f))))

(define opt-value-set/c
  (cons/c predicate/c ordered-dict?))

(define opt-value/c
  (or/c valid-opt-value? opt-value-set/c))

;; The returned dictionary has Lispy, all lowercase strings as keys,
;; i.e., valid-opt-name? holds for the keys. The opt-value/c contract
;; holds for the values, which may be either atoms or sets of values.
;; Set elements are also ordered, and must all be of the same value
;; type.
(define-with-contract*
  (-> (listof (list/c identifier? syntax?))
      ordered-dict?)
  (parse-analyze-build-annos build-lst)
  
  (define h (make-splay-tree string-order
                             #:key-contract valid-opt-name?
                             #:value-contract opt-value/c))

  (define (to-name id-stx n-stx)
    (define s (symbol->string (syntax-e n-stx)))
    (unless (valid-opt-name? s)
      (raise-syntax-error
       #f
       (format "illegal build option name for definition ~a"
               (syntax-e id-stx))
       n-stx))
    s)

  (define (to-value id-stx n-stx v-stx)
    (define v (syntax->datum v-stx))
    (define p? (opt-value-pred v))
    (unless p?
      (raise-syntax-error
       #f
       (format "illegal value for build option ~a of definition ~a"
               (syntax-e n-stx) (syntax-e id-stx))
       v-stx))
    (values p? v))
  
  (define (set-value-opt! id-stx n-stx v-stx)
    (define n (to-name id-stx n-stx))
    (define-values (p? v) (to-value id-stx n-stx v-stx))
    (if (dict-has-key? h n)
        (let ()
          (define x-v (dict-ref h n))
          (unless (equal? x-v v)
            (error 'parse-analyze-build-annos
                   "conflicting redefinition of build option ~a for definition ~a (previously: ~s): ~s"
                   n (syntax-e id-stx) x-v v-stx)))
        (dict-set! h n v)))

  (define (set-set-opt! id-stx stx n-stx v-stx-lst)
    (assert (not (null? v-stx-lst)))
    (define n (to-name id-stx n-stx))
    (define-values (type-p? v-h)
      (if (dict-has-key? h n)
          (let ((p (dict-ref h n)))
            (define-values (type-p? v-h) (values (car p) (cdr p)))
            (unless (ordered-dict? v-h)
              (error 'parse-analyze-build-annos
                     "conflicting use of operator += with build option ~a for definition ~a (previously defined as non-set ~s): ~s"
                     n (syntax-e id-stx) v-h stx))
            (values type-p? v-h))
          (values #f #f)))
    (for ((v-stx v-stx-lst))
      (define-values (p? v) (to-value id-stx n-stx v-stx))
      (if type-p?
          (unless (type-p? v)
            (raise-syntax-error
             #f
             (format "type mismatch for definition ~a build option ~a value (expected ~a)" (syntax-e id-stx) n (object-name type-p?))
             stx v-stx))
          (set!-values
           (type-p? v-h)
           (values p? (make-splay-tree (make-order-for-value v)))))
      (dict-set! v-h v #t))
    (dict-set! h n (cons type-p? v-h)))

  (define (parse-opt! id-stx build-stx opt-stx)
    (syntax-case opt-stx ()
      (n
       (identifier? #'n)
       (set-value-opt! id-stx #'n #'#t))
      ((n v)
       (identifier? #'n)
       (set-value-opt! id-stx #'n #'v))
      ((p n v more-v ...)
       (and (eq? '+= (syntax-e #'p)) (identifier? #'n))
       (set-set-opt! id-stx opt-stx #'n
                     (syntax->list #'(v more-v ...))))
      (_
       (raise-language-error
        'build
        "illegal (build ...) annotation sub-form"
        build-stx
        opt-stx
        #:continued
        (format "(for declaration ~a)" (syntax-e id-stx))))))

  (define (parse-build! id-stx build-stx)
    (syntax-case build-stx ()
      ((_ . opt)
       (for-each
        (fix parse-opt! id-stx build-stx)
        (syntax->list #'opt)))
      (_
       (raise-language-error
        'build
        "illegal (build ...) annotation form"
        build-stx
        #:continued
        (format "(for declaration ~a)" (syntax-e id-stx))))))
  
  (for ((build build-lst))
    (define-values (id-stx build-stx) (apply values build))
    (parse-build! id-stx build-stx))
    
  h)

;;; 
;;; code generation
;;; 
