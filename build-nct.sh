#!/bin/bash

set -eoux pipefail

ARCH=${ARCH:-x86_64}
FEDORA_VERSION=${FEDORA_VERSION:-43}

rm -rf build/NVT/centos8/$ARCH
mkdir -p build/NVT/centos8/$ARCH

DOCKER="podman" LIB_NAME="nct" DIST_DIR="$(pwd)/build/NVT" \
    make -C ./nvidia-container-toolkit LIB_TAG="" centos8-$ARCH
DOCKER="podman" DIST_DIR="$(pwd)/build/NVT" \
    make -C ./nvidia-container-toolkit/third_party/libnvidia-container -f mk/docker.mk centos8-$ARCH

rm -rf ./build/RPMS/f$FEDORA_VERSION/nvt-$ARCH
mkdir -p ./build/RPMS/f$FEDORA_VERSION/nvt-$ARCH
mv build/NVT/centos8/$ARCH/*.rpm ./build/RPMS/f$FEDORA_VERSION/nvt-$ARCH