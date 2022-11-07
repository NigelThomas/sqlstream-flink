#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` ; pwd -P)
source $SCRIPT_DIR/environment.sh

function printLogFileNames() {
	echo "INFO: Logged jstat output is in $jstatlog"
	echo "INFO: Logged top output is in $toplogfile"
	echo "INFO: Config log is in $configlog"
	echo "INFO: Run log is in $runlog"
}


runtime=${1,,}
viewname=${2,,}

case ${viewname} in
	parse_view | \
	projection_view| \
	agg_view| \
	join_view| \
	join_n_agg_view| \
	join_n_agg_view2)
		# view name is supported
		;;
	"")
		echo "Valid view names are: parse_view, projection_view, agg_view, join_view, join_n_agg_view, join_n_agg_view2"
		echo "Running with join_n_agg_view (last view supported by SQLstream and Flink)"
		viewname=join_n_agg_view
		;;
	*)
		# probably an unknown view
		echo "$viewname is an unexpected view name"
		# but try it anyway
		
esac

case ${runtime} in
	
	s|sql|sqlstream)
		runtime=sqlstream
		version=sqlstream-$SQLSTREAM_VERSION
		;;
	f|flink|a|apache)
		runtime=flink
		version=$FLINK_VERSION
		;;
	*) 
		echo "Unknown or unspecified runtime engine $runtime"
		exit 1
		;;
esac

dt=$(date +%Y%m%d)
tm=$(date +%H%M%S)
ts=${dt}.${tm}
: ${BENCHMARK_LOGDIR:=${SCRIPT_DIR}/logs/${version}}
mkdir -p $BENCHMARK_LOGDIR

# stop any engine which is running
stopFlink
stopsServer

toplogfile=${BENCHMARK_LOGDIR}/${dt}.${tm}.${viewname}.top.log
jstatlog=${BENCHMARK_LOGDIR}/${dt}.${tm}.${viewname}.jstat.log
configlog=${BENCHMARK_LOGDIR}/${dt}.${tm}.${viewname}.config.log
runlog=${BENCHMARK_LOGDIR}/${dt}.${tm}.${viewname}.run.log


if [ "$runtime" == "sqlstream" ]
then

		# check for a licence (for information only at this stage)
		startsServer

		(
			$SQLSTREAM_HOME/bin/showLicenses.sh 
			echo
			java -version 2>&1
			echo
			echo "---- aspen.properties ----"
			cat $SQLSTREAM_HOME/aspen.properties | grep -v "^#" | grep  "^[a-z|A-Z]"

		) > $configlog

		sserverpid=$(jps | grep -e AspenVJdbcServer | cut -d' ' -f1)

		topLog $sserverpid $toplogfile

		printLogFileNames

		# refresh the catalog, in case it has not been installed before
		$SQLSTREAM_HOME/bin/sqllineClient --incremental=true --run=$SCRIPT_DIR/sqlstream.sql

		(
			# actually run the SQL query
			sed -e "s/viewname/$viewname/g" ss_template.sql | \
				sqllineClient --incremental=true --outputformat=csv 2>&1 | tee $runlog

		)

		printLogFileNames
 
else 
		# Must be Flink

		checkFlinkMemory 
		# Is memory allocation sufficient?
		if [ $? -ne 0 ]
		then
			exit 1
		fi

		startFlink

		if [ "$viewname" == "join_n_agg_view2" ]
		then
			echo "Warning: join_n_agg_view2 is not defined for Flink"
		elif [ -n "$EXPLAIN_PLAN" ]
		then
			# Prepare the explain query
			cat flink.sql > /tmp/throughput.sql
			echo "EXPLAIN PLAN FOR SELECT * " >> /tmp/throughput.sql
			if [[ "$viewname" =~ "agg_view" ]]
			then
				echo ",count(minOctets) + count(maxOctets) + count(sumOctets) + count(countOctets) as countTotal" >> /tmp/throughput.sql
			fi
			echo "FROM (select PROCTIME() as proc_time, * from $viewname) AS a;" >> /tmp/throughput.sql

			# run the explain query
			$FLINK_HOME/bin/sql-client.sh embedded -f /tmp/throughput.sql 


		else
			# start background tasks to monitor the TaskManagerRunner JVM

			# Use top to collect CPU and memory stats
			flinkpids=$(jps | grep -e TaskManagerRunner -e StandaloneSessionCluster | awk '{print $1}' )
			flinkpids=$(echo $flinkpids | tr ' ' ',')

			topLog $flinkpids $toplogfile

			# Log jstat metrics for TaskManagerRunner
			tmrpid=$(jps | grep TaskManagerRunner | awk '{print $1}')

			(
				cat  <<!END

FLINK_VERSION=$FLINK_VERSION
FLINK_HOME=$FLINK_HOME

!END
				java -version 2>&1
				cat  <<!END

Flink configuration:

!END
				cat $FLINK_HOME/conf//flink-conf.yaml | grep -v "^#" | awk '{if (NF > 0) print $0}' 
				cat <<!END

Task Manager Command line:
!END
				ps -f $tmrpid | awk '{if (NF > 0) print $0}' 
				echo 
			
			) > $configlog 

			# the background job should terminate when the Flink cluster is stopped
			jstat -gc -t $tmrpid 10s &>> $jstatlog &

			printLogFileNames

			# Prepare the query
			(
				# prepare to inject start time; note that this includes SQL startup and schema install
				# which we will allow for later using a 6 second decrement in the calculation of testsecs

				q="'"
				starttime="${q}$(date '+%Y-%m-%d %H:%M:%S')${q}"
				cat flink.sql
				echo "SELECT *, TIMESTAMPDIFF(SECOND, timestamp $starttime, clocktime)-6 as testsecs FROM ("
				echo "SELECT TUMBLE_START(a.proc_time, INTERVAL '1' SECOND) as clocktime, COUNT(*) as recs_per_sec, max(eventtime) as max_event_time_$viewname" 
				if [[ "$viewname" =~ "agg_view" ]]
				then
					echo ",count(minOctets) + count(maxOctets) + count(sumOctets) + count(countOctets) as countTotal" 
				fi
				echo "FROM (select PROCTIME() as proc_time, * from $viewname) AS a" 
				echo "GROUP BY TUMBLE(a.proc_time, INTERVAL '1' SECOND)"
				echo ");" 
			) > /tmp/throughput.sql 

			# run the query
			$FLINK_HOME/bin/sql-client.sh embedded -f /tmp/throughput.sql | tee $runlog

			# stop logging top stats
			kill $toppid

			printLogFileNames
			stopFlink
			
		fi
fi
