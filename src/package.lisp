;;;; package.lisp -- Package definition for the clwasm demo

(defpackage #:clwasm
  (:use #:cl)
  (:export #:entry-point
           #:fib
           #:version-string))

(in-package #:clwasm)
