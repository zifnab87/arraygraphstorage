function AFL {
	iquery -naq "$1" >/dev/null
}

function AQL {
	iquery -nq "$1" >/dev/null
}


if [ $# -ne 2 -o "$1" == "--help" ]; then
	echo "usage: ./setup.sh [BFS start vertex] [num steps]"
	exit
fi

# clean up
iquery -nq "drop array A;" &>/dev/null
iquery -nq "drop array T;" &>/dev/null
iquery -nq "drop array x;" &>/dev/null
iquery -nq "drop array y;" &>/dev/null


echo Loading tuples representation into a flat array
AQL "create array T <i:int64, j:int64, val:int64> [d=0:*,100000,0];"
csv2scidb -p NNN -s 1 < input-tuples-sparse.csv > input.scidb
IMPORT_FILEPATH="$(pwd)/input.scidb"
AQL "load T from '$IMPORT_FILEPATH'"
rm input.scidb


echo Converting into adjacency matrix
AQL "create array A <val:int64> [i=0:4,1000,0, j=0:4,1000,0]"
AFL "redimension_store(T,A);"


echo Filling out NULL cells with 0\'s
AFL "store(merge(A, build(A,0)),A)"
# Unsucessfull attempt to use substitute() operator to replace NULL cells
# with 0's after redimensioning from flat tupples array
#
#iquery -aq "store(build(<val:int64>[i=0:0,1,0],0), subst_array)"
#iquery -aq "store(substitute(A, subst_array), A)"
#iquery -q "drop array subst_array;"
echo Loaded adjecency matrix: 
iquery -aq "scan(A)"

echo setting diagonal to 1\'s
AQL "update A set val=1 where i=j"


echo Performing BFS
AQL "create array x <val:int64> [i=0:0,1000,0, j=0:4,1000,0]"
AQL "create array y <val:int64> [i=0:0,1000,0, j=0:4,1000,0]"
AFL "store(build(x,iif(j=$1,1,0)),x)"
#AFL "store(subarray(A,$1,0,$1,4),x)"
echo "x[0] = "
iquery -aq "scan(x)"
CHAIN_MULT_QUERY="x"
for i in $(seq $2)
do
	CHAIN_MULT_QUERY="multiply($CHAIN_MULT_QUERY,A)"
done 
echo $CHAIN_QUERY
AFL "store($CHAIN_MULT_QUERY,y)"
AQL "update y set val=1 where val>0"
echo "y = A^$2 * x[0] = "
iquery -aq "scan(y)"

