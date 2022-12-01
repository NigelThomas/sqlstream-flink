# set environment variables for the SQLstream / Flink comparison
# source this from your .profiel or .bashrc

export FLINK_VERSION=flink-1.15.3
export FLINK_HOME=$HOME/$FLINK_VERSION

## Please set SQLSTREAM_HOME
export SQLSTREAM_MAJOR_VERSION=8.1.0
# SQLSTREAM_VERSION includes the build number/hash
#export SQLSTREAM_VERSION=8.1.0.20521-7f16b5644

## Please set SQLSTREAM_HOME
export SQLSTREAM_MAJOR_VERSION=8.1.1
# SQLSTREAM_VERSION includes the build number/hash
export SQLSTREAM_VERSION=8.1.1.20603-d5538544e


export SQLSTREAM_HOME=$HOME/sqlstream/${SQLSTREAM_VERSION}/s-Server


export PATH=$PATH:$FLINK_HOME/bin:$SQLSTREAM_HOME/bin

function getJdkVersion() {
    jdkversion=$(java -version 2>&1 | grep version | cut -d' ' -f 1,3 | tr -d '"' | tr " " "-")
}

function stopsServer() {
    $SQLSTREAM_HOME/bin/serverReady
    result=$?

    if [ $result -eq 0 ]
    then
        echo "INFO - stopping SQLstream s-Server"
        sserverpid=$(jps | grep AspenVJdbc | awk '{print $1}')
        kill -TERM $sserverpid


        while [ $result -eq 0 ]
        do
            sleep 2
            ps $sserverpid > /dev/null
            result=$?
        done
    fi
    
}

function startsServer () {
    # if the server is not ready, bring it up
    $SQLSTREAM_HOME/bin/serverReady
    result=$?

    if [ $result -ne 0 ]
    then
        # start server
        echo "INFO - starting SQLstream s-Server"
        $SQLSTREAM_HOME/bin/s-Server --daemon &
        # wait for server to start
        while [ $result -ne 0 ]
        do
            sleep 2
            $SQLSTREAM_HOME/bin/serverReady
            result=$?
        done
        sleep 10
    fi
}

function stopFlink() {
    # just stop without checking - the script takes care of it
    $FLINK_HOME/bin/stop-cluster.sh
}

function startFlink() {
    # start-cluster.sh is not idempotent, so stop and start for cleanliness / repeatability
    $FLINK_HOME/bin/stop-cluster.sh
    $FLINK_HOME/bin/start-cluster.sh
}

function checkFlinkMemory() {
    
    tmps=$(grep "^taskmanager.memory.process.size:" $FLINK_HOME/conf/flink-conf.yaml | awk '{print tolower($2)}')

    # get numerals - all but last letter
    tmps_size=${tmps:0:-1}
    # get last letter - we assume it is m or g, we're not expecting k or t
    tmps_unit=${tmps:0-1}
    
    if [ ${tmps_unit} = "g" ]
    then
        let "tmps_size=$tmps_size*1024"
    fi

    getJavaVersion
    case $jdkversion in
        *-11.*)
            echo "INFO - $jdkversion configured"
            ;;
        *-1.8*)
            echo "WARNING - $jdkversion configured; Apache Flink supports JDK8 but recommends JDK11"
            ;;
        *)
            echo "ERROR - $jdkversion configured; Apache Flink recommendeds to use JDK11"
            return 1
    esac

    if [[ ! "$javaversion" =~ "1.11" ]]
    then
        echo "WARNING - JDK $javaversion is not supported; Apache Flink recommends JDK11"
    fi

    if [ $tmps_size -lt  8192 ]
    then
        echo "WARNING: Flink task manager memory process size under-specified at $tmps, should be 8192m / 8g at least"
        echo "INFO: please edit $FLINK_HOME/conf/flink-conf.yaml and modify:"
        echo "   taskmanager.memory.process.size: 8g"
        echo "INFO: also consider reducing the memory managed fraction by adding:"
        echo "   taskmanager.memory.managed.fraction: 0.2"
        return 1
    else
        if [ "${tmps_unit}" == "g" ]
        then
            echo "INFO: Flink task manager memory process size adequately specified at $tmps (${tmps_size}m)"
        else
            echo "INFO: Flink task manager memory process size adequately specified at $tmps"
        fi
    fi

    return 0

}

function benchmark-status() {
    $SQLSTREAM_HOME/bin/serverReady

    for p in TaskManagerRunner StandaloneSessionClusterEntrypoint
    do
        if jps | grep $p &> /dev/null
        then
            echo "Flink $p is running"
        else
            echo "Flink $p is not running"
        fi
    done

}

function getTopPid() {
    toppid=$(ps -ef | grep top | grep -e \-b | awk '{print $2}')
    echo "INFO: top is running, pid=$toppid"
}

function topLog() {
    # Start logging top process stats for task manager,job manager or s-server
    # p1 = pid, p2 = logfile
    echo "INFO: top stats for pid(s) $1 logging to $2"
    # log pids from jps so we can distinguish the various JVMs
    jps | grep -e AspenVJdbcServer -e TaskManagerRunner -e StandaloneSessionCluster >> $2
    echo >> $2
    top -b -d 10 -c -E g  -p $1 >> $2 &
    getTopPid
}
