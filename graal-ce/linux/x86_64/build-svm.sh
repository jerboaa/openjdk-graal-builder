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

VENDOR_NAME="${VENDOR_NAME:-"GraalVM LIBGRAAL"}"
NAME="svm"
FINAL_NAME="svm.tar.gz"

prepare() {
  if [ "${OPENJDK_GRAAL_BUILDER}_" == "_" ]; then
    echo -n "Error. OPENJDK_GRAAL_BUILDER not set. Please point this " 1>&2
    echo    "environment variable to a 'graal-builder-jdk' image." 1>&2
    exit 1
  fi
  "${OPENJDK_GRAAL_BUILDER}/bin/java" -version 2>&1 | sed 's/^/BUILD JDK: /g'
  if [ "${MX_BIN}_" == "_" ]; then
    echo -n "Error. MX_BIN not set. Please point this " 1>&2
    echo    "environment variable to the mx python script." 1>&2
    exit 1
  fi
  if [ "${RESULT_DIR}_" == "_" ]; then
    echo -n "Error. RESULT_DIR not set. Please point this " 1>&2
    echo    "environment variable to a folder where results should be placed." 1>&2
    exit 1
  fi
  MX="${MX_BIN} --java-home=${OPENJDK_GRAAL_BUILDER}"
  $MX --version 2>&1 | sed 's/^/BUILD MX: /g'
  rm -rf substratevm/svmbuild
  rm -rf substratevm/testme-helloworld
  pushd substratevm > /dev/null
    $MX clean
  popd > /dev/null
}

build() {
  # Adjust Vendor Version
  echo "Setting vendor version to: $VENDOR_NAME"
  sed -i "s/__VENDOR_VERSION__/$VENDOR_NAME/g" sdk/mx.sdk/mx_sdk_vm_impl.py
  pushd substratevm > /dev/null
  cat > HelloWorld.java <<EOF
  public class HelloWorld {
    public static void main(String[] args) {
      System.out.println("Hello World!");
    }
  }
EOF
  JAVAC="${OPENJDK_GRAAL_BUILDER}/bin/javac"
  $JAVAC HelloWorld.java
  helloworld_image="testme-helloworld"
  $MX native-image -H:+ReportExceptionStackTraces HelloWorld $helloworld_image 2>&1 | tee svmbuild.log
  ./$helloworld_image | sed 's/^/Native image >>  /g'
  rm -rf testme-helloworld
  popd > /dev/null
}

archive() {
  OUTPUT=$(readlink -f substratevm/svmbuild/vm)
  OUTPUT_DIR=$(dirname $OUTPUT)
  OUTPUT_BASE=$(basename $OUTPUT)
  pushd $OUTPUT_DIR > /dev/null
    mv $OUTPUT_BASE $NAME
    tar -c -f $NAME.tar --dereference $NAME
    gzip $NAME.tar
    orig_file=$(pwd)/$FINAL_NAME
    # work around symlink-mess in distro
    mkdir tmp-svm
    pushd tmp-svm > /dev/null
      tar -xf $orig_file
      pushd $NAME/bin > /dev/null
        rm native-image
        ln -s ../lib/svm/bin/native-image native-image
      popd > /dev/null
      rm $orig_file
      tar -c -f $NAME.tar $NAME
      gzip $NAME.tar
      if [ ! -e $RESULT_DIR ]; then
        mkdir -p $RESULT_DIR
      fi
      mv $FINAL_NAME $RESULT_DIR/
    popd > /dev/null
    rm -rf tmp-svm
    # Test native image functionality from archive
    mkdir tmp-test-native
    pushd tmp-test-native > /dev/null
      tar -xf $RESULT_DIR/$FINAL_NAME
      cat > HelloWorld.java <<EOF
  public class HelloWorld {
    public static void main(String[] args) {
      System.out.println("Hello World!");
    }
  }
EOF
    ./$NAME/bin/javac HelloWorld.java
    ./$NAME/bin/native-image HelloWorld foobar-hello
    ./foobar-hello 2>&1 | sed 's/^/Native image (archive) >>>  /g'
    popd > /dev/null
    rm -rf tmp-test-native
  popd > /dev/null
  result=$(ls "$RESULT_DIR/$FINAL_NAME")
  echo "Native image capable JDK image at: $result"
}

prepare
build
archive
