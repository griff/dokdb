[ -n "$DEBUG" ] && set -x
if [ -z "$SCHEME" ]; then 
  SCHEME="$(docker run --rm --entrypoint sh $PROVIDER -c 'echo $DATABASE_SCHEME')"
fi

DOKDB_TEST_PORT="$(docker run --rm --entrypoint sh $PROVIDER -c 'echo $DATABASE_PORT')"
if [ -z "$DOKDB_TEST_PORT" ]; then
  echo "Provider is missing database port"
  exit 1
fi

DOKDB_EXTENSIONS="$(docker run --rm $PROVIDER extensions)"
require_extension() {
  found="$(echo "$DOKDB_EXTENSIONS" | grep "$1")"
  if [ -z "$found" ]; then
    echo "Skipping $0 tests because $1 is not supported by provider"
    exit 0
  fi
}

has_extension() {
  found="$(echo "$DOKDB_EXTENSIONS" | grep "$1")"
  if [ -z "$found" ]; then
    return 1
  fi
}

. $(dirname $0)/../../src/common.bash

assertFails() {
  local msg="$1"
  shift
  #echo "$@"
  if "$@"; then
    fail "$msg"
  fi
}

assertSucceeds() {
  local msg="$1"
  shift
  if ! "$@"; then
    fail "$msg"
  fi
}

setup_containers() {
  #echo "Doing setup..."
  CONTAINERS=()
}

remove_containers() {
  #echo "Doing cleanup... ${CONTAINERS[@]}"
  for k in ${CONTAINERS[@]} ; do
    #echo "Stopping: $k"
    docker stop $k > /dev/null
    docker rm -v $k > /dev/null
  done
}

make_container() {
  local output=$1
  shift
  local cid="$(docker run -d "$@" $PROVIDER run)"
  CONTAINERS+=($cid)
  local name=$(docker inspect --format '{{ .Name }}' $cid | sed -e 's/^\///g')
  eval "export $output='$name'"
}
