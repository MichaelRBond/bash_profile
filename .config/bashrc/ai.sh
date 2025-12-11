#!/bin/bash

cr() {
  local branch="${1:-main}"
  codex review --base "$branch"
}
