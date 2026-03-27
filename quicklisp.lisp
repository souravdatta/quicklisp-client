;;;;
;;;; quicklisp.lisp -- Quicklisp bootstrap for git-cloned installations
;;;;
;;;; Clone the quicklisp-client repo, start Lisp, then:
;;;;
;;;;   (load "path/to/quicklisp-client/quicklisp.lisp")
;;;;   (quicklisp-quickstart:install)
;;;;
;;;; Optional arguments to install:
;;;;
;;;;   :path   -- installation directory (default ~/quicklisp/)
;;;;   :proxy  -- proxy URL string
;;;;   :dist-url -- override the initial dist URL
;;;;

(cl:in-package #:cl-user)

(defpackage #:qlqs-info
  (:export #:*version*))

(defpackage #:quicklisp-quickstart
  (:use #:cl)
  (:export #:install
           #:help
           #:*quickstart-parameters*))

(in-package #:quicklisp-quickstart)

;;; Capture repo root at load time from *load-truename*

(eval-when (:load-toplevel :execute)
  (defvar *repo-root*
    (if *load-truename*
        (make-pathname :name nil :type nil :defaults *load-truename*)
        (error "quicklisp.lisp must be loaded from a file, not evaluated directly."))))

;;; Read version from the repo

(defvar qlqs-info:*version*
  (let ((vfile (merge-pathnames "quicklisp/version.txt" *repo-root*)))
    (if (probe-file vfile)
        (with-open-file (s vfile) (read-line s nil "unknown"))
        "unknown")))

;;; Installation target

(defvar *home*
  (merge-pathnames (make-pathname :directory '(:relative "quicklisp"))
                   (user-homedir-pathname))
  "Default Quicklisp installation directory.")

;;; Parameters passed through to the installed client's first-run setup

(defvar *quickstart-parameters* nil
  "Plist of parameters carried over to the initial client configuration,
e.g. :proxy-url and :initial-dist-url.")

(defun qmerge (pathname)
  (merge-pathnames pathname *home*))

;;; Messages

(defvar *help-message*
  (format nil "~&~%  ==== quicklisp quickstart install help ====~%~%  ~
               quicklisp-quickstart:install accepts these keyword args:~%~%    ~
               :path \"/path/to/installation/\"~%~%    ~
               :proxy \"http://your.proxy:port/\"~%~%    ~
               :dist-url <url>~%~%"))

(defvar *after-load-message*
  (format nil "~&~%  ==== quicklisp quickstart ~A loaded ====~%~%  ~
               To install, evaluate: (quicklisp-quickstart:install)~%~%  ~
               For options, evaluate: (quicklisp-quickstart:help)~%~%"
          qlqs-info:*version*))

(defvar *after-initial-setup-message*
  (with-output-to-string (*standard-output*)
    (format t "~&~%  ==== quicklisp installed ====~%~%")
    (format t "  To load a system:              (ql:quickload \"system-name\")~%")
    (format t "  To find systems:               (ql:system-apropos \"term\")~%")
    (format t "  To load Quicklisp on startup:  (ql:add-to-init-file)~%~%")))

;;; File utilities (pure CL, no dependencies)

(defun copy-file (source dest)
  "Copy SOURCE to DEST as raw bytes, overwriting DEST if it exists."
  (with-open-file (in source :element-type '(unsigned-byte 8))
    (with-open-file (out dest
                         :direction :output
                         :element-type '(unsigned-byte 8)
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (let ((buf (make-array 8192 :element-type '(unsigned-byte 8))))
        (loop for n = (read-sequence buf in)
              while (plusp n)
              do (write-sequence buf out :end n))))))

(defun copy-directory-files (source-dir dest-dir)
  "Copy all files directly under SOURCE-DIR into DEST-DIR."
  (ensure-directories-exist dest-dir)
  (dolist (file (directory (merge-pathnames
                             (make-pathname :name :wild :type :wild)
                             source-dir)))
    (let ((dest (merge-pathnames (file-namestring file) dest-dir)))
      (copy-file file dest))))

;;; Repo validation

(defun check-repo-structure (root)
  "Error if the expected files are missing under ROOT."
  (flet ((need (relative)
           (unless (probe-file (merge-pathnames relative root))
             (error "Required file missing from repo: ~A~%~
                     Is ~A a valid quicklisp-client checkout?"
                    relative root))))
    (need "setup.lisp")
    (need "asdf.lisp")
    (need "quicklisp/quicklisp.asd")))

;;; Core install logic

(defun initial-install (repo-root &key dist-url proxy-url)
  (setf *quickstart-parameters*
        (list :proxy-url proxy-url
              :initial-dist-url dist-url))
  (format t "~&; Installing Quicklisp to ~A~%" *home*)
  (format t "~&;   Copying setup.lisp~%")
  (copy-file (merge-pathnames "setup.lisp" repo-root)
             (qmerge "setup.lisp"))
  (format t "~&;   Copying asdf.lisp~%")
  (copy-file (merge-pathnames "asdf.lisp" repo-root)
             (qmerge "asdf.lisp"))
  (format t "~&;   Copying quicklisp/~%")
  (copy-directory-files (merge-pathnames "quicklisp/" repo-root)
                        (qmerge "quicklisp/"))
  (format t "~&;   Loading setup~%")
  (let ((*compile-verbose* nil)
        (*compile-print* nil)
        (*load-verbose* nil)
        (*load-print* nil))
    (handler-bind ((warning #'muffle-warning))
      (load (qmerge "setup.lisp") :verbose nil :print nil)))
  (write-string *after-initial-setup-message*)
  (finish-output))

;;; Public API

(defun help ()
  (write-string *help-message*)
  t)

(defun non-empty-file-namestring (pathname)
  (let ((string (file-namestring pathname)))
    (unless (or (null string) (equal string ""))
      string)))

(defun install (&key ((:path *home*) *home*)
                  ((:proxy proxy-url) nil)
                  dist-url)
  "Install Quicklisp by copying the cloned repo files into *home*.
Defaults to ~/quicklisp/. Override with :path."
  (setf *home* (merge-pathnames *home* (truename *default-pathname-defaults*)))
  (let ((name (non-empty-file-namestring *home*)))
    (when name
      (warn "Making ~A part of the install pathname directory" name)
      (setf *home*
            (make-pathname :defaults *home*
                           :directory (append (pathname-directory *home*)
                                              (list name))))))
  (let ((setup-file (qmerge "setup.lisp")))
    (when (probe-file setup-file)
      (multiple-value-bind (result proceed)
          (with-simple-restart (load-setup "Load ~S" setup-file)
            (error "Quicklisp is already installed at ~A. ~
                    Load ~S to use it."
                   *home* setup-file))
        (declare (ignore result))
        (when proceed
          (return-from install (load setup-file))))))
  (if (find-package '#:ql)
      (progn
        (write-line "Quicklisp is already set up.")
        (write-string *after-initial-setup-message*)
        t)
      (progn
        (check-repo-structure *repo-root*)
        (initial-install *repo-root*
                         :dist-url dist-url
                         :proxy-url proxy-url))))

(write-string *after-load-message*)

;;; End of quicklisp.lisp
