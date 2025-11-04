#!/bin/bash

set -eoux pipefail

FEDORA_VERSION=${FEDORA_VERSION:-43}
BUILDER_VERSION=${BUILDER_VERSION:-$FEDORA_VERSION}
BUILD_ARM=${BUILD_ARM:-}
SKIP_TARBAL=${SKIP_TARBAL:-}

if [ -n "$BUILD_ARM" ]; then
    ARCHES=("aarch64")
    DRV_ARCHES=("aarch64")
else
    ARCHES=("x86_64")
    DRV_ARCHES=("i386" "x86_64")
fi

SPEC_RELEASE=$(sed -n 's/^Version:[[:space:]]\+//p' nvidia-driver/nvidia-driver.spec)
export VERSION=${VERSION:-$SPEC_RELEASE}

if [ -z "$SKIP_TARBAL" ]; then
    pushd nvidia-driver
    ARCHES="$(uname -m)" bash ./nvidia-generate-tarballs.sh
    popd
fi

mkdir -p build/SPECS
cp -f ./nvidia-driver/nvidia-kmod-common*.tar.xz nvidia-kmod-common/
cp -f ./nvidia-driver/nvidia-kmod*.tar.xz nvidia-kmod/

sudo podman build . --tag 'nvidia_builder' \
    --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
    --build-arg FEDORA_VERSION=${BUILDER_VERSION:-43}

compile() {
    SPEC_TMP=build/SPECS/$1-f${FEDORA_VERSION}/$1.spec
    mkdir -p $(dirname $SPEC_TMP)
    cat $1/$1.spec | \
        sed -E "s/^Version:[[:space:]]+.+$/Version: ${VERSION}/gim" \
        > $SPEC_TMP
    sudo podman run --rm -v "$(pwd)/:/workspace" nvidia_builder \
        spectool -g -C $1 $SPEC_TMP
    
    if [ "$1" == "nvidia-driver" ]; then
        arches=("${DRV_ARCHES[@]}")
    else
        arches=("${ARCHES[@]}")
    fi

    for arch in "${arches[@]}"; do
        # sed version to $VERSION in case we want to run a diff. version
        # nvidia-kmod.spec really wants to be named that, so use a subdir
        mkdir -p ./build/MOCK/$arch
        sudo podman run --privileged --rm -v "$(pwd)/:/workspace" \
            -v "$(pwd)/build/MOCK/$arch:/var/lib/mock" nvidia_builder \
            mock -r fedora-${FEDORA_VERSION}-${arch} --arch=$arch \
                --resultdir /workspace/build/RPMS/f${FEDORA_VERSION}/$1-${arch} \
                --sources /workspace/$1 --spec /workspace/$SPEC_TMP --verbose
    done
}

# compile nvidia-kmod
compile nvidia-kmod-common
compile nvidia-modprobe
compile nvidia-persistenced
compile nvidia-driver

echo "$VERSION" > .driver-version