#!/bin/bash
set -e

NAME="foobar-vm"
FINAL_NAME="foobar-vm.tar.gz"

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
  popd
}

build() {
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
    tar -c -f $NAME.tar $NAME
    gzip $NAME.tar
    if [ ! -e $RESULT_DIR ]; then
      mkdir -p $RESULT_DIR
    fi
    mv $FINAL_NAME $RESULT_DIR/
  popd > /dev/null
  result=$(ls "$RESULT_DIR/$FINAL_NAME")
  echo "Native image capable JDK image at: $result"
}

prepare
build
archive
