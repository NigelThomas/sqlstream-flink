# Overview
This benchmark compares SQLstream & Flink’s throughput & footprint requirements for typical streaming operations such as time-series analytics & streaming joins.

# Use case
This benchmark comparison is performed on EDRs (Electronic Data Records) generated by a typical wireless telecommunications operator for monitoring & management of the network performance. This benchmark uses a synthetic data set generated using a simple python script. There are 2 data streams

* **Flows** - This data stream contains EDRs from the wireless network that collects telemetry information for a specific VOIP call or a user activity

*  **Sessions** - This data stream contains specific network events such as cell-tower handover during ongoing user activity such as VOIP calls or a browsing session.

The python script generates roughly 4 million flows records (EDRs) & a million sessions records  (EDRs) for every hour of operation of the wireless network. The number of hours of operation is passed as a parameter to the python script to generate the synthetic data.

# The SQL pipeline
The SQL pipeline performs a streaming join between Flows & Sessions streams and then compute time-series analytics, partitioned by cell-tower ID, to monitor the network performance. The SQL pipeline is described through a set of cascaded SQL views. These SQL views are are quite similar in syntax for both SQLstream as well as Flink.

1. `Flows_fs` - This is a relational stream abstraction defined on Flows EDRs collected in CSV files
2. `Parse_view` - This view simply extracts and projects all the columns (around 70) from the `Flows_fs` stream
    ```
    CREATE OR REPLACE VIEW Parse_view AS
    SELECT STREAM * FROM EDR.Flows_fs;
    ```
3. Projection_view - This view parses only 10 out of 70 columns from the Flows_fs stream
    ```
    CREATE OR REPLACE Projection_view AS
    SELECT STREAM sessionid,
      CAST(CASE WHEN CHAR_LENGTH(eventtime) = 22
          THEN SUBSTRING(eventtime, 1, 19) || '.000'
          ELSE eventtime END AS TIMESTAMP) AS ROWTIME,
      CAST(uplinkoctets AS BIGINT) + CAST(downlinkoctets AS BIGINT) +
      CAST(uplinkdropoctets AS BIGINT) + CAST(downlinkdropoctets AS BIGINT) as Octets,
      CAST(uplinkpackets AS BIGINT) + CAST(downlinkpackets AS BIGINT) +
      CAST(uplinkdroppackets AS BIGINT) + CAST(downlinkdroppackets AS BIGINT) as Packets
    FROM Flows_fs AS input;

    CREATE OR REPLACE Projection_Sessions_view AS
    SELECT STREAM sessionid,
      CAST(CASE WHEN CHAR_LENGTH(eventtime) = 22
          THEN SUBSTRING(eventtime, 1, 19) || '.000'
          ELSE eventtime END AS TIMESTAMP) AS ROWTIME,
      ecgieci AS cellid
    FROM Sessions_fs AS input;
    ```
4. `Agg_view` - This view computes time-series analytics on a 1-hour sliding window on Flows_fs, partitioned by sessionid
    ```
    CREATE OR REPLACE VIEW Agg_view AS
    SELECT STREAM sessionid, Octets,
      Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
      Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
    FROM Projection_view as s
    WINDOW w AS (PARTITION BY sessionid
                RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING
                AND CURRENT ROW);
    ```
5. `Join_view` - This view joins Projection_view with Sessions_fs on a 5-minute window.
    ```
    CREATE OR REPLACE VIEW Join_view AS
    SELECT STREAM lhs.sessionid as sessionid, cellid, Octets, Packets
    FROM Projection_view as lhs
      INNER JOIN
        Projection_Sessions_view OVER (RANGE INTERVAL '5' MINUTE PRECEDING) as rhs
      ON (lhs.sessionid = rhs.sessionid );
    ```
6. `Join_n_Agg_view` - This view computes time-series analytics on a 1-hour sliding window on the streaming result of the Join_view, partitioned by cellid (cell-tower ID)
    ```
    CREATE OR REPLACE VIEW Join_n_agg_view AS
    SELECT STREAM cellid, Octets,
        Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
        Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
    FROM Join_view as s
    WINDOW w AS (PARTITION BY cellid
                ORDER BY FLOOR(s.ROWTIME TO MINUTE)
                RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING
                AND INTERVAL '1' MINUTE PRECEDING);
    ```

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
   * This repository currently includes the installer for s-Server 8.1.1.20580-1497075c7; to use another version, either:
     1. Place the installer into the `assets` directory and modify the values of `SQLSTREAM_VERSION` and `SQLSTREAM_MAJOR_VERSION` in `environment.sh`
     2. Or set `SQLSTREAM_MAJOR_VERSION` to the version number of a generally available version that can be downloaded from http://downloads.sqlstream.com

4. Run the setup to install SQLstream s-Server (into `$HOME/sqlstream/<sqlstream_version>`) and Flink (into `$HOME/<flink_version>`). This can take 2-3 minutes.
    ```
    ./runSetup.sh
    ```
5. Generate the synthetic EDR data using the included python script (make sure to use `python3`). Run `python3 ./edrgen.py --help` for more help on parameters. This takes around 45-60 minutes depending on the speed of your processor and the parameters used. This command generates 360 mins (6 hours) of data:
    ```
    python3 ./edrgen.py -p 360
    ```
6. Copy (and concatenate) generated data files to /tmp directory
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
   * The `runTest.sh` script will stop the Flink cluster and start s-Server (if necessary)
   * The script reloads the schema for each run
   * Repeat tests with each view in turn.
   * The second column in the output shows rows/second
   * While tests are running, you may monitor physical memory and CPU% using the `top` or `vmstat` commands. 
   * use Cntrl-C to stop test
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
   * The `runTest.sh` script will stop s-Server ans start the Flink cluster (if necessary)
   * The script reloads the schema for each run
   * While tests are running, you may monitor Physical memory used and CPU% using the  `top` or  `vmstat` commands. 
   * The second column in the output shows rows/second
   * use Cntrl-C to stop test
3. Repeat tests as required
4. Stop the Flink cluster:
    ```
    $FLINK_HOME/bin/stop-cluster.sh
    ```

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
| `agg_view (Min, Max, Sum, Count)` | Flink | 5GB of 8GB Max | 58K | 1 | 8.8 | 6.5K | 
1
| | SQLstream | 1.1GB of 2GB Max | 452K | 7.8 | 1.6 | 282K | 43 
| `session_join_view` (60-minute session window) | Flink | NA | NA | NA | NA | NA | NA
| SQLstream | 1.1GB of 2GB Max | 822K | - | 3.5 | 235K | - 
| `join_view` (5-minute sliding window) | Flink | 5GB of 8GB Max | 107K | 1 | 7 | 18K | 1
| | SQLstream | 1.4GB of 2GB Max | 735K | 6.8 | 4 | 183K | 10 | 
| `join_n_agg_view` (zero offset) | Flink | 5.4GB of 8GB Max | 555* | 1 | 3 | 185 | 1 (TaskExecutor crashed after processing 800K rows)
| | SQLstream | 1.7GB of 2GB Max | 149K | 268 | 1.4 | 106K | 572 | 
| `join_n_agg_view2` (1-minute offset) | SQLstream | 1.2GB of 2GB Max | 727K | 1310 | 4 | 181K | 978 |

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
| `repro.sql` | TBA
| `run.distributed.sql` | Executes the sharded SQLstream deployment
| `runSetup.sh` | script to install SQLstream and Flink
| `runTest.sh` | script to read from any one of the test views in SQLstream or Flink
| `sqlstream.sql` | The SQLstream SQL script for creating the test schema
| `ss_template.sql` | The model SQLstream script used for reading from the test views
