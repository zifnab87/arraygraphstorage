#!/bin/bash
function AFL {
	iquery -naq "$1" >/dev/null
	if [ $? -ne 0 ]; then
		#cleanup
		exit
	fi
}

function AQL {
	iquery -nq "$1" >/dev/null
	if [ $? -ne 0 ]; then
		#cleanup
		exit
	fi
}

function setup {
	local P="1" # percent of non-zero element in a sparse matrix
	local N=$1 
	local CHNK1=$2
	local CHNK2=$3
	local Nm1=$(( $1 - 1 ))
	echo Initializing test matrices...
	AQL "create array A1 <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
	AQL "create array B1 <val:int64> [i=0:$Nm1,$CHNK2,0, j=0:$Nm1,$CHNK1,0]"
	AFL "store(build(A1,random() % 2),A1)"
	AFL "store(build(B1,random() % 2),B1)"
#iquery -aq "scan(A1)"
#iquery -aq "scan(B1)"
	AQL "create array A2 <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
	AQL "create array B2 <val:int64> [i=0:$Nm1,$CHNK2,0, j=0:$Nm1,$CHNK1,0]"
	AFL "store(build(A2, iif((random() % 1000) < $P,1,0)),A2)"
	AFL "store(build(B2, iif((random() % 1000) < $P,1,0)),B2)"
#iquery -aq "scan(A2)"
#iquery -aq "scan(B2)"
	AQL "create array A3 <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
	AQL "create array B3 <val:int64> [i=0:$Nm1,$CHNK2,0, j=0:$Nm1,$CHNK1,0]"
	local NNz=$(( $N * $N * $P / 1000 ))
	local NNzm1=$(( $NNz -1 ))
	# indirectly way of generating random sparse array
	# WARN: possible cell collisions
	# NOTE: number of non-zero elements in matrix always <= NNz
	AQL "create array T <i:int64, j:int64, val:int64> [d=0:$NNzm1,$NNz,0];"
	AFL "store(join(join(
			build(<i:int64>[d=0:$NNzm1,$NNz,0],random() % $N),
			build(<j:int64>[d=0:$NNzm1,$NNz,0],random() % $N)),
			build(<val:int64>[d=0:$NNzm1,$NNz,0], 1)),
		 T)"
	AFL "redimension_store(T,A3);"
	AFL "store(join(join(
			build(<i:int64>[d=0:$NNzm1,$NNz,0],random() % $N),
			build(<j:int64>[d=0:$NNzm1,$NNz,0],random() % $N)),
			build(<val:int64>[d=0:$NNzm1,$NNz,0], 1)),
		 T)"
	AFL "redimension_store(T,B3);"
	# straightforward way of generating random sparse array
	# WARN: fails because of scidb bug...
	#AFL "store(build_sparse(A3, 1, (random() % 1000) < $P),A3)"
	#AFL "store(build_sparse(B3, 1, (random() % 1000) < $P),B3)"
	#iquery -aq "scan(A3)"
	#iquery -aq "scan(B3)"
}

function cleanup {
	iquery -nq "drop array A1;" &>/dev/null
	iquery -nq "drop array B1;" &>/dev/null
	iquery -nq "drop array A2;" &>/dev/null
	iquery -nq "drop array B2;" &>/dev/null
	iquery -nq "drop array A3;" &>/dev/null
	iquery -nq "drop array B3;" &>/dev/null
	iquery -nq "drop array T;" &>/dev/null
}

if [ "$1" != "" ]; then
	cleanup
	# Recommended chunk size
	if [ $1 -lt 1024 ]; then 
		setup $1 $1 $1
	else
		setup $1 1024 1024
	fi
#	if [ $(( $1 * $1 )) -gt 10485760 ]; then
#		# Max chunk size for 85 Mb segment
#		#setup $1 "$(( 5 * 1024 ))" "$(( 2 * 1024 ))"
#	fi
fi

function test {
    "$@" 
    if [ $? -ne 0 ]; then
    	exit 1
    fi
}	

function time_msec {
	_tm_out=$((time test "$@" >/dev/null) 2>&1)
	if [ $? -ne 0 ]; then
		echo "$_tm_out" 1>&2
		exit 1
	fi
	_tm_t=$(echo "$_tm_out" | sed -ne 's/real\t\(.*\)s/\1/p') 
	_tm_min=$(expr ${_tm_t%m*} + 0)
	_tm_sec=${_tm_t#*m}
	_tm_msec=$(expr ${_tm_sec#*.} + 0)
	_tm_sec=$(expr ${_tm_sec%.*} + 0)
	_tm_tmsec=$(( $_tm_min * 60 * 1000 + $_tm_sec * 1000 + $_tm_msec ))
	echo $_tm_tmsec
}

echo "sparse (0's):"
time_msec iquery -naq "count(multiply(A2,B2))"
echo "sparse (empty cells, created w/ redimension() or build_sparse(), non-nullable value attribute):"
time_msec iquery -naq "count(multiply(A3,B3))"
echo "reference (naive native C code, in-memory):"
gcc matmulttest.c -o tmp
time_msec ./tmp $1
rm -f tmp
echo "dense:"
time_msec iquery -naq "count(multiply(A1,B1))"
#cleanup
