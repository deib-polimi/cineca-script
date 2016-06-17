#!/bin/bash

# Wait until runnig jobs are terminated
typeset cmnd="$HADOOP_HOME/bin/yarn job -list | tail -n 1 | grep $USER"
typeset ret_code=0

until [ $ret_code != 0 ]; do
    sleep 20
    eval $cmnd
    ret_code=$?
done

$HADOOP_HOME/sbin/stop-dfs.sh
$HADOOP_HOME/sbin/stop-yarn.sh
