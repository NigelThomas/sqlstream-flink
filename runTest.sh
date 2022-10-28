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

case ${runtime^^} in
	
	S|SQL|SQLSTREAM)
		# check for a licence (for information only at this stage)
		$SQLSTREAM_HOME/bin/showLicenses.sh

		stopFlink
		startsServer

		# refresh the catalog, in case it has not been installed before
		$SQLSTREAM_HOME/bin/sqllineClient --incremental=true --run=$SCRIPT_DIR/sqlstream.sql
		sed -e "s/viewname/$viewname/g" ss_template.sql | \
		sqllineClient --incremental=true --outputformat=csv 
		;;

	F|FLINK)
		stopsServer
		startFlink

		if [ "$viewname" == "Join_n_Agg_view2" ]
		then
			echo "Warning: Join_n_Agg_view2 is not defined for Flink"
		elif [ -n "$EXPLAIN_PLAN" ]
		then
			cat flink.sql > /tmp/throughput.sql
			echo "EXPLAIN PLAN FOR SELECT * " >> /tmp/throughput.sql
			if [[ "$viewname" =~ "Agg_view" ]]
			then
				echo ",count(minOctets) + count(maxOctets) + count(sumOctets) + count(countOctets) as countTotal" >> /tmp/throughput.sql
			fi
			echo "FROM (select PROCTIME() as proc_time, * from $viewname) AS a;" >> /tmp/throughput.sql

			$FLINK_HOME/bin/sql-client.sh embedded -f /tmp/throughput.sql

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

