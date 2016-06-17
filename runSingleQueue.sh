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
SCALE=$3
# extension of the query script, typically sql
QUERYEXTENSION=sql
# A list of queries to execute in the single query run, they are the ones we will execute in the session mode
QUERY=$2
# Database to be used
DB_NAME="tpcds_text_$SCALE"

QUERY_DIR=$4
QUEUE=$1
SCRATCH_DIR="$5/$6_${QUEUE}_${QUERY}"
SESSION_DIR="$5/session"
mkdir -p ${SESSION_DIR}
echo "CDIR: " + $(pwd)
mkdir -p $SCRATCH_DIR
cd ${SCRATCH_DIR}
echo "CD TO: " + ${SCRATCH_DIR}
echo "CDIR: " + $(pwd)

echo "Populating db..."
STARTTIME=$(date +%s)
$SCRIPT_PATH/initHive.sh $SCALE $DB_DIR
ENDTIME=$(date +%s)
echo "Database populated in $(($ENDTIME - $STARTTIME)) seconds"


STOP_FLAG="${SCRATCH_DIR}/stopSession"
TIME_FORMAT="+%d %T.%3N"

#rm -f "${STOP_FLAG}S"

out=$(mktemp --tmpdir=$SESSION_DIR/ -q "pippo_${QUERY}_${QUEUE}_XXXXX.txt")

i=0
while [ ! -f "${STOP_FLAG}" ]; do
	mkdir -p "${SCRATCH_DIR}/$i"
	init_file="${SCRATCH_DIR}/$i/init.sql"
	tmp_file="${SCRATCH_DIR}/$i/temp.tmp"
	sed "s/DB_NAME/${DB_NAME}/g" "${QUERY_DIR}/my_init.sql" > "${init_file}"
	echo "set mapred.job.queue.name=${QUEUE};" >> "${init_file}"

	echo "$(date): Launching ${QUERY} ${QUEUE}"
	TST=$(date "${TIME_FORMAT}")

	hive -v -i "${init_file}" \
		-f "${QUERY_DIR}/${QUERY}.${QUERYEXTENSION}" \
		> "${tmp_file}" 2>&1
	TND=$(date "${TIME_FORMAT}")

	while read -r line; do
		if [[ "$line" =~ .*(application_[0-9]+_[0-9]+).* ]]; then
			strresult=${BASH_REMATCH[1]}
		        echo "${strresult},${TST},${TND}" >> "${out}"
	    		break
                fi
	done < "${tmp_file}"
	#mkdir -p ${SCRATCH_DIR}/hdfs/$i
	#hdfs dfs -copyToLocal /tmp/hadoop-yarn/staging ${SCRATCH_DIR}/hdfs/$i

	#TODO SEt QUEUE NAME
	python "${SCRIPT_PATH}/waitExp.py"
	let i++
done

