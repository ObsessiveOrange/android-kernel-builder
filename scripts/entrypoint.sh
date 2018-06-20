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

# Temporary workaround for https://github.com/moby/moby/issues/6758
mount -o remount,exec /dev/shm

# Create mount and overlay attach points
mkdir -p /data/android
mkdir -p /data/android-upper
mkdir -p /data/android-work
mkdir -p /data/kernel
mkdir -p /data/kernel-upper
mkdir -p /data/kernel-work

# Prevents tests from hanging; I believe it's something to do with the UML
# kernel attempting to write back, and probably waiting for the file to appear.
# This would then fail because of the copy-on-write.
ROOTFS_NAME=$(ls /data/android-ro/kernel/tests/net/test | grep net_test.rootfs*)
if [ ! -z "$ROOTFS_NAME" ]; then
  echo $ROOTFS_NAME
  mkdir -p /data/android-upper/kernel/tests/net/test
  cp /data/android-ro/kernel/tests/net/test/$ROOTFS_NAME /data/android-upper/kernel/tests/net/test/$ROOTFS_NAME
fi

# Mount a copy-on-write OverlayFS to prevent things being written back to the host.
mount -t overlay overlay -o lowerdir=/data/android-ro,upperdir=/data/android-upper,workdir=/data/android-work /data/android
mount -t overlay overlay -o lowerdir=/data/kernel-ro,upperdir=/data/kernel-upper,workdir=/data/kernel-work /data/kernel

# Change to correct directory
cd /data/kernel

RUN_COUNT=1

# Parse arguments
while [[ $# -ge 1 ]]; do
  case "$1" in
    -h|--help)
      usageAndExit
      ;;
    -c|--clean)
      k-clean
      shift
      ;;
    -n)
      checkArgOrExit $@
      RUN_COUNT=$2
      shift 2
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

n=0
SUCCESS_COUNTER=0

until [ $n -ge $RUN_COUNT ]; do
  # Print run counter
  printf "\n\n\e[32mRun %d of %d\e[0m\n" $[n+1] $RUN_COUNT

  # Only build on first run
  if [ $n == 0 ]; then
    /data/android/kernel/tests/net/test/run_net_test.sh "$@"
  else
    /data/android/kernel/tests/net/test/run_net_test.sh --nobuild "$@"
  fi

  # Increment success counter if result was 0
  RES=$?
  echo "RESULT: $RES"
  if [ $RES == 0 ]; then
    SUCCESS_COUNTER=$[$SUCCESS_COUNTER+1]
  fi

  # Increment run counter
  n=$[$n+1]
  sleep 1
done


# Pretty-print results:
if [ $SUCCESS_COUNTER == $RUN_COUNT ]; then
  MSG_COLOR='32'
else
  MSG_COLOR='31'
fi

printf "\n\n\e[%smTests succeeded %d of %d times\e[0m\n" $MSG_COLOR $SUCCESS_COUNTER $RUN_COUNT
exit 0
