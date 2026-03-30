#!/usr/bin/env bash
# Claude Code status line — mirrors Starship prompt style
# Receives JSON on stdin from Claude Code

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Git info (skip locks to avoid blocking)
git_branch=""
git_repo=""
git_worktree=""
in_git=false
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  in_git=true
  git_branch=$(git -C "$cwd" -c core.fsmonitor=false symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" -c core.fsmonitor=false rev-parse --short HEAD 2>/dev/null)

  # Repo name: use the common dir (points to main repo's .git even in worktrees)
  common_dir=$(git -C "$cwd" -c core.fsmonitor=false rev-parse --git-common-dir 2>/dev/null)
  # Resolve to absolute path, then go up one level to get the repo root
  common_dir_abs=$(cd "$cwd" && cd "$common_dir" 2>/dev/null && pwd)
  git_repo=$(basename "${common_dir_abs%/.git}" 2>/dev/null)

  # Worktree name: basename of the worktree root (empty if in main worktree)
  top_level=$(git -C "$cwd" -c core.fsmonitor=false rev-parse --show-toplevel 2>/dev/null)
  worktree_name=$(basename "$top_level" 2>/dev/null)
  # Only show worktree name if it differs from the repo name (i.e. we're in a linked worktree)
  if [ "$worktree_name" = "$git_repo" ]; then
    git_worktree=""
  else
    git_worktree="$worktree_name"
  fi

  # Gather status indicators (condensed, like starship git_status)
  git_flags=""
  git_status_output=$(git -C "$cwd" -c core.fsmonitor=false status --porcelain 2>/dev/null)
  ahead=$(git -C "$cwd" -c core.fsmonitor=false rev-list --count @{u}..HEAD 2>/dev/null || echo "")
  behind=$(git -C "$cwd" -c core.fsmonitor=false rev-list --count HEAD..@{u} 2>/dev/null || echo "")

  [ -n "$(echo "$git_status_output" | grep '^?? ')" ]  && git_flags="${git_flags}?"
  [ -n "$(echo "$git_status_output" | grep '^ M\|^MM\|^ D')" ] && git_flags="${git_flags}!"
  [ -n "$(echo "$git_status_output" | grep '^[MADRC][[:space:]]')" ] && git_flags="${git_flags}+"
  [ -n "$ahead" ] && [ "$ahead" -gt 0 ] && git_flags="${git_flags}⇡${ahead}"
  [ -n "$behind" ] && [ "$behind" -gt 0 ] && git_flags="${git_flags}⇣${behind}"
fi

# Build output with ANSI colors (terminal renders these dimmed)
out=""

if [ "$in_git" = true ]; then
  # git: repo name (bold cyan)
  out="${out}\033[2mgit:\033[0m \033[1;36m${git_repo}\033[0m"

  # branch: name (purple)
  if [ -n "$git_branch" ]; then
    out="${out} \033[2mbranch:\033[0m \033[35m${git_branch}\033[0m"
  fi

  # wt: worktree name (dim cyan)
  if [ -n "$git_worktree" ]; then
    out="${out} \033[2mwt:\033[0m \033[2;36m${git_worktree}\033[0m"
  fi

  # Status flags (red)
  if [ -n "$git_flags" ]; then
    out="${out} \033[31m[${git_flags}]\033[0m"
  fi
else
  # Not in a git repo — show full directory (bold cyan)
  if [ -n "$cwd" ]; then
    out="${out}\033[2mdir:\033[0m \033[1;36m${cwd}\033[0m"
  fi
fi


# Context window usage
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  if [ "$used_int" -ge 80 ]; then
    color="\033[31m"  # red
  elif [ "$used_int" -ge 50 ]; then
    color="\033[33m"  # yellow
  else
    color="\033[32m"  # green
  fi
  out="${out} \033[2mctx:\033[0m ${color}${used_int}%\033[0m"
fi

printf "%b" "$out"
