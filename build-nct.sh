#!/bin/bash

set -eoux pipefail

ARCH=$(uname -m)
FEDORA_VERSION=${FEDORA_VERSION:-43}

rm -rf build/NVT/centos8/$ARCH
mkdir -p build/NVT/centos8/$ARCH

export DOCKER="podman"
export PATH="$(pwd):$PATH"

# Required to grab the tag info from git
git -C ./nvidia-container-toolkit fetch --depth=200
git -C ./nvidia-container-toolkit/third_party/libnvidia-container fetch --depth=200

DIST_DIR="$(pwd)/build/NVT" \
    make -C ./nvidia-container-toolkit/third_party/libnvidia-container -f mk/docker.mk centos8-$ARCH
LIB_NAME="nct" DIST_DIR="$(pwd)/build/NVT" \
    make -C ./nvidia-container-toolkit LIB_TAG="" DOCKER=podman centos8-$ARCH
rm -rf ./build/RPMS/f$FEDORA_VERSION/nvt-$ARCH
mkdir -p ./build/RPMS/f$FEDORA_VERSION/nvt-$ARCH
mv build/NVT/centos8/$ARCH/*.rpm ./build/RPMS/f$FEDORA_VERSION/nvt-$ARCH