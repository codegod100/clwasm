;;;; clwasm.asd -- ASDF definition for the ECL → C → WebAssembly demo

(asdf:defsystem "clwasm"
  :version "0.1.0"
  :description "Example Embeddable Common Lisp project that targets WebAssembly via generated C."
  :author "Your Name <you@example.com>"
  :license "MIT"
  :serial t
  :components ((:file "package")
               (:file "core")))
