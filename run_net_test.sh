#!/bin/bash

docker run -it --rm -v /dev/shm:/dev/shm -v $KERNEL_REPO_HOME:/data/kernel -v $ANDROID_REPO_HOME:/data/aosp k-builder /data/aosp/kernel/tests/net/test/run_net_test.sh "$@"
