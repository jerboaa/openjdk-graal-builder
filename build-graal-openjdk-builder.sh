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
# of building a substrate VM.
set -e

BOOT_JDK_VERSION="14"
ARCHITECTURE="x64"

cloneOpenJDK() {
  target_dir="$1"
  git clone --depth 1 https://github.com/AdoptOpenJDK/openjdk-jdk.git $target_dir
}

buildOpenJDK() {
  buildScript="$1"
  bootDir=$(basename $JDK_BOOT_DIR)
  baseDir=$(dirname $JDK_BOOT_DIR)
  if [ ! -e $JDK_BOOT_DIR ]; then
    mkdir -p $JDK_BOOT_DIR
    apiURL="https://api.adoptopenjdk.net/v3/binary/latest/${BOOT_JDK_VERSION}/ea/linux/${ARCHITECTURE}/jdk/hotspot/normal/adoptopenjdk"
    pushd $baseDir > /dev/null
      wget -q -O - "${apiURL}" | tar xpzf - --strip-components=1 -C "$bootDir"
    popd > /dev/null
  fi
  pushd $OPENJDK_SRC > /dev/null
    bash $buildScript
  popd > /dev/null
}

rm -rf "$(pwd)/src"
RESULTS_BASE_DIR="$(pwd)/results"
rm -rf "$(pwd)/results"
OPENJDK_SRC="$(pwd)/src/openjdk"
cloneOpenJDK "$OPENJDK_SRC"
export RESULT_DIR="$RESULTS_BASE_DIR/openjdk"
export JDK_BOOT_DIR="$(pwd)/jdk-$BOOT_JDK_VERSION"
buildOpenJDK "$(pwd)/openjdk/linux/x86_64/build-builder-jdk.sh"
