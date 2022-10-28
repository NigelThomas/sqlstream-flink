# set environment variables for the SQLstream / Flink comparison
# source this from your .profiel or .bashrc

export FLINK_VERSION=flink-1.15.1
export FLINK_HOME=$HOME/$FLINK_VERSION

## Please set SQLSTREAM_HOME
export SQLSTREAM_MAJOR_VERSION=8.1.1
# SQLSTREAM_VERSION includes the build number
export SQLSTREAM_VERSION=8.1.1.2001858-bcaa86c7
# 8.1.0.20521-7f16b5644
# 8.1.1.20580-1497075c7
# 8.1.1.2001858-bcaa86c7
export SQLSTREAM_HOME=$HOME/sqlstream/${SQLSTREAM_VERSION}/s-Server


export PATH=$PATH:$FLINK_HOME/bin:$SQLSTREAM_HOME/bin

function stopsServer() {
    $SQLSTREAM_HOME/bin/serverReady
    if [ $? -eq 0 ]
    then
        echo "INFO - stopping SQLstream s-Server"
        kill -TERM `jps | grep AspenVJdbc | awk '{print $1}'`
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
        sleep 5
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