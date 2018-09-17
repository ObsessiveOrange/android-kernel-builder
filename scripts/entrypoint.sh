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
  -b, --branch <ARG>             checks out a specific branch, pulls and cleans before running
  -c, --clean                    cleans build directory before running
  -d, --debug-shell              drop into debug shell; will never run tests
  -n, --run-count <ARG>          runs the specified tests n times (without rebuild)
  -q, --quiet                    silences output from kernel tests
  -u, --uml                      force uml instead of qemu
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
mkdir -p /data/android-upper/kernel/tests/net/test
cp /data/android-ro/kernel/tests/net/test/net_test.rootfs* /data/android-upper/kernel/tests/net/test/

# Mount a copy-on-write OverlayFS to prevent things being written back to the host.
mount -t overlay overlay -o lowerdir=/data/android-ro,upperdir=/data/android-upper,workdir=/data/android-work /data/android
mount -t overlay overlay -o lowerdir=/data/kernel-ro,upperdir=/data/kernel-upper,workdir=/data/kernel-work /data/kernel

# Change to correct directory
cd /data/kernel

# Set defaults
RUN_COUNT=1
CRASH_LOG_LINES=50
exec 5>&1 # Store an output for subshells to tee back to the parent shell

# Default to using qemu
export ARCH="x86_64"
export DEFCONFIG="x86_64_cuttlefish_defconfig"

# Parse arguments
while [[ $# -ge 1 ]]; do
  case "$1" in
    -h|--help)
      usageAndExit
      ;;
    -b|--branch)
      checkArgOrExit $@
      git reset --hard
      git checkout "$2"
      git pull
      k-clean
      shift 2
      ;;
    -c|--clean)
      k-clean
      shift
      ;;
    -d|--debug-shell)
      bash
      shift
      exit 0
      ;;
    -n)
      checkArgOrExit $@
      RUN_COUNT=$2
      shift 2
      ;;
    -q|--quiet)
      exec 5>/dev/null
      shift
      ;;
    -u|--uml)
      unset ARCH
      unset DEFCONFIG
      ;;
    *)
      break
      ;;
  esac
done

n=0
SUCCESS_COUNTER=0
CRASH_COUNTER=0

# Set qmeu image if necessary:
if [ ! -z "$ARCH" ]; then
  pushd /data/android/kernel/tests/net/test/ &>/dev/null
  export ROOTFS=$(ls -r1 net_test.rootfs* | head -n1)
  popd &>/dev/null
  echo "Using qemu image $ROOTFS"
fi

until [ $n -ge $RUN_COUNT ]; do
  # Print run counter
  printf "\n\n\e[32mRun %d of %d\e[0m\n" $[n+1] $RUN_COUNT


  # Only build on first run
  if [ $n == 0 ]; then
    OUTPUT=$(/data/android/kernel/tests/net/test/run_net_test.sh "$@" 2>&1 | tee >(cat - >&5) | tail -n $CRASH_LOG_LINES)
  else
    OUTPUT=$(/data/android/kernel/tests/net/test/run_net_test.sh --nobuild "$@" 2>&1 | tee >(cat - >&5) | tail -n $CRASH_LOG_LINES)
  fi

  # Increment success counter if result was 0
  if [[ "$OUTPUT" == *"Kernel panic"* ]]; then
    printf "\e[33mLast $CRASH_LOG_LINES lines of output: \n-----\n$OUTPUT\n-----\n\e[0m"
    echo "System crashed."
    CRASH_COUNTER=$[$CRASH_COUNTER+1]

  elif [[ "$OUTPUT" != *"FAILED"* ]]; then
    echo "Success."
    SUCCESS_COUNTER=$[$SUCCESS_COUNTER+1]

  fi

  # Increment run counter
  n=$[$n+1]
  printf "\n\nCurrent stats: succeeded %d of %d times, with %d crashes\n" $SUCCESS_COUNTER $n $CRASH_COUNTER
done


# Pretty-print results:
if [ $SUCCESS_COUNTER == $RUN_COUNT ]; then
  MSG_COLOR='32'
else
  MSG_COLOR='31'
fi

printf "\n\n\e[%smTests succeeded %d of %d times, with %d crashes\e[0m\n" $MSG_COLOR $SUCCESS_COUNTER $RUN_COUNT $CRASH_COUNTER
exit 0
