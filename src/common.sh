message() {
  if [ -z "$QUIET" ]; then
    echo "$*" 1>&2
  fi
}

cmd() {
  if [ "$QUIET" = "-q" ]; then
    "$@" > /dev/null 2>&1
  else
    "$@" 1>&2
  fi
}

indent_cmd() {
  if [ "$QUIET" = "-q" ]; then
    "$@" > /dev/null 2>&1
  else
    "$@" | (while read; do echo "    $REPLY"; done) 1>&2
  fi
}

return_variable() {
  eval echo "\$$1_$2"
}

unset_variable() {
  eval unset "$1_$2"
}

urldecode() {
    local data=${1//+/ }
    printf '%b' "${data//%/\x}"
}

urlencode() {
  local string="$1"
  local strlen=${#string}
  local encoded=""

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               o="$(echo -n "$c" | hexdump -v -e '/1 " %02X"' | tr ' ' %)" ;;
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

unset_parsed_url() {
  local prefix=DATABASE
  [ -n "$2" ] && prefix=$2
  unset_variable $prefix SCHEME
  unset_variable $prefix USER
  unset_variable $prefix PASSWORD
  unset_variable $prefix HOST
  unset_variable $prefix PORT
  unset_variable $prefix NAME
  unset_variable $prefix QUERY
}

parse_url() {
  local prefix=DATABASE
  [ -n "$2" ] && prefix=$2
  # extract the protocol
  local proto="`echo $1 | grep '://' | sed -e's,^\(.*://\).*,\1,g'`"
  local scheme="`echo $proto | sed -e 's,^\(.*\)://,\1,g'`"
  # remove the protocol
  local url=`echo $1 | sed -e s,$proto,,g`

  # extract the user and password (if any)
  local userpass="`echo $url | grep @ | cut -d@ -f1`"
  local pass=`echo $userpass | grep : | cut -d: -f2`
  if [ -n "$pass" ]; then
    local user=`echo $userpass | grep : | cut -d: -f1`
  else
    local user=$userpass
  fi

  # extract the host -- updated
  local hostport=`echo $url | sed -e s,$userpass@,,g | cut -d/ -f1`
  local port=`echo $hostport | grep : | cut -d: -f2`
  if [ -n "$port" ]; then
    local host=`echo $hostport | grep : | cut -d: -f1`
  else
    local host=$hostport
  fi

  # extract the path (if any)
  local full_path="`echo $url | grep / | cut -d/ -f2-`"
  local path="`echo $full_path | cut -d? -f1`"
  local query="`echo $full_path | grep ? | cut -d? -f2`"
  local -i rc=0
  
  [ -n "$proto" ] && eval "export ${prefix}_SCHEME=\"$scheme\"" || rc=$?
  [ -n "$user" ] && eval "export ${prefix}_USER=\"`urldecode $user`\"" || rc=$?
  [ -n "$pass" ] && eval "export ${prefix}_PASSWORD=\"`urldecode $pass`\"" || rc=$?
  [ -n "$host" ] && eval "export ${prefix}_HOST=\"`urldecode $host`\"" || rc=$?
  [ -n "$port" ] && eval "export ${prefix}_PORT=\"`urldecode $port`\"" || rc=$?
  [ -n "$path" ] && eval "export ${prefix}_NAME=\"`urldecode $path`\"" || rc=$?
  [ -n "$query" ] && eval "export ${prefix}_QUERY=\"$query\"" || rc=$?
}

make_url() {
  if [ -n "$2" ]; then
    if [ -n "$3" ]; then
      local userpass="$(urlencode "$2"):$(urlencode "$3")@"
    else
      local userpass="$(urlencode "$2")@"
    fi
  fi
  if [ -n "$5" ]; then
    local port=":$5"
  fi
  if [ -n "$6" ]; then
    if [ -n "$7" ]; then
      local query="?$7"
    fi
    local name="/$(urlencode "$6")${query}"
  fi
  echo "$(urlencode "$1")://${userpass}$(urlencode "$4")${port}${name}"
}

make_url_from_env() {
  local prefix=DATABASE
  [ -n "$1" ] && prefix="$1"
  local scheme="$(return_variable $prefix SCHEME)"
  local user="$(return_variable $prefix USER)"
  local password="$(return_variable $prefix PASSWORD)"
  local host="$(return_variable $prefix HOST)"
  local port="$(return_variable $prefix PORT)"
  local name="$(return_variable $prefix NAME)"
  local query="$(return_variable $prefix QUERY)"
  make_url "$scheme" "$user" "$password" "$host" "$port" "$name" "$query"
}

make_docker_link_database_url() {
  local prefix=DOKDB
  [ -n "$1" ] && prefix="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  local port=$(return_variable $prefix ENV_DATABASE_PORT)
  local override_hostport="$(eval echo \$OVERRIDE_${prefix}_HOSTPORT)"

  if [ -n "$override_hostport" ]; then
    local override_port=`echo $override_hostport | grep : | cut -d: -f2`
    if [ -n "$override_port" ]; then
      local override_host=`echo $override_hostport | grep : | cut -d: -f1`
    else
      override_port="$port"
      local override_host="$override_hostport"
    fi
    eval "local ${prefix}_ENV_DATABASE_PORT='$override_port'"
    eval "local ${prefix}_ENV_DATABASE_HOST='$override_host'"
  else
    eval "local ${prefix}_ENV_DATABASE_PORT=\$${prefix}_PORT_${port}_TCP_PORT"
    eval "local ${prefix}_ENV_DATABASE_HOST=\$${prefix}_PORT_${port}_TCP_ADDR"
  fi
  make_url_from_env "${prefix}_ENV_DATABASE"
}

make_docker_link_root_database_url() {
  local prefix=DOKDB
  [ -n "$1" ] && prefix="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  eval "local ${prefix}_ENV_DATABASE_USER=\$${prefix}_ENV_DATABASE_ROOT_USER"
  eval "local ${prefix}_ENV_DATABASE_PASSWORD=\$${prefix}_ENV_DATABASE_ROOT_PASSWORD"
  make_docker_link_database_url "$prefix"
}

detect_dokdb_link() {
  local prefix=DOKDB
  [ -n "$1" ] && prefix="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  for var in 'NAME' 'ENV_DATABASE_SCHEME' 'ENV_DATABASE_PORT' 'ENV_DATABASE_NAME' ; do
    if [ -z "$(return_variable $prefix $var)" ]; then
      return 1
    fi
  done
}

ensure_database_url() {
  if [ "$1" = "--root" -o "$1" = "-r" ]; then
      local use_root=1
      shift
  fi
  if [ -z "$DATABASE_URL" ]; then
      prefix="DOKDB"
      if [ -z "$use_root" ]; then
          DATABASE_URL="$(make_docker_link_database_url $prefix)"
      else
          DATABASE_URL="$(make_docker_link_root_database_url $prefix)"
      fi
  fi
}