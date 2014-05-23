#!/bin/bash

. $(dirname $0)/../provider.sh

require_extension self-test

setUp() {
  setup_containers
}

tearDown() {
  remove_containers
}

testEmptyWithoutSetup() {
  make_container MUH
  sleep 6
  assertFails "self-test on empty database" \
    docker run --rm --link $MUH:dokdb $PROVIDER self-test -q
}

testSelfTest() {
  make_container MUH
  sleep 6

  assertSucceeds "Setup database" \
    docker run --rm --link $MUH:dokdb $PROVIDER self-test-setup
  assertSucceeds "Running self-test" \
    docker run --rm --link $MUH:dokdb $PROVIDER self-test -q
  assertFails "Running self-test a second time" \
    docker run --rm --link $MUH:dokdb $PROVIDER self-test -q
}

testSecondSetupFailure() {
  make_container MUH
  sleep 6

  assertSucceeds "Setup database" \
    docker run --rm --link $MUH:dokdb $PROVIDER self-test-setup

  assertFails "Second database setup" \
    docker run --rm --link $MUH:dokdb $PROVIDER self-test-setup -q
}

. $(dirname $0)/../../shunit2/src/shunit2
