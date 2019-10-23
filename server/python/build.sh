#!/bin/bash

TOP=$(cd "$(dirname "$0")" && pwd)

cd "${TOP}"

if [ ! -d .virtualenv ]; then
  python3 -m venv "${TOP}/.virtualenv"
fi
. .virtualenv/bin/activate
pip install -r requirements.txt
exit $?