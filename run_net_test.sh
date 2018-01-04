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

docker run --name uml-android -it --rm --privileged -v /dev/shm:/dev/shm -v $KERNEL_REPO_HOME:/data/kernel -v $ANDROID_REPO_HOME:/data/aosp k-builder /data/aosp/kernel/tests/net/test/run_net_test.sh "$@"
