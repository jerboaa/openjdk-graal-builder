#!/bin/bash
#
# Top level build script to build an OpenJDK image capable
# of building a substrate VM. Then, build graal-ce code
# subsequently
set -e

BOOT_JDK_VERSION="14"
ARCHITECTURE="x64"

cloneOpenJDK() {
  target_dir="$1"
  git clone --depth 1 https://github.com/AdoptOpenJDK/openjdk-jdk.git $target_dir
}

cloneGraalCE() {
  target_dir="$1"
  graal_dir="$target_dir/graal-ce"
  mx_dir="$target_dir/mx"
  mkdir -p $target_dir
  git clone --depth 1 https://github.com/oracle/graal.git $graal_dir
  git clone --depth 1 https://github.com/graalvm/mx.git $mx_dir
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

patchGraalCESources() {
  patches_dir=$1
  pushd $GRAAL_CE_SRC > /dev/null
    git am $patches_dir/*.patch
  popd > /dev/null
}

buildSubstrate() {
  buildScript="$1"
  pushd $GRAAL_CE_SRC > /dev/null
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

BUILDER_IMAGE="$(ls $RESULT_DIR/*.tar.gz)"
rm -rf $(pwd)/graal-builder
mkdir -p $(pwd)/graal-builder
pushd $(pwd)/graal-builder > /dev/null
  tar -xf $BUILDER_IMAGE
  OPENJDK_GRAAL_BUILDER="$(pwd)/$(ls -d *)"
popd > /dev/null
export OPENJDK_GRAAL_BUILDER
export RESULT_DIR="$RESULTS_BASE_DIR/substrate"

GRAAL_BASE="$(pwd)/src/graal"
cloneGraalCE "$(pwd)/src/graal"
export MX_BIN="$GRAAL_BASE/mx/mx"
GRAAL_CE_SRC="$GRAAL_BASE/graal-ce"
patchGraalCESources "$(pwd)/graal-ce/adopt-openjdk-patches"

buildSubstrate "$(pwd)/graal-ce/linux/x86_64/build-svm.sh"

echo "Results in: "
find $RESULTS_BASE_DIR -name \*.tar.gz
