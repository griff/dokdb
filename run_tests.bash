#!/bin/bash

set -o errexit
[ -n "$DEBUG" ] && set -x

run_all_tests() {
  echo "Running tests for provider $PROVIDER"
  for test in $(dirname $0)/tests/provider/test_*.sh; do
    $test
  done
}

if [ -z "$PROVIDER" ]; then
  for image in $(docker images | awk '/dokdb-[a-zA-Z0-9]+/{ print $1 }'); do
    export PROVIDER=$image
    run_all_tests
  done
else
  run_all_tests
fi
