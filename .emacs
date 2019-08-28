;; Turn off version control following
;; If this isn't set, it doesn't correctly load .emacs, which I have as a symlink
;; to a git repo
(setq vc-follow-symlinks nil)

;; Directory where .el packages are located
;;(add-to-list 'load-path "~/.emacs.d/packages")
;; undo-tree enables redo
;;(require `undo-tree)

;; Turn on ncua mode so ctrl+c, v, x work for copy, paste, cut
(cua-mode t)

;; create the autosave and backups dir if necessary, since emacs won't.
(make-directory "~/.emacs.d/backups/" t)
(make-directory "~/.emacs.d/autosaves/" t)

;; Move the default Backups
;; Put autosave files (ie #foo#) and backup files (ie foo~) in ~/.emacs.d/.
(custom-set-variables
  '(auto-save-file-name-transforms '((".*" "~/.emacs.d/autosaves/\\1" t)))
  '(backup-directory-alist '((".*" . "~/.emacs.d/backups/"))))

;; Always end a file with a newline
(setq require-final-newline t)

;; Set time format and display in mode line
(setq display-time-string-forms
      '(12-hours ":" minutes))
(display-time)

;; Turn Column Numbers On %%% (Line,Col)
(column-number-mode)

;; Setup Line numbers in the gutter
;; Adds some padding to the right of the line number
(defun linum-format-func (line)
  (let ((w (length (number-to-string (count-lines (point-min) (point-max))))))
     (propertize (format (format "%%%dd " w) line) 'face 'linum)))
(setq linum-format 'linum-format-func)
;; Turns gutter line numbers on
(global-linum-mode 1)

;; Disable the menu bar in the terminal
(menu-bar-mode -1)
(when (display-graphic-p)
  (menu-bar-mode 1))

(global-set-key (kbd "C-l") 'goto-line) ;; GoTo Line

;; set tabs to use 2 spaces instead of 4
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)
(setq tab-width 2)

;;turn on everywhere
;;(global-undo-tree-mode 1)
;;(global-set-key (kbd "C-/") 'undo)
;;(defalias 'redo 'undo-tree-redo)
;;(global-set-key (kbd "C-?") 'redo)

;; Move current line or selected text
(defun move-text-internal (arg)
  (cond
   ((and mark-active transient-mark-mode)
    (if (> (point) (mark))
        (exchange-point-and-mark))
    (let ((column (current-column))
          (text (delete-and-extract-region (point) (mark))))
      (forward-line arg)
      (move-to-column column t)
      (set-mark (point))
      (insert text)
      (exchange-point-and-mark)
      (setq deactivate-mark nil)))
   (t
    (let ((column (current-column)))
      (beginning-of-line)
      (when (or (> arg 0) (not (bobp)))
        (forward-line)
        (when (or (< arg 0) (not (eobp)))
          (transpose-lines arg)
          (when (and (eval-when-compile
                       '(and (>= emacs-major-version 24)
                             (>= emacs-minor-version 3)))
                     (< arg 0))
            (forward-line -1)))
        (forward-line -1))
      (move-to-column column t)))))

(defun move-text-down (arg)
    "Move region (transient-mark-mode active) or current line
  arg lines down."
    (interactive "*p")
    (move-text-internal arg))

(defun move-text-up (arg)
    "Move region (transient-mark-mode active) or current line
  arg lines up."
    (interactive "*p")
    (move-text-internal (- arg)))


(global-set-key [C-M-up] 'move-text-up)
(global-set-key [C-M-down] 'move-text-down)
