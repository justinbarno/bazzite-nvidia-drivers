#!/bin/bash

set -eoux pipefail

FEDORA_VERSION=${FEDORA_VERSION:-43}
BUILDER_VERSION=${BUILDER_VERSION:-$FEDORA_VERSION}
BUILD_ARM=${BUILD_ARM:-}
SKIP_TARBAL=${SKIP_TARBAL:-}
LEGACY=${LEGACY:-}

if [ -n "$BUILD_ARM" ]; then
    ARCHES=("aarch64")
    DRV_ARCHES=("aarch64")
    SKIP_SOURCES="(i386|x86_64)"
else
    ARCHES=("x86_64")
    DRV_ARCHES=("i386" "x86_64")
    SKIP_SOURCES="aarch64"
fi

if [ -n "$LEGACY" ]; then
    prefix="nvidia-580/"
else
    prefix=""
fi

SPEC_RELEASE=$(sed -n 's/^Version:[[:space:]]\+//p' ${prefix}nvidia-driver/nvidia-driver.spec)
export VERSION=${VERSION:-$SPEC_RELEASE}

if [ -z "$SKIP_TARBAL" ]; then
    pushd ${prefix}nvidia-driver
    ARCHES="$(uname -m)" bash ./nvidia-generate-tarballs.sh
    popd
fi

mkdir -p build/SPECS
cp -f ${prefix}nvidia-driver/nvidia-kmod-common*.tar.xz ${prefix}nvidia-kmod-common/
cp -f ${prefix}nvidia-driver/nvidia-kmod*.tar.xz ${prefix}nvidia-kmod/

sudo podman build . --tag 'nvidia_builder' \
    --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
    --build-arg FEDORA_VERSION=${BUILDER_VERSION:-43}

compile() {
    if [ -n "$LEGACY" ]; then
        target_dir="nvidia-580/$1"
        target_fn="nvidia-580-$1"
    else
        target_dir="$1"
        target_fn="$1"
    fi

    SPEC_TMP=build/SPECS/$target_fn-f${FEDORA_VERSION}/$1.spec
    mkdir -p $(dirname $SPEC_TMP)

    cat $target_dir/$1.spec | \
        sed -E "s/^Version:[[:space:]]+.+$/Version: ${VERSION}/gim" | \
        sed -E "s/Source[0-9]+:[[:space:]].+$SKIP_SOURCES.tar.xz//gim" \
        > $SPEC_TMP
    sudo podman run --rm -v "$(pwd)/:/workspace" nvidia_builder \
        spectool -g -C $target_dir $SPEC_TMP
    
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
                --resultdir /workspace/build/RPMS/f${FEDORA_VERSION}/$target_fn-${arch} \
                --sources /workspace/$target_dir --spec /workspace/$SPEC_TMP --verbose
    done
}

compile nvidia-kmod
compile nvidia-kmod-common
compile nvidia-settings
compile nvidia-modprobe
compile nvidia-persistenced
compile nvidia-driver

echo "$VERSION" > .driver-version