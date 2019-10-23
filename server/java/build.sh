#!/bin/bash

TOP=$(cd "$(dirname "$0")" && pwd)

cd "${TOP}"

mvn package > build.log
exit $?