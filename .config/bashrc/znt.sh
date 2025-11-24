#!/bin/bash
# Zellij new-tab helper
# Opens a new Zellij tab in a project directory (mirrors cdgit logic)

function znt() {
  local spec="$1"
  local tabname="$2"
  local cwd="$HOME"

  if [[ -z "$spec" ]]; then
    cwd="$HOME"
  elif [[ "$spec" = /* && -d "$spec" ]]; then
    # absolute path escape hatch
    cwd="$spec"
  elif [[ "$spec" == *:* ]]; then
    # project:worktree -> $GITHOME/project/project.worktrees/worktree
    local project="${spec%%:*}"
    local wt="${spec#*:}"
    local wtpath="$GITHOME/$project/${project}.worktrees/$wt"
    if [[ -d "$wtpath" ]]; then
      cwd="$wtpath"
    else
      echo "znt: worktree not found: $wtpath" >&2
      return 1
    fi
  else
    # No colon: worktree-style project vs legacy
    local container="$GITHOME/$spec"
    local inner_clone="$container/$spec"
    local wt_dir="$container/${spec}.worktrees"

    if [[ -d "$inner_clone" || -d "$wt_dir" ]]; then
      # worktree project → prefer the inner clone dir
      if [[ -d "$inner_clone" ]]; then
        cwd="$inner_clone"
      else
        # inner clone missing; fall back to container
        cwd="$container"
      fi
    else
      # legacy repo (direct dir under $GITHOME)
      if [[ -d "$container" ]]; then
        cwd="$container"
      else
        echo "znt: repo not found: $container" >&2
        return 1
      fi
    fi
  fi

  zellij action new-tab --name "$2" --cwd "${cwd}" -l compact
}

# Use the shared _autoComplete_cdgit function from git.sh
complete -F _autoComplete_cdgit znt
