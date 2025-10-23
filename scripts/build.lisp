;;;; build.lisp -- Drive the ECL → C → wasm compilation pipeline
;;;; Usage (from the repo root):
;;;;   ECL_KEEP_TEMP_FILES=1 ecl --norc --load scripts/build.lisp

(require :asdf)
(require :uiop)

(defparameter *script-path*
  (or *load-truename* *compile-file-truename*)
  "Absolute pathname to this build script.")

(defparameter *script-dir*
  (uiop:pathname-directory-pathname *script-path*)
  "Directory that contains this script.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname *script-dir*)
  "Project root directory (one level above scripts/).")

(defun project-path (relative)
  "Resolve RELATIVE (a string) against the project root."
  (uiop:merge-pathnames* relative *project-root*))

(defparameter *build-dir*
  (uiop:ensure-directory-pathname (project-path "build/")))

(ensure-directories-exist *build-dir*)

(pushnew (project-path "src/") asdf:*central-registry* :test #'equal)

(asdf:load-asd (project-path "src/clwasm.asd"))

(defun configure-toolchain-from-env ()
  "Allow overriding the host C toolchain ECL calls while translating to C."
  (let ((cc (uiop:getenv "CLWASM_CC"))
        (ld (uiop:getenv "CLWASM_LD"))
        (ar (uiop:getenv "CLWASM_AR"))
        (ranlib (uiop:getenv "CLWASM_RANLIB"))
  (extra-cflags (uiop:getenv "CLWASM_CFLAGS")))
    (when cc
      (setf c::*cc* cc))
    (when ld
      (setf c::*ld* ld))
    (when ar
      (setf c::*ar* ar))
    (when ranlib
      (setf c::*ranlib* ranlib))
    (when extra-cflags
      (setf c:*user-cc-flags* extra-cflags))))

(defun compile-module (name)
  "Compile src/NAME.lisp, keeping the generated C and returning the object file."
  (let* ((source (project-path (format nil "src/~a.lisp" name)))
         (object (project-path (format nil "build/~a.o" name)))
         (c-file (project-path (format nil "build/~a.c" name)))
         (h-file (project-path (format nil "build/~a.h" name))))
    (format t "~&[clwasm] compiling ~a" (uiop:native-namestring source))
    (ensure-directories-exist (uiop:pathname-directory-pathname object))
    (multiple-value-bind (fasl-path warnings-p failure-p)
        (compile-file source
                      :system-p t
                      :output-file object
                      :c-file c-file
                      :h-file h-file)
      (declare (ignore fasl-path))
      (when failure-p
        (error "Compilation failed for ~A" source))
      (when warnings-p
        (format *error-output* "~&[clwasm] warning while compiling ~a~%"
                (uiop:native-namestring source)))
      object)))

(defun build-static-library (objects)
  "Use the compiled OBJECTS to emit a libclwasm.a with a stable init function."
  (let ((*default-pathname-defaults* *build-dir*))
    (c:build-static-library "clwasm"
                            :lisp-files (mapcar #'uiop:native-namestring objects)
                            :init-name "init_clwasm")))

(defun main ()
  (handler-case
      (progn
        (configure-toolchain-from-env)
    (asdf:operate 'asdf:load-op :clwasm)
        (let ((objects (mapcar #'compile-module '("package" "core"))))
          (build-static-library objects))
        (format t "~&[clwasm] static library ready under build/"))
    (serious-condition (err)
      (format *error-output* "~&[clwasm] build failed: ~a~%" err)
      (si:quit 1))))

(main)
(si:quit 0)
