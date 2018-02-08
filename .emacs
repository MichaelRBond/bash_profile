;; Turn off version control following
;; If this isn't set, it doesn't correctly load .emacs, which I have as a symlink
;; to a git repo
(setq vc-follow-symlinks nil)

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

;; Set time format anad display in mode line
(setq display-time-string-forms
      '(24-hours ":" minutes))
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
