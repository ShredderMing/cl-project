#|
  This file is a part of CL-Project package.
  URL: http://github.com/fukamachi/cl-project
  Copyright (c) 2011 Eitarow Fukamachi <e.arrows@gmail.com>

  CL-Project is freely distributable under the LLGPL License.
|#

(in-package :cl-user)
(defpackage cl-project
  (:use :cl
        :anaphora)
  (:import-from :cl-fad
                :directory-exists-p
                :pathname-as-directory
                :list-directory)
  (:import-from :cl-ppcre
                :regex-replace-all)
  (:import-from :cl-emb
                :execute-emb))
(in-package :cl-project)

(cl-syntax:use-syntax :annot)

@export
(defvar *skeleton-directory*
    #.(asdf:system-relative-pathname
       :cl-project
       #p"skeleton/"))

(defvar *skeleton-parameters* nil)

@export
(defun make-project (path &rest params &key name description author email (without-tests nil) license depends-on &allow-other-keys)
  "Generate a skeleton.
`path' must be a pathname or a string."
  (declare (ignorable name description author email license depends-on))

  ;; Ensure `path' ends with a slash(/).
  (setf path (fad:pathname-as-directory path))

  (sunless (getf params :name)
    (setf it
          (car (last (pathname-directory path)))))
  (generate-skeleton
   *skeleton-directory*
   path
   :env params)
  (load (merge-pathnames (concatenate 'string (getf params :name) ".asd")
                         path))
  (unless without-tests
    (load (merge-pathnames (concatenate 'string (getf params :name) "-test.asd")
                           path))))

@export
(defun generate-skeleton (source-dir target-dir &key env)
  "General skeleton generator."
  (let ((*skeleton-parameters* env))
    (copy-directory source-dir target-dir)
    (when (getf env :without-tests)
      (remove-tests target-dir (concatenate 'string (getf env :name) "-test.asd")))))

(defun copy-directory (source-dir target-dir)
  "Copy a directory recursively."
  (ensure-directories-exist target-dir)
  (loop for file in (cl-fad:list-directory source-dir)
        if (cl-fad:directory-pathname-p file)
          do (copy-directory
                  file
                  (concatenate 'string
                               (awhen (pathname-device target-dir)
                                 (format nil "~A:" it))
                               (directory-namestring target-dir)
                               (car (last (pathname-directory file))) "/"))
        else
          do (copy-file-to-dir file target-dir))
  t)

(defun copy-file-to-dir (source-path target-dir)
  "Copy a file to target directory."
  (let ((target-path (make-pathname
                      :device (pathname-device target-dir)
                      :directory (pathname-directory target-dir)
                      :name (regex-replace-all
                             "skeleton"
                             (pathname-name source-path)
                             (string-downcase (getf *skeleton-parameters* :name)))
                      :type (pathname-type source-path))))
    (copy-file-to-file source-path target-path)))

(defun copy-file-to-file (source-path target-path)
  "Copy a file `source-path` to the `target-path`."
  (format t "~&writing ~A~%" target-path)
  (with-open-file (stream target-path :direction :output :if-exists :supersede)
    (write-sequence
     (cl-emb:execute-emb source-path :env *skeleton-parameters*)
     stream)))

(defun remove-tests (target-dir test-asd)
  (let ((dir (cl-fad:merge-pathnames-as-directory target-dir (cl-fad:pathname-as-directory "t")))
        (asd (cl-fad:merge-pathnames-as-file target-dir (cl-fad:pathname-as-file test-asd))))
    (when (cl-fad:directory-exists-p dir)
      (format t "removing tests...")
      (delete-file asd)
      (cl-fad:delete-directory-and-files dir))))

@export
(defun wizard ()
  "A wizard to generate a common lisp project"
  (let ((params nil)
        (description '((:name . "Project name: ")
                       (:description . "Short description for the new project: ")
                       (:author  . "Your name: ")
                       (:email . "Your Email: ")
                       (:license . "License of the new project: ")
                       (:depends-on . "Dependencies split by space: ")
                       (:path . "Finally give a path to your project: "))))
    (loop for (key . value) in description
          do (format t "~A" value)
             (force-output)
          if (eql key :depends-on)
            do (setf params (cons key (cons (split-sequence (read-line)) params)))
          else
            do (setf params (cons key (cons (read-line) params))))
    (format t "Your settings are :")
    (force-output)
    (loop with lst = (reverse params)
          for key in (cdr lst) by #'cddr
          for value in lst by #'cddr
          do (format t "~&~A: ~A" key value)
          finally (format t "Confirm your settings[Y/n]? "))
    (force-output)
    (if (member (read-char) '(#\Newline #\Y #\y))
        (apply #'make-project (second params) (cddr params)))))

(defun split-sequence (sequence &optional (delimiter #\Space))
  (loop for start = 0 then (1+ end)
        as end = (position delimiter sequence :start start)
        collect (subseq sequence start end)
        while end))
