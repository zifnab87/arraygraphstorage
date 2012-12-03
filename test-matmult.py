#!/usr/bin/python

import os
import re
import subprocess

def _iquery_wrapper(query, flags='-q'):
    with open(os.devnull, "w") as fnull:
        res = subprocess.call(['iquery', '-naq', query], stdout = fnull)
    if res != 0:
        #cleanup()
        exit()

def afl(query):
    _iquery_wrapper(query, '-naq')

def aql(query):
    _iquery_wrapper(query, '-nq')

def trydrop(name):
    with open(os.devnull, "w") as fnull:
        subprocess.call(['iquery', '-nq', 'drop array %s;' % name], stdout = fnull, stderr = fnull)

def time_msec(command):
    res = subprocess.check_output( '((time '+ ' '.join(command) +' >/dev/null) 2>&1)', shell=True, executable='/bin/bash' )
    res = re.search('real\t(.*)s', res).group(1)
    tmin, sep, trest = res.partition('m')
    tsec, sep, tmsec = trest.partition('.')
    return int(tmin) * 60 * 1000 + int(tsec) * 1000 + int(tmsec)

""" arguments:
        n       size of a square matrix
        method  one of: dense, sparse-1, sparse-2
        name    array name in the database
        p       probability of each matrix element being assigned a nonzero
                value
"""
def randmat(n, method, name, p=0.001):
    optchnk = 1024
    chnk1 = chnk2 = n<=optchnk and n or optchnk
    # max chunk size for segment of 85Mb would b e 5*1024 x 2*1024	
    nm1 = n - 1
    nnz = n * n * p
    aql('''create array %(name)s <val:int64> 
        [i=0:%(nm1)d,%(chnk1)d,0, j=0:%(nm1)d,%(chnk2)d,0]'''
        % locals())
    if method == 'dense':
        afl("store(build(%(name)s,random() %% 2),%(name)s)" % locals())
    elif method == 'sparse-1':
        p1 = p * 1000
        afl("store(build(%(name)s, iif((random() %% 1000) < %(p1)d,1,0)),%(name)s)"
            % locals())
    elif method == 'sparse-2':
        # indirectly way of generating random sparse array
        # WARN: possible cell collisions
        # NOTE: number of non-zero elements in matrix always <= NNz
        if nnz >= 1:
            nnzm1 = nnz - 1
            aql("create array T <i:int64, j:int64, val:int64> [d=0:%(nnzm1)d,%(nnz)d,0];"             % locals())
            afl('''store(join(join(
                        build(<i:int64>[d=0:%(nnzm1)d,%(nnz)d,0],random() %% %(n)d),
                        build(<j:int64>[d=0:%(nnzm1)d,%(nnz)d,0],random() %% %(n)d)),
                    build(<val:int64>[d=0:%(nnzm1)d,%(nnz)d,0], 1)),
                T)''' % locals())
            afl("redimension_store(T,%(name)s);" % locals())
            trydrop("T")
            # straightforward way of generating random sparse array
            # WARN: fails because of scidb bug...
            #AFL "store(build_sparse($NAME, 1, (random() % 1000) < $P),$NAME)"

def benchmark(target, size):
    impl, sep, method = target.partition('-')
    if impl == 'scidb':
        randmat(size, method, "A")
        randmat(size, method, "B")
        t = time_msec(['iquery', '-naq', '\"count(multiply(A,B))\"'])
        trydrop("A")
        trydrop("B")
    elif impl == 'native':
        binname = 'native'
        subprocess.call(['gcc', '-DNDEBUG', '-O3', 'matmulttest.c', '-o', binname])
        t = time_msec(['./' + binname, method, str(size)])
        subprocess.call(['rm', '-f', binname])
    return t


targets = [ 
    'native-dense',
    'native-sparse',
    'scidb-dense',
    'scidb-sparse-1',
    'scidb-sparse-2'
]

thresh = 600000
maxruns = 5

if __name__ == "__main__":
    alist = dict(zip(targets, [True]*len(targets)))
    for s in map(lambda x: 2**x, range(4,25)):
        if True not in alist.values():
            break
        for k in targets: 
            if alist[k]:
                print "%(k)s\t%(s)s" % locals(),
                qo = thresh
                c = 0
                tl = []
                while qo > 0 and c < maxruns:
                    t = benchmark(k, s)
                    if t > thresh:
                        alist[k] = False
                    qo = qo - t
                    c = c + 1
                    tl.append(t)
                tavg = float(sum(tl))/float(len(tl))
                print "\t%g" % tavg


