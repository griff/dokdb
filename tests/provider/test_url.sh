#!/bin/bash

. $(dirname $0)/../provider.sh

setUp() {
  setup_containers
  make_container NAME
}

tearDown() {
  remove_containers
}

testUrl() {
  local ip="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $NAME)"
  (
    export OVERRIDE_DOKDB_HOSTPORT=db.maven-group.org:1212
    url=$(docker run -e OVERRIDE_DOKDB_HOSTPORT --rm --link $NAME:dokdb $PROVIDER url -q)
    assertEquals "$SCHEME://demo:demo@db.maven-group.org:1212/demo" "$url"
    url=$(docker run -e OVERRIDE_DOKDB_HOSTPORT --rm --link $NAME:dokdb $PROVIDER url -q --admin)
    assertEquals "$SCHEME://admin:admin@db.maven-group.org:1212/demo" "$url"

    export OVERRIDE_DOKDB_HOSTPORT=db.maven-group.org
    url=$(docker run -e OVERRIDE_DOKDB_HOSTPORT --rm --link $NAME:dokdb $PROVIDER url -q)
    assertEquals "$SCHEME://demo:demo@db.maven-group.org:$DOKDB_TEST_PORT/demo" "$url"
  )
}

. $(dirname $0)/../../shunit2/src/shunit2