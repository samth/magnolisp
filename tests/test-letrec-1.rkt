#lang magnolisp/2014

(typedef int (#:annos foreign))

(function (inc x)
  (#:annos (type (fn int int)) foreign)
  (add1 x))

(function (f x)
  (#:annos (type (fn int int)) export)
  (var y (inc x)) ;; y = 9
  (set! y (inc y)) ;; y = 10
  (var z y)
  (set! z (inc y)) ;; z = 11
  z)

(f 8) ;; => 11
