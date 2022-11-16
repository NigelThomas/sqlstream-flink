SCRIPT_DIR=$(cd `dirname $0` ; pwd -P)

engines="$1"
alltests="$2"

if [ -z $engines ]
then
    engines="sqlstream flink"
fi



for engine in ${engines,,}
do
    if [ -z "$alltests" ]
    then
        # by default perform these tests

        case $engine in
            s|sql|sqlstream)
                alltests="projection_view agg_view join_view join_n_agg_view join_n_agg_view2"
                ;;
            f|flink)
                # exclude join_n_agg_views because they take so long
                alltests="projection_view agg_view join_view"
                ;;
        esac
    fi

    for view in $alltests 
    do
        $SCRIPT_DIR/runTest.sh $engine $view
    done
done
