#include<stdint.h>
#include<stdlib.h>
#include<stdio.h>
#include<string.h>

typedef int32_t fFixedType_t;
typedef struct 
{
    uint16_t dx;
    uint16_t dy;
    int16_t ori;
    int32_t lsh_des[12];
} fpKeyPoint_t;

int32_t HammDistance(const int32_t* pnA, const int32_t* pnB, int32_t nDim);
void hamdis(const fpKeyPoint_t *pstFeat1, const fpKeyPoint_t *pstFeat2, fFixedType_t *pnMinData, fFixedType_t *pnMinPos,
            const int32_t*pnKeymapPara, int32_t nIStart, int32_t nIEnd, int32_t nJStart, int32_t nJEnd,
            uint16_t *pusDisArr, const int32_t nTh, const int32_t nDesBitLen, const int32_t nBitQMode);