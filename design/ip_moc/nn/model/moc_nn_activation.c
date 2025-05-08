#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "moc_nn.h"

const uint16_t SigmoidTableU16[256] = {
    32768, 33451, 34133, 34813, 35493, 36169, 36843, 37513, 38180, 38841, 39498, 40149, 40794, 41432, 42064, 42688,
    43304, 43912, 44511, 45102, 45683, 46255, 46817, 47369, 47911, 48443, 48964, 49475, 49975, 50464, 50942, 51409,
    51865, 52311, 52745, 53169, 53581, 53983, 54374, 54755, 55125, 55485, 55834, 56174, 56503, 56823, 57133, 57433,
    57724, 58007, 58280, 58544, 58800, 59048, 59288, 59519, 59743, 59959, 60168, 60370, 60565, 60753, 60935, 61110,
    61279, 61441, 61599, 61750, 61896, 62036, 62172, 62302, 62428, 62549, 62666, 62778, 62886, 62990, 63090, 63186,
    63279, 63368, 63454, 63536, 63615, 63691, 63765, 63835, 63903, 63968, 64030, 64090, 64148, 64204, 64257, 64308,
    64357, 64405, 64450, 64494, 64536, 64576, 64614, 64652, 64687, 64721, 64754, 64786, 64816, 64845, 64873, 64900,
    64926, 64950, 64974, 64997, 65019, 65039, 65060, 65079, 65097, 65115, 65132, 65149, 65164, 65179, 65194, 65208,
    65221, 65234, 65246, 65258, 65269, 65280, 65291, 65301, 65310, 65319, 65328, 65337, 65345, 65352, 65360, 65367,
    65374, 65381, 65387, 65393, 65399, 65404, 65410, 65415, 65420, 65425, 65429, 65433, 65438, 65442, 65445, 65449,
    65453, 65456, 65459, 65462, 65465, 65468, 65471, 65474, 65476, 65479, 65481, 65483, 65485, 65488, 65489, 65491,
    65493, 65495, 65497, 65498, 65500, 65501, 65503, 65504, 65505, 65507, 65508, 65509, 65510, 65511, 65512, 65513,
    65514, 65515, 65516, 65517, 65517, 65518, 65519, 65520, 65520, 65521, 65522, 65522, 65523, 65523, 65524, 65524,
    65525, 65525, 65526, 65526, 65526, 65527, 65527, 65528, 65528, 65528, 65529, 65529, 65529, 65529, 65530, 65530,
    65530, 65530, 65531, 65531, 65531, 65531, 65531, 65532, 65532, 65532, 65532, 65532, 65532, 65533, 65533, 65533,
    65533, 65533, 65533, 65533, 65533, 65534, 65534, 65534, 65534, 65534, 65534, 65534, 65534, 65534, 65534, 65535};

#define MOCNN_Q31_MAX ((int32_t)(0x7FFFFFFFL))
#define MOCNN_Q31_MIN ((int32_t)(0x80000000L))
#define MASK_IF_ZERO(x) (x) == 0?   ~0 : 0
#define MASK_IF_NON_ZERO(x) (x) != 0?   ~0 : 0
#define SELECT_USING_MASK(mask, a, b)  ((mask) & (a)) ^ (~(mask) & (b))

#define ACCUM_BITS 12
#define MUL_SAT(a,b)  MOCNN_DoublingHighMult((a),(b))
#define MUL_POW2(a,b)  MOCNN_MultByPowerOfTwo((a),(b))
#define DIV_POW2(a,b) MOCNN_DividePowerOfTwo((a),(b))
#define EXP_ON_NEG(x) MOCNN_ExpOnNegativeValues((x))
#define ONE_OVER1(x) MOCNN_OneOverOnePlusXForXIn01((x))

typedef enum
{
    MOCNN_SIGMOID = 0,
    MOCNN_TANH = 1,
};


int32_t MOCNN_DividePowerOfTwo(const int32_t dividend, const int32_t exponent)
{
    int32_t result = 0;
    const int32_t remainder_mask = (1 << exponent) - 1;
    int32_t remainder = remainder_mask & dividend;

    result = dividend >> exponent;

    int32_t threshold = remainder_mask >> 1;
    if(result < 0)
    {
        threshold++;
    }
    if(remainder > threshold)
    {
        result++;
    }
    return result;
}

// 统计0的个数
const uint8_t ClzTable[16] = {4,3,2,2,1,1,1,1,0,0,0,0,0,0,0,0};
int32_t MOCNN_CLZ(uint32_t x)
{
    if(x==0) return 32;
    int count = 0;
    if((x & 0xFFFF0000) == 0)   {count += 16;   x <<= 16; }
    if((x & 0xFF000000) == 0)   {count += 8;   x <<= 8;   }
    if((x & 0xF0000000) == 0)   {count += 4;   x <<= 4;   }
    return count + ClzTable[x >> 28];
}

// 移位乘法
int32_t MOCNN_MultByPowerOfTwo(const int32_t val, const int32_t exp)
{
    const int32_t thresh = ((1 << (31 - exp)) - 1);
    int32_t result = val << exp;
    result = SELECT_USING_MASK(MASK_IF_NON_ZERO(val > thresh), MOCNN_Q31_MAX, result);
    result = SELECT_USING_MASK(MASK_IF_NON_ZERO(val < -thresh), MOCNN_Q31_MIN, result);
    return result;
}

// 饱和乘法
int32_t MOCNN_DoublingHighMult(const int32_t m1, const int32_t m2)
{
    int32_t result = 0;
    // rounding offset ro add for a right shift of 31
    int64_t mult = 1 << 30;
    if((m1 < 0) ^ (m2 < 0))
    {
        mult = 1 - mult;
    }
    // gets resolved as a SMLAL instruction
    //printf("mult_pre=%d\n",mult);
    mult = mult + (int64_t)m1*m2;
    //printf("m1=%d, m2=%d, mult_post=%d\n",m1,m2,mult);
    // utilize all or the upper 32 bits. This is the doublign step
    result = (int32_t)(mult / (1ll << 31));
    //printf("res=%d\n",result);
    if((m1 == m2) && (m1 == (int32_t)MOCNN_Q31_MIN))
    {
        result = MOCNN_Q31_MAX;
    }
    return result;
}

int32_t MOCNN_OneOverOnePlusXForXIn01(int32_t val)
{
    const int64_t sum = (int64_t)val + (int64_t)MOCNN_Q31_MAX;
    //printf("val=%d, sum=%lld, ",val,sum);
    const int32_t half_denominator = (int32_t)((sum + (sum >= 0?    1: -1)) / 2L);
    //printf("\nhalf=%d\n",half_denominator);
    int32_t x = 1515870810 + MUL_SAT(half_denominator, -1010580540);
    //printf("x=%d\n",x);

    const int32_t shift = (1 << 29);
    x += MUL_POW2(MUL_SAT(x, shift - MUL_SAT(half_denominator, x)), 2);
    //printf("MUL_SAT(%d, %d, x): %d\n",half_denominator, x, MUL_SAT(half_denominator, x));
    //printf("MUL_SAT(%d,%d): %d\n",x, (shift - MUL_SAT(half_denominator, x)), MUL_SAT(x, shift - MUL_SAT(half_denominator, x)));
    x += MUL_POW2(MUL_SAT(x, shift - MUL_SAT(half_denominator, x)), 2);
    //printf("x=%d\n",x);
    x += MUL_POW2(MUL_SAT(x, shift - MUL_SAT(half_denominator, x)), 2);
    //printf("x=%d\n",x);
    return MUL_POW2(x, 1);
}

// 计算exp指数
int32_t MOCNN_ExpOnNegativeValues(int32_t val)
{
    int32_t mask = 0;
    int32_t shift = 24;
    const int32_t val_mod_minus_quarter = (val & ((1 << shift) - 1)) - (1 << shift);
    const int32_t remainder = val_mod_minus_quarter - val;
    const int32_t x = (val_mod_minus_quarter << 5) + (1 << 28);
    const int32_t x2 = MUL_SAT(x, x);
    //printf("val_mod_minus_quarter: %d\n", val_mod_minus_quarter);
    //printf("remainder: %d\n", remainder);
    //printf("x: %d\n", x);
    //printf("x2: %d\n", x2);
    //printf("MUL_SAT(x2, x): %d\n", MUL_SAT(x2, x));
    //printf("DIV_POW2(MUL_SAT(x2, x2), 2): %d\n", DIV_POW2(MUL_SAT(x2, x2), 2));
    //printf("DIV_POW2(MUL_SAT(x2, x2), 2) + MUL_SAT(x2, x): %d\n", DIV_POW2(MUL_SAT(x2, x2), 2) + MUL_SAT(x2, x));
    //printf("MUL_SAT(DIV_POW2(MUL_SAT(x2, x2), 2) + MUL_SAT(x2, x), 715827883): %d\n", MUL_SAT(DIV_POW2(MUL_SAT(x2, x2), 2) + MUL_SAT(x2, x), 715827883));
    //printf("x+DIV2: %d\n", x+DIV_POW2(MUL_SAT(DIV_POW2(MUL_SAT(x2, x2), 2) + MUL_SAT(x2, x), 715827883) + x2, 1));

    //printf("MUL_SAT(1895147668: %d\n", MUL_SAT(1895147668, x + DIV_POW2(MUL_SAT(DIV_POW2(MUL_SAT(x2, x2), 2) + MUL_SAT(x2, x), 715827883) + x2, 1)));

    int32_t result = 1895147668 + MUL_SAT(1895147668, x + DIV_POW2(MUL_SAT(DIV_POW2(MUL_SAT(x2, x2), 2) + MUL_SAT(x2, x), 715827883) + x2, 1));
    //printf("result: %d\n", result);

#define SELECT_IF_NON_ZERO(x)   \
    {                                                           \
        mask = MASK_IF_NON_ZERO(remainder & (1 << shift++));    \
        result = SELECT_USING_MASK(mask, MUL_SAT(result,x), result);    \
    }
    SELECT_IF_NON_ZERO(1672461947)

    SELECT_IF_NON_ZERO(1302514674)

    SELECT_IF_NON_ZERO(790015084)

    SELECT_IF_NON_ZERO(290630308)

    SELECT_IF_NON_ZERO(39332535)

    SELECT_IF_NON_ZERO(720401)

    SELECT_IF_NON_ZERO(242)


#undef SELECT_IF_NON_ZERO
    mask = MASK_IF_ZERO(val);
    return SELECT_USING_MASK(mask, MOCNN_Q31_MAX, result);
}

int32_t MOCNN_SigmoidTanh(const mocnn_tensor *pstInTensor, const mocnn_tensor *pstOutTensor, uint8_t uchOpType)
{
    printf("Entering SigmoidTanh\n");

    if(NULL == pstInTensor || NULL == pstOutTensor)
    {
        return MOCNN_NULL_PTR;
    }

    const uint8_t  uchBatchNum = pstInTensor ->nN; //输入数据的batch数
    const uint16_t usInW = pstInTensor ->nW;
    const uint16_t usInH = pstInTensor ->nH;
    const uint16_t usInC = pstInTensor ->nC;
        
    const uint8_t uchOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint
    const uint8_t uchInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint

    uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
    uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;
    if (NULL == puchInData || NULL == puchOutData)
    {
        return MOCNN_NULL_PTR;
    }

    int32_t nMuliIn = pstInTensor->nMuliSc;
    int32_t nMuliOut = pstOutTensor->nMuliSc;
    uint8_t uchShiftIn = pstInTensor->uchShift;
    uint8_t uchShiftOut = pstOutTensor->uchShift;

    int32_t nTotalNum = (int32_t)uchBatchNum*usInW*usInH*usInC;

    uint8_t *puchIn = (uint8_t*)pstInTensor->pData;
    uint8_t *puchOut = (uint8_t*)pstOutTensor->pData;
    uint8_t uchNegFlag  = 0;
    uint8_t uchAbsValue = 0;
    int32_t nValue = 0;

    nMuliOut = MAX(nMuliOut, 1);    // 防止除数为0

    uint8_t uchShiftIdx = 10;
    uint16_t usCofeIdx = 0x3ff;
    if (MOCNN_TANH == uchOpType)
    {
        uchShiftIdx = 9;
        usCofeIdx = 0x1ff;
    }

    for (int32_t i = 0; i < nTotalNum; i++)
    {
        printf("i : %d\n",i);
        uchNegFlag  = 0;
        uchAbsValue = puchIn[i];
        printf("if puchIn < uchInZP, change Abs = 2*uchInZP - puchIn\n");
        if (uchAbsValue < uchInZP)  //负数
        {
            printf("input is neg\n");
            uchAbsValue = 2 * uchInZP - puchIn[i];
            uchNegFlag = 1;
        }
        //将实际数据扩大512倍，便于求取插值系数
        printf("乘法计算nData\n");
        int64_t nData = (int64_t)(uchAbsValue - uchInZP)*nMuliIn * 24 * 1024;
        printf("根据nData得到nIndex和nCofe\n");
        //lut索引
        int32_t nIndex = (int32_t)(nData >> (uchShiftIn + uchShiftIdx));
        //插值系数
        int32_t nCofe = (int32_t)(nData >> uchShiftIn) & usCofeIdx;
        printf("nIndex : %d\n", nIndex);

        printf("取出table，计算Result，再得到nValue\n");
        int32_t nResult = ((SigmoidTableU16[nIndex + 1] - SigmoidTableU16[nIndex]) * nCofe + (SigmoidTableU16[nIndex] << uchShiftIdx)) >> uchShiftIdx;
        //计算sigmoid值，扩大65536倍
        if (uchNegFlag)
        {
            if (nIndex >= 255)
            {
                nValue = 0;
            }
            else 
            {
                nValue = 65536 - nResult;
            }
        }
        else
        {
            if (nIndex >= 255)
            {
                nValue = 65536;
            }
            else 
            {
                nValue = nResult;
            }
        }
        if (MOCNN_TANH == uchOpType)
        {
            nValue = 2 * nValue - (1<<16);
        }
        //量化输出
        int32_t nQuantValue = (int32_t)((((int64_t)nValue << (uchShiftOut - 16)) + (nMuliOut >> 1) + (int64_t)uchOutZP * nMuliOut) / nMuliOut);
        printf("Quant,包括乘法和除法\n");
        puchOut[i] = MIN(MAX(nQuantValue,0),255);
    }

    return MOCNN_OK;

}

int32_t MOCNN_Tanh(const mocnn_tensor *pstInTensor, const mocnn_tensor *pstOutTensor)
{
    return MOCNN_SigmoidTanh(pstInTensor, pstOutTensor, MOCNN_TANH);
}

int32_t MOCNN_Sigmoid(const mocnn_tensor *pstInTensor, const mocnn_tensor *pstOutTensor)
{
    return MOCNN_SigmoidTanh(pstInTensor, pstOutTensor, MOCNN_SIGMOID);
}

int32_t MOCNN_Relu(const mocnn_tensor *pstInTensor, const mocnn_tensor *pstOutTensor)
{
    printf("Entering Relu\n");

    if(NULL == pstInTensor || NULL == pstOutTensor)
    {
        return MOCNN_NULL_PTR;
    }

    const uint8_t  uchBatchNum = pstInTensor ->nN; //输入数据的batch数
    const uint16_t usInW = pstInTensor ->nW;
    const uint16_t usInH = pstInTensor ->nH;
    const uint16_t usInC = pstInTensor ->nC;
        
    const uint8_t uchInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint

    uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
    uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;
    if (NULL == puchInData || NULL == puchOutData)
    {
        return MOCNN_NULL_PTR;
    }

    int32_t nTotalSize = (int32_t)uchBatchNum*usInW*usInH*usInC;

    for (int32_t i = 0; i < nTotalSize; i++)
    {
        if (puchInData[i] < uchInZP)
        {
            puchOutData[i] = uchInZP;
        }
        else
        {
            puchOutData[i] = puchInData[i];
        }
    }

    return MOCNN_OK;

}


int32_t MOCNN_Softmax(const mocnn_tensor *pstInTensor, const mocnn_tensor *pstOutTensor, 
    const mocnn_activation_param * pstSoftmaxParam)
    {
        printf("Entering Softmax\n");
    
        if(NULL == pstInTensor || NULL == pstOutTensor || NULL == pstSoftmaxParam)
        {
            return MOCNN_NULL_PTR;
        }
    
        const uint8_t  uchBatchNum = pstInTensor ->nN; //输入数据的batch数
        const uint16_t usInW = pstInTensor ->nW;
        const uint16_t usInH = pstInTensor ->nH;
        const uint16_t usInC = pstInTensor ->nC;

        const int32_t nInMult = pstInTensor->nMuliSc;
        const uint8_t nInShift = pstInTensor->uchShift;
            
        const int64_t llMulBzp = pstSoftmaxParam->llMulBzp;
        const int64_t llMultSc = pstSoftmaxParam->llMultSc;
        const int64_t uchShiftN = pstSoftmaxParam->uchShift;

        uint8_t uchDim = pstSoftmaxParam->uchDim;

        uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
        uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;

        if (NULL == puchInData || NULL == puchOutData)
        {
            return MOCNN_NULL_PTR;
        }
        if (uchDim > 3)
        {
            return MOCNN_INVALID_PARAM;
        }
        const int32_t nMask = (1 << (57 - nInShift));
    
        for(uint32_t nIb = 0; nIb < uchBatchNum; nIb++)
        {
            printf("nIb : %d\n",nIb);
            if(1 == uchDim) // C维度
            {
                for (int32_t nOuty = 0; nOuty < usInH; nOuty++)
                {
                    //printf("nOuty : %d\n",nOuty);
                    for (int32_t nOutx = 0; nOutx < usInW; nOutx++)
                    {
                        printf("nOuty : %d, nOutx : %d\n",nOuty, nOutx);
                        int32_t nSum = 0;
                        int32_t nMax = 0;
                        int32_t nDiff = 0;
                        uint8_t *puchDataPt = puchInData + (nOuty*usInW + nOutx)*usInC;
                        uint8_t *puchOutPt = puchOutData + (nOuty*usInW + nOutx)*usInC;
                        //printf("puchDataPt = puchInData + %d\n",(nOuty*usInW + nOutx)*usInC);
                        for (int32_t i = 0; i < usInC; i++)
                        {
                            //printf("puchDataPt[%d] = %d\n", i, puchDataPt[i]);
                            if(puchDataPt[i] >= nMax)
                            {
                                nMax = puchDataPt[i];
                            }
                        }
                        printf("nMax = %d\n",nMax);
                        for (int32_t i = 0; i < usInC; i++)
                        {
                            nDiff = puchDataPt[i] - nMax;
                            nSum += DIV_POW2(EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)), ACCUM_BITS);
                            if(nIb==0 && nOuty==0 && nOutx==4){
                            //printf("Diff: %d\n", nDiff);
                            //printf("exp_in: %d\nexp_out:%d\n", MUL_SAT(nDiff * nMask, nInMult), EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)));
                            //printf("delta: %d\n", DIV_POW2(EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)), ACCUM_BITS));
                            //printf("nSum: %d\n\n", nSum);
                            }
                        }
                        printf("nSum = %d\n",nSum);
                        const int32_t nHeadroom = MOCNN_CLZ((uint32_t)nSum);
                        printf("nHeadroom = %d\n",nHeadroom);
                        const int32_t nBitsOverUnit = ACCUM_BITS - nHeadroom + 23;
                        const int32_t nShiftedScale = ONE_OVER1((nSum << nHeadroom) - (1 << 31));
                        printf("nBitsOverUnit = %d\n",nBitsOverUnit);
                        printf("nShiftedScale = %d\n",nShiftedScale);

                        for (int32_t i = 0; i < usInC; i++)
                        {
                            nDiff = puchDataPt[i] - nMax;
                            if(nIb == 0 && nOuty == 0 && nOutx == 0){
                                printf("EXP_ON_NEG = %d\n", EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)));
                            }
                            int32_t nData = DIV_POW2(MUL_SAT(nShiftedScale, EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult))), nBitsOverUnit);

                            nData = (int32_t) (((int64_t)nData*llMultSc + llMulBzp) >> uchShiftN);
                            puchOutPt[i] = MIN(MAX(nData, 0), 255);
                            //printf("puchOutPt = %d\n",puchOutPt[i]);
                            //printf("puchOutPt[%d] = %d\n",i,puchOutPt[i]);
                        }
                        printf("\n");
                    }
                }
            }
            else if(2 == uchDim)    // H
            {
                for (int32_t w = 0; w < usInW; w++)
                {
                    //printf("w : %d\n",w);
                    for (int c = 0; c < usInC; c++)
                    {
                        //printf("c : %d, nSum = 0\n",c);
                        int32_t nSum = 0;
                        int32_t nMax = 0;
                        int32_t nDiff = 0;
                        for (int32_t h = 0; h < usInH; h++)
                        {
                            if(puchInData[(h*usInW + w)*usInC + c] > nMax)
                            {
                                nMax = puchInData[(h*usInW + w)*usInC + c];
                            }
                        }
                        for (int32_t h = 0; h < usInH; h++)
                        {
                            nDiff = puchInData[(h*usInW + w)*usInC + c] - nMax;
                            nSum += DIV_POW2(EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)), ACCUM_BITS);
                            //if(nIb==0 && w==0 && c==0){
                                printf("nMax: %d\n", nMax);
                                //printf("Diff: %d\n", nDiff);
                                //printf("exp_in: %d\nexp_out:%d\n", MUL_SAT(nDiff * nMask, nInMult), EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)));
                               // printf("delta: %d\n", DIV_POW2(EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)), ACCUM_BITS));
                                printf("nSum: %d\n\n", nSum);
                            //    }
                        }
                        const int32_t nHeadroom = MOCNN_CLZ((uint32_t)nSum);
                        const int32_t nBitsOverUnit = ACCUM_BITS - nHeadroom + 23;
                        const int32_t nShiftedScale = ONE_OVER1((nSum << nHeadroom) - (1 << 31));
                        //if(nIb==0 && w==0 && c==0){
                        //    printf("nHeadroom: %d\n", nHeadroom);
                        //    printf("nBitsOverUnit: %d\n", nBitsOverUnit);
                        //    printf("nShiftedScale: %d\n", nShiftedScale);
                        //}
                        for (int32_t h = 0; h < usInH; h++)
                        {
                            nDiff = puchInData[(h*usInW + w)*usInC + c] - nMax;
                            int32_t nData = DIV_POW2(MUL_SAT(nShiftedScale, EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult))), nBitsOverUnit);

                            nData = (int32_t) (((int64_t)nData*llMultSc + llMulBzp) >> uchShiftN);
                            if(nIb==0 && w==0 && c==0){
                                printf("nData: %d\n", nData);
                            }
                            puchOutData[(h*usInW + w)*usInC + c] = MIN(MAX(nData, 0), 255);
                        }
                    }
                }
            }
            else if(3 == uchDim)    // W
            {
                for (int32_t h = 0; h < usInH; h++)
                {
                    //printf("h : %d\n",h);
                    for (int c = 0; c < usInC; c++)
                    {
                        //printf("c : %d, nSum = 0\n",c);
                        int32_t nSum = 0;
                        int32_t nMax = 0;
                        int32_t nDiff = 0;
                        for (int32_t w = 0; w < usInW; w++)
                        {
                            if(nIb ==0 && c==8 && h==0){
                                printf(" puchInData[%d] : %d\n",(h*usInW + w)*usInC + c ,puchInData[(h*usInW + w)*usInC + c]);
                            }
                            if(puchInData[(h*usInW + w)*usInC + c] > nMax)
                            {
                                nMax = puchInData[(h*usInW + w)*usInC + c];
                            }
                        }
                        for (int32_t w = 0; w < usInW; w++)
                        {
                            nDiff = puchInData[(h*usInW + w)*usInC + c] - nMax;
                            nSum += DIV_POW2(EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)), ACCUM_BITS);

                            if(nIb==0 && h==0 && c==0){
                                //printf("Diff: %d\n", nDiff);
                                //printf("exp_in: %d\nexp_out:%d\n", MUL_SAT(nDiff * nMask, nInMult), EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)));
                                printf("delta: %d\n", DIV_POW2(EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult)), ACCUM_BITS));
                                printf("nSum: %d\n\n", nSum);
                                }
                        }
                        if(nIb == 0){
                            printf("nMax: %d\n", nMax);
                            printf("nSum: %d\n", nSum);
                            }
                        const int32_t nHeadroom = MOCNN_CLZ((uint32_t)nSum);
                        const int32_t nBitsOverUnit = ACCUM_BITS - nHeadroom + 15;
                        const int32_t nShiftedScale = ONE_OVER1((nSum << nHeadroom) - (1 << 31));
                        for (int32_t w = 0; w < usInW; w++)
                        {
                            nDiff = puchInData[(h*usInW + w)*usInC + c] - nMax;
                            int32_t nData = DIV_POW2(MUL_SAT(nShiftedScale, EXP_ON_NEG(MUL_SAT(nDiff * nMask, nInMult))), nBitsOverUnit);
                            nData = (int32_t) (((int64_t)nData*llMultSc + llMulBzp) >> uchShiftN);
                            puchOutData[(h*usInW + w)*usInC + c] = MIN(MAX(nData, 0), 255);
                        }
                    }
                }
            }

            puchInData += (int32_t)usInW * usInH * usInC;
            puchOutData += (int32_t)usInW * usInH * usInC;
        }
        return MOCNN_OK;
    }
    
// **转换数值为二进制字符串**
void int_to_binary(uint8_t num, char *binary_str) {
    for (int i = 7; i >= 0; i--) {
        binary_str[7 - i] = (num & (1 << i)) ? '1' : '0';
    }
    binary_str[8] = '\0';
}


#define in_N 3
#define in_H 5
#define in_W 5
#define in_C 14
#define Dim 3


//uint8_t  pData_in[1][10][2][2];
//uint8_t pData_out[1][24][2][2];
uint8_t pData_out[in_N*in_C*in_H*in_W];
uint8_t  pData_in[in_N*in_C*in_H*in_W];
/*
uint8_t pData_in[in_N][in_C][in_H][in_W] = {
    {
        { {1, 2}, {3, 4} },
        { {5, 6}, {7, 8} },
        { {9, 10}, {11, 12} },
        { {13, 14}, {15, 16} },
        { {17, 18}, {19, 20} },
        { {21, 22}, {23, 24} },
        { {25, 26}, {27, 28} },
        { {29, 30}, {31, 32} },
        { {33, 34}, {35, 36} },
        { {37, 38}, {39, 40} },
        { {41, 42}, {43, 44} },
        { {45, 46}, {47, 48} },
        { {49, 50}, {51, 52} },
        { {53, 54}, {55, 56} },
        { {57, 58}, {59, 60} },
        { {61, 62}, {63, 64} },
        { {65, 66}, {67, 68} },
        { {69, 70}, {71, 72} },
        { {73, 74}, {75, 76} },
        { {77, 78}, {79, 80} },
        { {81, 82}, {83, 84} },
        { {85, 86}, {87, 88} },
        { {89, 90}, {91, 92} },
        { {93, 94}, {95, 96} }
    }
};
*/

const mocnn_tensor my_in_tensor = {
    .nN     = in_N     ,
    .nC     = in_C     ,
    .nH     = in_H     ,
    .nW     = in_W     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .nMuliSc = 100000000   ,
    .uchShift = 30  ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     =in_N     ,
    .nC     =in_C     ,
    .nH     =in_H     ,
    .nW     =in_W     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .nMuliSc = 100000000   ,
    .uchShift = 30  ,
    .pData  = pData_out
};

const mocnn_activation_param my_activation_param = {
    .uchDim     =  Dim    ,
    .llMulBzp   =  0    ,
    .llMultSc   =  1    ,
    .uchShift   =  1    
};

void run_nn_activation(){
    const mocnn_tensor *in_tensor = &my_in_tensor;
    const mocnn_tensor *out_tensor = &my_out_tensor;
    const mocnn_activation_param *param_tensor = &my_activation_param;

    // 初始化随机数种子
    srand(1);
    uint8_t source_data[in_N*in_H*in_W*in_C];

    // 生成随机数据存储到 source_data
    for (int i = 0; i < in_N*in_C*in_H*in_W; i++) {
        source_data[i] = (uint8_t)(rand() % 256);
    }

    // 将 source_data 复制到 pData_in
    int index = 0;
    for (int i = 0; i < in_N; i++) {
        for (int j = 0; j < in_H; j++) {
            for (int k = 0; k < in_W; k++) {
                for (int l = 0; l < in_C; l++) {
                    pData_in[index] = source_data[index];
                    //printf("source_data = %d\n",source_data[index]);
                    index++;
                }
            }
        }
    }
    //MOCNN_Tanh(in_tensor, out_tensor);
    MOCNN_Softmax(in_tensor, out_tensor, param_tensor);
    //printf("MUL_SAT: %d\n", MUL_SAT(MOCNN_Q31_MAX,MOCNN_Q31_MAX));
    //printf("MUL_SAT: %d\n", MUL_SAT(MOCNN_Q31_MIN,MOCNN_Q31_MIN));
    //printf("MUL_SAT: %d\n", MUL_SAT(MOCNN_Q31_MAX,MOCNN_Q31_MIN));
    //printf("MUL_SAT: %d\n", MUL_SAT(-4063231,715827883));

    //printf("CLZ : %d\n", MOCNN_CLZ(3));
    //printf("CLZ : %d\n", MOCNN_CLZ(15));
    //printf("CLZ : %d\n", MOCNN_CLZ(0));
    //printf("EXP_ON_NEG : %d\n\n\n", EXP_ON_NEG(-1));
    //printf("EXP_ON_NEG : %d\n\n\n", EXP_ON_NEG(-100));
    //printf("EXP_ON_NEG : %d\n\n\n", EXP_ON_NEG(-20252026));
    //printf("ONE : %d\n",MOCNN_OneOverOnePlusXForXIn01(1));
    //printf("ONE : %d\n",MOCNN_OneOverOnePlusXForXIn01(10));
    //printf("ONE : %d\n",MOCNN_OneOverOnePlusXForXIn01(-22));

    FILE *file_input_dec   = fopen("softmax/softmax_input_decimal.txt", "w");
    FILE *file_input_bin   = fopen("softmax/softmax_input_binary.txt", "w");
    FILE *file_output_dec  = fopen("softmax/softmax_output_decimal.txt", "w");
    FILE *file_output_bin  = fopen("softmax/softmax_output_binary.txt", "w");

    if (!file_input_dec || !file_input_bin || !file_output_dec || !file_output_bin) {
        printf("Error opening file for writing.\n");
        return;
    }
    char binary_str[9];

    int32_t ce_num;
    uint8_t data_in[8];
    ce_num = in_C/8 + ((in_C % 8) != 0);
    index = 0;
    for (int n = 0; n < in_N; n++) {
        for(int h = 0; h < in_H; h++ ){
            for(int w = 0; w < in_W; w++ ){
                for(int ce = 0; ce < ce_num; ce++){
                    for(int e = 0; e < 8; e++){
                        if(ce*8+e > in_C-1){
                            data_in[e] = 0;
                        }
                        else {
                            data_in[e] = pData_in[index];
                            index ++;
                        }
                    }
                    for(int e = 0; e < 8; e++){
                        fprintf(file_input_dec, "%d\t", data_in[7-e]); 
                        int_to_binary(data_in[7-e], binary_str);
                        fprintf(file_input_bin, "%s", binary_str);
                    }
                    fprintf(file_input_dec, "\n");
                    fprintf(file_input_bin, "\n");
                }
            }
        }
    }

    index = 0;
    uint8_t data_out[8];
    for (int n = 0; n < in_N; n++) {
        for(int h = 0; h < in_H; h++ ){
            for(int w = 0; w < in_W; w++ ){
                for(int ce = 0; ce < ce_num; ce++){
                    for(int e = 0; e < 8; e++){
                        if(ce*8+e > in_C-1){
                            data_out[e] = 0;
                        }
                        else {
                            data_out[e] = pData_out[index];
                            index ++;
                        }
                    }
                    for(int e = 0; e < 8; e++){
                        fprintf(file_output_dec, "%3d\t", data_out[7-e]); 
                        int_to_binary(data_out[7-e], binary_str);
                        fprintf(file_output_bin, "%s", binary_str);
                    }
                    fprintf(file_output_dec, "\n");
                    fprintf(file_output_bin, "\n");
                }
            }
        }
    }




    fclose(file_input_dec);
    fclose(file_input_bin);
    fclose(file_output_dec);
    fclose(file_output_bin);

}

int main()
{
    run_nn_activation();
    return 0;
}