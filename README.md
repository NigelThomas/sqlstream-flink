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

# Running all the benchmark tests in sequence

We recommend that you start by [running one or two tests individually](#running-the-benchmark-tests-individually) for each of SQLstream and Flink (see the next section). Once you are comfortable that your installation is working, you can run all the tests in sequence using `runAllTests.sh`:

```
./runAllTests.sh
```

This will execute all the tests for SQLstream, followed by all the tests for Apache Flink.

The runtime engine (s-Server or the Flink cluster as required) is restarted for each test.

Log files are produced into the `logs` directory as described in [Monitoring Benchmark Performance](#monitoring-benchmark-performance) below.

To run only the SQLstream tests, or only the Flink tests, use:

```
./runAllTests.sh sqlstream

./runAllTests.sh flink
```

# Running the benchmark tests individually

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
   * Use Cntrl-C to interrupt the test if required
   * The script will terminate itself when it reaches end of data
   * The script will shutdown s-Server.

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
## Monitoring Benchmark Performance

The test harness collects data while each test is running:

| Log file suffix | Applies to | Contains
| `config.log` | Both | For SQLstream - license, java version, aspen properties <br/>For Flink - java version, config properties, and the Task Manager command line |
| `top.log` | Both | Output from `top` at 10 second intervals, with summary info and details for the server process(es) - s-Server for SQLstream, and the Task Manager and Job Manager for Flink
| `jstat.log` | Flink only | `jstat -gc -t <Task Manager pid> 10s` output from the Task Manager
| `run.log` | Both | Records the SQL session query results (for Flink this also includes the catalog creation) 

Files are placed in the `logs/<engine-version>` directory and named `<date>.<time>.<viewname>.<log file suffix>`, for example `logs/sqlstream-8.1.1.2048798-d5538544/20221103.111733.projection_view.top.log` or `logs/flink-1.15.2/20221103.094843.projection_view.jstat.log`.

### Recording the SQL client console

`runTest.sh` records the SQL client console output to the `run.log` file.

#### Example SQLstream `run.log`
The SQLstream output includes the number of rows returned, and the time taken to execute the query:

```
Connecting to jdbc:sqlstream:sdp://c-3JWNJG3;sessionName='sqllineClient:nigel@c-3JWNJG3'
Connected to: SQLstream (version 8.1.1.2048798-d5538544)
Driver: SQLstreamJdbcDriver (version 7.0-distrib)
Autocommit status: true
Transaction isolation: TRANSACTION_REPEATABLE_READ
sqlline version 1.0.13-mb by Marc Prud'hommeaux
0: jdbc:sqlstream:sdp://c-3JWNJG3>
0: jdbc:sqlstream:sdp://c-3JWNJG3> SELECT STREAM s.ROWTIME, *
. . . . . . . . . . . . . . . . .>        , cast((unix_timestamp(s.rowtime) - unix_timestamp(current_timestamp))/1000 as int) as "TestSecs"
. . . . . . . . . . . . . . . . .> FROM STREAM (DATA_RATE_RPS(CURSOR (SELECT STREAM * FROM EDR.projection_view))) s
. . . . . . . . . . . . . . . . .> -- don't show rows where progress has stopped
. . . . . . . . . . . . . . . . .> WHERE RPS > 0
. . . . . . . . . . . . . . . . .> ;
'ROWTIME','RPS','BOUNDS','TIMEOUTS','CUMULATIVE_ROWS','ROWTIME_LOW','ROWTIME_HIGH','TestSecs'
'2022-11-03 12:48:58.0','1','0','0','1 | 00:00:00.0 | 00:00:00.0','0'
'2022-11-03 12:48:59.0','141863','0','0','141864 | 00:00:00.003 | 00:02:06.985','0'
'2022-11-03 12:49:00.0','1450038','0','0','1591902 | 00:02:06.989 | 00:23:37.421','1'
'2022-11-03 12:49:01.0','1485908','0','0','3077810 | 00:23:37.425 | 00:45:38.96','2'
'2022-11-03 12:49:02.0','1499027','0','0','4576837 | 00:45:38.964 | 01:07:57.251','3'
'2022-11-03 12:49:03.0','1516493','0','0','6093330 | 01:07:57.251 | 01:30:30.315','4'
'2022-11-03 12:49:04.0','1514645','0','0','7607975 | 01:30:30.319 | 01:52:59.985','5'
'2022-11-03 12:49:05.0','1503017','0','0','9110992 | 01:52:59.989 | 02:15:19.007','6'
'2022-11-03 12:49:06.0','1523223','0','0','10634215 | 02:15:19.007 | 02:37:48.425','7'
'2022-11-03 12:49:07.0','1494883','0','0','12129098 | 02:37:48.425 | 02:59:56.882','8'
'2022-11-03 12:49:08.0','1484862','0','0','13613960 | 02:59:56.882 | 03:21:55.195','9'
'2022-11-03 12:49:09.0','1515102','0','0','15129062 | 03:21:55.195 | 03:44:28.815','10'
'2022-11-03 12:49:10.0','1519063','0','0','16648125 | 03:44:28.815 | 04:07:02.748','11'
'2022-11-03 12:49:11.0','1518911','0','0','18167036 | 04:07:02.748 | 04:29:33.343','12'
'2022-11-03 12:49:12.0','1512751','0','0','19679787 | 04:29:33.347 | 04:51:58.641','13'
'2022-11-03 12:49:13.0','1463113','0','0','21142900 | 04:51:58.645 | 05:13:40.957','14'
'2022-11-03 12:49:14.0','1494519','0','0','22637419 | 05:13:40.957 | 05:35:49.989','15'
'2022-11-03 12:49:15.0','1490336','0','0','24127755 | 05:35:49.992 | 05:57:56.549','16'
'2022-11-03 12:49:15.0','138132','0','0','24265887 | 05:57:56.549 | 05:59:59.996','16'
19 rows selected (16.426 seconds)
0: jdbc:sqlstream:sdp://c-3JWNJG3> Closing: com.sqlstream.aspen.vjdbc.AspenDbcConnection
```

#### Example Flink `run.log`

The Flink SQL client loads the catalog and then runs the query in the same session, so the log includes the catalog being loaded.

Note that the SQL client decorates its output with colour. The control characters are included in this log. Per [SQL Client Startup Options](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sqlclient/#sql-client-startup-options) there doesn't seem to be a way to remove this decoration.

```
^[[34;1m[INFO] Executing SQL from file.^[[0m

Command history file path: /home/nigel/.flink-sql-history
Flink SQL> ^[[34;1m[INFO] Session property has been set.^[[0m

Flink SQL> ^[[34;1m[INFO] Session property has been set.^[[0m

Flink SQL>
> CREATE OR REPLACE TABLE flows_fs
> (
> load_ts VARCHAR(32),
> event_time VARCHAR(32),
> -- eventtime as CASE WHEN CHAR_LENGTH(event_time) = 22 THEN FLOOR(TO_TIMESTAMP(SUBSTRING(event_time, 1, 19) || '.000') TO MINUTE) ELSE FLOOR(TO_TIMESTAMP(event_time) TO MINUTE) END ,
> eventtime as CASE WHEN CHAR_LENGTH(event_time) = 22 THEN TO_TIMESTAMP(SUBSTRING(event_time, 1, 19) || '.000') ELSE TO_TIMESTAMP(event_time) END ,
> creationtime VARCHAR(32),
> lastaccesstime VARCHAR(32),
> flowid VARCHAR(8),
> bearerid VARCHAR(4),
> sessionid VARCHAR(16),
> recordtype VARCHAR(32),

<snipped the rest of the catalog>

Flink SQL>
> CREATE OR REPLACE VIEW join_n_agg_view AS
> SELECT cellid, Octets, eventtime,
> Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
> Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
> FROM join_view as s
> WINDOW w AS (PARTITION BY cellid
>             ORDER BY eventtime
>             RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING AND CURRENT ROW)^[[34;1m[INFO] Execute statement succeed.^[[0m

Flink SQL>
>
> SELECT *, TIMESTAMPDIFF(SECOND, timestamp '2022-11-03 12:58:10', clocktime)-5 as testsecs FROM (
> SELECT TUMBLE_START(a.proc_time, INTERVAL '1' SECOND) as clocktime, COUNT(*) as recs_per_sec, max(eventtime) as max_event_time_projection_view
> FROM (select PROCTIME() as proc_time, * from projection_view) AS a
> GROUP BY TUMBLE(a.proc_time, INTERVAL '1' SECOND)
> )+----+-------------------------+----------------------+--------------------------------+-------------+
| op |               clocktime |         recs_per_sec | max_event_time_projection_view |    testsecs |
+----+-------------------------+----------------------+--------------------------------+-------------+
| +I | 2022-11-03 12:58:16.000 |                14384 |        2022-01-01 00:00:12.783 |           1 |
| +I | 2022-11-03 12:58:17.000 |               173926 |        2022-01-01 00:02:48.088 |           2 |
| +I | 2022-11-03 12:58:18.000 |               231469 |        2022-01-01 00:06:12.960 |           3 |
| +I | 2022-11-03 12:58:19.000 |               255003 |        2022-01-01 00:10:00.836 |           4 |

<snipped some results>

| +I | 2022-11-03 12:59:48.000 |               246568 |        2022-01-01 05:35:50.950 |          93 |
| +I | 2022-11-03 12:59:49.000 |               255602 |        2022-01-01 05:39:37.546 |          94 |
| +I | 2022-11-03 12:59:50.000 |               253697 |        2022-01-01 05:43:23.897 |          95 |
| +I | 2022-11-03 12:59:51.000 |               251080 |        2022-01-01 05:47:07.985 |          96 |
| +I | 2022-11-03 12:59:52.000 |               251083 |        2022-01-01 05:50:51.166 |          97 |
| +I | 2022-11-03 12:59:53.000 |               248469 |        2022-01-01 05:54:31.329 |          98 |
| +I | 2022-11-03 12:59:54.000 |               249770 |        2022-01-01 05:58:15.407 |          99 |
+----+-------------------------+----------------------+--------------------------------+-------------+
Received a total of 99 rows

Flink SQL>
Shutting down the session...
done.
```
### Collecting configuration information

The `runTest.sh` script collects some basic configuration information and stores it in the logs directory.

#### SQLstream config log example
```
Searching for SQLstream s-Server licenses...
Missing tool /appactutil
 1. Renewable license in /home/nigel/tgl/sqlstream-flink/eval_2022_12.lic, expires 5-dec-2022  Version: 6.0, Attributes: "name: eval max-threads:0 installation-id:null license-check-period:2h usage-check-period:never usage-report-period:never throttle-when:never" HOSTID=ANY ISSUER="SQLstream Inc." ISSUED=5-oct-2022 START=4-oct-2022

openjdk version "1.8.0_312"
OpenJDK Runtime Environment (build 1.8.0_312-8u312-b07-0ubuntu1~20.04-b07)
OpenJDK 64-Bit Server VM (build 25.312-b07, mixed mode)

---- aspen.properties ----
aspen.test.noisy=true
aspen.test.noisy.timeout=60
aspen.test.server.jvm=internal
aspen.test.jdbc.stress.stmtsPerConn=2049
aspen.test.jdbc.stress.colsPerQuery=1980
aspen.test.repos.url=MDR
aspen.pumpmanager.startPumpsAtBoot=true
aspen.test.schema.names=JDBCTEST,JDBC_METADATA,MGMT
aspen.test.plugin.names=ECDA,AMQP10_SERVER,AMQP_LEGACY_SERVER,FILE_SERVER,HDFS_SERVER,HIVE_SERVER,HTTP_SERVER,KAFKA10_SERVER,KAFKA_SERVER,KINESIS_SERVER,MAIL_SERVER,MONGODB_SERVER,MQTT_SERVER,NET_SERVER,SNOWFLAKE_SERVER,WEBSOCKET_SERVER
aspen.dev.mode=true
aspen.trace.sampleLateRows=true
aspen.trace.sampleFailedRows=true
aspen.xo.useDoubleBuffering=true
aspen.sched.checker.timezone=America/Los_Angeles
aspen.sched.license.useTrustedStorage=true
aspen.sched.diamond.period = -1
BYTE_SIZE=64
aspen.tmp.dir=tmp
aspen.tmp.trace.dir=tmp/trace
aspen.perf.test.results=performanceTestResults.json
aspen.sdp.port=5570
aspen.installation.company=acompany
aspen.installation.email=nouser@acompany.com
```
#### Apache Flink config log example
```
FLINK_VERSION=flink-1.15.2
FLINK_HOME=/home/nigel/flink-1.15.2

openjdk version "1.8.0_312"
OpenJDK Runtime Environment (build 1.8.0_312-8u312-b07-0ubuntu1~20.04-b07)
OpenJDK 64-Bit Server VM (build 25.312-b07, mixed mode)

Flink configuration:

jobmanager.rpc.address: localhost
jobmanager.rpc.port: 6123
jobmanager.bind-host: localhost
jobmanager.memory.process.size: 1600m
taskmanager.bind-host: localhost
taskmanager.host: localhost
taskmanager.memory.process.size: 8g
taskmanager.memory.managed.fraction: 0.4
taskmanager.numberOfTaskSlots: 1
parallelism.default: 1
jobmanager.execution.failover-strategy: region
rest.address: localhost
rest.bind-address: localhost

Task Manager Command line:
UID        PID  PPID  C STIME TTY      STAT   TIME CMD
nigel     7214  6918  0 12:32 pts/3    Sl+    0:00 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -XX:+UseG1GC -Xmx3597035049 -Xms3597035049 -XX:MaxDirectMemorySize=880468305 -XX:MaxMetaspaceSize=268435456 -Dlog.file=/home/nigel/flink-1.15.2/log/flink-nigel-taskexecutor-0-c-3JWNJG3.log -Dlog4j.configuration=file:/home/nigel/flink-1.15.2/conf/log4j.properties -Dlog4j.configurationFile=file:/home/nigel/flink-1.15.2/conf/log4j.properties -Dlogback.configurationFile=file:/home/nigel/flink-1.15.2/conf/logback.xml -classpath /home/nigel/flink-1.15.2/lib/flink-cep-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-connector-files-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-csv-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-json-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-scala_2.12-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-shaded-zookeeper-3.5.9.jar:/home/nigel/flink-1.15.2/lib/flink-table-api-java-uber-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-table-planner-loader-1.15.2.jar:/home/nigel/flink-1.15.2/lib/flink-table-runtime-1.15.2.jar:/home/nigel/flink-1.15.2/lib/log4j-1.2-api-2.17.1.jar:/home/nigel/flink-1.15.2/lib/log4j-api-2.17.1.jar:/home/nigel/flink-1.15.2/lib/log4j-core-2.17.1.jar:/home/nigel/flink-1.15.2/lib/log4j-slf4j-impl-2.17.1.jar:/home/nigel/flink-1.15.2/lib/flink-dist-1.15.2.jar::: org.apache.flink.runtime.taskexecutor.TaskManagerRunner --configDir /home/nigel/flink-1.15.2/conf -D taskmanager.memory.network.min=746250577b -D taskmanager.cpu.cores=1.0 -D taskmanager.memory.task.off-heap.size=0b -D taskmanager.memory.jvm-metaspace.size=268435456b -D external-resources=none -D taskmanager.memory.jvm-overhead.min=858993472b -D taskmanager.memory.framework.off-heap.size=134217728b -D taskmanager.memory.network.max=746250577b -D taskmanager.memory.framework.heap.size=134217728b -D taskmanager.memory.managed.size=2985002310b -D taskmanager.memory.task.heap.size=3462817321b -D taskmanager.numberOfTaskSlots=1 -D taskmanager.memory.jvm-overhead.max=858993472b
```

### Monitoring process CPU and memory usage using `top`

When running either SQLstream or Apache Flink tests, the `runTest.sh` script starts off a process in the background that uses `top` to log stats in batch mode, by default every 10 seconds.

You will see the system-wide summary reported in each period; you will also see:

* For SQLstream, the s-Server process - known to `jps` as `AspenVJdbcServer`.
* For Flink, two processes - those java JVMs knowm to `jps` as `TaskManagerRunner` and `StandaloneSessionCluster`.


The data is logged to `/tmp/<engine>-top.<viewname>.<date>-<time>.log` - for example `/tmp/flink-top.projection_view.20221102-171451.log`

#### Example Flink `top.log`

An example of the Flink output is here. Note how we include the output of `jps` at the top of the file so we can identify the PIDs of the JVMs we are interested in:

```
32674 TaskManagerRunner
32372 StandaloneSessionClusterEntrypoint

top - 17:38:37 up 2 days, 19:47,  0 users,  load average: 0.80, 0.18, 0.50
Tasks:   2 total,   0 running,   2 sleeping,   0 stopped,   0 zombie
%Cpu(s): 35.9 us,  6.2 sy,  0.0 ni, 56.6 id,  0.0 wa,  0.0 hi,  1.2 si,  0.0 st
GiB Mem :     24.8 total,      8.5 free,      0.5 used,     15.9 buff/cache
GiB Swap:      7.0 total,      6.9 free,      0.1 used.     24.0 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
32674 nigel     20   0 8529408 143708  23968 S 213.3   0.6   0:00.79 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -XX:+UseG1GC -Xmx3597035049 -Xms3597035049 -XX:MaxDirect+
32372 nigel     20   0 4749356 188916  25260 S 200.0   0.7   0:01.73 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -Xmx1073741824 -Xms1073741824 -XX:MaxMetaspaceSize=26843+

top - 17:38:47 up 2 days, 19:47,  0 users,  load average: 1.06, 0.26, 0.52
Tasks:   2 total,   0 running,   2 sleeping,   0 stopped,   0 zombie
%Cpu(s): 23.9 us,  2.7 sy,  0.0 ni, 72.9 id,  0.0 wa,  0.0 hi,  0.5 si,  0.0 st
GiB Mem :     24.8 total,      4.3 free,      4.5 used,     16.0 buff/cache
GiB Swap:      7.0 total,      6.9 free,      0.1 used.     20.0 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
32674 nigel     20   0   12.4g   3.1g  28420 S 214.7  12.7   0:22.26 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -XX:+UseG1GC -Xmx3597035049 -Xms3597035049 -XX:MaxDirect+
32372 nigel     20   0   10.6g 535120  25324 S  70.5   2.1   0:08.78 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -Xmx1073741824 -Xms1073741824 -XX:MaxMetaspaceSize=26843+

top - 17:38:57 up 2 days, 19:48,  0 users,  load average: 1.28, 0.33, 0.54
Tasks:   2 total,   0 running,   2 sleeping,   0 stopped,   0 zombie
%Cpu(s): 15.5 us,  0.7 sy,  0.0 ni, 83.1 id,  0.0 wa,  0.0 hi,  0.8 si,  0.0 st
GiB Mem :     24.8 total,      4.1 free,      4.7 used,     16.0 buff/cache
GiB Swap:      7.0 total,      6.9 free,      0.1 used.     19.8 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
32674 nigel     20   0   12.5g   3.2g  28420 S 226.8  12.8   0:44.96 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -XX:+UseG1GC -Xmx3597035049 -Xms3597035049 -XX:MaxDirect+
32372 nigel     20   0   10.6g 546652  25324 S  12.1   2.1   0:09.99 /usr/lib/jvm/java-8-openjdk-amd64/bin/java -Xmx1073741824 -Xms1073741824 -XX:MaxMetaspaceSize=26843+
```
In this example we can see that the TaskManager (pid=21926) started at 273% `%CPU`, falling to 220% in the last period included here. We know this is the TaskManager because it has the larger figure for `RES`.
<!--TODO: add awk file to reformat this into something more concise / Excel ready-->

### Investigating Flink Performance using `jstat`

The `jstat.log` monitoring is only provided for Apache Flink. Most SQLstream memory management is handled by the core C++ code.

#### Example `jstat.log` file
This is generated from an `agg_view` test.
```
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

An `awk` script is provided to analyze the garbage collection metrics generated by `jstat`. 

```
cat /tmp/flink-jstat.agg_view.20221102-152858.log | awk -f jstat.awk
```

The result now looks like:

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

### Other performance tuning information

#### EXPLAIN PLAN
If you need to see the Flink plan for the selected view, then set the `EXPLAIN_PLAN` environment variable to a any non-empty value before running the script. The plan will be listed and no log files will be produced.


# Benchmark Results

* With Generated EDR Data

## Running Flink 1.15.1 vs SQLstream s-Server 8.1.0
* On a laptop with Intel Core i7-10875H

| Run | Engine | Memory Used| RPS | RPS Ratio<br/>(SQLstream / Flink)| Cores | RPS/core | RPS/core Ratio<br/>(SQLstream / Flink) |
|----|----|----|----|----|----|----|----|
| `parse_view` (70 columns)| Flink | 1GB of 2GB Max | 148K | 1 | 1.85 | 80K | 1
|                       | SQLstream  | 1GB of 2GB Max | 238K | 1.6 | 1.7 | 140K | 1.75
| `projection_view` (10 of 70 columns) | Flink | 1GB of 2GB Max | 154K | 1 | 2.0 | 77K | 1  
| | SQLstream | 1GB of 2GB Max | 881K | 5.7 | 1.9 | 463K | 6
| `agg_view (Min, Max, Sum, Count)` | Flink | 5GB of 8GB Max | 44K | 1 | 9 | 5K | 1
| | SQLstream | 1.1GB of 2GB Max | 452K | 7.8 | 1.6 | 282K | 57 
| `session_join_view` (60-minute session window) | Flink | NA | NA | NA | NA | NA | NA
| SQLstream | 1.1GB of 2GB Max | 822K | - | 3.5 | 235K | - 
| `join_view` (5-minute sliding window) | Flink | 5GB of 8GB Max | 107K | 1 | 7 | 18K | 1
| | SQLstream | 1.4GB of 2GB Max | 735K | 6.8 | 4 | 183K | 10 | 
| `join_n_agg_view` (zero offset) | Flink | 6GB of 8GB Max | 96K | 1 | 4 | 24K | 1 
| | SQLstream | 1.7GB of 2GB Max | 149K | 1.5 | 1.4 | 106K | 4.4 | 

## Running Flink 1.15.2 vs SQLstream s-Server 8.1.1
* On a laptop with  Intel(R) Core(TM) i7-11850H @ 2.50GHz - 16 cores/threads
* Windows Subsystem for Linux / Ubuntu 20.04
* 32GB RAM

* Coming soon...

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
# Useful commands for managing SQLstream and Flink

## Starting s-Server
    ```
    $SQLSTREAM_HOME/bin/s-server --daemon &
    ```
If you have sourced `environment.sh` you can start s-Server using a bash function defined there:
    ```
    startsServer
    ```

## Stopping s-Server
    ```
    kill -TERM `jps | grep AspenVJdbc | awk '{print $1}'`
    ```
If you have sourced `environment.sh` you can stop s-Server using a bash function defined there:
    ```
    stopsServer
    ```
## Starting Flink
```
$FLINK_HOME/bin/start-cluster.sh
```

## Stopping Flink
```
$FLINK_HOME/bin/stop-cluster.sh
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
| `runAllTests.sh` | script to run all tests in sequence for SQLstream and Flink 
| `runSetup.sh` | script to install SQLstream and Flink
| `runTest.sh` | script to read from any one of the test views in SQLstream or Flink
| `sqlstream.sql` | The SQLstream SQL script for creating the test schema
| `ss_template.sql` | The model SQLstream script used for reading from the test views

# Differences in logical (time-based) sliding window semantics between Flink and SQLstream

Apache Flink follows window semantics as they are defined in the SQL standard, with the limitations that:
* the ORDER BY can only be defined against an ascending [time attribute](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/concepts/time_attributes/). 
* The time attribute used must be defined against the source **table** (either as a regular column or as a column derived from a regular column)

SQLstream follows the SQL standard, except that:
* the ORDER BY can only be defined against the ROWTIME column, or a monotonic function of it. The ROWTIME may be derived from any timestamp data attribute using a [ROWTIME promotion](https://docs.sqlstream.com/concepts/streaming-data-and-windows/advanced-stream-resequencing/).
* The latest edge of (non-offset) sliding windows always includes the current row but no following rows, whereas according to the SQL standard the window should also include any following rows that have the same ORDER BY key value. 

This example shows the difference in a specific case - see [testwindow-flink.sql](./testwindow-flink.sql), [testwindow-sqlstream.sql](./testwindow-sqlstream.sql) and the data set [testwindow.dat](./testwindow.dat).

(Timestamps below have the date removed only to save space).

In the Flink results we can see that rows A, B and C all have the same window expression values (MIN, MAX, COUNT) = (A, C, 3) whereas for SQLstream we see (A, A, 1), (A, B, 2) and (A, C, 3). Rows drop out of the window at the same time in both SQLstream and Flink, but they are added to the window at different times.

| event_time | c1 |   min_et<br/>(F) |   max_et<br/>(F) | min_c1 <br/>(F) | max_c1 <br/>(F) | cnt <br/>(F) | min_et<br/>(S) |   max_et<br/>(S) | min_c1 <br/>(S) | max_c1 <br/>(S) | cnt <br/>(S) |
| ---------- | ---- |------- | -------- | ------ |------ | ---- | ------- | -------- | ------ |------ | ---- | 
|   00:01:01 |  A | 00:01:01 | 00:01:03 |      A |      C |   3 | 00:01:01| 00:01:01|A |A |1
|   00:01:02 |  B | 00:01:01 | 00:01:03 |      A |      C |   3 | 00:01:01| 00:01:02 |A |B |2
|   00:01:03 |  C | 00:01:01 | 00:01:03 |      A |      C |   3 | 00:01:01| 00:01:03 |A |C |3
|   00:02:01 |  D | 00:01:01 | 00:02:02 |      A |      E |   5 | 00:01:01| 00:02:01 |A |D |4
|   00:02:02 |  E | 00:01:01 | 00:02:02 |      A |      E |   5 | 00:01:01| 00:02:02 |A |E |5
|   00:03:01 |  F | 00:01:01 | 00:03:01 |      A |      F |   6 | 00:02:01| 00:03:01 |D |F |3
|   00:04:01 |  G | 00:02:01 | 00:04:02 |      D |      H |   5 | 00:03:01|00:04:01 |F |G |2 
|   00:04:02 |  H | 00:02:01 | 00:04:02 |      D |      H |   5 | 00:03:01| 00:04:02 |F |H |3
|   00:05:01 |  I | 00:03:01 | 00:05:03 |      F |      K |   6 |00:04:01 | 00:05:01 |G |I |3
|   00:05:02 |  J | 00:03:01 | 00:05:03 |      F |      K |   6 |  00:04:01 | 00:05:02 |G |J |4
|   00:05:03 |  K | 00:03:01 | 00:05:03 |      F |      K |   6 | 00:04:01 | 00:05:03 |G |K |5
|   00:06:01 |  L | 00:04:01 | 00:06:01 |      G |      L |   6 | 00:05:01 | 00:06:01 |I |L |4
|   00:07:01 |  M | 00:05:01 | 00:07:04 |      I |      P |   8 | 00:06:01 | 00:07:01 |L |M |2
|   00:07:02 |  N | 00:05:01 | 00:07:04 |      I |      P |   8 | 00:06:01 | 00:07:02 |L |N |3
|   00:07:03 |  O | 00:05:01 | 00:07:04 |      I |      P |   8 |00:06:01 | 00:07:03 |L |O |4
|   00:07:04 |  P | 00:05:01 | 00:07:04 |      I |      P |   8 | 00:06:01 | 00:07:04 |L |P |5
|   00:08:01 |  Q | 00:06:01 | 00:08:03 |      L |      S |   8 | 00:07:01 | 00:08:01 |M |Q |5
|   00:08:02 |  R | 00:06:01 | 00:08:03 |      L |      S |   8 | 00:07:01 | 00:08:02 |M |R |6
|   00:08:03 |  S | 00:06:01 | 00:08:03 |      L |      S |   8 | 00:07:01 | 00:08:03 |M |S |7
|   00:09:01 |  T | 00:07:01 | 00:09:02 |      M |      U |   9 |  00:08:01 | 00:09:01 |Q |T |4
|   00:09:02 |  U | 00:07:01 | 00:09:02 |      M |      U |   9 | 00:08:01 | 00:09:02 |Q |U |5
|   00:10:01 |  V | 00:08:01 | 00:10:05 |      Q |      Z |  10 | 00:09:01 | 00:10:01 |T |V |3
|   00:10:02 |  W | 00:08:01 | 00:10:05 |      Q |      Z |  10 | 00:09:01 | 00:10:02 |T |W |4
|   00:10:03 |  X | 00:08:01 | 00:10:05 |      Q |      Z |  10 | 00:09:01 | 00:10:03 |T |X |5
|   00:10:04 |  Y | 00:08:01 | 00:10:05 |      Q |      Z |  10 | 00:09:01 | 00:10:04 |T |Y |6
|   00:10:05 |  Z | 00:08:01 | 00:10:05 |      Q |      Z |  10 | 00:09:01 | 00:10:05 |T |Z |7
|   00:11:01 |  a | 00:09:01 | 00:11:02 |      T |      b |   9 | 00:10:01 | 00:11:01 |V |a |6
|   00:11:02 |  b | 00:09:01 | 00:11:02 |      T |      b |   9 | 00:10:01 | 00:11:02 |V |b |7

