#!/bin/sh
lock() {
  swaylock
}

case "$1" in
  lock)
    lock
    ;;
  suspend)
    systemctl suspend && lock
    ;;
  hibernate)
    systemctl hibernate && lock
    ;;
  *)
    echo "Usage: $0 {lock|suspend}"
    exit 2
esac

exit 0

