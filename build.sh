#!/bin/bash

set -e

BUILDER_VERSION=43
FEDORA_VERSIONS=("42" "43")
ARCHES=("x86_64") #("aarch64" "x86_64")

SPEC_RELEASE=$(sed -n 's/^Version:[[:space:]]\+//p' nvidia-driver/nvidia-driver.spec)
export VERSION=${VERSION:-$SPEC_RELEASE}

if [ -z "$SKIP_TARBAL" ]; then
    pushd nvidia-driver
    ./nvidia-generate-tarballs.sh
    popd
fi

mkdir -p build/SPECS
cp -f ./nvidia-driver/nvidia-kmod-common*.tar.xz nvidia-kmod-common/

sudo podman build . --tag 'nvidia_builder' \
    --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
    --build-arg FEDORA_VERSION=${BUILDER_VERSION:-43}

compile() {
    sudo podman run --rm -v "$(pwd)/:/workspace" nvidia_builder \
        spectool -g -C $1 $1/$1.spec
    for arch in "${ARCHES[@]}"; do
        # sed version to $VERSION in case we want to run a diff. version
        SPEC_TMP=build/SPECS/$1-f${FEDORA_VERSION}-${arch}.spec
        cat $1/$1.spec | \
            sed -E "s/^Version:[[:space:]]+.+$/Version: ${VERSION}/gim" \
            > $SPEC_TMP

        mkdir -p ./build/MOCK/$arch
        sudo podman run --privileged --rm -v "$(pwd)/:/workspace" \
            -v "$(pwd)/build/MOCK/$arch:/var/lib/mock" nvidia_builder \
            mock -r fedora-${FEDORA_VERSION}-${arch} --arch=$arch \
                --resultdir /workspace/build/RPMS/$1-f${FEDORA_VERSION}-${arch} \
                --sources /workspace/$1 --spec /workspace/$SPEC_TMP
    done
}

for FEDORA_VERSION in "${FEDORA_VERSIONS[@]}"; do
    compile nvidia-driver
    compile nvidia-kmod-common
    compile nvidia-modprobe
    compile nvidia-persistenced
done

echo "$VERSION" > .driver-version