#!/bin/bash
################################################################################
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################
#
#
# Top level build script to build an OpenJDK image capable
# of building a substrate VM. Then, build graal-ce code
# subsequently using the just produced builder image.
set -e

GRAAL_REPO="$1"
GRAAL_BRANCH="$2"
BUILDER_JDK_IMAGE="$3"
BUILDER_JDK_STATIC_LIBS_IMAGE="$4"

GRAAL_REPO_DEFAULT=https://github.com/oracle/graal.git
GRAAL_BRANCH_DEFAULT=master

cloneGraalCE() {
  target_dir="$1"
  graal_dir="$target_dir/graal-ce"
  mx_dir="$target_dir/mx"
  mkdir -p $target_dir
  git clone -b "${GRAAL_BRANCH}" --single-branch "${GRAAL_REPO}" "$graal_dir"
  git clone --depth 1 https://github.com/graalvm/mx.git $mx_dir
}

buildSubstrate() {
  buildScript="$1"
  pushd $GRAAL_CE_SRC > /dev/null
    bash $buildScript
  popd > /dev/null
}

downloadJDKandSanityCheck() {
  if [ "${BUILDER_JDK_IMAGE}_" == "_" ]; then
    echo "No builder JDK provided. Downloading..."
    TEMP_DIR="$(mktemp -d)"
    pushd $TEMP_DIR
      wget -O jdk-11.0.8-ea.tar.gz https://api.adoptopenjdk.net/v3/binary/latest/11/ea/linux/x64/jdk/hotspot/normal/openjdk
      wget -O static-libs-11.0.8-ea.tar.gz https://api.adoptopenjdk.net/v3/binary/latest/11/ea/linux/x64/staticlibs/hotspot/normal/openjdk
    popd
    BUILDER_JDK_IMAGE="$TEMP_DIR/jdk-11.0.8-ea.tar.gz"
    BUILDER_JDK_STATIC_LIBS_IMAGE="$TEMP_DIR/static-libs-11.0.8-ea.tar.gz"
  fi
  if [ -z "${GRAAL_REPO}" ]; then
    echo "GRAAL_REPO not set, using default: $GRAAL_REPO_DEFAULT"
    GRAAL_REPO="${GRAAL_REPO_DEFAULT}"
  fi
  if [ -z "${GRAAL_BRANCH}" ]; then
    echo "GRAAL_BRANCH not set, using default: $GRAAL_BRANCH_DEFAULT"
    GRAAL_BRANCH="${GRAAL_BRANCH_DEFAULT}"
  fi
  if [ ! -e "$BUILDER_JDK_IMAGE" ]; then
    echo "Error: Builder JDK tarball not found: $BUILDER_JDK_IMAGE"
    exit 1
  fi
  if [ ! -e "$BUILDER_JDK_STATIC_LIBS_IMAGE" ]; then
    echo "Error: Builder JDK static libs tarball not found: $BUILDER_JDK_STATIC_LIBS_IMAGE"
    exit 1
  fi
}

downloadJDKandSanityCheck
RESULTS_BASE_DIR="$(pwd)/results"
rm -rf "$RESULTS_BASE_DIR"

rm -rf $(pwd)/graal-builder
mkdir -p $(pwd)/graal-builder
pushd $(pwd)/graal-builder > /dev/null
  tar -xf $BUILDER_JDK_IMAGE
  tar -xf $BUILDER_JDK_STATIC_LIBS_IMAGE
  OPENJDK_GRAAL_BUILDER="$(pwd)/$(ls -d *)"
  echo "JDK 11 graal builder image in: $OPENJDK_GRAAL_BUILDER"
popd > /dev/null
export OPENJDK_GRAAL_BUILDER
export RESULT_DIR="$RESULTS_BASE_DIR/graalvm-mandrel"

GRAAL_BASE="$(pwd)/src/graal"
cloneGraalCE "$(pwd)/src/graal"
export MX_BIN="$GRAAL_BASE/mx/mx"
GRAAL_CE_SRC="$GRAAL_BASE/graal-ce"

buildSubstrate "$(pwd)/graal-ce/linux/x86_64/build-svm.sh"

echo "Results in: "
find $RESULTS_BASE_DIR -name \*.tar.gz

# Clean up potentially downloaded build JDK
if [ -d $TEMP_DIR ]; then
  rm -rf $TEMP_DIR
fi
