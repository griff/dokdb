#!/bin/bash

. $(dirname $0)/../provider.sh

setUp() {
  setup_containers
}

tearDown() {
  remove_containers
}

testSimpleRun() {
  make_container NAME
  local ip="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $NAME)"

  # Test that we can get a database url when linking
  local vars="$(docker run --rm --link $NAME:dokdb busybox env)"
  (
    eval "$vars"
    url=$(make_docker_link_database_url)
    assertEquals "$SCHEME://demo:demo@$ip:$DOKDB_ENV_DATABASE_PORT/demo" "$url"

    url=$(make_docker_link_admin_database_url)
    assertEquals "$SCHEME://admin:admin@$ip:$DOKDB_ENV_DATABASE_PORT/demo" "$url"
  )

  sleep 6

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q --admin
}

testRunWithOptions() {
  make_container NAME -e DATABASE_NAME=dbname -e DATABASE_HOST=localhost \
    -e DATABASE_USER=dbuser -e DATABASE_PASSWORD=dbpwd \
    -e DATABASE_ADMIN_USER=mastercommander -e DATABASE_ADMIN_PASSWORD=knockknock
  local ip="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $NAME)"

  # Test that we can get a database url when linking
  local vars="$(docker run --rm --link $NAME:dokdb busybox env)"
  (
    eval "$vars"
    url=$(make_docker_link_database_url)
    assertEquals "$SCHEME://dbuser:dbpwd@$ip:$DOKDB_ENV_DATABASE_PORT/dbname" "$url"
    url=$(make_docker_link_admin_database_url)
    assertEquals "$SCHEME://mastercommander:knockknock@$ip:$DOKDB_ENV_DATABASE_PORT/dbname" "$url"
  )
  sleep 6
  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q --admin
}

testRestartImmediately() {
  make_container NAME

  docker restart $NAME > /dev/null

  sleep 6

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q --admin
}

testRestartAfterStartup() {
  make_container NAME

  # Restart after it has been up
  sleep 6
  docker restart $NAME > /dev/null

  sleep 6

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q

  assertSucceeds "Test connection" \
    docker run --rm --link $NAME:dokdb $PROVIDER test -q --admin
}

. $(dirname $0)/../../shunit2/src/shunit2
