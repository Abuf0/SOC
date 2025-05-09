#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "moc_nn.h"

/***************************************
Prototype   : MOCNN_Conv
Description : 输入uint8，权重int8的量化卷积的通用实现
Input       : pstInTensor 输入tensor
              pstKerTensor kernel tensor
              pstConvParam 卷积参数
Output      : pstOuTensor 输出tensor
Return      : 错误码
 */
int32_t MOCNN_Conv(const mocnn_tensor * pstInTensor, const mocnn_tensor * pstOutTensor,
    const mocnn_tensor * pstKerTensor, const mocnn_conv_param * pstConvParam)
{
    if(NULL == pstInTensor || NULL == pstOutTensor || NULL == pstKerTensor || NULL == pstConvParam)
    {
        return MOCNN_NULL_PTR;
    }

    const int32_t uchBatchNum = pstInTensor ->nN; //输入数据的batch数
    const int32_t usInW = pstInTensor ->nW;
    const int32_t usInH = pstInTensor ->nH;
    const int32_t usInC = pstInTensor ->nC;
    const int32_t uchKernelW = pstConvParam ->uchKernelW;
    const int32_t uchKernelH = pstConvParam ->uchKernelH;
    const int32_t usKernelC = pstKerTensor ->nC;
    const int32_t usOutW = pstOutTensor ->nW;
    const int32_t usOutH = pstOutTensor ->nH;
    const int32_t usOutC = pstOutTensor ->nC;


    const int32_t uchPadX = pstConvParam ->uchPadX;
    const int32_t uchPadY = pstConvParam ->uchPadY;
    const int32_t uchStrideW = pstConvParam ->uchStrideW;
    const int32_t uchStrideH = pstConvParam ->uchStrideH;
    const int32_t uchDilationW = pstConvParam ->uchDilationW;
    const int32_t uchDilationH = pstConvParam ->uchDilationH;
    const int32_t uchOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint
    const int32_t uchInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint

    //卷积分组数
    const int32_t usGroups = usInC / MAX(usKernelC, 1);

    //每次需要计算的卷积数据个数
    const int32_t usKernelNum = uchKernelW * uchKernelH * usKernelC;

    //每个分组下卷积输出通道数
    const int32_t usOutputChPerGroup = usOutC / MAX(usGroups, 1);

    //分组卷积输出结果的偏移量
    const int32_t nGrpOft = usOutC - usOutputChPerGroup;

    //量化输出的截断值
    int32_t uchActMin = 0;    //conv_params->activation.min
    int32_t uchActMax = 255;  //conv_params->activation.max
    //量化系数顶点数据
    int64_t *plnOutMultBzp = pstConvParam ->plnMulBzp;
    int64_t *plnOutMult = pstConvParam ->plnMultSc;
    int32_t *puchOutShift = pstConvParam ->puchShift;
    if (NULL == plnOutMultBzp || NULL == plnOutMult || NULL == puchOutShift)
    {
        return MOCNN_NULL_PTR;
    }
    if (usInC % usGroups != 0 || usOutC % usGroups != 0)
    {
        return MOCNN_INVALID_PARAM;
    }

    //跟着激活时，设置最小截断为输出ZeroPoint
    if (pstConvParam-> uchActValue == 1)
    {
        uchActMin = uchOutZP;
    }

    uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
    uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;
    int8_t *pchKerData = (int8_t *)pstKerTensor-> pData;

    if (NULL == puchInData || NULL == puchOutData || NULL == pchKerData)
    {
        return MOCNN_NULL_PTR;
    }
    //此处申请内存存放Im2Col的数据
    uint8_t *puchBuf = (uint8_t *)malloc(usKernelNum*sizeof(uint8_t));
    if (NULL == puchBuf)
    {
        return MOCNN_OUT_OF_MEM;
    }

    for(int nIb = 0; nIb < uchBatchNum; nIb++)
    {
        const int8_t *pchFilterPt = pchKerData;
        const int64_t *plnMulBzpPt = plnOutMultBzp;
        const int64_t *plnMultPt = plnOutMult;
        const int32_t *puchShiftPt = puchOutShift;

        //This part implements the im2col function
        for (int32_t nGidx = 0; nGidx < usGroups; nGidx++)
        {
            uint8_t *puchOut = puchOutData + nGidx * usOutputChPerGroup;
            for (int nOuty = 0; nOuty < usOutH; nOuty++)
            {
                for (int nOutx = 0; nOutx < usOutW; nOutx++)
                {
                    const int32_t nBaseX = uchStrideW * nOutx - uchPadX;
                    const int32_t nBaseY = uchStrideH * nOuty - uchPadY;
                    uint8_t *puchIm2ColPt = (uint8_t *)puchBuf;
                    for (int32_t nKy = 0; nKy < uchKernelH; nKy++)
                    {
                        for (int32_t nKx = 0; nKx < uchKernelW; nKx++)
                        {
                            const int32_t nPosY = nBaseY + uchDilationH * nKy;
                            const int32_t nPosX = nBaseX + uchDilationW * nKx;

                            //此处使用Input ZeroPoint进行padding
                            if (nPosY < 0 || nPosY >= usInH || nPosX < 0 || nPosX >= usInW)
                            {
                                memset(puchIm2ColPt, (uint8_t)uchInZP, sizeof(uint8_t)* usKernelC);
                            }
                            else //将数据进行复制进行im2col
                            {
                                memcpy(puchIm2ColPt, puchInData + (nPosY * usInW + nPosX) * usInC + nGidx * usKernelC, sizeof(uint8_t)* usKernelC);
                            }
                            puchIm2ColPt += usKernelC;
                        }
                    }
                    //将输入数据乘卷积核得到累加和
                    const int8_t *pchKer = pchFilterPt;
                    for (int32_t i = 0; i < usOutputChPerGroup; i++)
                    {
                        int32_t nSum = 0;
                        const uint8_t *puchInPt = puchBuf;
                        uint16_t nCalCount = usKernelNum;
                        while(nCalCount)
                        {
                            int8_t chKerValue = *pchKer++;
                            int32_t nInValue = *puchInPt++ - uchInZP;

                            nSum += chKerValue * nInValue;
                            nCalCount--;
                        }
                        //将卷积累加和进行量化后输出
                        int32_t nData = (int32_t)((plnMultPt[i] * nSum + plnMulBzpPt[i]) >> puchShiftPt[i]);
                        nData = MAX(nData, uchActMin);
                        nData = MIN(nData, uchActMax);
                        *puchOut++ = (uint8_t)nData;
                    }
                    puchOut += nGrpOft;
                }
            }
            //指向下一组输出通道
            pchFilterPt += usOutputChPerGroup * usKernelNum;
            plnMulBzpPt += usOutputChPerGroup;
            plnMultPt += usOutputChPerGroup;
            puchShiftPt += usOutputChPerGroup;
        }
        //指向下一batch
        puchInData += (usInW * usInH * usInC);
        puchOutData += (usOutW * usOutH * usOutC);
    }
    free(puchBuf);
    return MOCNN_OK;
}
