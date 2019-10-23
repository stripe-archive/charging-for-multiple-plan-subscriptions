#!/usr/bin/env bash
REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "${REPO_ROOT}/scripts/utilities.sh"

TOP=$(cd "$(dirname "$0")" && pwd)
cd "${TOP}"

start_and_check_process "${TOP}/server.pid" "${TOP}/server.log" \
  "ruby server.rb"
exit $?