#lang magnolisp

;; we use `Bool` values, but do not explicitly refer to the type
(function (f) #:: (export)
  (let ((x #f))
    x))

(f)
