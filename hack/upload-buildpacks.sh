#!/usr/bin/env bash

# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu

publish=${PUBLISH:-false}

readonly registry=${1:?Error: Please supply a registry}
shift

readonly version=${1:-latest}

rootpath=$(cd "$(dirname "$0")/.." && pwd)
dir=${rootpath}/builder

builder_config=${dir}/builder.toml
builder_image="${registry}/buildpack-builder:${version}"

# Create a temp directory so we can manipulate the builder.toml. We can't
# simply use a temp file "<(...)" because the builder.toml could have relative
# paths to the buildpacks.
temp_dir=$(mktemp -d)
function finish {
  rm -rf "${temp_dir}"
}
trap finish EXIT
cp -r "$rootpath/builder"/* "$temp_dir"


build_pack(){
  PACK_VERSION=v0.4.1
  PACK_SHA256=fde82abd696600a79da07795d7a3f55d17ac40703c1c33c5f2b77ee3305171df
  curl -LJo "${temp_dir}/pack.tar.gz" https://github.com/buildpack/pack/releases/download/${PACK_VERSION}/pack-${PACK_VERSION}-linux.tgz
  tar xfz "${temp_dir}/pack.tar.gz" -C "${temp_dir}"
  [ "$PACK_SHA256" = "$(sha256sum < "${temp_dir}/pack.tar.gz" | cut -d' ' -f1)" ]
}

run_pack(){
  "${temp_dir}/pack" $@
}

# Fill in our gcr.io registry for the builder
builder_toml=$temp_dir/builder.toml
cat ${builder_toml} | REPLACE_WITH_REGISTRY="${registry}" envsubst  > "${builder_toml}.new"

build_pack
echo "building builder from $builder_config..."
run_pack create-builder "$builder_image" --builder-config "$builder_toml.new"

if [ "$publish" == "true" ]; then
    echo "Publishing ${builder_image}..."
    docker push "${builder_image}"
else
    echo "To publish ${builder_image}:"
    echo "  docker push ${builder_image}"
fi
