#!/bin/sh
lock() {
  i3lock
}

case "$1" in
  lock)
    lock
    ;;
  suspend)
    lock && systemctl suspend
    ;;
  *)
    echo "Usage: $0 {lock|suspend}"
    exit 2
esac

exit 0

