SCRIPT_DIR=$(cd `dirname $0` ; pwd -P)

engines="$*"

if [ -z $engines ]
then
    engines="sqlstream flink"
fi

for engine in ${engines}
do
    for view in parse_view projection_view agg_view join_view join_n_agg_view
    do
        $SCRIPT_DIR/runTest.sh $engine $view
    done
done
