SCRIPT_DIR=$(cd `dirname $0` ; pwd -P)

for engine in sqlstream flink
do
    for view in projection_view agg_view join_view join_agg_view join_n_agg_view
    do
        $SCRIPT_DIR/runTest.sh $engine $view
    done
done