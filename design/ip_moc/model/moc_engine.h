#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

typedef float float32_t;
typedef int32_t q31_t;
typedef int64_t q63_t;

typedef struct
{
    uint16_t fftLen;
    const q31_t *pTwiddle;
    const uint16_t *pBitRevTable;
    uint16_t bitRevLength;
} arm_cfft_instance_q31;

int32_t arm_cfft_init_q31(
    arm_cfft_instance_q31 * S,
    uint16_t fftLen
){
    S->fftLen = fftLen;
}



void arm_cfft_q31(
    const arm_cfft_instance_q31 *S,
    q31_t * p1,
    uint8_t ifftFlag,
    uint8_t bitReverseFlag
);