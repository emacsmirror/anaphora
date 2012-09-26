;;; anaphora.el --- anaphoric macros providing implicit temp variables
;;
;; This code is in the public domain.
;;
;; Author: Roland Walker <walker@pobox.com>
;; Homepage: http://github.com/rolandwalker/anaphora
;; URL: http://raw.github.com/rolandwalker/anaphora/master/anaphora.el
;; Version: 0.0.4
;; Last-Updated: 19 Sep 2012
;; EmacsWiki: Anaphora
;; Keywords: extensions
;;
;;; Commentary:
;;
;; Quickstart
;;
;;     (require 'anaphora)
;;
;;     (awhen (big-long-calculation)
;;       (foo it)      ; `it' is provided as
;;       (bar it))     ; a temporary variable
;;
;;     ;; anonymous function to compute factorial using `self'
;;     (alambda (x) (if (= x 0) 1 (* x (self (1- x)))))
;;
;; Explanation
;;
;; Anaphoric expressions implicitly create one or more temporary
;; variables which can be referred to during the expression.  This
;; technique can improve clarity in certain cases.  It also enables
;; recursion for anonymous functions.
;;
;; To use anaphora, place the anaphora.el library somewhere
;; Emacs can find it, and add the following to your ~/.emacs file:
;;
;;     (require 'anaphora)
;;
;; The following macros are made available
;;
;;     `aand'
;;     `ablock'
;;     `acase'
;;     `acond'
;;     `aecase'
;;     `aetypecase'
;;     `aif'
;;     `alambda'
;;     `alet'
;;     `aprog1'
;;     `atypecase'
;;     `awhen'
;;     `awhile'
;;     `a+'
;;     `a-'
;;     `a*'
;;     `a/'
;;
;; See Also
;;
;;     M-x customize-group RET anaphora RET
;;     http://en.wikipedia.org/wiki/On_Lisp
;;     http://en.wikipedia.org/wiki/Anaphoric_macro
;;
;; Notes
;;
;; Principally based on examples from the book "On Lisp", by Paul
;; Graham.
;;
;; When this library is loaded, the provided anaphoric forms are
;; registered as keywords in font-lock.  This may be disabled via
;; customize.
;;
;; Compatibility and Requirements
;;
;;     Tested on GNU Emacs versions 23.3 and 24.1
;;
;; Bugs
;;
;; TODO
;;
;;     better face for it and self
;;
;;; License
;;
;; This code is in the public domain.  It is provided without
;; any express or implied warranties.
;;
;;; Code:
;;

;;; requires

;; for declare, labels, do, block, case, ecase, typecase, etypecase
(require 'cl)

;;; customizable variables

;;;###autoload
(defgroup anaphora nil
  "Anaphoric macros providing implicit temp variables"
  :version "0.0.4"
  :link '(emacs-commentary-link "anaphora")
  :prefix "anaphora-"
  :group 'extensions)

(defcustom anaphora-add-font-lock-keywords t
  "Add anaphora macros to font-lock keywords when editing Emacs Lisp."
  :type 'boolean
  :group 'anaphora)

;;;###autoload
(defcustom anaphora-use-long-names-only nil
  "Use only long names such as `anaphoric-if' instead of traditional `aif'."
  :type 'boolean
  :group 'anaphora)

;;; font-lock

(when anaphora-add-font-lock-keywords
  (eval-after-load "lisp-mode"
    '(progn
       (let ((new-keywords '(
                             "anaphoric-if"
                             "anaphoric-prog1"
                             "anaphoric-when"
                             "anaphoric-while"
                             "anaphoric-and"
                             "anaphoric-cond"
                             "anaphoric-lambda"
                             "anaphoric-block"
                             "anaphoric-case"
                             "anaphoric-ecase"
                             "anaphoric-typecase"
                             "anaphoric-etypecase"
                             "anaphoric-let"
                             "aif"
                             "aprog1"
                             "awhen"
                             "awhile"
                             "aand"
                             "acond"
                             "alambda"
                             "ablock"
                             "acase"
                             "aecase"
                             "atypecase"
                             "aetypecase"
                             "alet"
                             ))
             (special-variables '(
                                  "it"
                                  "self"
                                  )))
         (font-lock-add-keywords 'emacs-lisp-mode `((,(concat "\\<" (regexp-opt special-variables 'paren) "\\>")
                                                     1 font-lock-variable-name-face)) 'append)
         (font-lock-add-keywords 'emacs-lisp-mode `((,(concat "(\\s-*" (regexp-opt new-keywords 'paren) "\\>")
                                                     1 font-lock-keyword-face)) 'append))
       (dolist (buf (buffer-list))
         (with-current-buffer buf
           (when (and (eq major-mode 'emacs-lisp-mode)
                      (boundp 'font-lock-mode)
                      font-lock-mode)
             (font-lock-refresh-defaults)))))))

;;; aliases

;;;###autoload
(defun anaphora--install-traditional-aliases ()
  "Install short names for anaphoric macros."
  (defalias 'aif        'anaphoric-if)
  (defalias 'aprog1     'anaphoric-prog1)
  (defalias 'awhen      'anaphoric-when)
  (defalias 'awhile     'anaphoric-while)
  (defalias 'aand       'anaphoric-and)
  (defalias 'acond      'anaphoric-cond)
  (defalias 'alambda    'anaphoric-lambda)
  (defalias 'ablock     'anaphoric-block)
  (defalias 'acase      'anaphoric-case)
  (defalias 'aecase     'anaphoric-ecase)
  (defalias 'atypecase  'anaphoric-typecase)
  (defalias 'aetypecase 'anaphoric-etypecase)
  (defalias 'alet       'anaphoric-let)
  (defalias 'a+         'anaphoric-+)
  (defalias 'a-         'anaphoric--)
  (defalias 'a*         'anaphoric-*)
  (defalias 'a/         'anaphoric-/))

;;;###autoload
(unless anaphora-use-long-names-only
  (anaphora--install-traditional-aliases))

;;; macros

;;;###autoload
(defmacro anaphoric-if (cond then &rest else)
  "Like `if', but the result of evaluating COND is bound to `it'.

The variable `it' is available within THEN and ELSE.

COND, THEN, and ELSE are otherwise as documented for `if'."
  (declare (debug (sexp form &rest form))
           (indent 2))
  `(let ((it ,cond))
     (if it ,then ,@else)))

;;;###autoload
(defmacro anaphoric-prog1 (first &rest body)
  "Like `prog1', but the result of evaluating FIRST is bound to `it'.

The variable `it' is available within BODY.

FIRST and BODY are otherwise as documented for `prog1'."
  (declare (debug (sexp &rest form))
           (indent 1))
  `(let ((it ,first))
     (progn ,@body)
     it))

;;;###autoload
(defmacro anaphoric-when (cond &rest body)
  "Like `when', but the result of evaluating COND is bound to `it'.

The variable `it' is available within BODY.

COND and BODY are otherwise as documented for `when'."
  (declare (debug (sexp &rest form))
           (indent 1))
  `(anaphoric-if ,cond
       (progn ,@body)))

;;;###autoload
(defmacro anaphoric-while (test &rest body)
  "Like `while', but the result of evaluating TEST is bound to `it'.

The variable `it' is available within BODY.

TEST and BODY are otherwise as documented for `while'."
  (declare (debug (sexp &rest form))
           (indent 1))
  `(do ((it ,test ,test))
       ((not it))
     ,@body))

;;;###autoload
(defmacro anaphoric-and (&rest conditions)
  "Like `and', but the result of the previous condition is bound to `it'.

The variable `it' is available within all CONDITIONS after the
initial one.

CONDITIONS are otherwise as documented for `and'.

Note that some implementations of this macro bind only the first
condition to `it', rather than each successive condition."
  (cond
    ((null conditions)
     t)
    ((null (cdr conditions))
     (car conditions))
    (t
     `(anaphoric-if ,(car conditions) (anaphoric-and ,@(cdr conditions))))))

;;;###autoload
(defmacro anaphoric-cond (&rest clauses)
  "Like `cond', but the result of each condition is bound to `it'.

The variable `it' is available within the remainder of each of CLAUSES.

CLAUSES are otherwise as documented for `cond'."
  (declare (indent 0))
  (if (null clauses)
      nil
    (let ((cl1 (car clauses))
          (sym (gensym)))
      `(let ((,sym ,(car cl1)))
         (if ,sym
             (if (null ',(cdr cl1))
                 ,sym
               (let ((it ,sym)) ,@(cdr cl1)))
           (anaphoric-cond ,@(cdr clauses)))))))

;;;###autoload
(defmacro anaphoric-lambda (args &rest body)
  "Like `lambda', but the function may refer to itself as `self'.

ARGS and BODY are otherwise as documented for `lambda'."
  (declare (debug (sexp &rest form))
           (indent defun))
  `(labels ((self ,args ,@body))
     #'self))

;;;###autoload
(defmacro anaphoric-block (name &rest body)
  "Like `block', but the result of the previous expression is bound to `it'.

The variable `it' is available within all expressions of BODY
except the initial one.

NAME and BODY are otherwise as documented for `block'."
  (declare (debug (sexp &rest form))
           (indent 1))
  `(block ,name
     ,(funcall (anaphoric-lambda (body)
                 (case (length body)
                   (0 nil)
                   (1 (car body))
                   (t `(let ((it ,(car body)))
                         ,(self (cdr body))))))
               body)))

;;;###autoload
(defmacro anaphoric-case (expr &rest clauses)
  "Like `case', but the result of evaluating EXPR is bound to `it'.

The variable `it' is available within CLAUSES.

EXPR and CLAUSES are otherwise as documented for `case'."
  (declare (debug (sexp &rest form))
           (indent 1))
  `(let ((it ,expr))
     (case it ,@clauses)))

;;;###autoload
(defmacro anaphoric-ecase (expr &rest clauses)
  "Like `ecase', but the result of evaluating EXPR is bound to `it'.

The variable `it' is available within CLAUSES.

EXPR and CLAUSES are otherwise as documented for `ecase'."
  (declare (indent 1))
  `(let ((it ,expr))
     (ecase it ,@clauses)))

;;;###autoload
(defmacro anaphoric-typecase (expr &rest clauses)
  "Like `typecase', but the result of evaluating EXPR is bound to `it'.

The variable `it' is available within CLAUSES.

EXPR and CLAUSES are otherwise as documented for `typecase'."
  (declare (indent 1))
  `(let ((it ,expr))
     (typecase it ,@clauses)))

;;;###autoload
(defmacro anaphoric-etypecase (expr &rest clauses)
  "Like `etypecase', but result of evaluating EXPR is bound to `it'.

The variable `it' is available within CLAUSES.

EXPR and CLAUSES are otherwise as documented for `etypecase'."
  (declare (indent 1))
  `(let ((it ,expr))
     (etypecase it ,@clauses)))

;;;###autoload
(defmacro anaphoric-let (varlist &rest body)
  "Like `let', but the content of VARLIST is bound to `it'.

VARLIST as it appears in `it' is not evaluated.  The variable `it'
is available within BODY.

VARLIST and BODY are otherwise as documented for `let'."
  (declare (debug (sexp &rest form))
           (indent 1))
  `(let ((it ',varlist)
          ,@varlist)
     (progn ,@body)))

;;;###autoload
(defmacro anaphoric-+ (&rest numbers-or-markers)
  "Like `+', but the result of evaluating the previous expression is bound to `it'.

The variable `it' is available within all expressions after the
initial one.

NUMBERS-OR-MARKERS are otherwise as documented for `+'."
  (cond
    ((null numbers-or-markers)
     0)
    (t
     `(let ((it ,(car numbers-or-markers)))
        (+ it (anaphoric-+ ,@(cdr numbers-or-markers)))))))

;;;###autoload
(defmacro anaphoric-- (&optional number-or-marker &rest numbers-or-markers)
  "Like `-', but the result of evaluating the previous expression is bound to `it'.

The variable `it' is available within all expressions after the
initial one.

NUMBER-OR-MARKER and NUMBERS-OR-MARKERS are otherwise as
documented for `-'."
  (cond
    ((null number-or-marker)
     0)
    ((null numbers-or-markers)
     `(- ,number-or-marker))
    (t
     `(let ((it ,(car numbers-or-markers)))
        (- ,number-or-marker (+ it (anaphoric-+ ,@(cdr numbers-or-markers))))))))

;;;###autoload
(defmacro anaphoric-* (&rest numbers-or-markers)
  "Like `*', but the result of evaluating the previous expression is bound to `it'.

The variable `it' is available within all expressions after the
initial one.

NUMBERS-OR-MARKERS are otherwise as documented for `*'."
  (cond
    ((null numbers-or-markers)
     1)
    (t
     `(let ((it ,(car numbers-or-markers)))
        (* it (anaphoric-* ,@(cdr numbers-or-markers)))))))

;;;###autoload
(defmacro anaphoric-/ (dividend divisor &rest divisors)
  "Like `/', but the result of evaluating the previous divisor is bound to `it'.

The variable `it' is available within all expressions after the
first divisor.

DIVIDEND, DIVISOR, and DIVISORS are otherwise as documented for `/'."
  (cond
    ((null divisors)
     `(/ ,dividend ,divisor))
    (t
     `(let ((it ,divisor))
        (/ ,dividend (* it (anaphoric-* ,@divisors)))))))

(provide 'anaphora)

;;
;; Emacs
;;
;; Local Variables:
;; indent-tabs-mode: nil
;; mangle-whitespace: t
;; require-final-newline: t
;; coding: utf-8
;; byte-compile-warnings: (not cl-functions redefine)
;; End:
;;
;; LocalWords: Anaphora EXPR awhen COND ARGS alambda ecase typecase
;; LocalWords: etypecase aprog aand acond ablock acase aecase alet
;; LocalWords: atypecase aetypecase VARLIST
;;

;;; anaphora.el ends here
