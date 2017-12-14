;;; helm-system-packages-dpkg.el --- Helm UI for Debian's dpkg. -*- lexical-binding: t -*-

;; Copyright (C) 2012 ~ 2014 Thierry Volpiatto <thierry.volpiatto@gmail.com>
;;               2017        Pierre Neidhardt <ambrevar@gmail.com>

;; Version: 1.6.9
;; Package-Requires: ((helm "2.8.6"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; Helm UI for dpkg.

;;; Code:
(require 'helm)

(defgroup helm-system-packages-dpkg nil
  "Predefined configurations for `helm.el'."
  :group 'helm)

(defun helm-system-packages-dpkg-list-explicit ()
  "List explicitly installed packages."
  (split-string (with-temp-buffer
                  (call-process "apt-mark" nil t nil "showmanual")
                  (buffer-string))))

(defun helm-system-packages-dpkg-list-dependencies ()
  "List packages installed as a dependency."
  (split-string (with-temp-buffer
                  (call-process "apt-mark" nil t nil "showauto")
                  (buffer-string))))

(defun helm-system-packages-dpkg-list-all ()
  "List all packages."
  (split-string (with-temp-buffer
                  (call-process "apt-cache" nil t nil "pkgnames")
                  (buffer-string))))

(defun helm-system-packages-dpkg-init ()
  "Cache package lists and create Helm buffer."
  (setq helm-system-packages--all
        (or helm-system-packages--all (helm-system-packages-dpkg-list-all))
        helm-system-packages--explicit
        (or helm-system-packages--explicit (helm-system-packages-dpkg-list-explicit))
        helm-system-packages--dependencies
        (or helm-system-packages--dependencies (helm-system-packages-dpkg-list-dependencies)))
  (unless (helm-candidate-buffer)
    (helm-init-candidates-in-buffer
        'global
      (with-temp-buffer
        (dolist (i helm-system-packages--all)
          (insert (concat i "\n")))
        (buffer-string)))))

(defun helm-system-packages-dpkg-print-url (_)
  "Print homepage URLs of `helm-marked-candidates'.

With prefix argument, insert the output at point.
Otherwise display in `helm-system-packages-buffer'."
  (let ((res (helm-system-packages-run "apt-cache" "show"))
        urls)
    (if (string-empty-p res)
        (message "No result")
      (setq urls
            (split-string
            (with-temp-buffer
              (insert res)
              (keep-lines "^Homepage: " (point-min) (point-max))
              (replace-regexp "^Homepage: " "")
              (delete-duplicate-lines (point-min) (point-max)) ; TODO: Can Helm do this?
              (buffer-string))))
      (if helm-current-prefix-arg
          (insert urls)
        (browse-url (helm-comp-read "URL: " urls :must-match t))))))

(setq helm-system-packages-dpkg-source ; TODO: Use defvar.
  (helm-build-in-buffer-source "dpkg source"
    :init 'helm-system-packages-dpkg-init
    :candidate-transformer 'helm-system-packages-highlight
    :action  '(("Show package(s)" .
                (lambda (_)
                  (helm-system-packages-print "apt-cache" "show")))
               ;; ("Copy in kill-ring" . kill-new) ; TODO: Helm can do this by default, right?
               ;; ("Insert at point" . insert) ; TODO: Helm can do this by default, right?
               ("Install" .
                (lambda (_)
                  (helm-system-packages-run-as-root "apt-get" "install")))
               ("Uninstall" .
                (lambda (_)
                  (helm-system-packages-run-as-root "apt-get" "autoremove")))
               ("Find files" .
                  ;; TODO: Use helm-read-file or similar?
                (lambda (_)
                  (helm-system-packages-print "dpkg" "-L")))
               ("Show dependencies" .
                (lambda (_)
                  (helm-system-packages-print "apt-cache" "depends")))
               ("Show reverse dependencies" .
                (lambda (_)
                  (helm-system-packages-print "apt-cache" "rdepends")))
               ("Browse homepage URL" . helm-system-packages-dpkg-print-url)
               ("Refresh" . (lambda (_)
                              ;; TODO: Re-use init function?
                              (setq helm-system-packages--all (helm-system-packages-dpkg-list-all)
                                    helm-system-packages--explicit (helm-system-packages-dpkg-list-explicit)
                                    helm-system-packages--dependencies (helm-system-packages-dpkg-list-dependencies)))))))

(defun helm-system-packages-dpkg ()
  "Preconfigured `helm' for dpkg."
  (helm-other-buffer '(helm-system-packages-dpkg-source)
                     "*helm dpkg*"))

(provide 'helm-system-packages-dpkg)

;;; helm-system-packages-dpkg.el ends here
