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
	echo Chunk size is $CHNK1 x $CHNK2
	AQL "create array A1 <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
	AQL "create array B1 <val:int64> [i=0:$Nm1,$CHNK2,0, j=0:$Nm1,$CHNK1,0]"
	AFL "store(build(A1,random() % 2),A1)"
	AFL "store(build(B1,random() % 2),B1)"
	AQL "create array A2 <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
	AQL "create array B2 <val:int64> [i=0:$Nm1,$CHNK2,0, j=0:$Nm1,$CHNK1,0]"
	AFL "store(build(A2, iif((random() % 1000) < $P,1,0)),A2)"
	AFL "store(build(B2, iif((random() % 1000) < $P,1,0)),B2)"
}

function cleanup {
	iquery -nq "drop array A1;" &>/dev/null
	iquery -nq "drop array B1;" &>/dev/null
	iquery -nq "drop array A2;" &>/dev/null
	iquery -nq "drop array B2;" &>/dev/null
}

if [ "$1" != "" ]; then
	if [ $(( $1 * $1 )) -gt 10485760 ]; then
		# WARN: this scidb instance appears to be configured with a 85 Mb segment
		setup $1 "$(( 5 * 1024 ))" "$(( 2 * 1024 ))"
	else 
		setup $1 $1 $1
	fi
fi

echo Dense multiply:
time iquery -naq "multiply(A1,B1)"

echo Sparse multiply:
time iquery -naq "multiply(A2,B2)"

#cleanup
