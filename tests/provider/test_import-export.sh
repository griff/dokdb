#!/bin/bash

. $(dirname $0)/../provider.sh

require_extension import/export
require_extension self-test

setUp() {
  setup_containers
  make_container EXP
  make_container IMPORT -e DATABASE_NAME=imported -e DATABASE_USER=importer
  sleep 5
}

tearDown() {
  remove_containers
}

testImportExport() {
  local tmp=""
  if [ "$(uname)" == "Darwin" ]; then
    tmp="$(mktemp -t dokdb-export)"
  else
    tmp="$(mktemp)"
  fi
  assertSelfTestSetup "Setup data" $EXP

  docker run --rm --link $EXP:dokdb $PROVIDER export -q - > $tmp || fail "Export data"

  assertSelfTest "Self-test of exported database" $EXP
  assertFailsSelfTest "Self-test of imported database before import" $IMPORT

  cat $tmp | docker run -i --rm --link $IMPORT:dokdb $PROVIDER import -q - || echo "Import data $?"
  assertSelfTest "Self-test of imported database after import" $IMPORT
}

testRemoteImportExport() {
  # Startup a flynn/shelf for testing export to http
  local shelf_cid="$(docker run -d -v /storage --expose 8080 flynn/shelf -p 8080 -s /storage)"
  CONTAINERS+=($shelf_cid)
  local shelf_name=$(docker inspect --format '{{ .Name }}' $shelf_cid)
  local shelf_ip="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $shelf_name)"
  local shelf_url="http://$shelf_ip:8080/data.dump"

  sleep 5
  # Make sure there is some data to export and import
  assertSelfTestSetup "Setup data" $EXP

  # The actual import we are testing
  assertSucceeds "Export data" \
    docker run --rm --link $EXP:dokdb --link $shelf_name:shelf \
      $PROVIDER export -q $shelf_url

  # Check that something was actually sent to the http server
  assertSucceeds "Exported data exists" \
    docker run --rm --volumes-from $shelf_name busybox test -s "/storage/data.dump"

  # Make sure that we can run 
  assertSelfTest "Self-test of exported database" $EXP

  # Validate that a self-test will fail on the database we are importing to
  assertFailsSelfTest "Self-test of imported database before import" $IMPORT

  # Do the actual import
  assertSucceeds "Import data" \
    docker run -i --rm --link $IMPORT:dokdb --link $shelf_name:shelf \
      $PROVIDER import -q $shelf_url

  # Do a self-test on the imported database to verify that everything works
  assertSelfTest "Self-test of imported database after import" $IMPORT
}

. $(dirname $0)/../../shunit2/src/shunit2
