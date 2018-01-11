#!/bin/bash

function print-error() { printf '\e[31m%s\e[0m\n' "$1"; }
function check-var-set() {
 if [ -z "${!1}" ]; then
   print-error "Variable $1 must be provided."
   print-error "To set it, run \"export $1=<value>\", then try again";
   return -1
fi
}

check-var-set KERNEL_REPO_HOME || exit -1
check-var-set ANDROID_REPO_HOME || exit -1


# Use workaround with --privileged until new version of docker hits:
# Bug with /dev/shm and noexec flag: https://github.com/moby/moby/issues/6758
# Resolution of above bug: https://github.com/moby/moby/pull/35467
#
#docker run -it --rm \
#  --name uml-android \
#  --tmpfs /dev/shm:rw,nosuid,nodev,exec,size=1g \
#  --mount type=bind,source=$KERNEL_REPO_HOME,target=/data/kernel \
#  --mount type=bind,source=$ANDROID_REPO_HOME,target=/data/aosp \
#  k-builder \
#  /scripts/entrypoint.sh "$@"
#'''

docker run -it --rm \
  --privileged \
  --name uml-android \
  --ipc=private \
  --shm-size="1g" \
  --mount type=bind,source=$KERNEL_REPO_HOME,target=/data/kernel \
  --mount type=bind,source=$ANDROID_REPO_HOME,target=/data/aosp \
  k-builder \
  /scripts/entrypoint.sh "$@"

