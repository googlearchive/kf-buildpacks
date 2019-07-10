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

rootpath=$(cd $(dirname $0)/.. && pwd)
dir=${rootpath}/builder

builder_config=${dir}/builder.toml
builder_image="${registry}/buildpack-builder:${version}"

# Create a temp directory so we can manipulate the builder.toml. We can't
# simply use a temp file "<(...)" because the builder.toml could have relative
# paths to the buildpacks.
temp_dir=$(mktemp -d)
function finish {
  rm -rf "$temp_dir"
}
trap finish EXIT
cp -r $rootpath/builder/* $temp_dir

# For each CF buildpack that we have to build
build_cf_buildpack(){
  echo "Building $1"
  pushd $temp_dir/$1
  [ -f "./ci/build.sh" ] && ./ci/build.sh
  [ -f "./scripts/build.sh" ] && ./scripts/build.sh
  popd
}

build_cf_buildpack "archive-expanding-cnb"
build_cf_buildpack "build-system-cnb"
build_cf_buildpack "google-stackdriver-cnb"
build_cf_buildpack "jvm-application-cnb"
build_cf_buildpack "openjdk-cnb"
build_cf_buildpack "procfile-cnb"
build_cf_buildpack "spring-boot-cnb"
build_cf_buildpack "tomcat-cnb"

# Fill in our gcr.io registry for the builder
builder_toml=$temp_dir/builder.toml
cat $builder_toml | sed "s|REPLACE_WITH_REGISTRY|$registry|g" > $builder_toml.new

echo "building builder from $builder_config..."
pack create-builder $builder_image --builder-config $builder_toml.new

if [ $publish == "true" ]; then
    echo "Publishing these images..."
    for image in "${builder_image}"; do
      docker push ${image}
    done
else
    echo "To publish these images:"
    for image in "${builder_image}"; do
      echo "  docker push ${image}"
    done
fi
