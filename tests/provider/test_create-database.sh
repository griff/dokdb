#!/bin/bash

. $(dirname $0)/../provider.sh

require_extension create-database
require_extension self-test

run_command() {
  local output=$1
  local command=$2
  shift 2
  local cid="$(docker run -d "$@" $PROVIDER $command)"
  CONTAINERS+=($cid)
  local name=$(docker inspect --format '{{ .Name }}' $cid | sed -e 's/^\///g')
  eval "export $output='$name'"
}

setUp() {
  setup_containers
  make_container NAME
  sleep 5
}

tearDown() {
  remove_containers
}

testDatabaseServerOnly() {
  make_container ONLY -e "DATABASE_SERVER_ONLY=true"

  sleep 6
  assertFails "Has no database" \
    docker run --rm --link $ONLY:dokdb $PROVIDER test -q

  local after="$(docker run --rm --link $ONLY:dokdb $PROVIDER list-databases | grep demo)"
  assertNull "$after"
}

testCreateDatabase() {
  local before="$(docker run --rm --link $NAME:dokdb $PROVIDER list-databases | grep 'muhdb')"
  assertNull "$before"

  docker run --rm -e DATABASE_NAME=muhdb -e DATABASE_USER=cow \
    -e DATABASE_PASSWORD=milk --link $NAME:dokdb $PROVIDER create-database -q

  assertFails "Testing with no password" \
    docker run --rm -e DOKDB_ENV_DATABASE_NAME=muhdb -e DOKDB_ENV_DATABASE_USER=cow \
      --link $NAME:dokdb $PROVIDER test -q

  assertSucceeds "Testing with right password" \
    docker run --rm -e DOKDB_ENV_DATABASE_NAME=muhdb -e DOKDB_ENV_DATABASE_USER=cow \
      -e DOKDB_ENV_DATABASE_PASSWORD=milk --link $NAME:dokdb $PROVIDER test -q

  assertSelfTestSetup "Self-test setup" $NAME -e DOKDB_ENV_DATABASE_NAME=muhdb \
    -e DOKDB_ENV_DATABASE_USER=cow -e DOKDB_ENV_DATABASE_PASSWORD=milk

  assertSelfTest "Self-test" $NAME -e DOKDB_ENV_DATABASE_NAME=muhdb \
    -e DOKDB_ENV_DATABASE_USER=cow -e DOKDB_ENV_DATABASE_PASSWORD=milk

  local after="$(docker run --rm --link $NAME:dokdb $PROVIDER list-databases | grep 'muhdb')"
  assertEquals muhdb "$after"
}

testCreateDatabaseProxy() {
  run_command CREATED 'create-database -q -p' -e DATABASE_NAME=muhdb \
    -e DATABASE_USER=cow -e DATABASE_PASSWORD=milk --link $NAME:dokdb

  sleep 3
  assertSucceeds "Testing connection" \
    docker run --rm --link $CREATED:dokdb $PROVIDER test -q

  assertSelfTestSetup "Self-test setup" $CREATED
  assertSelfTest "Self-test" $CREATED
}

testListDatabases() {
  local before="$(docker run --rm --link $NAME:dokdb $PROVIDER list-databases | grep 'demo')"
  assertEquals demo "$before"
}

testCantDropDatabaseIfNotThere() {
  assertFails "Droping non-existing database" docker run --rm -e DATABASE_NAME=muhdb -e DATABASE_USER=cow \
    --link $NAME:dokdb $PROVIDER drop-database -q
}


testCanDropDatabase() {
  assertSucceeds "Create database" \
    docker run --rm -e DATABASE_NAME=muhdb -e DATABASE_USER=cow \
      -e DATABASE_PASSWORD=milk --link $NAME:dokdb $PROVIDER create-database -q

  assertSucceeds "Ensure that database was created" \
    docker run --rm -e DOKDB_ENV_DATABASE_NAME=muhdb -e DOKDB_ENV_DATABASE_USER=cow \
      -e DOKDB_ENV_DATABASE_PASSWORD=milk --link $NAME:dokdb $PROVIDER test -q

  assertSucceeds "Drop database" \
    docker run --rm -e DATABASE_NAME=muhdb -e DATABASE_USER=cow \
      --link $NAME:dokdb $PROVIDER drop-database -q

  assertFails "Ensure that database was dropped" \
    docker run --rm -e DOKDB_ENV_DATABASE_NAME=muhdb -e DOKDB_ENV_DATABASE_USER=cow \
      -e DOKDB_ENV_DATABASE_PASSWORD=milk --link $NAME:dokdb $PROVIDER test -q

  local after="$(docker run --rm --link $NAME:dokdb $PROVIDER list-databases | grep muhdb)"
  assertNull "$after"
}

. $(dirname $0)/../../shunit2/src/shunit2
