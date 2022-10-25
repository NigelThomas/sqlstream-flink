# set environment variables for the SQLstream / Flink comparison
# source this from your .profiel or .bashrc

export FLINK_VERSION=flink-1.15.2
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

