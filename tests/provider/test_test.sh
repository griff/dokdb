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

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q
}

testAdminLink() {
  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q --admin
}

testURL() {
  make_container NON_LINKED
  local ip="$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' $NON_LINKED)"
  local url="$(docker run --rm --link $NON_LINKED:dokdb $PROVIDER url)"
  sleep 6

  assertSucceeds "Test connection" \
    docker run --rm -e "DATABASE_URL=$url" --link $NAME:blabla $PROVIDER test -q
}

testURLTakesPrecedent() {
  assertFails "Test connection" \
    docker run --rm -e "DATABASE_URL=test://127.0.0.1/testname" --link $NAME:dokdb $PROVIDER test -q
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