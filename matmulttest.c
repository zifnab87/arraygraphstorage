#include <stdlib.h> // random()
#include <stdio.h>  // printf()
#include <stdint.h> // int64_t
#include <inttypes.h> // PRId64
#include <string.h>   // memset()
#include <assert.h>


typedef int64_t elem_t;


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


void mat_print(elem_t** M, int n)
{
	int i,j;
	assert(M != NULL && n > 0);
	if (n > 40) {
		printf("[matrix too large to be displayed]\n");
		return;
	} 
	for (i = 0; i<n; i++) {
		for (j = 0; j<n; j++) {
			printf("%2" PRId64, M[i][j]);
		}
		printf("\n");
	}
}


elem_t** mat_mult(elem_t** A, elem_t** B, int n)
{
	int i,j,c,sum;
	assert(A != NULL && B != NULL && n > 0);
	elem_t** C = mat_new(n);
	for (i = 0; i<n; i++) {
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


int main(int argc, char** argv) 
{
	if (argc != 2) {
		printf("usage: matmulttest [N]\n");
		return 1;
	}
	int N = atoi(argv[1]);
	assert(N > 0);
	printf("Initializing 2 random dense matrices of size %d x %d\n", N, N);
	elem_t** A = mat_new(N);
	mat_init_rand_boolean(A,N);
	printf("A = \n");
	mat_print(A,N);
	elem_t** B = mat_new(N);
	mat_init_rand_boolean(B,N);
	printf("B = \n");
	mat_print(B,N);
	printf("A x B = \n");
	elem_t** C = mat_mult(A,B,N);
	mat_print(C,N);
	return 0;
}
