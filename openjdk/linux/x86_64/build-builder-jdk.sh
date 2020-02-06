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

set -e

NAME="jdk-jdk"
FINAL_NAME="jdk-jdk.tar.gz"
CONF_NAME="openjdk"
IMAGE_DIR_NAME="graal-builder-jdk"
IMAGES_DIR="build/$CONF_NAME/images"
OUTPUT_DIR="$IMAGES_DIR/$IMAGE_DIR_NAME"

prepare() {
  if [ "${JDK_BOOT_DIR}_" == "_" ]; then
    echo "Error. JDK_BOOT_DIR not set." 1>&2
    exit 1
  fi
  if [ "${RESULT_DIR}_" == "_" ]; then
    echo -n "Error. RESULT_DIR not set. Please point this " 1>&2
    echo    "environment variable to a folder where results should be placed." 1>&2
    exit 1
  fi
  # clean up from previous builds (if any)
  rm -rf build
}

build() {
  bash configure  --with-boot-jdk="$JDK_BOOT_DIR"  \
                  --with-debug-level="release"  \
                  --with-native-debug-symbols="none" \
                  --with-conf-name="$CONF_NAME" \
                  --disable-warnings-as-errors
  make graal-builder-image
}

archive() {
  mv "$OUTPUT_DIR" "$IMAGES_DIR/$NAME"
  pushd $IMAGES_DIR > /dev/null
    tar -c -f $NAME.tar $NAME
    gzip $NAME.tar
  popd > /dev/null
  mv "$IMAGES_DIR/$NAME" "$OUTPUT_DIR"

  if [ ! -e $RESULT_DIR ]; then
    mkdir -p $RESULT_DIR
  fi
  mv $IMAGES_DIR/$FINAL_NAME $RESULT_DIR/
  result=$(ls "$RESULT_DIR/$FINAL_NAME")
  echo "Graal builder JDK image: $result"
}

prepare
build
archive
