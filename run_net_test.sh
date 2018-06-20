#!/bin/bash

function print-ok() { printf '\e[32m%s\e[0m\n' "$1"; }
function print-error() { printf '\e[31m%s\e[0m\n' "$1"; }
function check-var-set() {
 if [ -z "${!1}" ]; then
   print-error "Variable $1 must be provided."
   print-error "To set it, run \"export $1=<value>\", then try again";
   return -1
fi
}

ANDROID_REPO_HOME=$1
KERNEL_REPO_HOME=$2

check-var-set KERNEL_REPO_HOME || exit -1
check-var-set ANDROID_REPO_HOME || exit -1

echo "Running Kernel tests from $ANDROID_REPO_HOME, on $KERNEL_REPO_HOME"

# Use workaround with --privileged until new version of docker hits apt:
# Bug with /dev/shm and noexec flag: https://github.com/moby/moby/issues/6758
# Resolution of above bug: https://github.com/moby/moby/pull/35467
#
#docker run -it --rm \
#  --name uml-android \
#  --tmpfs /dev/shm:rw,nosuid,nodev,exec,size=1g \
#  --mount type=tmpfs,target=/data \
#  --mount type=bind,source=$KERNEL_REPO_HOME,target=/data/kernel-ro \
#  --mount type=bind,source=$ANDROID_REPO_HOME,target=/data/android-ro \
#  k-builder \
#  /scripts/entrypoint.sh "$@"
#'''

DATE=$(date +%s%6N)
grepstat=$(mktemp)

if [ -z "$(ps -o stat= -p $$ | grep +)" ]; then
  if [ -z "$(echo "$@" | grep builder)" ]; then
    print-error "Running in background without --builder flag will cause tests to hang. Exiting."
    exit -1
  fi
  docker run --rm \
    --privileged \
    --name "uml-android-$DATE" \
    --ipc=private \
    --shm-size="1g" \
    --mount type=tmpfs,target=/data \
    --mount type=bind,source=$KERNEL_REPO_HOME,target=/data/kernel-ro,readonly \
    --mount type=bind,source=$ANDROID_REPO_HOME,target=/data/android-ro,readonly \
    k-builder \
    /scripts/entrypoint.sh "${@:3}" &>/dev/null # Force builder; no terminal attached.
  RESULT=$?
else
  docker run -it --rm \
    --privileged \
    --name "uml-android-$DATE" \
    --ipc=private \
    --shm-size="1g" \
    --mount type=tmpfs,target=/data \
    --mount type=bind,source=$KERNEL_REPO_HOME,target=/data/kernel-ro,readonly \
    --mount type=bind,source=$ANDROID_REPO_HOME,target=/data/android-ro,readonly \
    k-builder \
    /scripts/entrypoint.sh "${@:3}" 2>&1 |
    tee >( grep -m1 'unregister_netdevice' >${grepstat} && docker kill "uml-android-$DATE"; )
  RESULT=$?
fi

if [ -s "$grepstat" ]; then
  print-error "TESTS HUNG - FAILED"
  exit 1
else
  echo "TESTS RAN FULLY"
  exit $RESULT
fi
