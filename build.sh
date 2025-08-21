#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

set -e

base_dir=$(cd "$(dirname "$0")"; pwd)

REGISTRY="quay.io"
ORGANIZATION="devspaces"
TAG="next"
DOCKERFILE="./build/dockerfiles/Dockerfile"
NODE_BUILD_OPTIONS="${NODE_BUILD_OPTIONS:-}"
BUILD_COMMAND="build"

OPENVSX_ASSET_SRC=openvsx-server.tar.gz
OPENVSX_ASSET_DEST="$base_dir"/openvsx-server.tar.gz
OPENVSX_BUILDER_IMAGE=che-openvsx:latest

OVSX_ASSET_SRC=opt/app-root/src/ovsx.tar.gz
OVSX_ASSET_DEST="$base_dir"/ovsx.tar.gz
OVSX_BUILDER_IMAGE=che-ovsx:latest

USAGE="
Usage: ./build.sh [OPTIONS]
Options:
    --help
        Print this message.
    --tag, -t [TAG]
        Docker image tag to be used for image; default: 'next'
    --registry, -r [REGISTRY]
        Docker registry to be used for image; default 'quay.io'
    --organization, -o [ORGANIZATION]
        Docker image organization to be used for image; default: 'eclipse'
"

function print_usage() {
    echo -e "$USAGE"
}

function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -t|--tag)
            TAG="$2"
            shift; shift;
            ;;
            -r|--registry)
            REGISTRY="$2"
            shift; shift;
            ;;
            -o|--organization)
            ORGANIZATION="$2"
            shift; shift;
            ;;
            *)
            print_usage
            exit 0
        esac
    done
}

parse_arguments "$@"

detectBuilder() {
    if [[ -z $BUILDER ]]; then
        echo "BUILDER not specified, trying with podman"
        BUILDER=$(command -v podman || true)
        if [[ ! -x $BUILDER ]]; then
            echo "[WARNING] podman is not installed, trying with buildah"
            BUILDER=$(command -v buildah || true)
            if [[ ! -x $BUILDER ]]; then
                echo "[WARNING] buildah is not installed, trying with docker"
                BUILDER=$(command -v docker || true)
                if [[ ! -x $BUILDER ]]; then
                    echo "[ERROR] neither docker, buildah, nor podman are installed. Aborting"; exit 1
                fi
            else
                BUILD_COMMAND="bud"
            fi
        fi
    else
        if [[ ! -x $(command -v "$BUILDER" || true) ]]; then
            echo "Builder $BUILDER is missing. Aborting."; exit 1
        fi
        if [[ $BUILDER =~ "docker" || $BUILDER =~ "podman" ]]; then
            if [[ ! $($BUILDER ps) ]]; then
                echo "Builder $BUILDER is not functioning. Aborting."; exit 1
            fi
        fi
        if [[ $BUILDER =~ "buildah" ]]; then
            BUILD_COMMAND="bud"
        fi
    fi
    echo "Build with $BUILDER $BUILD_COMMAND"
}

prepareOVSXPackagingAsset() {
    cd "$base_dir" || exit 1
    if [ -f "$OVSX_ASSET_DEST" ]; then
        echo "Removing '$OVSX_ASSET_DEST'"
        rm "$OVSX_ASSET_DEST"
    fi

    ${BUILDER} ${BUILD_COMMAND} --progress=plain -f build/dockerfiles/ovsx-installer.Dockerfile -t "$OVSX_BUILDER_IMAGE" .
    # shellcheck disable=SC2181
    if [[ $? -eq 0 ]]; then
        echo "Container '$OVSX_BUILDER_IMAGE' successfully built"
    else
        echo "Container OVSX build failed"
        exit 1
    fi

    extractFromContainer "$OVSX_BUILDER_IMAGE" "$OVSX_ASSET_SRC" "$OVSX_ASSET_DEST"
}

prepareOpenvsxPackagingAsset() {
    cd "$base_dir" || exit 1
    if [ -f "$OPENVSX_ASSET_DEST" ]; then
        echo "Removing '$OPENVSX_ASSET_DEST'"
        rm "$OPENVSX_ASSET_DEST"
    fi
 
    # get the tag of che-openvsx from build-config.json
    OPENVSX_VERSION=$(jq -r '.OPENVSX_VERSION' "${build_config_json}");

    # get Che Code version from build-config.json
    CHE_CODE_VERSION=$(jq -r '.CHE_CODE_VERSION' "${build_config_json}");

    ${BUILDER} ${BUILD_COMMAND} --progress=plain --no-cache -f build/dockerfiles/openvsx-builder.Dockerfile --build-arg CHE_CODE_VERSION="$CHE_CODE_VERSION" --build-arg OPENVSX_VERSION="$OPENVSX_VERSION" -t "$OPENVSX_BUILDER_IMAGE" .
     
    # shellcheck disable=SC2181
    if [[ $? -eq 0 ]]; then
        echo "Container '$OPENVSX_BUILDER_IMAGE' successfully built"
    else
        echo "Container Openvsx build failed"
        exit 1
    fi

    extractFromContainer "$OPENVSX_BUILDER_IMAGE" "$OPENVSX_ASSET_SRC" "$OPENVSX_ASSET_DEST"
}

# $1 is the container name
# $2 is the path to extract from the container
# $3 is the destination path to where located extracted path
extractFromContainer() {
    echo "Extract '$2' from '$1' container to '$3'"
    tmpContainer="$(echo "$1" | tr "/:" "--")-$(date +%s)"

    echo "Using temporary container '$tmpContainer'"
    ${BUILDER} create --name="$tmpContainer" "$1" sh >/dev/null 2>&1
    ${BUILDER} export "$tmpContainer" > "/tmp/$tmpContainer.tar"

    tmpDir="/tmp/$tmpContainer"
    echo "Created temporary directory '$tmpDir'"
    rm -rf "$tmpDir" || true
    mkdir -p "$tmpDir"

    echo "Trying to unpack container '$tmpContainer'"
    tar -xf "/tmp/$tmpContainer.tar" -C "$tmpDir" --no-same-owner "$2" || exit 1

    echo "Moving '$tmpDir/$2' to '$3'"
    mv "$tmpDir/$2" "$3"

    echo "Clean up the temporary container and directory"
    ${BUILDER} rm -f "$tmpContainer" >/dev/null 2>&1
    rm -rf "/tmp/$tmpContainer.tar"
    rm -rf "$tmpDir" || true
}

# delete images from the local cache
cleanupImages () {
    ${BUILDER} rmi -f "${OVSX_BUILDER_IMAGE}" "${OPENVSX_BUILDER_IMAGE}" || true
}

# load build-config.json file from ./
build_config_json="${base_dir}/build-config.json"

detectBuilder
# remove any leftovers from failed builds
cleanupImages

# create images and tarballs
prepareOVSXPackagingAsset
prepareOpenvsxPackagingAsset

echo "Build with $BUILDER $BUILD_COMMAND"
IMAGE="${REGISTRY}/${ORGANIZATION}/pluginregistry-rhel9:${TAG}"
# Copy to root directory to behave as if in Brew or devspaces-images
cp "${DOCKERFILE}" ./builder.Dockerfile
${BUILDER} ${BUILD_COMMAND} --progress=plain -t "${IMAGE}" -f ./builder.Dockerfile .
# Remove copied Dockerfile and tarred zip
rm ./builder.Dockerfile openvsx-server.tar.gz ovsx.tar.gz
# remove unneeded images from container registry
cleanupImages
