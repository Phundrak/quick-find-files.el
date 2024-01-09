;;; quick-find-files.el --- Quickly find files in directories and by extension -*- lexical-binding: t -*-

;; Author: Lucien Cartier-Tilet <lucien@phundrak.com>
;; Maintainer: Lucien Cartier-Tilet <lucien@phundrak.com>
;; Version: 0.3.0
;; Package-Requires: ((emacs "26"))
;; Homepage: https://labs.phundrak.com/phundrak/quick-find-files.el
;; Keywords: convenience

;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; quick-find-files.el is a utlity to quickly find files in a specific
;; directory, with maybe a specific file extension.  It can use both
;; the shell utilities find and fd to quickly find your files and let
;; you select the file you’re looking for in a completing read prompt.
;; Refer to the README for more information.

;;; Code:

                                        ; Group ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgroup quick-find-files nil
  "Quickly find files by directory and extension."
  :group 'convenience
  :prefix "quick-find-files-"
  :link '(url-link :tag "Repository" "https://labs.phundrak.com/phundrak/quick-find-files.el")
  :link '(url-link :tag "GitHub" "https://github.com/phundrak/quick-find-files.el"))

                                        ; Custom variables ;;;;;;;;;;;;;;;;;;;;

(defcustom quick-find-files-program 'find
  "Program to find files on your system.

By default, the value is \\='fd, but you can change it to
\\='find too.  For now, no other program is supported.

By default, `quick-find-files' will try to find fd or find in
your path.  You can customize the executable to use with
`quick-find-files-fd-executable' and
`quind-find-files-find-executable'."
  :group 'quick-find-files
  :type 'symbol
  :options '(fd find))

(defcustom quick-find-files-fd-executable (executable-find "fd")
  "Executable name or path to the executable of fd."
  :group 'quick-find-files
  :type 'string)

(defcustom quick-find-files-find-executable (executable-find "find")
  "Executable name or path to the executable of find."
  :group 'quick-find-files
  :type 'string)

(defcustom quick-find-files-dirs-and-exts nil
  "List of pairs of directories and extensions.

Each element should be a pair of a directory path and an
extension, such as

\\='((\"~/Documents/org/\" . \"org\"))"
  :group 'quick-find-files
  :type 'list)

(make-obsolete-variable 'quick-find-files-dirs-and-exts 'quick-find-files-dirs "0.3")

(defcustom quick-find-files-dirs nil
  "List of directories and their rules.

This is a list of property lists which contain at most three
properties:
- :dir (compulsory): a single path as a string which indicates
  the root directory in which to search for files
- :ext (optional): an array of strings listing what file
  extension to look for

- :ignored (optional): an array of paths as strings which
  indicates which paths to ignore (files or directories).
  Absolute paths are kept as is, while relative paths will be
  understood as paths beginning in the :dir path.  For instance:

    (:dir \"~/org\" :ignored \\='(\"~/org/config\" \"config2\"))

  is equivalent to

    (:dir \"~/org\" :ignored \\='(\"~/org/config\" \"~/org/config2\"))"
  :group 'quick-find-files
  :type 'list)

(defcustom quick-find-files-ignored-paths nil
  "List of paths to ignore.

If a file found matches at least one of these paths, or if one of
these paths is one of its ancestors, then the file is ignored."
  :group 'quick-find-files
  :type 'list)

(defcustom quick-find-files-fd-additional-options ""
  "Additional command line options for fd."
  :group 'quick-find-files
  :type 'string
  :safe #'stringp)

(defcustom quick-find-files-find-additional-options ""
  "Additional command line options for find."
  :group 'quick-find-files
  :type 'string)

(defcustom quick-find-files-completing-read #'completing-read
  "Completing read function.

The function must accept a prompt as its first argument and the
collection of elements to choose from as its second argument."
  :group 'quick-find-files
  :type 'function)

                                        ; Internal functions ;;;;;;;;;;;;;;;;;;

(defun quick-find-files--split-lines (str &optional omit-null)
  "Split a multilines `STR' into a list of strings.

If `OMIT-NULL' is non-null, ignore empty strings."
  (declare (side-effect-free t))
  (split-string str "\\(\r\n\\|[\n\r]\\)" omit-null))

(defun quick-find-files--normalize-ignored-paths (ignored-paths root-dir)
  "Normalize IGNORED-PATHS.

Change members of IGNORED-PATHS so that they are all absolute
paths.  Paths that are relative paths are considered to be
relative to ROOT-DIR."
  (when ignored-paths
    (mapcar (lambda (path)
              (expand-file-name path root-dir))
            ignored-paths)))

(defun quick-find-files--filter-out-files (files ignored-paths)
  "Remove files in FILES matching IGNORED-PATHS.

A file matches IGNORED-PATHS if any of the latter's paths equals
or is an ancestor of said file."
  (seq-filter (lambda (file)
                (not (seq-some (lambda (ignored-path)
                                 (or (equal file ignored-path)
                                     (string-prefix-p ignored-path file)))
                               ignored-paths)))
              files))

(defun quick-find-files--find-files (dir ext ignored-paths)
  "Find files in directory DIR with extension EXT.

If EXT is nil, return all files in DIR.

Ignore files matching IGNORED-PATHS.  See
`quick-find-files--filter-out-files' on how this argument is
used.

Use fd or find depending on `quick-find-files-program'.
Return files as a list of absolute paths."
  (declare (side-effect-free t))
  (let ((ignored-paths (quick-find-files--normalize-ignored-paths ignored-paths dir)))
    (quick-find-files--filter-out-files
     (quick-find-files--split-lines
      (shell-command-to-string
       (pcase quick-find-files-program
         ('fd (format "%s . %s %s -c never %s"
                      quick-find-files-fd-executable
                      dir
                      (if ext (concat "-e " ext) "")
                      quick-find-files-fd-additional-options))
         ('find (format "%s %s %s %s"
                        quick-find-files-find-executable
                        dir
                        (if ext (format "-name \"*.%s" ext) "")
                        quick-find-files-find-additional-options))
         (otherwise (error "Find program %s not implemented" otherwise)))))
     ignored-paths)))

                                        ; Public functions ;;;;;;;;;;;;;;;;;;;;

(defun quick-find-files-list-files (dir ext ignored-paths)
  "List files in directories and with specific extensions.

The directories and extensions are specified in the variable
`quick-find-files-dirs'.

If DIR is non-nil, search only in DIR for files with an extension
matching EXT.  If EXT is nil, return all files in DIR.

When DIR is non-nil, any file whose path matches or who is a
descendant of any value in IGNORED-PATHS will be filtered out.

If DIR is nil, use `quick-find-files-dirs' instead.

Return a list of paths to files."
  (declare (side-effect-free t))
  (if dir
      (quick-find-files--find-files dir ext ignored-paths)
    (mapcan (lambda (dir)
              (quick-find-files--find-files (plist-get dir :dir)
                                            (plist-get dir :ext)
                                            (plist-get dir :ignored)))
            quick-find-files-dirs)))

;;;###autoload
(defun quick-find-files (&optional arg dir extension ignored-paths)
  "Quickly find and open files in directories with specific extensions.

Directories in which to look for files with specific extensions
are specified in `quick-find-files-dirs'.

When called interactively with a prefix (i.e. non-nil ARG), ask
user for the root directory of their search and the file
extention they are looking for.  When the file extension is left
empty, all files are to be looked for.

DIR is the root directory in which files are searched for,
recursively.  If nil, the paths set in `quick-find-files-dirs'
will be used.

EXTENSION is the file extension to look for.  If it is nil, then
all files in DIR will be listed.  If DIR is nil, this argument
will be ignored.

IGNORED-PATHS will exclude all files matching at least one of
these paths."
  (interactive "P")
  (when arg
    (setq dir (read-file-name "Root directory: "))
    (setq extension (read-string "File extension (leave blank for all files): ")))
  (find-file (funcall quick-find-files-completing-read
                      "Open file: "
                      (quick-find-files-list-files dir
                                                   extension
                                                   ignored-paths))))

                                        ; Provides ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide 'quick-find-files)

;;; quick-find-files.el ends here
