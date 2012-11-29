function AFL {
	iquery -naq "$1" >/dev/null
}

function AQL {
	iquery -nq "$1" >/dev/null
}


if [ $# -ne 2 ]; then
	echo "usage: ./setup.sh [BFS start vertex] [num steps]"
	exit
fi

# clean up
iquery -nq "drop array adj;" &>/dev/null
iquery -nq "drop array x;" &>/dev/null
iquery -nq "drop array y;" &>/dev/null


echo Loading tuples representation into a flat array
AQL "create array adjFlat <vertex1:int64, vertex2:int64, isAdjacent:int64> [i=0:*,100000,0];"
csv2scidb -p NNN -s 1 < input-tuples-sparse.csv > input.scidb
IMPORT_FILEPATH="$(pwd)/input.scidb"
AQL "load adjFlat from '$IMPORT_FILEPATH'"
rm input.scidb


echo Converting into adjacency matrix
AQL "create array adj <isAdjacent:int64> [vertex1=0:4,1000,0, vertex2=0:4,1000,0]"
AFL "redimension_store(adjFlat,adj);"
AQL "drop array adjFlat;"


echo Filling out NULL cells with 0\'s
AFL "store(merge(adj, build(adj,0)),adj)"
# Unsucessfull attempt to use substitute() operator to replace NULL cells
# with 0's after redimensioning from flat tupples array
#
#iquery -aq "store(build(<isAdjacent:int64>[i=0:0,1,0],0), subst_array)"
#iquery -aq "store(substitute(adj, subst_array), adj)"
#iquery -q "drop array subst_array;"
echo Loaded adjecency matrix: 
iquery -aq "scan(adj)"

echo setting diagonal to 1\'s
AQL "update adj set isAdjacent=1 where vertex1=vertex2"




echo Performing BFS
AQL "create array x <isAdjacent:int64> [vertex1=0:0,1000,0, vertex2=0:4,1000,0]"
AQL "create array y <isAdjacent:int64> [vertex1=0:0,1000,0, vertex2=0:4,1000,0]"
AFL "store(build(x,iif(vertex2=$1,1,0)),x)"
#AFL "store(subarray(adj,$1,0,$1,4),x)"
echo "x[0] = "
iquery -aq "scan(x)"
CHAIN_MULT_QUERY="x"
for i in $(seq $2)
do
	CHAIN_MULT_QUERY="multiply($CHAIN_MULT_QUERY,adj)"
done 
echo $CHAIN_QUERY
AFL "store($CHAIN_MULT_QUERY,y)"
AQL "update y set isAdjacent=1 where isAdjacent>0"
echo "y = A^$2 * x[0] = "
iquery -aq "scan(y)"

