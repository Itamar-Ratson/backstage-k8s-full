#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <overlay-file> <image-repository> <image-tag>" >&2
}

if [ "$#" -ne 3 ]; then
  usage
  exit 2
fi

overlay_file="$1"
IMAGE_REPOSITORY="$2"
IMAGE_TAG="$3"
repository_path="${BUMP_REPOSITORY_PATH:-.image.repository}"
tag_path="${BUMP_TAG_PATH:-.image.tag}"
export IMAGE_REPOSITORY IMAGE_TAG

if [ ! -f "$overlay_file" ]; then
  echo "not found: $overlay_file" >&2
  exit 1
fi

yq -i \
  "$repository_path = strenv(IMAGE_REPOSITORY) | $tag_path = strenv(IMAGE_TAG)" \
  "$overlay_file"
