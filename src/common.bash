message() {
  if [ -z "$QUIET" ]; then
    echo "$*" 1>&2
  fi
}
message_n() {
  if [ -z "$QUIET" ]; then
    echo -n "$*" 1>&2
  fi
}

cmd() {
  if [ "$QUIET" = "-q" ]; then
    "$@" > /dev/null 2>&1
  else
    "$@" 1>&2
  fi
}

indent() {
  (while read; do echo "    $REPLY"; done)
}

indent_cmd() {
  if [ "$QUIET" = "-q" ]; then
    "$@" 2> /dev/null
  else
    { "$@" 2>&1 1>&3 | indent 1>&2; } 3>&1
    return ${PIPESTATUS[0]}
  fi
}

read_var() {
  eval "echo \$$1_$2"
}

unset_var() {
  eval unset "$1_$2"
}

urldecode() {
  typeset encoded=$1 decoded= rest= c= c1= c2=
  typeset rest2= bug='rest2=${rest}'

  if [[ -z ${BASH_VERSION:-} ]]; then
          typeset -i16 hex=0; typeset -i8 oct=0

          # bug /usr/bin/sh HP-UX 11.00
          typeset _encoded='xyz%26xyz'
          rest="${_encoded#?}"
          c="${_encoded%%${rest}}"
          if (( ${#c} != 1 )); then
                  typeset qm='????????????????????????????????????????????????????????????????????????'
                  typeset bug='(( ${#rest} > 0 )) && typeset -L${#rest} rest2="${qm}" || rest2=${rest}'
          fi
  fi

  rest="${encoded#?}"
  eval ${bug}
  c="${encoded%%${rest2}}"
  encoded="${rest}"
 
  while [[ -n ${c} ]]; do
    if [[ ${c} = '%' ]]; then
      rest="${encoded#?}"
      eval ${bug}
      c1="${encoded%%${rest2}}"
      encoded="${rest}"
 
      rest="${encoded#?}"
      eval ${bug}
      c2="${encoded%%${rest2}}"
      encoded="${rest}"
 
      if [[ -z ${c1} || -z ${c2} ]]; then
        c="%${c1}${c2}"
        echo "WARNING: invalid % encoding: ${c}" >&2
      elif [[ -n ${BASH_VERSION:-} ]]; then
        c="\\x${c1}${c2}"
        c=$(\echo -e "${c}")
      else
        hex="16#${c1}${c2}"; oct=hex
        c="\\0${oct#8\#}"
        c=$(print -- "${c}")
      fi
    elif [[ ${c} = '+' ]]; then
      c=' '
    fi
 
    decoded="${decoded}${c}"
 
    rest="${encoded#?}"
    eval ${bug}
    c="${encoded%%${rest2}}"
    encoded="${rest}"
  done
 
  if [[ -n ${BASH_VERSION:-} ]]; then
    \echo -E "${decoded}"
  else
    print -r -- "${decoded}"
  fi
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
  unset_var $prefix SCHEME
  unset_var $prefix USER
  unset_var $prefix PASSWORD
  unset_var $prefix HOST
  unset_var $prefix PORT
  unset_var $prefix NAME
  unset_var $prefix QUERY
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
  [ -n "$user" ] && eval "export ${prefix}_USER=\"$(urldecode $user | sed -e 's/"/\\"/g')\"" || rc=$?
  [ -n "$pass" ] && eval "export ${prefix}_PASSWORD=\"$(urldecode $pass | sed -e 's/"/\\"/g')\"" || rc=$?
  [ -n "$host" ] && eval "export ${prefix}_HOST=\"$(urldecode $host | sed -e 's/"/\\"/g')\"" || rc=$?
  [ -n "$port" ] && eval "export ${prefix}_PORT=\"$(urldecode $port | sed -e 's/"/\\"/g')\"" || rc=$?
  [ -n "$path" ] && eval "export ${prefix}_NAME=\"$(urldecode $path | sed -e 's/"/\\"/g')\"" || rc=$?
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
  local scheme="$(read_var $prefix SCHEME)"
  local user="$(read_var $prefix USER)"
  local password="$(read_var $prefix PASSWORD)"
  local host="$(read_var $prefix HOST)"
  local port="$(read_var $prefix PORT)"
  local name="$(read_var $prefix NAME)"
  local query="$(read_var $prefix QUERY)"
  make_url "$scheme" "$user" "$password" "$host" "$port" "$name" "$query"
}

make_docker_link_database_url() {
  local prefix=DOKDB
  [ -n "$1" ] && prefix="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  local port=$(read_var $prefix ENV_DATABASE_PORT)
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

make_docker_link_admin_database_url() {
  local prefix=DOKDB
  [ -n "$1" ] && prefix="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  eval "local ${prefix}_ENV_DATABASE_USER=\$${prefix}_ENV_DATABASE_ADMIN_USER"
  eval "local ${prefix}_ENV_DATABASE_PASSWORD=\$${prefix}_ENV_DATABASE_ADMIN_PASSWORD"
  make_docker_link_database_url "$prefix"
}

detect_dokdb_link() {
  local prefix=DOKDB
  [ -n "$1" ] && prefix="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  for var in 'NAME' 'ENV_DATABASE_SCHEME' 'ENV_DATABASE_PORT' 'ENV_DATABASE_NAME' ; do
    if [ -z "$(read_var $prefix $var)" ]; then
      return 1
    fi
  done
}

set_dokdb_database_url() {
  if [ "$1" = "--admin" -o "$1" = "-a" ]; then
    local use_admin='admin_'
    shift
  fi
  if [ -z "$DATABASE_URL" ]; then
    if detect_dokdb_link DOKDB; then
      DATABASE_URL="$(make_docker_link_${use_admin}database_url DOKDB)"
    elif detect_dokdb_link DB; then
      DATABASE_URL="$(make_docker_link_${use_admin}database_url DB)"
    fi
  fi
}