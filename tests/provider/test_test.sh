#!/bin/bash

. $(dirname $0)/../provider.sh

oneTimeSetUp() {
  setup_containers
  make_container NAME
  sleep 7
}

oneTimeTearDown() {
  remove_containers
}

testLink() {
  #local ip="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $name)"

  docker run --rm --link $NAME:dokdb $PROVIDER test -q
  assertEquals "Test connection" "0" "$?"
}

testAdminLink() {
  docker run --rm --link $NAME:dokdb $PROVIDER test -q --admin
  assertEquals "Test admin connection" "0" "$?"
}

testRestart() {
  make_container RESTARTED
  sleep 6

  local cid="$(docker run -d --link $RESTARTED:dokdb $PROVIDER test -q)"
  local ext=$(docker wait $cid)
  assertEquals "Test connection" "0" "$ext"

  docker restart $RESTARTED > /dev/null

  sleep 6

  docker start $cid > /dev/null
  local ext=$(docker wait $cid)
  assertEquals "Test connection" "0" "$ext"
}

. $(dirname $0)/../../shunit2/src/shunit2