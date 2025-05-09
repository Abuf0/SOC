#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "moc_nn.h"

/***************************************
Prototype   : MOCNN_DWConv
Description : 输入uint8，权重int8的量化卷积的通用实现
Input       : pstInTensor 输入tensor
              pstKerTensor kernel tensor
              pstConvParam 卷积参数
Output      : pstOuTensor 输出tensor
Return      : 错误码
 */
int32_t MOCNN_DWConv(const mocnn_tensor * pstInTensor, const mocnn_tensor * pstOuTensor,
    const mocnn_tensor * pstKerTensor, const mocnn_conv_param * pstConvParam)
{
    if(NULL == pstInTensor || NULL == pstOutTensor || NULL == pstKerTensor || NULL == pstConvParam)
    {
        return MOCNN_NULL_PTR;
    }

    const int32_t nBatchNum = pstInTensor ->nN; //输入数据的batch数
    const int32_t nInW = pstInTensor ->nW;
    const int32_t nInH = pstInTensor ->nH;
    const int32_t nInC = pstInTensor ->nC;
    const int32_t nKernelW = pstConvParam ->uchKernelW;
    const int32_t nKernelH = pstConvParam ->uchKernelH;
    const int32_t nKernelC = pstKerTensor ->nC;
    const int32_t nOutW = pstOutTensor ->nW;
    const int32_t nOutH = pstOutTensor ->nH;
    const int32_t nOutC = pstOutTensor ->nC;

    const int32_t nPadX = pstConvParam ->uchPadX;
    const int32_t nPadY = pstConvParam ->uchPadY;
    const int32_t nStrideW = pstConvParam ->uchStrideW;
    const int32_t nStrideH = pstConvParam ->uchStrideH;
    const int32_t nDilationW = pstConvParam ->uchDilationW;
    const int32_t nDilationH = pstConvParam ->uchDilationH;
    const int32_t nOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint
    const int32_t nInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint


    //量化输出的截断值
    int32_t nActMin = 0;    //conv_params->activation.min
    int32_t nActMax = 255;  //conv_params->activation.max

    

    //量化系数顶点数据
    int64_t *plnOutMultBzp = pstConvParam ->plnMulBzp;
    int64_t *plnOutMult = pstConvParam ->plnMultSc;
    int32_t *pnOutShift = pstConvParam ->pnShift;
    if (NULL == plnOutMultBzp || NULL == plnOutMult || NULL == pnOutShift)
    {
        return MOCNN_NULL_PTR;
    }
    if (nInC % nGroups != 0 || nOutC % nGroups != 0)
    {
        return MOCNN_INVALID_PARAM;
    }

    //跟着激活时，设置最小截断为输出ZeroPoint
    if (pstConvPram-> nActValue == 1)
    {
        nActMin = nOutZP;
    }

    uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
    uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;
    int8_t *pchKerData = (int8_t *)pstKerTensor-> pData;

    if (NULL == puchInData || NULL == puchOutData || NULL == pchKerData)
    {
        return MOCNN_NULL_PTR;
    }
    //此处申请内存存放Im2Col的数据
    uint8_t *puchBuf = (uint8_t *)malloc(nKernelNum*sizeof(uint8_t));
    if (NULL == puchBuf)
    {
        return MOCNN_OUT_OF_MEM;
    }

    for(int nIb = 0; nIb < nBatchNum; nIb++)
    {
        const int8_t *pchFilterPt = pchKerData;
        const int64_t *plnMulBzpPt = plnOutMultBzp;
        const int64_t *plnMultPt = plnOutMult;
        const int32_t *pnShiftPt = pnOutShift;

        //This part implements the im2col function
        for (int32_t nGidx = 0; nGidx < nGroups; nGidx++)
        {
            uint8_t *puchOut = puchOutData + nGidx * nOutputChPerGroup;
            for (int nOuty = 0; nOuty < nOutH; nOuty++)
            {
                for (int nOutx = 0; nOutx < nOutW; nOutx++)
                {
                    const int32_t nBaseX = nStrideW * nOutx - nPadX;
                    const int32_t nBaseY = nStrideH * nOuty - nPadY;
                    uint8_t *puchIm2ColPt = (uint8_t *)puchBuf;
                    for (int32_t nKy = 0; nKy < nKernelH; nKy++)
                    {
                        for (int32_t nKx = 0; nKx < nKernelW; nKx++)
                        {
                            const int32_t nPosY = nBaseY + nDilationH * nKy;
                            const int32_t nPosX = nBaseX + nDilationW * nKx;

                            //此处使用Input ZeroPoint进行padding
                            if (nPosY < 0 || nPosY >= nInH || nPosX < 0 || nPosX >= nInW)
                            {
                                memset(puchIm2ColPt, (uint8_t)nInZP, sizeof(uint8_t)* nKernelC);
                            }
                            else //将数据进行复制进行im2col
                            {
                                memcpy(puchIm2ColPt, puchInData + (nPosY * nInW + nPosX) * nInC + nGidx * nKernelC, sizeof(uint8_t)* nKernelC);
                            }
                            puchIm2ColPt += nKernelC;
                        }
                    }
                    //将输入数据乘卷积核得到累加和
                    const int8_t *pchKer = pchFilterPt;
                    for (int32_t i = 0; i < nOutputChPerGroup; i++)
                    {
                        int32_t nSum = 0;
                        const uint8_t *puchInPt = puchBuf;
                        uint16_t nCalCount = nKernelNum;
                        while(nCalCount)
                        {
                            int8_t chKerValue = *pchKer++;
                            int32_t nInValue = *puchInPt++ - nInZP;

                            nSum += chKerValue * nInValue;
                            nCalCount--;
                        }
                        //将卷积累加和进行量化后输出
                        int32_t nData = (int32_t)((plnMultPt[i] * nSum + plnMulBzpPt[i]) >> pnShift[i]);
                        nData = MAX(nData, nActMin);
                        nData = MIN(nData, nActMax);
                        *puchOut++ = (uint8_t)nData;
                    }
                    puchOut += nGrpOft;
                }
            }
            //指向下一组输出通道
            pchFilterPt += nOutputChPerGroup * nKernelNum;
            plnMulBzpPt += nOutputChPerGroup;
            plnMultPt += nOutputChPerGroup;
            pnShiftPt += nOutputChPerGroup;
        }
        //指向下一batch
        puchInData += (nInW * nInH * nInC);
        puchOutData += (nOutW * nOutH * nOutC);
    }
    free(puchBuf);
    return MOCNN_OK;
}
