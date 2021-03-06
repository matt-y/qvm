;;;; app-ng/src/safety-hash/impl-bordeaux-threads.lisp
;;;;
;;;; Author: appleby
;;;;
;;;; The SAFETY-HASH implementation in this file is intended to be simple and portable (and probably
;;;; slow). This portable implementation acquires and releases a recursive per-object lock around
;;;; every operation. It depends on BORDEAUX-THREADS for the locking primitives.
(in-package #:qvm-app-ng.safety-hash)

(defstruct (safety-hash (:constructor %make-safety-hash))
  (lock  (error "Must provide LOCK")  :read-only t)
  (table (error "Must provide TABLE") :read-only t))

(defun call-with-locked-safety-hash (safety-hash function)
  (bt:with-recursive-lock-held ((safety-hash-lock safety-hash))
    (funcall function (safety-hash-table safety-hash))))

#+#:warning-extreme-danger-will-robinson-use-only-in-case-of-testing
(defun call-with-locked-safety-hash (safety-hash function)
  (funcall function (safety-hash-table safety-hash)))

(defmacro with-locked-safety-hash ((hash-table) safety-hash &body body)
  (check-type hash-table symbol)
  `(call-with-locked-safety-hash ,safety-hash (lambda (,hash-table) ,@body)))


;;; Standard HASH-TABLE API replacements.

(defun make-safety-hash (&rest make-hash-table-args)
  (%make-safety-hash :lock (bt:make-recursive-lock)
                     :table (apply #'make-hash-table make-hash-table-args)))

(defun clrhash (safety-hash)
  (with-locked-safety-hash (hash-table) safety-hash
    (cl:clrhash hash-table))
  safety-hash)

(defun gethash (key safety-hash &optional default)
  (with-locked-safety-hash (hash-table) safety-hash
    (cl:gethash key hash-table default)))

(defun (setf gethash) (new-value key safety-hash)
  (with-locked-safety-hash (hash-table) safety-hash
    (setf (cl:gethash key hash-table) new-value)))

(defun hash-table-count (safety-hash)
  (with-locked-safety-hash (hash-table) safety-hash
    (cl:hash-table-count hash-table)))

(defun remhash (key safety-hash)
  (with-locked-safety-hash (hash-table) safety-hash
    (cl:remhash key hash-table)))


;;; Higher-level multi-access & convenience functions.

(defun gethash-or-lose (key safety-hash)
  (with-locked-safety-hash (hash-table) safety-hash
    (multiple-value-bind (value foundp) (cl:gethash key hash-table)
      (if foundp
          value
          (error "Failed to find key ~A in SAFETY-HASH" key)))))

(defun insert-unique (key value safety-hash)
  (with-locked-safety-hash (hash-table) safety-hash
    (if (nth-value 1 (cl:gethash key hash-table))
        (error "Collision for key ~A in SAFETY-HASH" key)
        (setf (cl:gethash key hash-table) value))))
