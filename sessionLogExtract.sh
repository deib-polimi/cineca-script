#!/bin/bash
## Copyright 2015-2016 Alessandro Maria Rizzi
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

if [ $# -ne 1 ]; then
    echo "Usage: $0 sourceDir"
    exit -1;
fi

cp $1/ssdata.conf $1/logs
cp -R $1/hive/session $1/logs

BASE_DIR="$1/hdfs/staging/history/done_intermediate/$USER"

cp $BASE_DIR/* $1/logs

