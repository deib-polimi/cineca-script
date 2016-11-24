#!/bin/bash
## Copyright 2016 Alessandro Maria Rizzi
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

if [ $# -ne 8 ]; then
    echo "Usage: $0 scriptPath maxWallTime numNodes numCpu mem queries scale numIterations"
    exit -1;
fi

. $1/config

mkdir -p "$JOB_DIR"
FILENAME="$JOB_DIR/$3_$4_$5_$7.sh"


cat $1/templateSpark | sed -e "s,V_AC,$CINECA_ACCOUNT,g;s,V_SP,$1,g;s/V_WT/$2/g;s/V_NN/$3/g;s/V_NC/$4/g;s/V_MM/$5/g;s/V_QR/$6/g;s/V_SC/$7/g;s/N_IT/$8/g" > $FILENAME
qsub $FILENAME

