#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` ; pwd -P)
source $SCRIPT_DIR/environment.sh

runtime=$1

case ${2,,} in
	parse_view)
		viewname=Parse_view
		;;
	projection_view)
		viewname=Projection_view
		;;
	agg_view) 
		viewname=Agg_view
		;;
	join_view)
		viewname=Join_view
		;;
	join_n_agg_view)
		viewname=Join_n_Agg_view
		;;
	join_n_agg_view2)
		viewname=Join_n_Agg_view2
		;;
	"")
		echo "Valid view names are: Parse_view, Projection_view, Agg_view, Join_view, Join_n_Agg_view, Join_n_agg_view2"
		echo "Running with Join_n_Agg_view (last view supported by SQLstream and Flink)"
		viewname=Join_n_Agg_view
		;;
	*)
		# probably an unknown view
		viewname=$2
		echo "$viewname is an unexpected view name"
		# but try it anyway
		
esac

case ${runtime^^} in
	
	S|SQL|SQLSTREAM)
		# check for a licence (for information only at this stage)
		$SQLSTREAM_HOME/bin/showLicenses.sh

		# check that Flink IS running (locally)
		jps | grep TaskManagerRunner
		if [ $? -eq 0 ]
		then
			echo "WARNING - Apache Flink cluster is running"
			$FLINK_HOME/bin/stop-cluster.sh
		fi

		# if the server is not ready, bring it up
		$SQLSTREAM_HOME/bin/serverReady
		result=$?

		if [ $result -ne 0 ]
		then
			# start server
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

		# refresh the catalog, in case it has not been installed before
		$SQLSTREAM_HOME/bin/sqllineClient --incremental=true --run=$SCRIPT_DIR/sqlstream.sql
		sed -e "s/viewname/$viewname/g" ss_template.sql | \
		sqllineClient --incremental=true --outputformat=csv 
		;;

	F|FLINK)
		# Check that s-Server is NOT running
		$SQLSTREAM_HOME/bin/serverReady
		if [ $? -eq 0 ]
		then
			echo "WARNING - stopping SQLstream s-Server"
			kill -TERM `jps | grep AspenVJdbc | awk '{print $1}'`
		fi

		# check that Flink IS running (locally)
		jps | grep TaskManagerRunner
		if [ $? -eq 1 ]
		then
			echo "WARNING - starting Apache Flink cluster"
			$FLINK_HOME/bin/start-cluster.sh
		fi

		if [ "$viewname" == "Join_n_Agg_view2" ]
		then
			echo "Warning: Join_n_Agg_view2 is not defined for Flink"
		else
			cat flink.sql > /tmp/throughput.sql
			echo "SELECT TUMBLE_START(a.proc_time, INTERVAL '1' SECOND) as clocktime, COUNT(*) as recs_per_sec, max(eventtime) as max_event_time_$viewname" >> /tmp/throughput.sql
			if [[ "$viewname" =~ "Agg_view" ]]
			then
				echo ",count(minOctets) + count(maxOctets) + count(sumOctets) + count(countOctets) as countTotal" >> /tmp/throughput.sql
			fi
			echo "FROM (select PROCTIME() as proc_time, * from $viewname) AS a" >> /tmp/throughput.sql
			echo "GROUP BY TUMBLE(a.proc_time, INTERVAL '1' SECOND);" >> /tmp/throughput.sql

			$FLINK_HOME/bin/sql-client.sh embedded -f /tmp/throughput.sql
		fi
		;;

	*) 
		echo "Unknown or unspecified runtime engine $runtime"
		exit 1
		;;
esac

