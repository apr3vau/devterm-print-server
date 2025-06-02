(defpackage devterm-print-server
  (:use :cl))

(in-package devterm-print-server)

(hunchentoot:define-easy-handler (index :uri "/") ()
  (uiop:read-file-string
   (merge-pathnames "index.html"
                    (asdf:system-source-directory :devterm-print-server))))

(defun set-font (noto-font-name)
  (with-open-file (out "/usr/local/etc/devterm-printer"
                       :direction :output
                       :if-exists :supersede)
    (format out "TTF=~A" noto-font-name)))

(hunchentoot:define-easy-handler (call-print :uri "/print") (encoding family size density content)
  (with-open-file (out "/tmp/DEVTERM_PRINTER_IN"
                       :direction :output
                       :if-exists :append)
    (cond ((string= family "sans") (set-font "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"))
          ((string= family "serif") (set-font "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc"))
          (t (set-font "/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf")))
    (uiop:run-program "systemctl restart devterm-printer")
    (if (string= encoding "ascii")
        (format out "~C~C~C" (code-char #x1b) #\! (code-char 0))
        (format out "~C~C~C" (code-char #x1b) #\! (code-char 1)))
    (format out "~C~C~C" (code-char #x1d) #\! (code-char (parse-integer size)))
    (format out "~C~C~C" (code-char #x12) #\# (code-char (parse-integer density)))
    (setq content (nsubstitute #\Newline #\Return content))
    (princ content out)
    (princ (make-string 18 :initial-element #\Newline) out))
  (setf (hunchentoot:content-type*) "text/plain")
  (format nil "Printing..."))

(defvar *acceptor* (make-instance 'hunchentoot:easy-acceptor :port 4242))

(hunchentoot:start *acceptor*)
(bt:join-thread (find-if (lambda (thread)
                           (uiop:string-prefix-p "hunchentoot"
                                                 (bt:thread-name thread)))
                         (bt:all-threads)))
