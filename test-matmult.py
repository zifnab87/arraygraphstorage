#!/usr/bin/python

import os
import sys
import signal
import re
import subprocess
import pickle

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
    try:
        res = subprocess.check_output( '((time '+ ' '.join(command) +' >/dev/null) 2>&1)', shell=True, executable='/bin/bash' )
        res = re.search('real\t(.*)s', res).group(1)
        tmin, sep, trest = res.partition('m')
        tsec, sep, tmsec = trest.partition('.')
        return int(tmin) * 60 * 1000 + int(tsec) * 1000 + int(tmsec)
    except subprocess.CalledProcessError, e:
        print "time_msec() terminated due to non-zero return code"
        print e
        return -1

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

def benchmark(target, size, cleanupFunc=None):
    impl, sep, method = target.partition('-')

    def cleanup(signum=None, frame=None):
        if impl == 'scidb':
            trydrop("A")
            trydrop("B")
            trydrop("T")
        elif impl == 'native':
            subprocess.call(['rm', '-f', binname])
        if signum:
            if cleanupFunc:
                cleanupFunc()
            exit()

    oldhdl = signal.signal(signal.SIGINT, cleanup)
    if impl == 'scidb':
        randmat(size, method, "A")
        randmat(size, method, "B")
        t = time_msec(['iquery', '-naq', '\"count(multiply(A,B))\"'])
    elif impl == 'native':
        binname = 'native'
        subprocess.call(['gcc', '-DNDEBUG', '-O3', 'matmulttest.c', '-o', binname])
        t = time_msec(['./' + binname, method, str(size)])

    cleanup()
    signal.signal(signal.SIGINT, oldhdl)
    if t == -1:
        if cleanupFunc:
            cleanupFunc()
        exit()
    return t


targets = [ 
    'native-dense',
    'native-sparse',
    'scidb-dense',
    'scidb-sparse-1',
    'scidb-sparse-2'
]

thresh = 10000
maxruns = 3

if __name__ == "__main__":
    def _print_usage():
        print '''usage:
    ./test-matmult.py --run-benchmark [OUTPUT_FILE]
    ./test-matmult.py --plot-results [INPUT_FILE]'''

    if len(sys.argv) < 2:
        _print_usage()
        exit()
    filename = len(sys.argv) == 3 and sys.argv[2] or 'results.csv'

    if sys.argv[1] == '--run-benchmark':
        print "TARGET\t\tSIZE\tAVG.TIME(msec)\tNUM.RUNS\tMIN.T\tMAX.T"
        result = []
        def store():
            outfile = open(filename, 'wb')
            pickle.dump(result, outfile)
            outfile.close()

        alist = dict(zip(targets, [True]*len(targets)))
        for s in map(lambda x: 2**x, range(4,25)):
            if True not in alist.values():
                break
            for k in targets: 
                if alist[k]:
                    r = {"target": k, "size": s}
                    print "%(k)s\t%(s)s" % locals(),
                    qo = thresh
                    c = 0
                    tl = []
                    while qo > 0 and c < maxruns:
                        t = benchmark(k, s, store)
                        if t > thresh:
                            alist[k] = False
                        qo = qo - t
                        c = c + 1
                        tl.append(t)
                    r['avg_time'] = float(sum(tl))/float(len(tl))
                    r['num_runs'] = c
                    r['min_time'] = min(tl) 
                    r['max_time'] = max(tl)
                    result.append(r)
                    print "\t%(avg_time)g\t\t%(num_runs)d\t\t%(min_time)d\t%(max_time)d" % r
        store()
    
    elif sys.argv[1] == '--plot-results':
        infile = open(filename, 'rb')
        results = pickle.load(infile)
        infile.close()
        import numpy as np
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        plt.figure(1)
        plt.subplot(111)
        xmin = xmax = topmin= None

        for k in targets:
            data = map(
                lambda x: [x['size'], x['avg_time'], x['min_time'], x['max_time']],
                filter(
                    lambda x: x['target'] == k,
                    results)
                )
            a = zip(*data)
            line, = plt.loglog(*a[:2], label=k)
            print line.get_color()
            plt.fill_between(a[0],a[2],a[3],color=(0.6,0.9,0.7,0.5))
            if xmin and xmax and topmin :
                xmin = min(xmin,min(a[0]))
                xmax = max(xmax,max(a[0]))
                topmin = min(topmin, min(np.array(a[1])/ np.array(a[0])**3))
            else:
                xmin = min(a[0])
                xmax = max(a[0])
                topmin = min(np.array(a[1])/ np.array(a[0])**3)

        x = np.arange(300,xmax,100) 
        print xmin
        print xmax
        print topmin
        plt.loglog(x, topmin * x**3, '--', label='theory')

        plt.ylabel('avg. time (seconds, log-scale)')
        plt.xlabel('matrix size (P(a_ij!=0)=0.001)')
        plt.legend(loc=2)
        plt.savefig('test.png')
    else:
        _print_usage()
 
