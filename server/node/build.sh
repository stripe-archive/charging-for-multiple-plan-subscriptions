#!/bin/bash

TOP=$(cd $(dirname $0) && pwd)

cd "${TOP}"

npm install
exit $?