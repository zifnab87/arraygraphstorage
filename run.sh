if [ "$1" == "" ]; then
	echo "usage: ./setup.sh [BFS start vertex]"
	exit
fi
echo Loading tuples representation into a flat array
iquery -q 'create array adjFlat <vertex1:int64, vertex2:int64, isAdjacent:int64> [i=0:*,100000,0];'
csv2scidb -p NNN -s 1 < input-tuples-sparse.csv > input.scidb
IMPORT_FILEPATH="$(pwd)/input.scidb"
iquery -q "load adjFlat from '$IMPORT_FILEPATH'"
rm input.scidb
echo Converting into adjacency matrix
iquery -q "create array adj <isAdjacent:int64> [vertex1=0:4,1000,0, vertex2=0:4,1000,0]"
iquery -aq "redimension_store(adjFlat,adj);"
iquery -q "drop array adjFlat;"
echo Filling out NULL cells with 0\'s
iquery -aq "merge(adj, build(adj,0))"
#iquery -aq "store(build(<isAdjacent:int64>[i=0:0,1,0],0), subst_array)"
#iquery -aq "store(substitute(adj, subst_array), adj)"
#iquery -q "drop array subst_array;"
echo Result:
iquery -aq "show(adj)"
iquery -aq "scan(adj)"
echo Performing BFS
iquery -q "create array stepV <isAdjacent:int64> [vertex1=0:1,1,0, vertex2=0:4,1000,0]"
echo "stepV = "
iquery -aq "subarray(adj,$1,0,$1,4)"
echo "stepV * adj = "
iquery -aq "multiply(multiply(subarray(adj,$1,0,$1,4),adj),adj)"
echo "Cleaning up..."
iquery -q "drop array adj;"
iquery -q "drop array stepV;"
