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
iquery -nq "drop array r;" &>/dev/null
iquery -nq "drop array rs;" &>/dev/null


# loading tuples representation into a flat array
AQL "create array T <i:int64, j:int64, val:int64> [d=0:*,100000,0];"
csv2scidb -p NNN -s 1 < input-tuples-sparse.csv > input.scidb
IMPORT_FILEPATH="$(pwd)/input.scidb"
AQL "load T from '$IMPORT_FILEPATH'"
rm input.scidb


# converting into adjacency matrix
AQL "create array A <val:int64> [i=0:4,1000,0, j=0:4,1000,0]"
AFL "redimension_store(T,A);"


# filling out NULL cells with 0\'s
AFL "store(merge(A, build(A,0)),A)"
# Unsucessfull attempt to use substitute() operator to replace NULL cells
# with 0's after redimensioning from flat tupples array
#
#iquery -aq "store(build(<val:int64>[i=0:0,1,0],0), subst_array)"
#iquery -aq "store(substitute(A, subst_array), A)"
#iquery -q "drop array subst_array;"
echo Loaded adjecency matrix: 
iquery -aq "scan(A)"

# setting diagonal to 1\'s
AQL "update A set val=1 where i=j"


echo "Performing BFS (startNode = $1, numSteps = $2)"
AQL "create array x <val:int64> [i=0:0,1000,0, j=0:4,1000,0]"
AQL "create array y <val:int64> [i=0:0,1000,0, j=0:4,1000,0]"
AQL "create array r <val:int64> [i=0:0,1000,0, j=0:4,1000,0]"
AFL "store(build(x,iif(j=$1,1,0)),x)"
#AFL "store(subarray(A,$1,0,$1,4),x)"
CHAIN_MULT_QUERY="x"
for i in $(seq $2)
do
	CHAIN_MULT_QUERY="multiply($CHAIN_MULT_QUERY,A)"
done 
iquery -taq "store($CHAIN_MULT_QUERY,y)" | tail -n +2
AQL "update y set val=1 where val>0"
echo "Result:"

# convert to list of node inexes representation
AQL "insert into r select j from y where val=1"
NRES=$(iquery -q "select count(val) from r")
NRES=$(( ${NRES:2:1} - 1 ))
AQL "create array rs <val:int64> [m=0:$NRES,1000,0]"
AFL "store(subarray(project(unpack(r,m,1000),val),0,$NRES),rs)"
iquery -o csv -aq "scan(rs)" | tail -n +2
