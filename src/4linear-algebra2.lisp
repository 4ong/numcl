#|

This file is a part of NUMCL project.
Copyright (c) 2019 IBM Corporation
SPDX-License-Identifier: LGPL-3.0-or-later

NUMCL is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any
later version.

NUMCL is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
NUMCL.  If not, see <http://www.gnu.org/licenses/>.

|#

(in-package :numcl.impl)

;; dot(a, b[, out]) 	Dot product of two arrays.
;; linalg.multi_dot(arrays) 	Compute the dot product of two or more arrays in a single function call, while automatically selecting the fastest evaluation order.
;; vdot(a, b) 	Return the dot product of two vectors.
;; inner(a, b) 	Inner product of two arrays.
;; outer(a, b[, out]) 	Compute the outer product of two vectors.
;; matmul(a, b[, out]) 	Matrix product of two arrays.
;; tensordot(a, b[, axes]) 	Compute tensor dot product along specified axes for arrays >= 1-D.
;; einsum(subscripts, *operands[, out, dtype, …]) 	Evaluates the Einstein summation convention on the operands.
;; einsum_path(subscripts, *operands[, optimize]) 	Evaluates the lowest cost contraction order for an einsum expression by considering the creation of intermediate arrays.
;; linalg.matrix_power(a, n) 	Raise a square matrix to the (integer) power n.
;; kron(a, b) 	Kronecker product of two arrays.

;; misc functions. These are tentative, base implementations.
;; they will eventually be replaced by BLAS/LAPACK routines.

(inline-except-toplevel ()
  (defun transpose (matrix &optional result)
    "Reverses the axes of an array."
    (let ((indices (make-gensym-list (rank matrix))))
      ;; needs some caching for functions here
      (if result
          (einsum `(,indices -> ,(reverse indices)) matrix result)
          (einsum `(,indices -> ,(reverse indices)) matrix)))))

(inline-except-toplevel ()
  (defun matmul (a b &optional result)
    "Matrix product of two arrays."
    (if result
        (einsum '(ij jk -> ik) a b result)
        (einsum '(ij jk -> ik) a b))))

(inline-except-toplevel ()
  (defun vdot (a b &optional result)
    "Dot product of two vectors. For complex values, the first value is conjugated."
    (if result
        (einsum '(i i -> ) (numcl:conjugate a) b result)
        (einsum '(i i -> ) (numcl:conjugate a) b))))

(inline-except-toplevel ()
  (defun inner (a b &optional result)
    "Inner product of two vectors."
    (if result
        (einsum '(i i -> ) a b result)
        (einsum '(i i -> ) a b))))

(inline-except-toplevel ()
  (defun outer (a b &optional result)
    "Compute the outer product of two vectors."
    (if result
        (einsum '(i j -> ij) a b result)
        (einsum '(i j -> ij) a b))))

(inline-except-toplevel ()
  (defun kron (a b &optional result)
    "Compute the kronecker product of two vectors."
    (reshape (if result
                 (einsum '(ij kl -> ikjl) a b result)
                 (einsum '(ij kl -> ikjl) a b))
             (mapcar #'* (shape a) (shape b)))))

;; (declaim (inline dot))
;; (defun dot (a b)
;;   "Dot product of two arrays."
;;   (etypecase 
;;   
;;   (einsum '(ij jk -> ik) a b))

(inline-except-toplevel ()
  (defun diag (a &optional result)
    "Return the diagonal element of a matrix as a vector"
    (if result
        (einsum '(ii -> i) a result)
        (einsum '(ii -> i) a))))

(inline-except-toplevel ()
  (defun tri (n &key (m n) (k 0) (type 'bit))
    "Returns a triangle matrix whose lower diagnonal (including the diagonal) filled with 1.
 N,M specifies the shape of the return array. K will adjust the sub-diagonal -- positive K fills more 1s."
    (let ((a (zeros (list n m) :type type))
          (one (%coerce 1 type)))
      (dotimes (i n a)
        (dotimes (j m)
          (when (>= i (- j k))            ; numpy documentation is wrong... it is not i <= j+k
            (setf (aref a i j) one)))))))

(inline-except-toplevel ()
  (defun tril (matrix &optional (k 0))
    "Returns the copy of matrix with elements above the k-th diagonal zeroed. Positive K fills less 0s."
    (match matrix
      ((array :dimensions (list n m)
              :element-type type)
       (let ((a (zeros (list n m) :type type)))
         (dotimes (i n a)
           (dotimes (j m)
             (when (>= i (- j k))
               (setf (aref a i j) (aref matrix i j))))))))))

(inline-except-toplevel ()
  (defun triu (matrix &optional (k 0))
    "Returns the copy of matrix with elements below the k-th diagonal zeroed. Positive K fills more 0s."
    (match matrix
      ((array :dimensions (list n m)
              :element-type type)
       (let ((a (zeros (list n m) :type type)))
         (dotimes (i n a)
           (dotimes (j m)
             (when (<= i (- j k))
               (setf (aref a i j) (aref matrix i j))))))))))

(inline-except-toplevel ()
  (defun eye (n &key (m n) (k 0) (type 'bit))
    "Returns a matrix whose k-th diagnonal filled with 1.
 N,M specifies the shape of the return array. K will adjust the sub-diagonal -- positive K moves it upward."
    (let ((a (zeros (list n m) :type type))
          (one (%coerce 1 type)))
      (do ((i (max 0 (- k)) (1+ i))
           (j (max 0 k)     (1+ j)))
          ((or (= i n) (= j m))
           a)
        (setf (aref a i j) one)))))

(inline-except-toplevel ()
  (defun vander (v &key (n (length v)) increasing)
    "Returns a matrix where M[i,j] == V[i]^(N-j) when increasing is false (default), and 
 M[i,j] == V[i]^j when increasing is true."
    (let* ((m (length v))
           (a (zeros (list m n) :type (array-element-type v))))
      (if increasing
          (dotimes (i m)
            (dotimes (j n)
              (setf (aref a i j) (expt (aref v i) j))))
          (dotimes (i m)
            (do ((j 0 (1+ j))
                 (e (1- n) (1- e)))
                ((= j n))
              (setf (aref a i j) (expt (aref v i) e)))))
      a)))

;;; multi-arg GEMM

;; naive version

(defun matmul*-naive (&rest args)
  "Takes an arbitrary number of matrices and performs multiplication."
  (reduce (lambda (acc m)
            (matmul acc m))
          (cdr args)
          :initial-value (car args)))

(defun matmul* (&rest args)
  "Takes an arbitrary number of matrices and performs multiplication,
optimizing the order using the shape information and the associativity
to minimize the size of the intermediate matrix."
  (let* ((dimension-vector (map 'vector #'array-dimensions args))
         (tree (car (%build-tree dimension-vector))))
    (labels ((process-tree (tree)
               (cond ((atom tree) (nth tree args))
                     ((consp tree)
                      (assert (= 2 (length tree)) nil "Tree must be binary")
                      (matmul (process-tree (first tree))
                              (process-tree (second tree)))))))
      (process-tree tree))))

(define-compiler-macro matmul* (&whole form &rest args)
  (if (= 2 (length args))
      `(matmul ,@args)                   ;avoid runtime overhead
      form))


(defun %build-tree (dimensions)
  "Builds an order tree of multiplications, dynamically solving it for all ranges."
  (let* ((n (length dimensions))
         (table (make-array (list n n))))
    (loop :for i :from 0 :below n
          :do (setf (aref table i i) (list i (aref dimensions i) 0)))
    (loop :for i :from 0 :below (1- n)
          :do (setf (aref table i (1+ i))
                    (cons (list i (1+ i)) (%check-two-matrices (second (aref table i i))
                                                               (second (aref table (1+ i) (1+ i)))))))
    (loop :for len :from 2 :below n
          :do (loop :for ind :from 0 :below (- n len)
                    :do (setf (aref table ind (+ ind len))
                              (loop :for step :from 1 :upto len
                                    :with best := (cons (list (first (aref table ind ind))
                                                              (first (aref table (1+ ind) (+ ind len))))
                                                        (%add-two-cases
                                                            (cdr (aref table ind ind))
                                                            (cdr (aref table (1+ ind) (+ ind len)))))
                                    :for next := (cons (list (first (aref table ind (+ ind (1- step))))
                                                             (first (aref table (+ ind step) (+ ind len))))
                                                       (%add-two-cases
                                                        (cdr (aref table ind (+ ind (1- step))))
                                                        (cdr (aref table (+ ind step) (+ ind len)))))
                                    :when (< (third next) (third best))
                                      :do (setf best next)
                                    :finally (return best)))))
    (aref table 0 (1- n))))

(defun %check-two-matrices (first second)
  #.(format
     nil "~@{~A~%~}"
     "first and second are cons of a form (height width) in this case."
     "The function returns the dimensions of resulting thing and the number of"
     "multiplications requred. I work under assertion, that those matrices are"
     "actually multipliable => (= (cdr first) (car second)).")
  (destructuring-bind (first-height first-width) first
    (destructuring-bind (sec-height sec-width) second
      (list (list first-height sec-width) (* first-width sec-height sec-width)))))

(defun %add-two-cases (first second)
  "Compares two cases of what previous thing returns and returns the best one."
  (destructuring-bind (first-matrix first-mult) first
    (destructuring-bind (sec-matrix sec-mult) second
      (let ((res (%check-two-matrices first-matrix sec-matrix)))
        (incf (second res) first-mult)
        (incf (second res) sec-mult)
        res))))


(defun %index->matrix (operation indices matrices)
  "Tree of indexes -> tree of multiplications"
  (if (atom indices)
      (elt matrices indices)
      (list operation (%index->matrix operation (car indices) matrices)
                      (%index->matrix operation (cadr indices) matrices))))


(defun %straight-forward-check (sizes)
  "Naive atomic multiplications check for comparison"
  (loop :for i :from 1 :below (length sizes)
        :with fh := (car (aref sizes 0))
        :sum (* fh (car (aref sizes i)) (cadr (aref sizes i)))))

;; performance testing

#+(or)
(defun test1-base ()
  (let ((*print-array* nil))
    (time (print
           (matmul (zeros '(1000 1000) :type 'fixnum)
                   (zeros '(1000 1000) :type 'fixnum)))))
  nil)

;; should be same as test1-base
#+(or)
(defun test2-check-compiler-macro ()
  (let ((*print-array* nil))
    (time (print
           (matmul* (zeros '(1000 1000) :type 'fixnum)
                    (zeros '(1000 1000) :type 'fixnum)))))
  nil)


;; test the effect
;; #+(or)
(defun test3 ()
  (let ((*print-array* nil))
    (time (print
           ;; naive approach will generate a 1000x1000 intermediate matrix
           (matmul* (zeros '(1000 1) :type 'fixnum)
                    (zeros '(1 1000) :type 'fixnum)
                    (zeros '(1000 1000) :type 'fixnum)))))
  nil)

;; #+(or)
(defun test3-naive ()
  (let ((*print-array* nil))
    (time (print
           ;; naive approach will generate a 1000x1000 intermediate matrix
           (matmul*-naive (zeros '(1000 1) :type 'fixnum)
                          (zeros '(1 1000) :type 'fixnum)
                          (zeros '(1000 1000) :type 'fixnum)))))
  nil)

;; Results

#|

Environment: sbcl 1.5.9, RYZEN 1700

* Naive

IMPL> (test3-naive)

#<(ARRAY FIXNUM (1000 1000)) {1004500D1F}> 
Evaluation took:
  4.646 seconds of real time
  4.643399 seconds of total run time (4.635514 user, 0.007885 system)
  99.94% CPU
  6 forms interpreted
  410 lambdas converted
  13,910,318,070 processor cycles
  30,318,096 bytes consed
  
NIL



* proposed

IMPL> (test3)

#<(ARRAY FIXNUM (1000 1000)) {1003C3046F}> 
Evaluation took:
  0.032 seconds of real time
  0.031556 seconds of total run time (0.031556 user, 0.000000 system)
  100.00% CPU
  6 forms interpreted
  410 lambdas converted
  95,227,980 processor cycles
  22,308,112 bytes consed
  
NIL

|#
