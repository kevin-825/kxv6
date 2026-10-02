#!/bin/bash
set -euo pipefail

# ==========================================
# 1. Global Definitions
# ==========================================
imgName="kflyn825/kxv6-dev:latest"
version="1.0"
dockerFileName="Dockerfile"

# ==========================================
# 2. Functions
# ==========================================


build_image() {
    local dockerfile="$1"
    local target_img="${2}"
    local target_ver="${3}"

    echo "=========================================="
    echo ">>> Building Image: ${target_img}"
    echo ">>> Dockerfile:     ${dockerfile}"
    echo ">>> Version:        ${target_ver}"
    echo "=========================================="

    docker buildx build \
        --builder default \
        --progress=plain \
        --pull=false \
        --load \
        -f "${dockerfile}" \
        -t "${target_img}" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VERSION="${target_ver}" \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -g)" \
        --build-arg USERNAME="$(id -u -n)" \
        --label maintainer="kflyn825@outlook.com" \
        --label version="${target_ver}" \
        .
}
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help      Show this help message and exit"
    echo "  -f, --file      Specify the Dockerfile to use (default: ${dockerFileName})"
    echo "  -t, --tag       Specify the image tag (default: ${imgName})"
    echo "  -v, --version   Specify the version (default: ${version})"
    echo ""
    echo "Example0:"
    echo "  $0 -f Dockerfile -t myimage:latest -v 1.0"
    echo ""
    echo "Example1: Build the default image"
    echo "  $0"
    echo ""
}
# ==========================================
# 3. Main Execution
# ==========================================
main() {
    local dockerfile="${dockerFileName}"
    local target_img="${imgName}"
    local target_ver="${version}"

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--file)
                dockerfile="$2"
                shift 2
                ;;
            -t|--tag)
                target_img="$2"
                shift 2
                ;;
            -v|--version)
                target_ver="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    build_image "${dockerfile}" "${target_img}" "${target_ver}"
}

main "$@"