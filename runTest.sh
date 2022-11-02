#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` ; pwd -P)
source $SCRIPT_DIR/environment.sh

runtime=$1
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

# stop any engine which is running
stopFlink
stopsServer

case ${runtime^^} in
	
	S|SQL|SQLSTREAM)
		# check for a licence (for information only at this stage)
		$SQLSTREAM_HOME/bin/showLicenses.sh

		startsServer

		# refresh the catalog, in case it has not been installed before
		$SQLSTREAM_HOME/bin/sqllineClient --incremental=true --run=$SCRIPT_DIR/sqlstream.sql
		sed -e "s/viewname/$viewname/g" ss_template.sql | \
		sqllineClient --incremental=true --outputformat=csv 
		;;

	F|FLINK)

		# Is memory allocation sufficient?
		tmps=$(grep "^taskmanager.memory.process.size:" $FLINK_HOME/conf/flink-conf.yaml | awk '{print tolower($2)}')

		# get numerals - all but last letter
		tmps_size=${tmps:0:-1}
		# get last letter - we assume it is m or g, we're not expecting k or t
		tmps_unit=${tmps:0-1}
		
		if [ ${tmps_unit} = "g" ]
		then
			let "tmps_size=$tmps_size*1024"
		fi

		if [ $tmps_size -lt  8192 ]
		then
			echo "WARNING: Flink task manager memory process size under-specified at $tmps, should be 8192m / 8g at least"
			exit 1
		else
			if [ "${tmps_unit}" == "g" ]
			then
				echo "INFO: Flink task manager memory process size adequately specified at $tmps (${tmps_size}m)"
			else
				echo "INFO: Flink task manager memory process size adequately specified at $tmps"
			fi
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
			# start a background task to monitor the TaskManagerRunner JVM
			tmrpid=$(jps | grep TaskManagerRunner | awk '{print $1}')
			tmrlog=/tmp/flink-jstat.${viewname}.$(date +%Y%m%d-%H%M%S).log

			java -version 2>&1 | awk '{if (NF > 0) printf("# %s\n", $0)}' > $tmrlog

			

			cat >>$tmrlog <<!END
#
# FLINK_VERSION=$FLINK_VERSION
# FLINK_HOME=$FLINK_HOME
# JAVA_VERSION=$(java -version)
#
# Flink configuration:
#
!END
			cat $FLINK_HOME/conf//flink-conf.yaml | grep -v "^#" | awk '{if (NF > 0) printf("# %s\n", $0)}' >> $tmrlog
			cat >>$tmrlog <<!END
#
# Task Manager Command line:
!END
			ps -f $tmrpid | awk '{if (NF > 0) printf("# %s\n", $0)}' >> $tmrlog
			cat >>$tmrlog <<!END
#
!END
			# the background job should terminate when the Flink cluster is stopped
			jstat -gc -t $tmrpid 30s &>> $tmrlog &
			echo "Logging jstat output to $tmrlog"

			# Prepare the query
			cat flink.sql > /tmp/throughput.sql
			echo "SELECT TUMBLE_START(a.proc_time, INTERVAL '1' SECOND) as clocktime, COUNT(*) as recs_per_sec, max(eventtime) as max_event_time_$viewname" >> /tmp/throughput.sql
			if [[ "$viewname" =~ "agg_view" ]]
			then
				echo ",count(minOctets) + count(maxOctets) + count(sumOctets) + count(countOctets) as countTotal" >> /tmp/throughput.sql
			fi
			echo "FROM (select PROCTIME() as proc_time, * from $viewname) AS a" >> /tmp/throughput.sql
			echo "GROUP BY TUMBLE(a.proc_time, INTERVAL '1' SECOND);" >> /tmp/throughput.sql

			# run the query
			$FLINK_HOME/bin/sql-client.sh embedded -f /tmp/throughput.sql

			echo "Logged jstat output is in $tmrlog"
			stopFlink
			
		fi
		;;

	*) 
		echo "Unknown or unspecified runtime engine $runtime"
		exit 1
		;;
esac

