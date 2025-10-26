#!/bin/bash

set -e

FEDORA_VERSION=${FEDORA_VERSION:-43}

# Create buildah from scratch
BOCI=$(buildah from scratch)

# Trap to remove on errors
trap 'buildah rm $BOCI' ERR

# Mount the filesystem
MOCI=$(buildah mount $BOCI)

# Copy rpms from ./build/RPMS/fVER for each fVER
for DIR in ./build/RPMS/f${FEDORA_VERSION}/*; do
    if [ ! -d "$DIR" ]; then
        continue
    fi

    # Copy only binary RPMs (exclude src.rpm) directly into rpms/
    find "$DIR" -type f -name "*.rpm" ! -name "*.src.rpm" -exec cp -t "$MOCI/" {} +
done

# Unmount the filesystem
buildah unmount $BOCI

# Commit the image
buildah commit $BOCI nvidia-oci-f${FEDORA_VERSION}

# Get digest
DIGEST=$(buildah images --noheading --format "{{.Digest}}" nvidia-oci-f${FEDORA_VERSION})
echo "OCI Image created with digest: $DIGEST"

echo $DIGEST > .oci-digest