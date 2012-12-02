#include <stdlib.h> // random()
#include <stdio.h>  // printf()
#include <stdint.h> // int64_t
#include <inttypes.h> // PRId64
#include <string.h>   // memset()
#include <assert.h>


typedef int64_t elem_t;

struct sparse_elem;

struct sparse_elem {
	int ind;
	elem_t val;
	struct sparse_elem *nxt;
};

typedef struct sparse_elem sparse_elem_t;

elem_t** mat_new(int n)
{
	int i,j;
	assert(n > 0);
	elem_t** M = (elem_t**)malloc(n * sizeof(elem_t*));
	for (i = 0; i<n; i++) {
		M[i] = (elem_t*)malloc(n * sizeof(elem_t));
		memset(M[i], 0, n * sizeof(elem_t*));
	}
	return M;
}

void mat_destroy(elem_t** A, int n)
{
	int i;
	assert(A != NULL && n > 0);
	for (i = 0; i<n; i++) {
		free(A[i]);
	}
	free(A);
}


sparse_elem_t** mat_sparse_new(int n)
{
	int i;
	assert(n > 0);
	sparse_elem_t** M = (sparse_elem_t**)malloc(n * sizeof(sparse_elem_t*));
	for (i = 0; i<n; i++) {
		sparse_elem_t* n = (sparse_elem_t*)malloc(sizeof(sparse_elem_t));				  n->ind = -1;
		n->val = 0;
		n->nxt = NULL;
		M[i]=n;
	}
	return M;
}


void mat_sparse_destroy(sparse_elem_t** A, int n)
{
	int i;
	sparse_elem_t* pj;
	assert(A != NULL && n > 0);
	for (i = 0; i<n; i++) {
		pj = A[i]->nxt;
		while (pj != NULL) {
			pj = pj->nxt;
			free(pj);
		}
		free(A[i]);
	}
	free(A);
}


void mat_init_rand_boolean(elem_t** M, int n)
{
	int i,j;
	assert(M != NULL && n > 0);
	for (i = 0; i<n; i++) {
		for (j = 0; j<n; j++) {
			M[i][j] = random() % 2;
		}
	}
}


int mat_equals(elem_t** A, elem_t** B, int n)
{
	int i,j;
	assert(A != NULL && B != NULL && A != B && n > 0);
	for (i = 0; i<n; i++) {
		for (j = 0; j<n; j++) {
			if (A[i][j] != B[i][j]) {
				return 0;
			}	
		}
	}
	return 1;
}


void mat_sparse_init_rand_boolean(sparse_elem_t** M, int n, double p)
{
	int i,j;
	sparse_elem_t* pj;
	assert(M != NULL && n > 0);
	for (i = 0; i<n; i++) {
		pj = M[i];
		assert(pj != NULL && pj->ind == -1 && pj->nxt == NULL);
		for (j = 0; j<n; j++) {
			double x = ((double)rand()/(double)RAND_MAX);
			if ( x < p ) {
				sparse_elem_t* n = (sparse_elem_t*)malloc(sizeof(sparse_elem_t));				  n->ind = j;
				n->val = 1;
				pj->nxt = n;
				pj = n;
			}
		}
		pj->nxt = NULL;
	}
}


#ifndef NDEBUG
void mat_print(const char* name, elem_t** M, int n)
{
	int i,j;
	assert(M != NULL && n > 0);
	printf("%s =\n", name);
	if (n > 40) {
		printf("[too large to be displayed]\n");
		return;
	} 
	for (i = 0; i<n; i++) {
		for (j = 0; j<n; j++) {
			printf("%2" PRId64, M[i][j]);
		}
		printf("\n");
	}
}


void mat_sparse_print(const char* name, sparse_elem_t** M, int n)
{
	int i;
	sparse_elem_t* pj;
	assert(M != NULL && n > 0);
	printf("%s =\n", name);
	if (n > 40) {
		printf("[matrix too large to be displayed]\n");
		return;
	} 
	for (i = 0; i<n; i++) {
		int r;
		int prev_ind = -1;
		for (pj = M[i]->nxt; pj != NULL; pj = pj->nxt) {
			assert(pj->ind >= prev_ind);
			for (r = 0; r < (pj->ind - prev_ind - 1); r++) {
				printf("%2s", "0");
			}
			prev_ind = pj->ind;
			printf("%2" PRId64, pj->val);
			
		}
		for (r = 0; r < (n - 1 - prev_ind); r++) {
			printf("%2s", "0");
		}
		printf("\n");
	}
}
#else
#define mat_print(name,A,n) 
#define mat_sparse_print(name,A,n) 
#endif



elem_t** mat_mult(elem_t** A, elem_t** B, int n)
{
	int i,j,c,sum;
	assert(A != NULL && B != NULL && n > 0);
	elem_t** C = mat_new(n);
	for (i = 0; i < n; i++) {
		for (j = 0; j<n; j++) {
			sum = 0;
			for (c = 0; c < n; c++) {
				sum += A[i][c] * B[c][j];
			}
			C[i][j] = sum;
		}
	}
	return C;
}

sparse_elem_t** mat_sparse_transpose(sparse_elem_t** M, int n)
{
	int i,j;
	sparse_elem_t* pj;
	sparse_elem_t** ppt;
	assert(M != NULL && n > 0);
	sparse_elem_t** T = mat_sparse_new(n);
	ppt = (sparse_elem_t**)malloc(n * sizeof(sparse_elem_t*));
	for (j = 0; j<n; j++) {
		ppt[j] = T[j]; 
	}
	for (i = 0; i<n; i++) {
		for (pj = M[i]->nxt; pj != NULL; pj = pj->nxt) {
			sparse_elem_t* n = (sparse_elem_t*)malloc(sizeof(sparse_elem_t));
			n->ind = i;
			n->val = pj->val;
			ppt[pj->ind]->nxt = n;
			ppt[pj->ind] = n;
		}
	}
	for (j = 0; j<n; j++) {
		ppt[j]->nxt = NULL;
	}
	return T;
}

elem_t** mat_sparse_to_dense(sparse_elem_t** S, int n)
{
	int i;
	elem_t** D;
	sparse_elem_t* pj;
	assert(S != NULL && n > 0);
	D = mat_new(n);
#ifndef NDEBUG
	int j;
	for (i = 0; i<n; i++) {
		for (j = 0; j<n; j++) {
			assert(D[i][j] == 0);
		}
	}	
#endif
	for (i = 0; i<n; i++) {
		for (pj = S[i]->nxt; pj != NULL; pj = pj->nxt) {
			assert(pj->ind >= 0 && pj->ind < n);
			D[i][pj->ind] = pj->val;
		}
	}
	return D;
}


elem_t** mat_sparse_mult_transposed(sparse_elem_t** A, sparse_elem_t** B, int n)
{
	int i,j,sum;
	sparse_elem_t *pac,*pbc;
	assert(A != NULL && B != NULL && n > 0);
	elem_t** C = mat_new(n);
	for (i = 0; i < n; i++) {
		for (j = 0; j<n; j++) {
			sum = 0;
			pac = A[i]->nxt;
			pbc = B[j]->nxt;
			if (pac != NULL && pbc != NULL) {
				while (1) {
					if (pac->ind > pbc->ind) {
						if ((pbc = pbc->nxt) == NULL)
							break;
					} else if (pac->ind < pbc->ind) {				
						if ((pac = pac->nxt) == NULL)
							break;
					} else {
						sum += pac->val * pbc->val;
						pac = pac->nxt;
						pbc = pbc->nxt;
						if (pac == NULL || pbc == NULL)
							break;
					}
				}
			}
			C[i][j] = sum;
		}
	}
	return C;
}


elem_t** mat_sparse_mult(sparse_elem_t** A, sparse_elem_t** B, int n)
{
	sparse_elem_t** Bt = mat_sparse_transpose(B,n);
	elem_t** C = mat_sparse_mult_transposed(A, Bt, n);
	mat_sparse_destroy(Bt,n);
	return C;
}


int _test_multiply_sparse_dense_same_result() 
{
	int res;
	const int _n = 50;
	sparse_elem_t** _s1 = mat_sparse_new(_n);
	mat_sparse_init_rand_boolean(_s1,_n,0.5);
	sparse_elem_t** _s2 = mat_sparse_new(_n);
	mat_sparse_init_rand_boolean(_s2,_n, 0.5);
	elem_t** _s3 = mat_sparse_mult(_s1,_s2,_n);
	elem_t** _d1 = mat_sparse_to_dense(_s1,_n);
	elem_t** _d2 = mat_sparse_to_dense(_s2,_n);
	elem_t** _d3 = mat_mult(_d1,_d2,_n);
	res = mat_equals(_s3,_d3,_n);
	mat_sparse_destroy(_s1,_n);
	mat_sparse_destroy(_s2,_n);
	mat_destroy(_s3,_n);
	mat_destroy(_d1,_n);
	mat_destroy(_d2,_n);
	mat_destroy(_d3,_n);
	return res;
}

int main(int argc, char** argv) 
{
	assert(_test_multiply_sparse_dense_same_result());

	if (argc != 3) {
		printf("usage: matmulttest [dense|sparse] [N]\n");
		return 1;
	}
	char* repr = argv[1];
	int N = atoi(argv[2]);
	assert(N > 0);
	if (strcmp(repr, "dense") == 0) {
		printf("Initializing 2 random dense matrices of size %d x %d\n", N, N);
		elem_t** A = mat_new(N);
		mat_init_rand_boolean(A,N);
		mat_print("A", A,N);
		elem_t** B = mat_new(N);
		mat_init_rand_boolean(B,N);
		mat_print("B", B, N);
		elem_t** C = mat_mult(A,B,N);
		mat_print("A x B", C, N);
		mat_destroy(A,N);
		mat_destroy(B,N);
		mat_destroy(C,N);
	} else if (strcmp(repr, "sparse") == 0) {

		const double p = 0.01;
		printf("Initializing 2 random sparse matrices (P(A[i][j] != 0) = %g)of size %d x %d\n", p, N, N);
		sparse_elem_t** A = mat_sparse_new(N);
		mat_sparse_init_rand_boolean(A,N,p);
		mat_sparse_print("A", A, N);
		sparse_elem_t** B = mat_sparse_new(N);
		mat_sparse_init_rand_boolean(B,N,p);
		mat_sparse_print("B", B, N);
		elem_t** C = mat_sparse_mult(A,B,N);
		mat_print("A x B", C, N);
		mat_sparse_destroy(A,N);
		mat_sparse_destroy(B,N);
		mat_destroy(C,N);

	} else {
		printf("usage: matmulttest [dense|sparse] [N]\n");
		return 1;
	}
	return 0;
}
