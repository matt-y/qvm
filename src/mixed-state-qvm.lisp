;;;; src/mixed-state-qvm.lisp
;;;;
;;;; Authors: Robert Smith
;;;;          Erik Davis
;;;;          Sophia Ponte

(in-package #:qvm)

;;; This file implements a qvm that evolves pure and mixed states by
;;; means of a DENSITY-MATRIX-STATE.

;;; General Overview

;;; The MIXED-STATE-QVM is an implementation of a QVM that can evolve
;;; either a pure or mixed state using a DENSITY-MATRIX-STATE. The
;;; MIXED-STATE-QVM inherits most of its core behavior from BASE-QVM,
;;; but provides more specialized functionality for methods like
;;; TRANSITION, MEASURE, and MEASURE-ALL. Since the MIXED-STATE-QVM
;;; uses a DENSITY-MATRIX-STATE, it converts quil gates to
;;; superoperators for gate application. Additional superoperators can
;;; be defined in the SUPEROPERATOR-DEFINITIONS slot of the
;;; MIXED-STATE-QVM.

(defclass mixed-state-qvm (base-qvm)
  ((state :accessor state
          :initarg :state
          :type (or null density-matrix-state)))
  (:documentation "A qvm for simulating mixed-state quantum systems."))

(defmethod initialize-instance :after ((qvm mixed-state-qvm) &rest args)
  (declare (ignore args))
  ;; PURE-STATE-QVM does its own allocation, which we don't want, so
  ;; here we make sure that the AMPLITUDES slot has a vector of the
  ;; right size (e.g. it was constructed by MAKE-MIXED-STATE-QVM).
  (when (or (not (slot-boundp qvm 'state))
            (null (slot-value qvm 'state)))
      (setf (state qvm) 
            (make-instance 'density-matrix-state :num-qubits (number-of-qubits qvm)))
      (set-to-zero-state (state qvm))))

(defun make-mixed-state-qvm (num-qubits &key (allocation nil) &allow-other-keys)
  "Build a MIXED-STATE-QVM with a DENSITY-MATRIX-STATE representing NUM-QUBITS qubits."
  (check-type num-qubits unsigned-byte)
  (make-instance 'mixed-state-qvm :number-of-qubits num-qubits 
                                  :state (make-density-matrix-state 
                                          num-qubits  
                                          :allocation allocation)))

(defun full-density-number-of-qubits (vec-density)
  "Computes the number of qubits encoded by a vectorized density matrix."
  (1- (integer-length (isqrt (length vec-density)))))


;;; Superoperators 

;;; Ordinary gates, as well as user-specified "Kraus operators" in
;;; SUPEROPERATOR-DEFINITIONS, can represented by a SUPEROPERATOR type
;;; (in apply-gate.lisp). The quil syntax for specifying
;;; superoperators is done through pragmas where a user may specify a
;;; "SUPEROPERATOR-DEFINTION" on a gate and a specific set of
;;; qubits. During the QVM evaluation, such a user defined
;;; SUPEROPERATOR definition will replace the usual gate.
;;;
;;; The primary difference between the MIXED-STATE-QVM's superoperator
;;; application and the PURE-STATE-QVM's is that application of a
;;; superoperator to a DENSITY-MATRIX-STATE is completely
;;; deterministic and "folds all of the noisy" into the density
;;; matrix, whereas the application to a PURE-STATE is
;;; nondeterministic and tracks only a specific realization of the
;;; gate noise in a stochastic process.

(defun mixed-state-qvm-measurement-probabilities (qvm)
  "Computes the probability distribution of measurement outcomes (a vector)
  associated with the STATE of the DENSITY-QVM."
  (density-matrix-state-measurement-probabilities (state qvm)))

(defun lift-matrix-to-superoperator (mat)
  "Converts a magicl matrix MAT into a SINGLE-KRAUS SUPEROPERATOR."
  (single-kraus
   (make-instance 'quil:simple-gate
                  :name (string (gensym "KRAUS-TEMP"))
                  :matrix mat)))

(defgeneric conjugate-entrywise (gate)
  (:documentation "Construct a new gate from GATE with corresponding matrix entries conjugated.")
  (:method ((gate quil:simple-gate))
    (make-instance 'quil:simple-gate
                   :name (concatenate 'string (quil:gate-name gate) "*")
                   :matrix (magicl:conjugate-entrywise (quil:gate-matrix gate))))
  (:method ((gate quil:permutation-gate))
    (make-instance 'quil:permutation-gate
                   :name (concatenate 'string (quil:gate-name gate) "*")
                   :permutation (quil:permutation-gate-permutation gate)))
  (:method ((gate quil:parameterized-gate))
    (make-instance 'quil:parameterized-gate
                   :name (concatenate 'string (quil:gate-name gate) "*")
                   :dimension (quil:gate-dimension gate)
                   :matrix-function #'(lambda (&rest parameters)
                                        (magicl:conjugate-entrywise
                                         (apply #'quil:gate-matrix gate parameters))))))

;;; Don't compile things for the mixed-state-qvm.
(defmethod compile-loaded-program ((qvm mixed-state-qvm))
  qvm)

;;; TODO: FIXME: we should be able to compile density operator stuff
;;; just fine.
(defmethod compile-instruction ((qvm mixed-state-qvm) isn)
  (declare (ignore qvm))
  isn)