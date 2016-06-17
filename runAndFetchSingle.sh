#!/bin/bash
## Copyright 2015-2016 Alessandro Maria Rizzi
## Copyright 2015 Fabio Colzada
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

# run specified query many times and fetch log and stats in an appropriate folder
# A file with all the hosts, line by line, is expected in the same folder


# Scale size for datagen
SCALE=$2
# extension of the query script, typically sql
QUERYEXTENSION=sql
# A list of queries to execute in the single query run, they are the ones we will execute in the session mode
QUERY=$1
# Database to be used
DB_NAME="tpcds_text_$SCALE"

QUERY_DIR=$3
SCRATCH_DIR="$4/scratch"

mkdir -p $SCRATCH_DIR

init_file="${SCRATCH_DIR}/init.sql"
tmp_file="${SCRATCH_DIR}/temp.tmp"

sed "s/DB_NAME/${DB_NAME}/g" "${QUERY_DIR}/my_init.sql" > "${init_file}"


hive -v -i "${init_file}" \
    -f "${QUERY_DIR}/${QUERY}.${QUERYEXTENSION}" \
    > "${tmp_file}" 2>&1

