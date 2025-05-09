#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "moc_nn.h"


int32_t MOCNN_Math(const mocnn_tensor *pstInTensor0, const mocnn_tensor *pstInTensor1,
     const mocnn_tensor *pstOutTensor, const mocnn_elementwise_param * pstElewiseParam)
    {
        printf("Entering elementwise\n");
    
        if(NULL == pstInTensor0 || NULL == pstInTensor1 || NULL == pstOutTensor)
        {
            return MOCNN_NULL_PTR;
        }
        uint8_t *puchIn0 = (uint8_t *)pstInTensor0-> pData;
        uint8_t *puchIn1 = (uint8_t *)pstInTensor1-> pData;
        uint8_t *puchOut = (uint8_t *)pstOutTensor-> pData;
        if (NULL == puchIn0 || NULL == puchIn1 || NULL == puchOut)
        {
            return MOCNN_NULL_PTR;
        }

        uint8_t uchZp0 = pstInTensor0->uchZP;
        uint8_t uchZp1 = pstInTensor1->uchZP;
        uint8_t uchOutZp = pstOutTensor->uchZP;

        int32_t nMulsc0 = pstInTensor0->nMuliSc;
        int32_t nMulsc1 = pstInTensor1->nMuliSc;
        int32_t nMulsc = pstOutTensor->nMuliSc;
        uint8_t uchOpType = pstElewiseParam->uchOpType;
        int64_t nBzp = 0;
        //寻找最大移位系数
        uint8_t uchShiftN = MAX(pstInTensor0->uchShift, pstInTensor1->uchShift);
        uchShiftN = MAX(uchShiftN, pstOutTensor->uchShift);

        if (MOCNN_OP_MUL == uchOpType)
        {
            nMulsc0 = (nMulsc0 >> 8);
            nMulsc1 = (nMulsc1 >> 8);
            nMulsc  = (nMulsc  >> 8);
            uchShiftN = pstInTensor0->uchShift + pstInTensor1->uchShift - pstOutTensor->uchShift - 8;
            nBzp = (uchOutZP * nMulsc + nMulsc / 2)*(1 << (uchShiftN));
        }
        else
        {
            nMulsc0 *= (1 << (uchShiftN - pstInTensor0->uchShift));
            nMulsc1 *= (1 << (uchShiftN - pstInTensor1->uchShift));
            nMulsc  *= (1 << (uchShiftN - pstOutTensor->uchShift));
            nBzp = (uchOutZP * nMulsc + nMulsc / 2);
        }
        
        uint8_t uchActMin = 0;    //conv_params->activation.min
        uint8_t uchActMax = 255;  //conv_params->activation.max
        if (pstElewiseParam->uchActValue == 1)
        {
            uchActMin = uchOutZP;
        }
        int32_t nTotalSize = pstOutTensor->uchN*pstOutTensor->uchC*pstOutTensor->uchH*pstOutTensor->uchW;

        int32_t nStrideArrA[4] = { 0 };
        int32_t nStrideArrB[4] = { 0 };
        int32_t nIndicesC[4] = { 0 };
        uint16_t usDimA[4] = { 0 };
        uint16_t usDimB[4] = { 0 };
        uint16_t usDimC[4] = { 0 };

        nStrideArrA[3] = 1;
        nStrideArrA[2] = pstInTensor0->usC;
        nStrideArrA[1] = pstInTensor0->usW * pstInTensor0->usC;
        nStrideArrA[0] = pstInTensor0->usW * pstInTensor0->usH * pstInTensor0->usC;

        nStrideArrB[3] = 1;
        nStrideArrB[2] = pstInTensor1->usC;
        nStrideArrB[1] = pstInTensor1->usW * pstInTensor1->usC;
        nStrideArrB[0] = pstInTensor1->usW * pstInTensor1->usH * pstInTensor1->usC;
    
        usDimA[0] = pstInTensor0->uchN;
        usDimA[1] = pstInTensor0->usH;
        usDimA[2] = pstInTensor0->usW;
        usDimA[3] = pstInTensor0->usC;

        usDimB[0] = pstInTensor1->uchN;
        usDimB[1] = pstInTensor1->usH;
        usDimB[2] = pstInTensor1->usW;
        usDimB[3] = pstInTensor1->usC;

        usDimC[0] = pstOutTensor->uchN;
        usDimC[1] = pstOutTensor->usH;
        usDimC[2] = pstOutTensor->usW;
        usDimC[3] = pstOutTensor->usC;

        for (int32_t i = 0; i < nTotalSize; ++i)
        {
            //将扁平索引i转换为多维索引（NCHW顺序下标）
            int32_t nTemp = i;
            for (int8_t d = 3; d >= 0; d--)
            {
                nIndicesC[d] = nTemp % usDimC[d];
                nTemp /= usDimC[d];
            }

            //使用广播规则计算A和B的偏移（Stride-Based Offset Calculation）
            int32_t nOffsetA = 0;
            int32_t nOffsetB = 0;
            for (int8_t d = 0; d < 4; d++)
            {
                int32_t nDimIndexA = nIndicesC[d];
                int32_t nDimIndexB = nIndicesC[d];
                nDimIndexA = (usDimA[d] == 1)?  0 : nDimIndexA;
                nOffsetA += nDimIndexA * nStrideArrA[d];
                nDimIndexB = (usDimB[d] == 1)?  0 : nDimIndexB;
                nOffsetB += nDimIndexB * nStrideArrB[d];
            }

            //通过广播计算最终结果
            int32_t nData = 0;
            switch (uchOpType)
            {
                case MOCNN_OP_ADD :
                    nData = ((int64_t)(puchIn0[nOffsetA] - (int16_t)uchZP0)*nMulsc0 + \
                        (int64_t)(puchIn1[nOffsetB] - (int16_t)uchZP1)*nMulsc1 + nBzp) / nMulsc;
                    break;
                    case MOCNN_OP_SUB :
                    nData = ((int64_t)(puchIn0[nOffsetA] - (int16_t)uchZP0)*nMulsc0 - \
                        (int64_t)(puchIn1[nOffsetB] - (int16_t)uchZP1)*nMulsc1 + nBzp) / nMulsc;
                    break;
                    case MOCNN_OP_MUL :
                    nData = ((int64_t)(puchIn0[nOffsetA] - (int16_t)uchZP0)*nMulsc0 * \
                        (int64_t)(puchIn1[nOffsetB] - (int16_t)uchZP1)*nMulsc1 + nBzp) >> (uchShiftN) / nMulsc;
                    break;
            }
            puchOut[i] = MIN(MAX(nData, uchActMin), uchActMax);
        }
        return MOCNN_OK;
    }

    int32_t MOCNN_Elementwise(const mocnn_tensor *pstInTensor0, const mocnn_tensor *pstInTensor1,
        const mocnn_tensor *pstOutTensor, const mocnn_elementwise_param * pstElewiseParam)
       {
           printf("Entering elementwise\n");
       
           if(NULL == pstInTensor0 || NULL == pstInTensor1 || NULL == pstOutTensor || pstElewiseParam)
           {
               return MOCNN_NULL_PTR;
           }

           return MOCNN_Math(pstInTensor0, pstInTensor1, pstOutTensor, pstElewiseParam);
        }