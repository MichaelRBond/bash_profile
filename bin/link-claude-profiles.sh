#!/usr/bin/env bash
#
# Point per-client Claude Code profile directories at ~/.claude so that
# skills, rules, hooks, commands and settings are shared, while each
# profile keeps its own login and session state.
#
# Usage:  ./link-claude-profiles.sh
#         ./link-claude-profiles.sh --dry-run
#
set -euo pipefail

SHARED="$HOME/.claude"

# ---------------------------------------------------------------------------
# One entry per client. Add or remove as needed.
# ---------------------------------------------------------------------------
PROFILES=(
  "$HOME/.claude-personal"
)

# ---------------------------------------------------------------------------
# Directories you author. Created in ~/.claude if absent, then linked.
# ---------------------------------------------------------------------------
SHARED_DIRS=(
  skills
  commands
  agents
  rules
  workflows
  hooks
  status-lines
  output-styles
  themes
)

# ---------------------------------------------------------------------------
# Files you author. Linked only if they already exist in ~/.claude.
# ---------------------------------------------------------------------------
SHARED_FILES=(
  CLAUDE.md
  settings.json
  keybindings.json
)

# ---------------------------------------------------------------------------
# Shared but higher risk — see the notes at the bottom of this file.
# Set to 0 to leave plugins independent per profile.
# ---------------------------------------------------------------------------
SHARE_PLUGINS=1

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

STAMP="$(date +%Y%m%d-%H%M%S)"

run() {
  if (( DRY_RUN )); then
    printf '   would: %s\n' "$*"
  else
    "$@"
  fi
}

link_item() {
  local profile="$1" name="$2"
  local src="$SHARED/$name"
  local dst="$profile/$name"

  [[ -e "$src" ]] || return 0

  # Already pointing where we want it.
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    printf '   ok    %s\n' "$name"
    return 0
  fi

  # Something real is in the way — move it aside rather than delete it.
  if [[ -e "$dst" || -L "$dst" ]]; then
    printf '   move  %s -> %s.bak-%s\n' "$name" "$name" "$STAMP"
    run mv "$dst" "$dst.bak-$STAMP"
  fi

  printf '   link  %s\n' "$name"
  run ln -s "$src" "$dst"
}

# --- sanity checks ---------------------------------------------------------

if [[ ! -d "$SHARED" ]]; then
  echo "error: $SHARED does not exist. Run 'claude' once first." >&2
  exit 1
fi

for profile in "${PROFILES[@]}"; do
  if [[ "$(cd "$profile" 2>/dev/null && pwd -P || echo "$profile")" == "$(cd "$SHARED" && pwd -P)" ]]; then
    echo "error: profile '$profile' resolves to the shared directory." >&2
    exit 1
  fi
done

# --- make sure the shared directories exist --------------------------------

for d in "${SHARED_DIRS[@]}"; do
  run mkdir -p "$SHARED/$d"
done

# --- link each profile -----------------------------------------------------

ITEMS=( "${SHARED_DIRS[@]}" "${SHARED_FILES[@]}" )
(( SHARE_PLUGINS )) && ITEMS+=( plugins )

for profile in "${PROFILES[@]}"; do
  printf '\n%s\n' "$profile"
  run mkdir -p "$profile"
  for name in "${ITEMS[@]}"; do
    link_item "$profile" "$name"
  done
done

printf '\nDone.\n'
if (( DRY_RUN )); then
  printf 'Dry run only — nothing was changed.\n'
else
  cat <<'EOF'

Next steps:
  1. Add a launcher per client to ~/.zshrc, for example:

       claude-acme()   { CLAUDE_CONFIG_DIR="$HOME/.claude-acme"   command claude "$@"; }
       claude-globex() { CLAUDE_CONFIG_DIR="$HOME/.claude-globex" command claude "$@"; }

  2. Run each one once and complete /login with that client's account.
  3. Run /status inside a session to confirm the account and the
     "Setting sources" line.

Deliberately NOT linked — these are per-account or per-session:

  .claude.json            OAuth session, project trust, personal MCP servers
  backups/                snapshots of .claude.json
  policy-limits.json      cached org policy for THIS account
  remote-settings.json    cached managed settings for THIS org
  stats-cache.json        /usage totals for this account
  mcp-needs-auth-cache.json
  projects/  history.jsonl  file-history/  sessions/  session-env/
  shell-snapshots/  tasks/  plans/  paste-cache/  debug/  telemetry/
  cache/  downloads/  config/

Two things to watch:

  settings.json  Claude Code writes to this file when you use /config or
                 commands like /effort and /fast. If a write replaces the
                 symlink with a real file, the profiles drift apart. Check
                 with:  ls -l ~/.claude-*/settings.json

  plugins/       Shared so that enabledPlugins in settings.json resolves
                 everywhere. Install and update plugins from your default
                 profile only, and not while another profile is running.
                 Set SHARE_PLUGINS=0 above to keep them separate instead.
EOF
fi
