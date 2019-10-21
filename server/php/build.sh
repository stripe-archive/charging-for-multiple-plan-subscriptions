#!/bin/bash

TOP=$(cd $(dirname $0) && pwd)

cd "${TOP}"

composer install
exit $?