#!/usr/bin/env bash
REPO_ROOT=$(cd  $(dirname $0)/../.. && pwd)
. "${REPO_ROOT}/scripts/utilities.sh"

TOP=$(cd $(dirname $0) && pwd)
cd "${TOP}"

. "${TOP}/.virtualenv/bin/activate"

start_and_check_process "${TOP}/server.pid" "${TOP}/server.log" \
  "python3 server.py"
exit $?