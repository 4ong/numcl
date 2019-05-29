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


;; These interfaces return a list instead of arrays;
;; Indexing routines are fundamentally dynamic, and there is no reason
;; for storing them in an array.

(declaim (inline array-index-from-row-major-index))
(defun array-index-from-row-major-index (array row-major-index)
  "Takes a multidimentional array and a row-major-index.
 Returns a list containing the normal index."
  (let* ((r (rank array))
         (s (asarray (shape array) :type 'fixnum))
         (result '()))
    (iter (for i in-vector s with-index j from (1- r) downto 0)
          (declare (iterate:declare-variables))
          (multiple-value-bind (quo rem) (floor row-major-index i)
            (setf row-major-index quo)
            (push rem result)))
    result))

(declaim (inline %array-index-from-row-major-index/vector))
(defun %array-index-from-row-major-index/vector (array row-major-index &optional result)
  "Takes a multidimentional array and a row-major-index.
 Returns a vector containing the normal index."
  (let* ((r (rank array))
         (s (asarray (shape array) :type 'fixnum))
         (result (or result (empty r :type 'fixnum))))
    (iter (for i in-vector s with-index j from (1- r) downto 0)
          (declare (iterate:declare-variables))
          (setf (values row-major-index
                        (aref result j))
                (floor row-major-index i)))
    result))

;; (array-index-from-row-major-index (zeros '(3 3)) 8)
;; (array-index-from-row-major-index (zeros '(100 100)) 8)
;; 
;; (array-index-from-row-major-index (reshape (arange 27) '(3 3 3)) 15)
;; 
;; (let ((a (reshape (arange 27) '(3 3 3))))
;;   (apply #'aref a (coerce (array-index-from-row-major-index a 14) 'list)))

(declaim (inline where))
(defun where (array fn)
  "collect multidimentional indices where the predicate FN is satisfied"
  (declare (array array)
           ((function (T) boolean) fn))
  (let ((base (array-displacement array)))
    (declare ((simple-array * 1) base))
    (iter (for i below (array-total-size array))
          (declare (declare-variables))
          (when (funcall fn (aref base i))
            (collect (array-index-from-row-major-index array i))))))

(declaim (inline nonzero))
(defun nonzero (array)
  "collect multidimentional indices where the element is nonzero"
  (where array (lambda (x) (not (zerop x)))))

#+(or)
(let ((b (uniform 0 10 '(5 5))))
  (print b)
  (print (nonzero b))
  (print (where b #'evenp)))

(declaim (inline take))
(defun take (array indices)
  "collect elements from the list of multidimentional indices"
  (declare (array array)
           (list indices))
  (mapcar (lambda (indice)
            (declare (list indice))
            (apply #'aref array indice))
          indices))

