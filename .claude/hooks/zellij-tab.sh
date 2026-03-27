#!/usr/bin/env bash
[[ -z "$ZELLIJ" ]] && exit 0

MODE=$1
STATE_DIR="/tmp/zellij-claude-tab"
STATE_FILE="${STATE_DIR}/${ZELLIJ_SESSION_NAME}-${PPID}"

strip_prefix() {
  echo "$1" | sed 's/^🤔 //' | sed 's/^✅ //'
}

get_active_tab() {
  # dump-layout's tab with focus=true is the actually visible tab
  local line
  line=$(zellij action dump-layout 2>/dev/null \
    | grep '^\s*tab ' \
    | grep -n 'focus=true' \
    | head -1)
  [[ -z "$line" ]] && return 1

  # extract 0-indexed position and tab name
  local pos name
  pos=$(( $(echo "$line" | cut -d: -f1) - 1 ))
  name=$(echo "$line" | sed 's/.*name="\([^"]*\)".*/\1/')

  # map position to tab_id via list-panes
  local tab_id
  tab_id=$(zellij action list-panes --json --tab 2>/dev/null \
    | python3 -c "
import sys, json
panes = json.load(sys.stdin)
for p in panes:
    if p.get('tab_position') == $pos:
        print(p['tab_id'])
        break
")

  [[ -z "$tab_id" ]] && return 1
  echo "$tab_id"
  echo "$name"
}

case "$MODE" in
  start)
    INFO=$(get_active_tab)
    [[ $? -ne 0 ]] && exit 0
    TAB_ID=$(echo "$INFO" | sed -n '1p')
    TAB_NAME=$(echo "$INFO" | sed -n '2p')
    [[ -z "$TAB_ID" || -z "$TAB_NAME" ]] && exit 0
    CLEAN=$(strip_prefix "$TAB_NAME")
    [[ -z "$CLEAN" ]] && exit 0
    mkdir -p "$STATE_DIR"
    echo "${TAB_ID}" > "$STATE_FILE"
    echo "${CLEAN}" >> "$STATE_FILE"
    zellij action rename-tab "🤔 $CLEAN"
    ;;

  stop)
    INPUT=$(cat)
    echo "$INPUT" | grep -q '"stop_hook_active": true' && exit 0
    [[ ! -f "$STATE_FILE" ]] && exit 0
    TAB_ID=$(sed -n '1p' "$STATE_FILE")
    CLEAN=$(sed -n '2p' "$STATE_FILE")
    rm -f "$STATE_FILE"
    [[ -z "$TAB_ID" || -z "$CLEAN" ]] && exit 0
    zellij action rename-tab --tab-id "$TAB_ID" "✅ $CLEAN"
    ;;
esac
