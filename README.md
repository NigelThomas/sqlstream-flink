# Overview
This benchmark compares SQLstream & Apache Flink’s throughput & footprint requirements for typical streaming operations such as time-series analytics & streaming joins.

[[_TOC_]]

# Use case
This benchmark comparison is performed on EDRs (Electronic Data Records) generated by a typical wireless telecommunications operator for monitoring & management of the network performance. This benchmark uses a synthetic data set generated using a simple python script. There are 2 data streams

* **Flows** - This data stream contains EDRs from the wireless network that collects telemetry information for a specific VOIP call or a user activity

*  **Sessions** - This data stream contains specific network events such as cell-tower handover during ongoing user activity such as VOIP calls or a browsing session.

The python script generates roughly 4 million flows records (EDRs) & a million sessions records  (EDRs) for every hour of operation of the wireless network. The number of hours of operation is passed as a parameter to the python script to generate the synthetic data.

# The SQL pipeline
The SQL pipeline performs a streaming join between Flows & Sessions streams and then compute time-series analytics, partitioned by cell-tower ID, to monitor the network performance. The SQL pipeline is described through a set of cascaded SQL views. These SQL views are are quite similar in syntax for both SQLstream as well as Flink. See [sqlstream.sql](./sqlstream.sql) and [flink.sql](./flink.sql) for the detailed view definitions.

1. `flows_fs` - This is a relational stream abstraction defined on Flows EDRs collected in CSV files
2. `parse_view` - This view simply extracts and projects all the columns (around 70) from the `Flows_fs` stream
3. `projection_view` - This view parses only 10 out of 70 columns from the Flows_fs stream
4. `agg_view` - This view computes time-series analytics on a 1-hour sliding window on flows_fs, partitioned by sessionid
5. `join_view` - This view joins flows and sessions pipelines on a 5-minute window.
6. `join_n_agg_view` - This view computes time-series analytics on a 1-hour sliding window on the streaming result of the Join_view, partitioned by cellid (cell-tower ID)

# Setting up SQLstream and Apache Flink
The benchmark expects that SQLstream and Flink are already installed on the host machine. The following steps describe how to install SQLstream s-Server and Flink, and how to test the SQL pipelines.

## Pre-requisites

1. Extract the attached tarball above under home directory
    ```
    tar xzvf sqlstream_flink.tar.gz
    cd ~/sqlstream_flink
    ```
2. Make sure openjdk-8-jdk & lsb-core packages on ubuntu are installed:
    ```
    sudo apt-get install -y openjdk-8-jdk lsb-core python3
    ```
3. Install libssl-1.1. If you are using Ubuntu 22.04, you need to `wget` it)
    ```
    wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
    sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
    ```
   * For CentOS/RHEL use the package manager to install equivalent packages

## Installing Apache Flink and SQLstream

1. Check `environment.sh` to verify you have the desired versions of Apache Flink and SQLstream s-Server
   * By default Apache Flink 1.15.2 will be downloaded from Apache; change the value of `FLINK_VERSION` if you want to test a different version
   * This repository currently expects the installer for s-Server 8.1.1.20580-1497075c7 to be added to the assets directory (it is **not** included in the repository); to use another version, either:
     1. Place the installer into the `assets` directory and modify the values of `SQLSTREAM_VERSION` and `SQLSTREAM_MAJOR_VERSION` in `environment.sh`
     2. Or set `SQLSTREAM_MAJOR_VERSION` to the version number of a generally available version that can be downloaded from http://downloads.sqlstream.com

4. Run the setup to install SQLstream s-Server (into `$HOME/sqlstream/<sqlstream_version>`) and Flink (into `$HOME/<flink_version>`). This can take 2-3 minutes.
    ```
    ./runSetup.sh
    ```
5. Generate the synthetic EDR data using the included python script (make sure to use `python3`). Run `python3 ./edrgen.py --help` for more help on parameters. This takes 20-40 minutes depending on the speed of your processor and the parameters used. You only need to do this once (unless you want to generate larger data sets). This command generates 360 mins (6 hours) of data:
    ```
    python3 ./edrgen.py -p 360
    ```
6. Copy (and concatenate) generated data files into /tmp directory
    ```
    cat flows_*.csv > /tmp/flows_all.csv
    cat sessions_*.csv > /tmp/sessions_all.csv
    ```

# Running the benchmark tests 

Use the `runTest.sh` script. This has two parameters:

* runtime: this must be supplied and can be `SQLstream` or `Flink` (any case accepted). You can abbreviate `SQLstream` to `S` or `SQL` and you can abbreviate `Flink` to `F`.
* viewname: can be any of the views mentioned above (`parse_view`,`projection_view`,`agg_view`,`join_view`,`join_n_agg_view`,`join_n_agg_view2`) but note that `join_n_agg_view2` is not supported by Flink. If ommitted then `join_n_Agg_view` is used. This parameter will accept any case.

## Run the benchmark tests using SQLstream s-Server

1. Ensure your environment is set (if this isn't already set from your `~/.profile` or `~/.bashrc`)
    ```
    source environment.sh
    ```
2. Run the throughput query on any one of the views mentioned in the earlier section 
(`parse_view`,`projection_view`,`agg_view`,`join_view`,`join_n_agg_view`,`join_n_agg_view2`)
    ```
    ./runTest.sh SQLSTREAM <viewname>  ## e.g., ./runTest.sh SQLSTREAM Agg_view
    ```
   * The `runTest.sh` script will stop the Flink cluster if necessary, and start or restart s-Server, so we always start from a consistent point.
   * The script reloads the schema for each run
   * Repeat tests with each view in turn.
   * The second column in the output shows rows/second
   * While tests are running, you may monitor physical memory and CPU% using the `top` or `vmstat` commands. 
   * use Cntrl-C to stop the test. The streaming query never spontaneously ends.
3. Finally, you stop s-Server:
    ```
    kill -TERM `jps | grep AspenVJdbc | awk '{print $1}'`
    ```
   * If you have sourced `environment.sh` you can stop s-Server using a bash function defined there:
    ```
    stopsServer
    ```

## Run the benchmark tests using Apache Flink.

1. Ensure your environment is set (if this isn't already set from your `~/.profile` or `~/.bashrc`)
    ```
    source environment.sh
    ```
2. Install the schema and run the throughput query on any one of the views mentioned in the earlier section (except `join_n_agg_view2`). Repeat tests with different view names (`parse_view`,`projection_view`,`agg_view`,`join_view`,`join_n_agg_view`)
    ```
    $ ./runTest.sh FLINK <viewname> 
    ```
   * The `runTest.sh` script will stop s-Server if necessary and start or restart the Flink cluster (so we always start from a consistent clean point, and we always take account of any changes to the Flink configuratiomn)
   * The script reloads the schema for each run
   * While tests are running, you may monitor Physical memory used and CPU% using the  `top` or  `vmstat` commands. 
   * This script also monitors the JVM using `jstat`. The name of the log file is reported at the start and end of the run in the form `/tmp/flink-jstat.<viewname>.<date>-<starttime>.log`, for example `/tmp/flink-jstat.join_n_agg_view.20221101-170000.log`.
   * The SQL script exits when the source data is exhausted
   * use Cntrl-C to interrupt the test if necessary
3. Repeat tests as required
4. Stop the Flink cluster:
    ```
    $FLINK_HOME/bin/stop-cluster.sh
    ```
### Investigating Flink Performance

#### EXPLAIN PLAN
If you need to see the Flink plan for the selected view, then set the `EXPLAIN_PLAN` environment variable to a any non-empty value before running the script.

#### Capturing Flink configuration and GC metrics using `jstat`

An `awk` script is provided to analyze the garbage collection metrics generated by `jstat`. 

For convenience the log file also captures some configuration information (FLINK_VERSION, the java version, non-defaulted properties from the Flink configuration file and the `ps` listing of the task manager showing the full command line).

#### Example log file
```
# FLINK_VERSION=flink-1.15.2
# FLINK_HOME=/home/nigel/flink-1.15.2
# JAVA_VERSION=
#
# Flink configuration:
#
# jobmanager.rpc.address: localhost
# jobmanager.rpc.port: 6123
# jobmanager.bind-host: localhost
# jobmanager.memory.process.size: 1600m
# taskmanager.bind-host: localhost
# taskmanager.host: localhost
# taskmanager.memory.process.size: 8g
# taskmanager.memory.managed.fraction: 0.4
# taskmanager.numberOfTaskSlots: 1
# parallelism.default: 1
# jobmanager.execution.failover-strategy: region
# rest.address: localhost
# rest.bind-address: localhost
#
# Task Manager Command line:
# UID        PID  PPID  C STIME TTY      STAT   TIME CMD
# nigel    17855 16894  0 15:28 pts/1    Sl+    0:00 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -XX:+UseG1GC -Xmx3597035049 -Xms3597035049 -XX:MaxDirectMemorySize=880468305 -XX:MaxMetaspaceSize=268435456 -Dlog.file=/home/nigel/flink-1.15.2/log/flink-nigel-taskexecutor-0-c-3JWNJG3.log -Dlog4j.configuration=file:/home/nigel/flink-1.15.2/conf/log4j.properties -Dlog4j.configurationFile=file:/home/nigel/flink-1.15.2/conf/log4j.properties -Dlogback.configurationFile=file:/home/nigel/flink-1.15.2/conf/logback.xml -classpath /home/nigel/flink-1.15.2/lib/flink-cep-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-connector-files-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-csv-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-json-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-scala_2.12-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-shaded-zookeeper-3.5.9.jar:/home/nigel/flink-1.15.2/lib/flink-table-api-java-uber-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-table-planner-loader-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-table-runtime-1.15.2.jar:/home/nigel/flink-1.15.2/lib/log4j-1.2-api-2.17.1.jar:/home/nigel/flink-1.15.2/lib/log4j-api-2.17.1.jar:/home/nigel/flink-1.15.2/lib/log4j-core-2.17.1.jar:/home/nigel/flink-1.15.2/lib/log4j-slf4j-impl-2.17.1.jar:/home/nigel/flink-1.15.2/lib/flink-dist-1.15.2.jar::: org.apache.flink.runtime.taskexecutor.TaskManagerRunner --configDir /home/nigel/flink-1.15.2/conf -D taskmanager.memory.network.min=746250577b -D taskmanager.cpu.cores=1.0 -D taskmanager.memory.task.off-heap.size=0b -D taskmanager.memory.jvm-metaspace.size=268435456b -D external-resources=none -D taskmanager.memory.jvm-overhead.min=858993472b -D taskmanager.memory.framework.off-heap.size=134217728b -D taskmanager.memory.network.max=746250577b -D taskmanager.memory.framework.heap.size=134217728b -D taskmanager.memory.managed.size=2985002310b -D taskmanager.memory.task.heap.size=3462817321b -D taskmanager.numberOfTaskSlots=1 -D taskmanager.memory.jvm-overhead.max=858993472b
#
Timestamp        S0C    S1C    S0U    S1U      EC       EU        OC         OU       MC     MU    CCSC   CCSU   YGC     YGCT    FGC    FGCT     GCT
            0.2  0.0    0.0    0.0    0.0   184320.0 21504.0  3330048.0     0.0     4480.0 781.5  384.0   76.6       0    0.000   0      0.000    0.000
           30.2  0.0   132096.0  0.0   132096.0 1601536.0 654336.0 1780736.0  1378304.0  58160.0 54440.6 7984.0 7387.9     49    3.617   0      0.000    3.617
           60.2  0.0   26624.0  0.0   26624.0 1132544.0 542720.0 2355200.0  1976149.0  58416.0 54441.2 7984.0 7366.8    188   13.722   0      0.000   13.722
           90.2  0.0   15360.0  0.0   15360.0 1145856.0 284672.0 2353152.0  1962898.5  58416.0 54600.7 7984.0 7370.6    359   25.353   0      0.000   25.353
          120.2  0.0   39936.0  0.0   39936.0 1108992.0 1053696.0 2365440.0  1994240.5  58416.0 54656.8 7984.0 7370.6    524   36.703   0      0.000   36.703
          150.2  0.0   15360.0  0.0   15360.0 168960.0 26624.0  3330048.0  1970363.0  58672.0 54737.2 7984.0 7372.3    695   48.983   0      0.000   48.983
          180.2  0.0   19456.0  0.0   19456.0 164864.0 54272.0  3330048.0  1962290.0  58672.0 54807.8 7984.0 7375.6    874   61.290   0      0.000   61.290
          210.2  0.0   15360.0  0.0   15360.0 168960.0 54272.0  3330048.0  2061548.0  58672.0 54822.4 7984.0 7375.6   1049   73.400   0      0.000   73.400
          240.2  0.0   17408.0  0.0   17408.0 166912.0 116736.0 3330048.0  1907507.5  58672.0 54851.9 7984.0 7375.6   1226   85.738   0      0.000   85.738
          270.2  0.0   12288.0  0.0   12288.0 172032.0  7168.0  3330048.0  1899520.0  58672.0 54871.2 7984.0 7375.6   1399   97.753   0      0.000   97.753
          300.2  0.0   20480.0  0.0   20480.0 163840.0 152576.0 3330048.0  1904402.5  58928.0 54989.6 7984.0 7375.6   1572  109.689   0      0.000  109.689
          329.8  0.0   10240.0  0.0   10240.0 174080.0 35840.0  3330048.0  2016909.0  59312.0 55161.3 8112.0 7412.0   1736  120.474   0      0.000  120.474
```
#### Log file transformed using `awk`

```
cat /tmp/flink-jstat.agg_view.20221102-152858.log | awk -f jstat.awk
```

The result retains the configuration information and the remainder now looks like:

```
#
Timestamp,HeapUsedGib,HeapCurrentGib,YGC,YGCT,FGC,FGCT,GCT,DeltaGC%,GC%
0,0.021,3.352,0,0.00,0,0.00,0.00, 0.000%, 0.000%
30,2.064,3.352,49,3.62,0,0.00,3.62,12.057%,12.057%
60,2.428,3.352,188,13.72,0,0.00,13.72,33.683%,22.870%
90,2.158,3.352,359,25.35,0,0.00,25.35,38.770%,28.170%
120,2.945,3.352,524,36.70,0,0.00,36.70,37.833%,30.586%
150,1.919,3.352,695,48.98,0,0.00,48.98,40.933%,32.655%
180,1.942,3.352,874,61.29,0,0.00,61.29,41.023%,34.050%
210,2.032,3.352,1049,73.40,0,0.00,73.40,40.367%,34.952%
240,1.947,3.352,1226,85.74,0,0.00,85.74,41.127%,35.724%
270,1.830,3.352,1399,97.75,0,0.00,97.75,40.050%,36.205%
300,1.981,3.352,1572,109.69,0,0.00,109.69,39.787%,36.563%
329,1.967,3.352,1736,120.47,0,0.00,120.47,37.190%,36.618%
```

* `HeapUsedGib` is the sum of `S0U + S1U + EU + OU`
* `HeapCurrentGib` is the sum of `S0C + S1C + EC + OC`
* `GC%` is time spent in GC divided by total time - `GCT*100/Timestamp`%
* `DeltaGC%` us the time ratio for GC in the last period

Any rows where there are no GC executions are dropped.

This example shows quite significant GC activity (climbing up towards 40% of time used).

## Benchmark Results

* With Generated EDR Data
* On a laptop with Intel Core i7-10875H
* Running Flink 1.15.1 vs SQLstream s-Server 8.1.0

| Run | Engine | Memory Used| RPS | RPS Ratio<br/>(SQLstream / Flink)| Cores | RPS/core | RPS/core Ratio<br/>(SQLstream / Flink) |
|----|----|----|----|----|----|----|----|
| `parse_view` (70 columns)| Flink | 1GB of 2GB Max | 148K | 1 | 1.85 | 80K | 1
|                       | SQLstream  | 1GB of 2GB Max | 238K | 1.6 | 1.7 | 140K | 1.75
| `projection_view` (10 of 70 columns) | Flink | 1GB of 2GB Max | 154K | 1 | 2.0 | 77K | 1  
| | SQLstream | 1GB of 2GB Max | 881K | 5.7 | 1.9 | 463K | 6
| `agg_view (Min, Max, Sum, Count)` | Flink | 5GB of 8GB Max | 44K | 1 | 9 | 5K | 
1
| | SQLstream | 1.1GB of 2GB Max | 452K | 7.8 | 1.6 | 282K | 57 
| `session_join_view` (60-minute session window) | Flink | NA | NA | NA | NA | NA | NA
| SQLstream | 1.1GB of 2GB Max | 822K | - | 3.5 | 235K | - 
| `join_view` (5-minute sliding window) | Flink | 5GB of 8GB Max | 107K | 1 | 7 | 18K | 1
| | SQLstream | 1.4GB of 2GB Max | 735K | 6.8 | 4 | 183K | 10 | 
| `join_n_agg_view` (zero offset) | Flink | 6GB of 8GB Max | 96K | 1 | 4 | 24K | 1 
| | SQLstream | 1.7GB of 2GB Max | 149K | 1.5 | 1.4 | 106K | 4.4 | 

# Deploying sharded pipelines in SQLstream

1. Start SQLstream s-Server, running as a background task
    ```
    $SQLSTREAM_HOME/bin/s-Server --daemon &
    ```
   * If you have sourced `environment.sh` you can execute a function:
    ```
    startsServer
    ```
2. Load the schema and define SQL pipelines (pumps)
    ```
    $SQLSTREAM_HOME/bin/sqllineClient --run=catalog.distributed.sql
    ```
3. Run the application with 2 shards. The result stream reports avg_rows_per_second updated every second
    ```
    $SQLSTREAM_HOME/bin/sqllineClient --run=run.distributed.sql
    ```
4. While tests are running, you may monitor physical memory and CPU% using the `top` command. You can record stats using `vmstat`.
5. Stop the test.
6. Edit `run.distributed.sql` to set `num_shards = 1` and modify the `ALTER PUMP` statement as described in inline comments. Then:
    ```
    $HOME/sqlstream/8.1.1*/s-Server/bin/sqllineClient --run=run.distributed.sql
    ```
# Contents of this repository

| File | Description
| ---- | ------ |
| `.gitignore` | gitignore file
| `README.md` | This file
| `assets` | Directory containing a development build of SQLstream s-Server
| `catalog.distributed.sql` | Deploys SQLstream schema for sharded pipeline 
| `edrgen.md` | README for `edrgen.py`
| `edrgen.py` | The data generator for these benchmark tests
| `environment.sh` | script to set environment for SQLstream and Flink
| `eval_2022_12.lic` | a SQLstream license file expires 31-Dec-2022
| `flink.sql` | The Apache Flink SQL script for creating the test schema
| `jstat.awk` | Awk file to analyse the `jstat -gc` output
| `repro.sql` | TBA
| `run.distributed.sql` | Executes the sharded SQLstream deployment
| `runSetup.sh` | script to install SQLstream and Flink
| `runTest.sh` | script to read from any one of the test views in SQLstream or Flink
| `sqlstream.sql` | The SQLstream SQL script for creating the test schema
| `ss_template.sql` | The model SQLstream script used for reading from the test views
