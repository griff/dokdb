set -o errexit
[ -n "$DEBUG" ] && set -x
if [ -z "$SCHEME" ]; then 
  SCHEME="$(docker run --rm --entrypoint sh $PROVIDER -c 'echo $DATABASE_SCHEME')"
fi

DOKDB_TEST_PORT="$(docker run --rm --entrypoint sh $PROVIDER -c 'echo $DATABASE_PORT')"
if [ -z "$DOKDB_TEST_PORT" ]; then
  echo "Provider is missing database port"
  exit 1
fi

. $(dirname $0)/../../src/common.bash

setup_containers() {
  #echo "Doing setup..."
  CONTAINERS=()
}

remove_containers() {
  #echo "Doing cleanup... ${CONTAINERS[@]}"
  for k in ${CONTAINERS[@]} ; do
    echo "Stopping: $k"
    docker stop $k > /dev/null
    docker rm -v $k > /dev/null
  done
}

make_container() {
  local output=$1
  shift
  local cid="$(docker run -d $@ $PROVIDER run)"
  CONTAINERS+=($cid)
  local name=$(docker inspect --format '{{ .Name }}' $cid)
  eval "export $output='$name'"
}
