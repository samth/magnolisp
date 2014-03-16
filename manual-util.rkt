#lang racket

#|

Utilities for authoring manual.scrbl.

|#

(require "util.rkt" scribble/manual)

(begin ;; trick from Racket docs
  (define-syntax-rule (bind id-1 id-2)
    (begin
      (require (for-label racket/base))
      (define* id-1 (racket do))
      (define* id-2 (racket #%module-begin))))
  (bind racket-do racket-module-begin))

(define* (warning . str)
  (list "(" (italic "Warning: ") str ")"))

(define-syntax* (subscript-var stx)
  (syntax-case stx ()
    ((_ nt s)
     #`(elem (racketvarfont #,(symbol->string (syntax->datum #'nt)))
             (subscript s)))))

(define-syntax-rule
  (define-subscript-var* n s)
  (define-syntax* (n stx)
    (syntax-case stx ()
      ((_ nt)
       #`(elem (racketvarfont #,(symbol->string (syntax->datum #'nt)))
               (subscript s))))))

(define-subscript-var* rkt-nt "rkt")
(define-subscript-var* ign-nt "ign")
(define-subscript-var* rkt-ign-nt "rkt,ign")

(define-syntax* (indirect-id stx)
  (syntax-case stx ()
    ((_ id)
     #`(elem (racket id)
             (subscript (racketvarfont "id-expr"))))))

(define-syntax* (stxprop-flag stx)
  (syntax-case stx ()
    ((_ flag)
     #`(subscript (racket '#,(syntax->datum #'flag) ≠ #f)))))