;;;; core.lisp -- Minimal functionality that we will compile to WebAssembly

(in-package #:clwasm)

(defparameter *app-version* "0.1.0"
  "Semantic version that is reported by the exported API.")

(defun version-string ()
  "Return the semantic version of the library."
  *app-version*)

(defun fib (n)
  "Compute the nth Fibonacci number (small n; demo purposes)."
  (check-type n (integer 0 *))
  (loop with a of-type fixnum = 0
        with b of-type fixnum = 1
        for i below n
        do (psetq a b
                  b (+ a b))
        finally (return a)))

(defun entry-point (&optional (limit 10))
  "Return a formatted greeting plus a short Fibonacci table up to LIMIT."
  (check-type limit (integer 1 93))
  (with-output-to-string (out)
    (format out "clwasm demo (version ~a)~%" (version-string))
    (loop for i from 0 below limit
          do (format out "fib(~d) = ~d~%" i (fib i)))))
