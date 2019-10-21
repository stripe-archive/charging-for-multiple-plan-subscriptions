#### Bash Utility Functions

## Logging
RED='\033[0;31m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
LIGHT_GRAY='\033[0;37m'
NC='\033[0m'

function ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

function debug() {
  if [[ ${DEBUG} = "true" ]]; then
    echo -e "${LIGHT_GRAY}[DEBUG]${NC} $(ts) $@"
  fi
}

function info() {
    echo -e "${CYAN}[INFO] ${NC}$(ts) $@"
}

function warn() {
  echo -e "${ORANGE}[WARN]${NC} $(ts) $@"

}

function error() {
  echo -e "${RED}[ERROR]${NC} $(ts) $@"
}

# STRIPE API UTILS
function stripe_curl() {
  curl --silent -u "${STRIPE_SECRET_KEY}:" "$@"
}

function local_curl() {
  curl --silent --max-time 3 "$@"
}

function describe_api_result() {
  local RESULT="$1"
  local ACTION="$2"
  debug "${RESULT}"
  ERROR=$(echo "${RESULT}" | jq -e .error)
  error_check_status=$?
  if [ $error_check_status -eq 0 ]; then
    warn "Error performing action: \"${ACTION}\""
    warn "${ERROR}" | jq .message
  else
    info "Performed action \"${ACTION}\" successfully with id=$(echo "${RESULT}" | jq .id)"
  fi
}

function start_and_check_process() {
  local pidfile=$1
  local logfile=$2
  shift
  shift
  local proc="$@"

  if [[ -f "${pidfile}" ]]; then
    error "Stale pidfile exists. Is server currently running? Try running ./stop.sh to clean up."
    return 1
  fi

  $proc 2>> "$logfile" >> "$logfile" &
  pid=$!
  echo $pid > "$pidfile"
  sleep 2
  proc_count="$(ps ax | grep -c "$proc")"
  if [[ $proc_count -eq 0 ]]; then
    error "Process did not start."
    tail "$logfile"
    return 1
  else
    info "Started server with pid $(cat "$pidfile")"
    return 0
  fi
}

function stop_process() {
  local pidfile=$1
  shift
  local proc_signature="$@"

  if [[ ! -f "${pidfile}" ]]; then
    error "Could not stop server, pidfile not found."
    return 1
  fi
  pid=$(cat $pidfile)
  proc_count="$(ps ax | grep $pid |  grep -c "$proc_signature")"
  if [[ $proc_count -gt 0 ]]; then
    kill $pid
    sleep 1
    proc_count="$(ps ax | grep $pid |  grep -c "$proc_signature")"
    if [[ $proc_count -gt 0 ]]; then
     error "Could not shut down server. Check server logs."
      return 1
    else
      info "Stopped server successfully."
    fi
  else
    warn "Server was not running."
  fi
  rm -f "$pidfile"

  return 0
}

function string_to_list() {
  local str="$1"
  echo "$1" | sed "s/,/ /g"
}