#lang magnolisp/2014

(typedef int (#:annos foreign))

(function (one)
  (#:annos foreign (type (fn int)))
  1)

(function (add x y)
  (#:annos foreign (type (fn int int int)) (build need-adder))
  (+ x y))

(function (f x)
  (#:annos export (type (fn int int)))
  (define y (let ((x x)) (add (one) x)))
  y)

(f 1)
