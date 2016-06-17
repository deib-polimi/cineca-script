#!/bin/bash
################################################################################
# myhadoop-configure.sh - establish a valid $HADOOP_CONF_DIR with all of the
#   configurations necessary to start a Hadoop cluster from within a HPC batch
#   environment.  Additionally format HDFS and leave everything in a state ready
#   for Hadoop to start up via start-all.sh.
#
#   Glenn K. Lockwood, San Diego Supercomputer Center
#   Sriram Krishnan, San Diego Supercomputer Center              Feburary 2014
#   tuning added by Hugo Meiland, Bull                           June 2014
#   Changes by Giueppe Fiameni - g.fiameni@cineca.it
################################################################################

MH_HOME="$(dirname $(readlink -f $0))/.."

## List of available nodes
NODE_LIST=()


function mh_print {
    echo "myHadoop: $@"
}

function print_usage {
    echo "Usage: $(basename $0) [options]" >&2
    cat <<EOF >&2
    -n <num> 
        specify number of nodes to use.  (default: all nodes from resource 
        manager)

    -p <dir> 
        use persistent HDFS and store namenode and datanode state on the shared 
        filesystem given by <dir> (default: n/a)

    -c <dir>
        build the resulting Hadoop config directory in <dr> (default: from 
        user environment's HADOOP_CONF_DIR or myhadoop.conf)

    -s <dir>
        location of node-local scratch directory where datanode and tasktracker
        will be stored.  (default: user environment's MH_SCRATCH_DIR or 
        myhadoop.conf)

    -h <dir>
        location of Hadoop installation containing the myHadoop configuration
        templates in <dir>/conf and the 'hadoop' executable in <dir>/bin/hadoop
        (default: user environment's HADOOP_HOME or myhadoop.conf)

    -i <regular expression>
        transformation (passed to sed -e) to turn each hostname provided by the
        resource manager into an IP over InfiniBand host.  (default: "")

    -?
        show this help message
EOF
}

function host_name {
  echo $1 | awk -F. '{ print $1 }'
}

if [ "z$1" == "z-?" ]; then
  print_usage
  exit 0
fi

### Read in some system-wide configurations (if applicable) but do not override
### the user's environment
if [ -e "$MH_HOME/myhadoop-conf/myhadoop.conf" ]; then
  while read line; do
    rex='^[^# ]*='
    if [[ $line =~ $rex ]]; then
      variable=$(cut -d = -f1 <<< $line)
      value=$(cut -d = -f 2- <<< $line)
      if [ "z${!variable}" == "z" ]; then
        eval "$variable=$value"
        mh_print "Setting $variable=$value from myhadoop.conf"
      else
        mh_print "Keeping $variable=${!variable} from user environment"
      fi
    fi
  done < $MH_HOME/myhadoop-conf/myhadoop.conf
fi

### Detect our resource manager and populate necessary environment variables
if [ "z$PBS_JOBID" != "z" ]; then
    RESOURCE_MGR="pbs"
elif [ "z$PE_NODEFILE" != "z" ]; then
    RESOURCE_MGR="sge"
elif [ "z$SLURM_JOBID" != "z" ]; then
    RESOURCE_MGR="slurm"
else
    echo "No resource manager detected.  Aborting." >&2
    print_usage
    exit 1
fi

if [ "z$RESOURCE_MGR" == "zpbs" ]; then
    NODES=$(cat $PBS_NODEFILE | wc -l)
    NUMPROCS=$PBS_NP # not sure
    JOBID=$PBS_JOBID
elif [ "z$RESOURCE_MGR" == "zsge" ]; then
    NODES=$NHOSTS
    NUMPROCS=$NSLOTS
    JOBID=$JOB_ID
elif [ "z$RESOURCE_MGR" == "zslurm" ]; then
    NODES=$SLURM_NNODES
    NUMPROCS=$SLURM_NPROCS
    JOBID=$SLURM_JOBID
fi

### Get the list of available nodes
if [ -e "$PBS_NODEFILE" ]; then
    i=0
    while read line
    do
      NODE_LIST[i]=$(host_name $line)
      i=$(($i + 1))
    done < $PBS_NODEFILE
fi



### Parse arguments
args=`getopt n:p:c:s:h:i:? $*`
if test $? != 0
then
    print_usage
    exit 1
fi

set -- $args
for i
do
    case "$i" in
        -n) shift;
            NODES=$1
            shift;;

        -p) shift;
            MH_PERSIST_DIR=$1
            shift;;

        -c) shift;
            HADOOP_CONF_DIR=$1
            shift;;

        -s) shift;
            MH_SCRATCH_DIR=$1
            shift;;

        -h) shift;
            HADOOP_HOME=$1
            shift;;

        -i) shift;
            MH_IPOIB_TRANSFORM=$1
            shift;;
    esac
done

if [ "z$HADOOP_HOME" == "z" ]; then
    if [ "z$HADOOP_PREFIX" == "z" ]; then
        echo 'You must set $HADOOP_HOME before configuring a new cluster.' >&2
        exit 1
    else
        HADOOP_HOME=$HADOOP_PREFIX
    fi
fi
mh_print "Using HADOOP_HOME=$HADOOP_HOME"

if [ "z$HADOOP_SCRATCH_DIR_GLOBAL" == "z" ]; then
    echo "You must specify the global disk filesystem location with -s.  Aborting." >&2
    print_usage
    exit 1
fi
mh_print "Using HADOOP_SCRATCH_DIR_GLOBAL=$HADOOP_SCRATCH_DIR_GLOBAL"

if [ "z$JAVA_HOME" == "z" ]; then
    echo "JAVA_HOME is not defined.  Aborting." >&2
    print_usage
    exit 1
fi
mh_print "Using JAVA_HOME=$JAVA_HOME"

if [ "z$HADOOP_CONF_DIR" == "z" ]; then
    echo "Location of configuration directory not specified.  Aborting." >&2
    print_usage
    exit 1
fi
mh_print "Generating Hadoop configuration in directory in $HADOOP_CONF_DIR..."

### Support for persistent HDFS on a shared filesystem
if [ "z$HADOOP_SCRATCH_DIR_GLOBAL" != "z" ]; then
    mh_print "Using directory $HADOOP_SCRATCH_DIR_GLOBAL for persisting HDFS state..."
fi

### Create the config directory and begin populating it. All the nodes are going to point to
### central directory
if [ -d $HADOOP_CONF_DIR ]; then
    i=0
    while [ -d $HADOOP_CONF_DIR.$i ]
    do
        let i++
    done
    mh_print "Backing up old config dir to $HADOOP_CONF_DIR.$i..."
    mv -v $HADOOP_CONF_DIR $HADOOP_CONF_DIR.$i
fi
mkdir -p $HADOOP_CONF_DIR

### First copy over all default Hadoop configs
if [ -d $HADOOP_CONF_DIR_DEFAULT ]; then           # Hadoop 1.x
  cp $HADOOP_CONF_DIR_DEFAULT/* $HADOOP_CONF_DIR
  MH_HADOOP_VERS=2
fi

### Pick the master node as the first node in the nodefile
if [ ${#NODE_LIST[@]} -gt 0 ]; then
  MASTER_NODE=${NODE_LIST[0]}
#  NAME_NODE=${NODE_LIST[1]:-$MASTER_NODE} 
  NAME_NODE=$MASTER_NODE

  mh_print "Designating $MASTER_NODE as master node (namenode, secondary namenode, and jobtracker)"
  echo $MASTER_NODE > $HADOOP_CONF_DIR/masters

  ### Make every node in the nodefile a slave
  printf "%s\n" "${NODE_LIST[@]}" > $HADOOP_CONF_DIR/slaves
  ## print_nodelist | awk '{print $1}' | sort -u | head -n $NODES > $HADOOP_CONF_DIR/slaves
  mh_print "The following nodes will be slaves (datanode, tasktracer):"
  cat $HADOOP_CONF_DIR/slaves
fi


#Create one conf
i=0
for node in $(cat $HADOOP_CONF_DIR/slaves $HADOOP_CONF_DIR/masters | sort -u | head -n $NODES)
do
    # mkdir -p $MH_PERSIST_DIR/$i
    # echo "Linking $MH_PERSIST_DIR/$i to ${config_subs[DFS_DATA_DIR]} on $node"

    DFS_DATANODE_DIR_NODE=${HADOOP_SCRATCH_DIR_GLOBAL}/${node}/datanode
    mkdir -p ${DFS_DATANODE_DIR_NODE}

    DFS_NAMENODE_DIR_NODE=${HADOOP_SCRATCH_DIR_GLOBAL}/${node}/namenode
    mkdir -p ${DFS_NAMENODE_DIR_NODE}

    MAPRED_LOCAL_DIR_NODE=${HADOOP_SCRATCH_DIR_GLOBAL}/${node}/mapred-local
    mkdir -p ${MAPRED_LOCAL_DIR_NODE}

    MAPRED_SYSTEM_DIR_NODE=${HADOOP_SCRATCH_DIR_GLOBAL}/${node}/mapred-system
    mkdir -p ${MAPRED_SYSTEM_DIR_NODE}

    HADOOP_TMP_DIR=${HADOOP_SCRATCH_DIR_GLOBAL}/${node}/tmp
    mkdir -p ${HADOOP_TMP_DIR}

    #### ssh $node "mkdir -p $(dirname ${config_subs[DFS_DATA_DIR]}); ln -s $MH_PERSIST_DIR/$i ${config_subs[DFS_DATA_DIR]}"

    ssh $node "mkdir -p ${HADOOP_SCRATCH_DIR_LOCAL}; ln -sf ${DFS_DATANODE_DIR_NODE} ${HADOOP_SCRATCH_DIR_LOCAL}/datanode; ln -sf ${DFS_NAMENODE_DIR_NODE} ${HADOOP_SCRATCH_DIR_LOCAL}/namenode"

    ssh $node "ln -sf ${MAPRED_LOCAL_DIR_NODE} ${HADOOP_SCRATCH_DIR_LOCAL}/mapred-local; ln -s ${MAPRED_SYSTEM_DIR_NODE} ${HADOOP_SCRATCH_DIR_LOCAL}/mapred-system; ln -sf ${HADOOP_TMP_DIR} ${HADOOP_SCRATCH_DIR_LOCAL}/tmp"

    let i++
done

## Set the Hadoop configuration files to be specific for our job.  Populate
### the subsitutions to be applied to the conf/*.xml files below.  If you update
### the config_subs hash, be sure to also update myhadoop-cleanup.sh to ensure 
### any new directories you define get properly deleted at the end of the job!
cat <<EOF > $HADOOP_CONF_DIR/myhadoop.conf
NODES=$NODES
declare -A config_subs
config_subs[MASTER_NODE]="$MASTER_NODE"
config_subs[YARN_RES_MANAGER]="$MASTER_NODE"
config_subs[MAPRED_JOB_TRACKER]="$MASTER_NODE"
config_subs[NAMENODE_URI]="$NAME_NODE"
config_subs[MAPRED_LOCAL_DIR]="${HADOOP_SCRATCH_DIR_LOCAL}/mapred-local"
config_subs[MAPRED_SYSTEM_DIR]="${HADOOP_SCRATCH_DIR_LOCAL}/mapred-system"
config_subs[DFS_NAME_DIR]="${HADOOP_SCRATCH_DIR_LOCAL}/namenode"
config_subs[DFS_DATA_DIR]="${HADOOP_SCRATCH_DIR_LOCAL}/datanode"
config_subs[DFS_REPLICA_FACTOR]="$DFS_REPLICA_FACTOR"
config_subs[DFS_BLOCK_SIZE]="$MH_DFS_BLOCK_SIZE"
config_subs[MAPRED_TASKTRACKER_MAP_TASKS_MAXIMUM]="$MH_MAP_TASKS_MAXIMUM"
config_subs[MAPRED_TRACKER_GROUP]="$MAPRED_TRACKER_GROUP"
config_subs[MAPRED_TASKTRACKER_REDUCE_TASKS_MAXIMUM]="$MH_REDUCE_TASKS_MAXIMUM"
config_subs[MAPRED_MAP_TASKS]="$MH_MAP_TASKS"
config_subs[MAPRED_REDUCE_TASKS]="$MH_REDUCE_TASKS"
config_subs[HADOOP_LOG_DIR]="${HADOOP_SCRATCH_DIR_GLOBAL}/logs"
config_subs[HADOOP_TMP_DIR]="${HADOOP_SCRATCH_DIR_LOCAL}/tmp"
config_subs[HADOOP_PID_DIR]="${HADOOP_SCRATCH_DIR_LOCAL}/pids"
EOF

source $HADOOP_CONF_DIR/myhadoop.conf

### And actually apply those substitutions:
for key in "${!config_subs[@]}"; do
  for xml in mapred-site.xml core-site.xml hdfs-site.xml yarn-site.xml
  do
    if [ -f $HADOOP_CONF_DIR/$xml ]; then
      sed -i 's#'$key'#'${config_subs[$key]}'#g' $HADOOP_CONF_DIR/$xml
    fi
  done
done

### A few Hadoop file locations are set via environment variables:
cat << EOF >> $HADOOP_CONF_DIR/hadoop-env.sh

# myHadoop alterations for this job:
export HADOOP_LOG_DIR=${config_subs[HADOOP_LOG_DIR]}
export HADOOP_PID_DIR=${config_subs[HADOOP_PID_DIR]}
export YARN_LOG_DIR=${config_subs[HADOOP_LOG_DIR]} # no effect if using Hadoop 1
export YARN_PID_DIR=${config_subs[HADOOP_PID_DIR]} # no effect if using Hadoop 1
# export HADOOP_SECURE_DN_PID_DIR=${config_subs[HADOOP_PID_DIR]}
export HADOOP_HOME_WARN_SUPPRESS=TRUE
export JAVA_HOME=$JAVA_HOME
### Jetty leaves garbage in /tmp no matter what \$TMPDIR is; this is an extreme 
### way of preventing that
# export _JAVA_OPTIONS="-Djava.io.tmpdir=${config_subs[HADOOP_TMP_DIR]} $_JAVA_OPTIONS"

# Other job-specific environment variables follow:
EOF

## #Format HDFS if it does not already exist from persistent mode
if [ ! -e ${config_subs[DFS_NAME_DIR]}/current ]; then
  mh_print "Formatting namenode"
  HADOOP_CONF_DIR=$HADOOP_CONF_DIR $HADOOP_HOME/bin/hdfs namenode -format
fi

killall -9 java > /dev/null 2>&1
