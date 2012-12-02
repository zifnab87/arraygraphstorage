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
	echo "$_tm_tmsec"
}



function trydrop {
	iquery -nq "drop array $1;" &>/dev/null
}

function randmat {
	# Recommended chunk size
	local N=$1 
	local TYPE=$2
	local NAME=$3
	local P=$4
	if [ $# -lt 3 ]; then
		echo "usage: randmat [N] [TYPE=dense|sparse-1|sparse-2] [NAME] [PROB_NONZERO]"
		exit 1
	fi
	if [ $N -lt 1024 ]; then 
		local CHNK1=$N
		local CHNK2=$N
	else
		local CHNK1=1024
		local CHNK2=1024
	fi
#	if [ $(( $1 * $1 )) -gt 10485760 ]; then
#		# Max chunk size for 85 Mb segment
#		#setup $1 "$(( 5 * 1024 ))" "$(( 2 * 1024 ))"
#	fi
	local P="1" # percent of non-zero element in a sparse matrix
	local Nm1=$(( $1 - 1 ))
	local NNz=$(( $N * $N * $P / 1000 ))
	if [ $NNz -le 0 ]; then
		local NNz=0
	fi
	local NNzm1=$(( $NNz -1 ))
	if [ "$TYPE" == "dense" ]; then
		AQL "create array $NAME <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
		AFL "store(build($NAME,random() % 2),$NAME)"
	else if [ "$TYPE" == "sparse-1" ]; then
		AQL "create array $NAME <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
		AFL "store(build($NAME, iif((random() % 1000) < $P,1,0)),$NAME)"
	else if [ "$TYPE" == "sparse-2" ]; then
		# indirectly way of generating random sparse array
		# WARN: possible cell collisions
		# NOTE: number of non-zero elements in matrix always <= NNz
		AQL "create array $NAME <val:int64> [i=0:$Nm1,$CHNK1,0, j=0:$Nm1,$CHNK2,0]"
		if [ $NNz -ge 1 ]; then
			AQL "create array T <i:int64, j:int64, val:int64> [d=0:$NNzm1,$NNz,0];"
			AFL "store(join(join(
					build(<i:int64>[d=0:$NNzm1,$NNz,0],random() % $N),
					build(<j:int64>[d=0:$NNzm1,$NNz,0],random() % $N)),
					build(<val:int64>[d=0:$NNzm1,$NNz,0], 1)),
				 T)"
			AFL "redimension_store(T,$NAME);"
		fi
		iquery -nq "drop array T;" &>/dev/null
		# straightforward way of generating random sparse array
		# WARN: fails because of scidb bug...
		#AFL "store(build_sparse($NAME, 1, (random() % 1000) < $P),$NAME)"
	fi
	fi
	fi
	#iquery -aq "scan($NAME)"
}

function cleanup {
	trydrop A1
	trydrop B1
	trydrop A2
	trydrop B2
	trydrop A3
	trydrop B3
}


function setup {
	randmat $1 dense A1
	randmat $1 dense B1
	randmat $1 sparse-1 A2
	randmat $1 sparse-1 B2
	randmat $1 sparse-2 A3
	randmat $1 sparse-2 B3
}

function timemult {
	time_msec iquery -naq "count(multiply($1,$2))"
}

function benchmark {
    if [ $# -ne 2 ]; then
        echo "benchmark() expected 2 parameters"
        exit 1
    fi
    local target=$1
    local size=$2
    local impl=${target%%-*}
    local method=${target#*-}
    echo "$target:$size"
    if [ "$impl" == "scidb" ]; then
        echo -en        "initializing..."
	    randmat $size $method A
    	randmat $size $method B
        echo -en      "\rrunning...     "
        local T=$(timemult A B)
        echo -en      "\r               " "\r"
    	trydrop A
	    trydrop B
    else if [ "$impl" == "native" ]; then
        gcc -DNDEBUG -O3 matmulttest.c -o native
        local T=$(time_msec ./native $method $size)
        rm -f native
    else
        echo "target=[native-dense|native-sparse|scidb-dense|scidb-sparse-1|scidb-sparse=2]"
        exit 1
    fi
    fi 
    echo $T 
    return 0
}

for size in 10 100 200 500 750
do 
    for target in 'native-dense' 'native-sparse' 'scidb-dense' 'scidb-sparse-1' 'scidb-sparse-2'
    do
        benchmark $target $size
    done
done
