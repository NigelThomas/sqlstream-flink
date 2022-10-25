#!/bin/bash
SCRIPT_DIR=$(cd `dirname $0` ; pwd -P)

# make changes to Flink and SQLstream versions in environment.sh, not here
source $SCRIPT_DIR/environment.sh

## Install Apache Flink, getting binaries from Apache download site
echo "... checking $FLINK_VERSION install "
if [ -f $FLINK_HOME/bin/sql-client.sh ]
then
    echo "INFO: $FLINK_VERSION already installed"
else
    # get Flink binary tarball
    # TODO scala version may need to change in future
    flinkTarball=/tmp/${FLINK_VERSION}-bin-scala_2.12.tgz

    if [ ! -f $flinkTarball ] 
    then
        wget "https://archive.apache.org/dist/flink/${FLINK_VERSION}/${FLINK_VERSION}-bin-scala_2.12.tgz" -P /tmp
    else
        echo "INFO: $flinkTarball already present"
    fi
    # unpack it to install
    tar xvf $flinkTarball -C $HOME
    if [ $? -eq 0 ]
    then
        # rm  /tmp/${FLINK_VERSION}-bin-scala_2.12.tgz
        echo "$FLINK_VERSION installed"
    else
        echo "WARNING - failed to unpack $flinkTarball"
    fi
fi

# Install SQLstream s-Server
# Binaries may be stored in the assets subdirectory or fetched from SQLstream download site
# If you are installing a development version of s-Server, do it before running this script

result=Y
if [ -d $SQLSTREAM_HOME ]
then
    result=I
elif [ -f $SCRIPT_DIR/assets/SQLstream-sServer-${SQLSTREAM_VERSION}-x64.run ]
then
    # This is the version included in the tarball / git repo
    sserverInstaller=SQLstream-sServer-${SQLSTREAM_VERSION}-x64.run
    sserverInstallerDir=$SCRIPT_DIR/assets
else
    # This gets one of the generally available s-Server releases
    sserverInstaller=SQLstream-sServer-${SQLSTREAM_MAJOR_VERSION}-x64.run
    sserverInstallerDir=/tmp

    if [ ! -f $sserverInstallerDir/$sserverInstaller ]
    then
        wget "https://downloads.sqlstream.com/$SQLSTREAM_MAJOR_VERSION/$sserverInstaller" -P $sserverInstallerDir
        if [ $? -eq 0 ]
        then
            chmod +x "$sserverInstallerDir/$sserverInstaller" 
        else
            result=D
        fi
    else
        echo "INFO: $sserverInstallerDir/$sserverInstaller already present"
    fi
fi

case "$result" in

    "I")
        echo "INFO: SQLstream s-Server $SQLSTREAM_VERSION already installed at $SQLSTREAM_HOME"
        ;;
    "D")
        echo "WARNING: Unable to download SQLstream s-Server $SQLSTREAM_MAJOR_VERSION from https://downloads.sqlstream.com/$SQLSTREAM_MAJOR_VERSION/$sserverInstaller"
        ;;
    *)
        echo "... Installing $sserverInstallerDir/$sserverInstaller"
        $sserverInstallerDir/$sserverInstaller --mode unattended --email nouser@acompany.com --company acompany
        echo "aspen.sched.license.path=$SCRIPT_DIR" > $SQLSTREAM_HOME/aspen.custom.properties
        echo "SQLstream s-Server $SQLSTREAM_VERSION installed"
        ;;
esac

