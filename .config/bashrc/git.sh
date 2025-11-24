#!/bin/bash
# Git home layout (supports legacy repos and worktree-style projects)
#
# $GITHOME/
# ├─ legacy-repo-A/                       # ← legacy clone (no special layout)
# │  └─ .git/
# ├─ legacy-repo-B/
# │  └─ .git/
# ├─ project-foo/                         # ← worktree *container* folder
# │  ├─ project-foo/                      #    primary clone (the "main" tree)
# │  │  └─ .git/
# │  └─ project-foo.worktrees/            #    holds all additional worktrees
# │     ├─ wt-feature-login/              #    worktree "wt-feature-login"
# │     │  └─ .git                        #    (git worktree metadata/dir link)
# │     └─ wt-bugfix-123/                 #    another worktree
# │        └─ .git
# └─ project-bar/
#    ├─ project-bar/
#    │  └─ .git/
#    └─ project-bar.worktrees/
#       └─ release-1.2.3/
#          └─ .git
#
# Notes
# - "Legacy" repos live directly under $GITHOME/<name> and act like normal clones.
# - "Worktree projects" live under a container: $GITHOME/<project>/
#      • Primary clone:           $GITHOME/<project>/<project>/
#      • Worktrees directory:     $GITHOME/<project>/<project>.worktrees/
#      • Individual worktrees:    $GITHOME/<project>/<project>.worktrees/<wtname>/
#
# Commands (custom)
# - cdgit <legacy>                → cd $GITHOME/<legacy>
# - cdgit <project>               → cd $GITHOME/<project>/<project>                   (primary clone)
# - cdgit <project>:<wtname>      → cd $GITHOME/<project>/<project>.worktrees/<wtname>
#
# - mkwt <project> <branch> [wt]  → create worktree at $GITHOME/<project>/<project>.worktrees/<wt or branch>
#                                   (auto-creates .worktrees, ensures branch, cds into new WT)
# - rmwt <project> <wtname>       → remove that worktree only (never deletes the .worktrees dir)
#
# Tab completion
# - cdgit <TAB>                   → lists legacy repos and worktree containers
# - cdgit <project>:<TAB>         → lists existing worktree names (suffix-only)
# - mkwt  <project> <TAB>         → branch names (local + origin/*)
# - rmwt  <project> <TAB>         → removable worktree names for that project
cdgit() {
  local spec="$1"

  if [[ -z "$spec" ]]; then
    cd -- "$GITHOME" || return
  else
    # Allow absolute/relative paths as an escape hatch
    if [[ "$spec" = /* || -d "$spec" ]]; then
      cd -- "$spec" || return
    elif [[ "$spec" == *:* ]]; then
      # project:worktree  ->  $GITHOME/project/project.worktrees/worktree
      local project="${spec%%:*}"
      local wt="${spec#*:}"
      local target="$GITHOME/$project/${project}.worktrees/$wt"
      if [[ -d "$target" ]]; then
        cd -- "$target" || return
      else
        printf 'cdgit: worktree not found: %s\n' "$target" >&2
        return 1
      fi
    else
      # No colon: decide legacy vs worktree-style container
      # Worktree-style if either inner clone or worktrees dir exists
      local container="$GITHOME/$spec"
      local inner_clone="$container/$spec"
      local wt_dir="$container/${spec}.worktrees"

      if [[ -d "$inner_clone" || -d "$wt_dir" ]]; then
        # Worktree project → go to inner clone: $GITHOME/project/project
        if [[ -d "$inner_clone" ]]; then
          cd -- "$inner_clone" || return
        else
          # Inner clone missing, but worktrees dir exists—fallback to container
          cd -- "$container" || return
        fi
      else
        # Legacy behavior → $GITHOME/project
        cd -- "$container" || return
      fi
    fi
  fi

  if [[ -f ".nvmrc" ]]; then
    nvm use
  fi
}
export -f cdgit
# ===== Shared helpers (DRY) =====
_gitproj_clone()   { echo "$GITHOME/$1/$1"; }
_gitproj_wtdir()   { echo "$GITHOME/$1/${1}.worktrees"; }

_gitproj_is_worktree_project() {
  local clone; clone="$(_gitproj_clone "$1")"
  [[ -d "$clone/.git" ]]
}

_gitproj_list_projects() {
  local d base
  for d in "$GITHOME"/*; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    [[ -d "$d/$base/.git" ]] && printf '%s\n' "$base"
  done
}

_gitproj_list_worktrees() {
  local project="$1" wtdir; wtdir="$(_gitproj_wtdir "$project")"
  [[ -d "$wtdir" ]] || return 0
  local wt
  for wt in "$wtdir"/*; do
    [[ -d "$wt" ]] || continue
    printf '%s\n' "$(basename "$wt")"
  done
}

_gitproj_list_branches() {
  local clone; clone="$(_gitproj_clone "$1")"
  [[ -d "$clone/.git" ]] || return 0
  git -C "$clone" for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin 2>/dev/null \
    | sed -E 's|^origin/||' | grep -v '^HEAD$' | sort -u
}

_gitproj_default_branch() {
  local clone="$1" default_ref default_branch
  default_ref=$(git -C "$clone" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) # origin/main
  default_branch="${default_ref#origin/}"
  if [[ -z "$default_branch" ]]; then
    for b in main master; do
      if git -C "$clone" show-ref --quiet "refs/heads/$b" \
         || git -C "$clone" ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
        default_branch="$b"; break
      fi
    done
  fi
  [[ -n "$default_branch" ]] || default_branch="main"
  printf '%s\n' "$default_branch"
}

_gitproj_ensure_branch_local() {
  local clone="$1" branch="$2"
  git -C "$clone" fetch --prune --quiet origin

  if ! git -C "$clone" show-ref --verify --quiet "refs/heads/$branch"; then
    if git -C "$clone" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
      git -C "$clone" branch --track "$branch" "origin/$branch" || return 1
    else
      local def; def="$(_gitproj_default_branch "$clone")"
      git -C "$clone" branch "$branch" "origin/$def" 2>/dev/null \
        || git -C "$clone" branch "$branch" "$def" || return 1
    fi
  fi

  # Force upstream = origin/<branch> (even if remote branch doesn't exist yet)
  git -C "$clone" branch --unset-upstream "$branch" 2>/dev/null || true
  git -C "$clone" config "branch.$branch.remote" origin
  git -C "$clone" config "branch.$branch.merge" "refs/heads/$branch"
}

# ===== mkwt =====
mkwt() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: mkwt <project> <branch> [worktree-name]" >&2
    return 2
  fi

  local project="$1"
  local branch="$2"

  # Robust defaulting for wtname (avoid ${3:-...} quirkiness across shells)
  local wtname
  if [[ -n "${3-}" ]]; then
    wtname="$3"
  else
    wtname="$branch"
  fi

  # Guard against empty/invalid names
  if [[ -z "$wtname" || "$wtname" == "." || "$wtname" == ".." ]]; then
    echo "mkwt: invalid worktree name '$wtname'." >&2
    return 1
  fi

  local container="$GITHOME/$project"
  local clone="$container/$project"
  local wtdir="$container/${project}.worktrees"
  local wtpath="$wtdir/$wtname"

  # Sanity checks
  if [[ ! -d "$clone/.git" ]]; then
    echo "mkwt: not a worktree-style repo: $clone" >&2
    echo "Expected: $GITHOME/<project>/<project>/.git" >&2
    return 1
  fi

  # Ensure worktrees dir exists
  mkdir -p "$wtdir" || return 1

  # Don't clobber
  if [[ -e "$wtpath" ]]; then
    echo "mkwt: target path already exists: $wtpath" >&2
    return 1
  fi

  # Make sure we have up-to-date refs
  git -C "$clone" fetch --prune --quiet origin

  # Detect remote default branch
  local default_ref default_branch
  default_ref=$(git -C "$clone" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  default_branch="${default_ref#origin/}"
  if [[ -z "$default_branch" ]]; then
    for b in main master; do
      if git -C "$clone" show-ref --quiet "refs/heads/$b" \
         || git -C "$clone" ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
        default_branch="$b"; break
      fi
    done
  fi
  [[ -n "$default_branch" ]] || default_branch="main"

  # Ensure branch exists locally (and set upstream appropriately)
  if git -C "$clone" show-ref --verify --quiet "refs/heads/$branch"; then
    : # local branch exists
  else
    if git -C "$clone" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
      # Remote branch exists → create local branch that tracks it
      git -C "$clone" branch --track "$branch" "origin/$branch" || return 1
    else
      # Remote branch does not exist → create from default
      local def; def="$(_gitproj_default_branch "$clone")"
      git -C "$clone" branch "$branch" "origin/$def" 2>/dev/null \
        || git -C "$clone" branch "$branch" "$def" \
        || { echo "mkwt: failed to create branch '$branch' from '$def'." >&2; return 1; }
    fi
  fi

  # Force upstream = origin/<branch> (even if remote branch doesn't exist yet)
  git -C "$clone" branch --unset-upstream "$branch" 2>/dev/null || true
  git -C "$clone" config "branch.$branch.remote" origin
  git -C "$clone" config "branch.$branch.merge" "refs/heads/$branch"

  echo "→ Creating worktree:"
  echo "   project:   $project"
  echo "   branch:    $branch"
  echo "   worktree:  $wtname"
  echo "   path:      $wtpath"

  # Create the worktree
  git -C "$clone" worktree add "$wtpath" "$branch" || return 1
  git -C "$clone" config "branch.$branch.remote" origin
  git -C "$clone" config "branch.$branch.merge" "refs/heads/$branch"
  echo "✔ Worktree created: $wtpath"

  # Auto-cd into the new worktree
  cd "$wtpath" || return
}
export -f mkwt


# ===== rmwt =====
rmwt() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: rmwt <project> <worktree-name> [--force|-f]" >&2
    return 2
  fi

  local project="$1" wtname="$2" force_flag="$3"
  if ! _gitproj_is_worktree_project "$project"; then
    echo "rmwt: not a worktree-style repo: $(_gitproj_clone "$project")" >&2
    return 1
  fi

  cdgit $1

  local clone wtdir wtpath
  clone="$(_gitproj_clone "$project")"
  wtdir="$(_gitproj_wtdir "$project")"
  wtpath="$wtdir/$wtname"

  if [[ ! -d "$wtpath" ]]; then
    echo "rmwt: worktree directory not found: $wtpath" >&2
    return 1
  fi

  case "$PWD/" in
    "$wtpath/"*) echo "rmwt: you are inside '$wtpath'. cd elsewhere first." >&2; return 1 ;;
  esac

  local registered=0
  if git -C "$clone" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' \
      | grep -Fx -- "$wtpath" >/dev/null 2>&1; then
    registered=1
  fi

  if (( registered )); then
    if [[ "$force_flag" == "--force" || "$force_flag" == "-f" ]]; then
      git -C "$clone" worktree remove --force "$wtpath" || return 1
    else
      if ! git -C "$clone" worktree remove "$wtpath"; then
        echo "rmwt: clean remove failed. Use '--force' to discard uncommitted changes." >&2
        return 1
      fi
    fi
  fi

  # extra guard: only delete subdir under .worktrees (never the container itself)
  if [[ -d "$wtpath" && "$wtpath" == "$wtdir/"* ]]; then
    rm -rf -- "$wtpath" || return 1
  fi

  echo "✔ Worktree removed: $wtpath"
}
export -f rmwt

# ===== Completions (reuse helpers) =====
_mkwt_complete() {
  COMPREPLY=()
  local cur="${COMP_WORDS[COMP_CWORD]}"

  case $COMP_CWORD in
    1)
      COMPREPLY=( $(compgen -W "$(_gitproj_list_projects)" -- "$cur") )
      ;;
    2)
      local project="${COMP_WORDS[1]}"
      COMPREPLY=( $(compgen -W "$(_gitproj_list_branches "$project")" -- "$cur") )
      ;;
    3)
      local project="${COMP_WORDS[1]}"
      local sugg="$(_gitproj_list_worktrees "$project")"$'\n'"${COMP_WORDS[2]}"
      COMPREPLY=( $(compgen -W "$sugg" -- "$cur") )
      ;;
  esac
}
complete -o nospace -F _mkwt_complete mkwt

_rmwt_complete() {
  COMPREPLY=()
  local cur="${COMP_WORDS[COMP_CWORD]}"

  case $COMP_CWORD in
    1)
      COMPREPLY=( $(compgen -W "$(_gitproj_list_projects)" -- "$cur") )
      ;;
    2)
      local project="${COMP_WORDS[1]}"
      COMPREPLY=( $(compgen -W "$(_gitproj_list_worktrees "$project")" -- "$cur") )
      ;;
    3)
      COMPREPLY=( $(compgen -W "--force -f" -- "$cur") )
      ;;
  esac
}
complete -o nospace -F _rmwt_complete rmwt

# for cdgit, autocompletes the directories under the github base
# Helpers used by completion
# Autocomplete for cdgit supporting "legacy" and "project:worktree"
_autoComplete_cdgit() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local line="${COMP_LINE:0:COMP_POINT}"
  local token="${line##*[[:space:]]}"   # last whitespace-delimited token

  # If token contains "project:...": complete worktree names (suffix-only)
  if [[ "$token" == *:* ]]; then
    local project="${token%%:*}"
    local suffix="${token#*:}"
    local wtdir="$GITHOME/$project/${project}.worktrees"

    # Collect worktree names from $GITHOME/project/project.worktrees/*
    local wts=()
    if [[ -d "$wtdir" ]]; then
      local wt
      for wt in "$wtdir"/*; do
        [[ -d "$wt" ]] || continue
        wts+=( "$(basename "$wt")" )
      done
    fi

    # If ":" is a wordbreak, Bash will keep "project:" and insert our suffix,
    # so return only the suffix matches.
    COMPREPLY=( $(compgen -W "${wts[*]}" -- "$suffix") )
    return
  fi

  # Otherwise: complete top-level projects / legacy repos in $GITHOME
  local projects=()
  local d
  for d in "$GITHOME"/*; do
    [[ -d "$d" ]] || continue
    projects+=( "$(basename "$d")" )
  done
  COMPREPLY=( $(compgen -W "${projects[*]}" -- "$cur") )
}

# Rebind
complete -r cdgit 2>/dev/null
complete -F _autoComplete_cdgit cdgit
