#!/bin/bash

set -o errexit

. $(dirname $0)/../../src/common.bash

tearDown() {
  unset DATABASE_URL
  unset_parsed_url DATABASE
}

resetURLParameters() {
  export DATABASE_SCHEME="$1 scheme"
  export DATABASE_USER="$1 user"
  export DATABASE_PASSWORD="$1 password"
  export DATABASE_HOST="$1 host"
  export DATABASE_PORT="$1 port"
  export DATABASE_NAME="$1 name"
  export DATABASE_QUERY="$1 query"
}

testUrlencode() {
  url=`urlencode mu©llet`
  assertEquals 'mu%C2%A9llet' "$url"
}

testUrldecode() {
  url=`urldecode mu%C2%A9llet`
  assertEquals 'mu©llet' "$url"
}

testBasicURLParsing1() {
  resetURLParameters testBasicURLParsing1
  parse_url "mug://test.example.com/name"
  assertEquals "Database scheme"     'mug' "${DATABASE_SCHEME}"
  assertEquals "Database user"       'testBasicURLParsing1 user' "${DATABASE_USER}"
  assertEquals "Database password"   'testBasicURLParsing1 password' "${DATABASE_PASSWORD}"
  assertEquals "Database host"       'test.example.com' "${DATABASE_HOST}"
  assertEquals "Database port"       'testBasicURLParsing1 port' "${DATABASE_PORT}"
  assertEquals "Database name"       'name' "${DATABASE_NAME}"
  assertEquals "Database parameters" 'testBasicURLParsing1 query' "${DATABASE_QUERY}"
}

testBasicURLParsing2() {
  resetURLParameters testBasicURLParsing2
  parse_url "mug://mullet:supersecret@192.168.10.1:1024"
  assertEquals "Database scheme"     'mug' "${DATABASE_SCHEME}"
  assertEquals "Database user"       'mullet' "${DATABASE_USER}"
  assertEquals "Database password"   'supersecret' "${DATABASE_PASSWORD}"
  assertEquals "Database host"       '192.168.10.1' "${DATABASE_HOST}"
  assertEquals "Database port"       '1024' "${DATABASE_PORT}"
  assertEquals "Database name"       'testBasicURLParsing2 name' "${DATABASE_NAME}"
  assertEquals "Database parameters" 'testBasicURLParsing2 query' "${DATABASE_QUERY}"
}

testBasicURLParsing3() {
  resetURLParameters testBasicURLParsing3
  parse_url "mug://mullet@192.168.10.1"
  assertEquals "Database scheme"     'mug' "${DATABASE_SCHEME}"
  assertEquals "Database user"       'mullet' "${DATABASE_USER}"
  assertEquals "Database password"   'testBasicURLParsing3 password' "${DATABASE_PASSWORD}"
  assertEquals "Database host"       '192.168.10.1' "${DATABASE_HOST}"
  assertEquals "Database port"       'testBasicURLParsing3 port' "${DATABASE_PORT}"
  assertEquals "Database name"       'testBasicURLParsing3 name' "${DATABASE_NAME}"
  assertEquals "Database parameters" 'testBasicURLParsing3 query' "${DATABASE_QUERY}"
}

testParsingUrlDecode() {
  resetURLParameters testParsingUrlDecode
  parse_url "mug://mu%C2%A9llet:fg%27l%20%22e%3Blk%C2%A9kd@mic%C2%A9k.example.com/na%C2%A9me?a%C2%A9rg=te%C2%A9st"
  assertEquals "Database scheme"     'mug' "${DATABASE_SCHEME}"
  assertEquals "Database user"       'mu©llet' "${DATABASE_USER}"
  assertEquals "Database password"   "fg'l \"e;lk©kd" "${DATABASE_PASSWORD}"
  assertEquals "Database host"       'mic©k.example.com' "${DATABASE_HOST}"
  assertEquals "Database port"       'testParsingUrlDecode port' "${DATABASE_PORT}"
  assertEquals "Database name"       'na©me' "${DATABASE_NAME}"
  assertEquals "Database parameters" 'a%C2%A9rg=te%C2%A9st' "${DATABASE_QUERY}"
}

testMakeURL1() {
  url=$(make_url mug '' '' test.example.com '' name)
  assertEquals 'mug://test.example.com/name' "$url"
}

testMakeURL2() {
  url=`make_url mug mullet supersecret 192.168.10.1 1024`
  assertEquals 'mug://mullet:supersecret@192.168.10.1:1024' "$url"
}

testMakeURL3() {
  url=`make_url mug mullet '' 192.168.10.1 1024 name arg=test`
  assertEquals 'mug://mullet@192.168.10.1:1024/name?arg=test' "$url"
}

testMakeURLEncode() {
  url=`make_url 'mu g' mu©llet super©secret mic©k.example.com '' na©me a©rg=te©st`
  assertEquals 'mu%20g://mu%C2%A9llet:super%C2%A9secret@mic%C2%A9k.example.com/na%C2%A9me?a©rg=te©st' "$url"
}

testMakeUrlFromEnv1() {
  local DATABASE_SCHEME='mug'
  local DATABASE_HOST='test.example.com'
  local DATABASE_NAME='name'
  local url="$(make_url_from_env)"
  assertEquals 'mug://test.example.com/name' "$url"
}

testMakeUrlFromEnv2() {
  local MUH_SCHEME='mug'
  local MUH_USER='plaq'
  local MUH_PASSWORD='Mack'
  local MUH_HOST='test.example.com'
  local -i MUH_PORT=1212
  local MUH_NAME='name'
  local MUH_QUERY='test=mowl'
  local url="$(make_url_from_env MUH)"
  assertEquals 'mug://plaq:Mack@test.example.com:1212/name?test=mowl' "$url"
}

testMakeDockerLinkDatabaseURL() {
  local DOKDB_ENV_DATABASE_SCHEME='postgresql'
  local DOKDB_ENV_DATABASE_PORT=5432
  local DOKDB_ENV_DATABASE_NAME='crowddb'
  local DOKDB_ENV_DATABASE_USER='crowd'
  local DOKDB_ENV_DATABASE_PASSWORD='jellyfish'
  local DOKDB_PORT_5432_TCP_ADDR='172.17.0.2'
  local DOKDB_PORT_5432_TCP_PORT=3000
  local url="$(make_docker_link_database_url)"
  assertEquals 'postgresql://crowd:jellyfish@172.17.0.2:3000/crowddb' "$url"
}

testMakeDockerLinkDatabaseURLPrefix() {
  local CROWDDB_ENV_DATABASE_SCHEME='postgresql'
  local CROWDDB_ENV_DATABASE_PORT=5432
  local CROWDDB_ENV_DATABASE_NAME='crowddb'
  local CROWDDB_ENV_DATABASE_USER='crowd'
  local CROWDDB_ENV_DATABASE_PASSWORD='jellyfish'
  local CROWDDB_PORT_5432_TCP_ADDR='172.17.0.2'
  local CROWDDB_PORT_5432_TCP_PORT=3000
  local url="$(make_docker_link_database_url crowddb)"
  assertEquals 'postgresql://crowd:jellyfish@172.17.0.2:3000/crowddb' "$url"
}

testMakeDockerLinkDatabaseURLOverrideHost() {
  local DOKDB_ENV_DATABASE_SCHEME='postgresql'
  local DOKDB_ENV_DATABASE_PORT=5432
  local DOKDB_ENV_DATABASE_NAME='crowddb'
  local DOKDB_ENV_DATABASE_USER='crowd'
  local DOKDB_ENV_DATABASE_PASSWORD='jellyfish'
  local DOKDB_PORT_5432_TCP_ADDR='172.17.0.2'
  local DOKDB_PORT_5432_TCP_PORT=3000
  local OVERRIDE_DOKDB_HOSTPORT='localhost'
  local url="$(make_docker_link_database_url)"
  assertEquals 'postgresql://crowd:jellyfish@localhost:5432/crowddb' "$url"
}

testMakeDockerLinkDatabaseURLOverrideHostPrefix() {
  local CROWDDB_ENV_DATABASE_SCHEME='postgresql'
  local CROWDDB_ENV_DATABASE_PORT=5432
  local CROWDDB_ENV_DATABASE_NAME='crowddb'
  local CROWDDB_ENV_DATABASE_USER='crowd'
  local CROWDDB_ENV_DATABASE_PASSWORD='jellyfish'
  local CROWDDB_PORT_5432_TCP_ADDR='172.17.0.2'
  local CROWDDB_PORT_5432_TCP_PORT=3000
  local OVERRIDE_CROWDDB_HOSTPORT='localhost'
  local url="$(make_docker_link_database_url crowddb)"
  assertEquals 'postgresql://crowd:jellyfish@localhost:5432/crowddb' "$url"
}

testMakeDockerLinkDatabaseURLOverrideHostPort() {
  local DOKDB_ENV_DATABASE_SCHEME='postgresql'
  local DOKDB_ENV_DATABASE_PORT=5432
  local DOKDB_ENV_DATABASE_NAME='crowddb'
  local DOKDB_ENV_DATABASE_USER='crowd'
  local DOKDB_ENV_DATABASE_PASSWORD='jellyfish'
  local DOKDB_PORT_5432_TCP_ADDR='172.17.0.2'
  local DOKDB_PORT_5432_TCP_PORT=3000
  local OVERRIDE_DOKDB_HOSTPORT='localhost:4000'
  local url="$(make_docker_link_database_url)"
  assertEquals 'postgresql://crowd:jellyfish@localhost:4000/crowddb' "$url"
}

testMakeDockerLinkDatabaseURLOverrideHostPortPrefix() {
  local CROWDDB_ENV_DATABASE_SCHEME='postgresql'
  local CROWDDB_ENV_DATABASE_PORT=5432
  local CROWDDB_ENV_DATABASE_NAME='crowddb'
  local CROWDDB_ENV_DATABASE_USER='crowd'
  local CROWDDB_ENV_DATABASE_PASSWORD='jellyfish'
  local CROWDDB_PORT_5432_TCP_ADDR='172.17.0.2'
  local CROWDDB_PORT_5432_TCP_PORT=3000
  local OVERRIDE_CROWDDB_HOSTPORT='localhost:4000'
  local url="$(make_docker_link_database_url crowddb)"
  assertEquals 'postgresql://crowd:jellyfish@localhost:4000/crowddb' "$url"
}

testDetectLink() {
  local DOKDB_NAME='muh'
  local DOKDB_ENV_DATABASE_SCHEME='mysql'
  local DOKDB_ENV_DATABASE_NAME='crowddb'
  local DOKDB_ENV_DATABASE_PORT=5432
  detect_dokdb_link || fail 'Did not detect link'
}

testDetectLinkNoPort() {
  local DOKDB_NAME='muh'
  local DOKDB_ENV_DATABASE_SCHEME='mysql'
  local DOKDB_ENV_DATABASE_NAME='crowddb'
  detect_dokdb_link || return 0 && fail 'Did detect link'
}

testDetectLinkNoDatabase() {
  local DOKDB_NAME='muh'
  local DOKDB_ENV_DATABASE_SCHEME='mysql'
  local DOKDB_ENV_DATABASE_PORT=5432
  detect_dokdb_link || return 0 && fail 'Did detect link'
}

testDetectLinkNoScheme() {
  local DOKDB_NAME='muh'
  local DOKDB_ENV_DATABASE_NAME='crowddb'
  local DOKDB_ENV_DATABASE_PORT=5432
  detect_dokdb_link || return 0 && fail 'Did detect link'
}

testDetectLinkNoName() {
  local DOKDB_ENV_DATABASE_SCHEME='mysql'
  local DOKDB_ENV_DATABASE_NAME='crowddb'
  local DOKDB_ENV_DATABASE_PORT=5432
  detect_dokdb_link || return 0 && fail 'Did detect link'
}

. $(dirname $0)/../../shunit2/src/shunit2
