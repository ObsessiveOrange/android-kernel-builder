#!/bin/bash

function checkArgOrExit() {
  if [[ $# -lt 2 ]]; then
    echo "Missing argument for option $1"
    exit 1
  fi
}

function usageAndExit() {
  cat >&2 << HERE_DOCUMENT_DELIMITER
  entrypoint.sh - wrapper for run_net_test.sh that configures environment

  entrypoint.sh [entrypoint.sh options] [run_net_test.sh options]

  options:
  -h, --help                     show this menu
  -c, --clean                    cleans build directory before running
  -b, --branch                   checks out a specific branch, pulls and cleans before running
HERE_DOCUMENT_DELIMITER
  exit 0
}

function k-clean() {
  make distclean
  make mrproper
  git clean -fx
}

# Parse arguments
while [ -n "$1" ]; do
  case "$1" in
    -h|--help)
      usageAndExit
      ;;
    -c|--clean)
      k-clean
      shift
      ;;
    -b|--branch)
      checkArgOrExit $@
      git reset --hard
      git checkout "$2"
      git pull
      k-clean
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

# Temporary workaround for https://github.com/moby/moby/issues/6758
mount -o remount,exec /dev/shm

/data/aosp/kernel/tests/net/test/run_net_test.sh "$@"
