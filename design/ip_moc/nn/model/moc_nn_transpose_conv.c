#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
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


int32_t MOCNN_TransposeConv(const mocnn_tensor * pstInTensor, const mocnn_tensor * pstOutTensor,
    const mocnn_tensor * pstKerTensor, const mocnn_conv_param * pstConvParam)
{
    if(NULL == pstInTensor || NULL == pstOutTensor || NULL == pstKerTensor || NULL == pstConvParam)
    {
        return MOCNN_NULL_PTR;
    }

    const uint8_t  uchBatchNum = pstInTensor ->nN; //输入数据的batch数
    const uint16_t usInW = pstInTensor ->nW;
    const uint16_t usInH = pstInTensor ->nH;
    const uint16_t usInC = pstInTensor ->nC;
    const uint8_t  uchKernelW = pstConvParam ->uchKernelW;
    const uint8_t  uchKernelH = pstConvParam ->uchKernelH;
    const uint16_t usKernelC = pstKerTensor ->nC;
    const uint16_t usOutW = pstOutTensor ->nW;
    const uint16_t usOutH = pstOutTensor ->nH;
    const uint16_t usOutC = pstOutTensor ->nC;

    const uint8_t uchPadX = pstConvParam ->uchPadX;
    const uint8_t uchPadY = pstConvParam ->uchPadY;
    const uint8_t uchStrideW = pstConvParam ->uchStrideW;
    const uint8_t uchStrideH = pstConvParam ->uchStrideH;
    
    const uint8_t uchOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint
    const uint8_t uchInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint

    //量化输出的截断值
    int32_t uchActMin = 0;    //conv_params->activation.min
    int32_t uchActMax = 255;  //conv_params->activation.max

    //跟着激活时，设置最小截断为输出ZeroPoint
    if (pstConvParam->uchActValue == 1)
    {
        uchActMin = uchOutZP;
    }
    //量化系数顶点数据
    int64_t *plnOutMultBzp = pstConvParam ->plnMulBzp;
    int64_t *plnOutMult = pstConvParam ->plnMultSc;
    int32_t *puchOutShift = pstConvParam ->puchShift;

    if (NULL == plnOutMultBzp || NULL == plnOutMult || NULL == puchOutShift)
    {
        return MOCNN_NULL_PTR;
    }


    uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
    uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;
    int8_t *pchKerData = (int8_t *)pstKerTensor-> pData;

    if (NULL == puchInData || NULL == puchOutData || NULL == pchKerData)
    {
        return MOCNN_NULL_PTR;
    }

    uint16_t usVaH = (usInH - 1) * uchStrideH - 2 * uchPadY + uchKernelH;
    uint16_t usVaW = (usInW - 1) * uchStrideW - 2 * uchPadX + uchKernelW;
    if (usOutH != usVaH || usOutW != usVaW)
    {
        return MOCNN_INVALID_PARAM;
    }
    printf("Entering NN trans\n");
    for(uint8_t nIb = 0; nIb < uchBatchNum; nIb++)
    {
        printf("nIb : %d\n",nIb);
        for (int32_t nOc = 0; nOc < usOutC; nOc++)
        {
            printf("nOc : %d\n",nOc);
            for (int32_t nOuty = 0; nOuty < usOutH; nOuty++)
            {
                printf("nOuty : %d\n",nOuty);
                for (int nOutx = 0; nOutx < usOutW; nOutx++)
                {
                    printf("nOutx : %d, nSum = 0\n",nOutx);
                    int32_t nSum = 0;

                    for (uint8_t nKy = 0; nKy < uchKernelH; nKy++)
                    {
                        printf("nKy : %d\n",nKy);
                        const int32_t nPosY = nOuty - nKy + uchPadY;
                        int32_t nInY = nPosY / uchStrideH;
                        if ((nPosY % uchStrideH) != 0 || (nInY < 0) || (nInY >= usInH))
                        {
                            continue;
                        }
                        for (uint8_t nKx = 0; nKx < uchKernelW; nKx++)
                        {
                            printf("nKx : %d\n",nKx);
                            const int32_t nPosX = nOutx - nKx + uchPadX;
                            int32_t nInX = nPosX / uchStrideW;
                            if ((nPosX % uchStrideW) != 0 || (nInX < 0) || (nInX >= usInW))
                            {
                                continue;
                            }
                            int32_t nInPos = (nInY * usInW + nInX) * usInC;
                            int32_t nKerPos = nOc * usInC * uchKernelW * uchKernelH + (nKy * uchKernelW + nKx) * usInC;
                            for(uint16_t nCh = 0; nCh < usInC; nCh++)
                            {
                                printf("nCh : %d\n",nCh);
                                //此处两个无符号相减要考虑得到负数，需要将uchZP转成int16
                                nSum += (puchInData[nInPos + nCh] - (int16_t)uchInZP) * pchKerData[nKerPos + nCh];
                            }
                        }
                    }

                    nSum = (int32_t)((plnOutMult[nOc] * nSum + plnOutMultBzp[nOc]) >> puchOutShift[nOc]);
                    nSum = MAX(nSum, uchActMin);
                    nSum = MIN(nSum, uchActMax);
                    puchOutData[nOc + (nOuty*usOutW + nOutx)*usOutC] = (uint8_t)nSum;

                }
            }
        }
        puchInData += ((int32_t)usInW * usInH * usInC);
    }
    return MOCNN_OK;
}

uint8_t pData_in[2][4][8][8];
uint8_t pData_out[2][10][6][6];
uint8_t pKernel[10][4][3][3];
uint64_t plnMulBzp[20];
uint64_t plnMultSc[20];
uint32_t puchShift[20];

const mocnn_tensor my_in_tensor = {
    .nN     = 2     ,
    .nC     = 4     ,
    .nH     = 8     ,
    .nW     = 8     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     = 2     ,
    .nC     = 10     ,
    .nH     = 10     ,
    .nW     = 10     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_out
};

const mocnn_tensor my_kernel_tensor = {
    .nN     = 10    ,
    .nC     = 4     ,
    .nH     = 3     ,
    .nW     = 3     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pKernel
};

const mocnn_conv_param my_conv_param = {
    .uchKernelH     = 3  ,
    .uchKernelW     = 3  ,
    .uchStrideH     = 1  ,
    .uchStrideW     = 1  ,
    .uchDilationH   = 0  ,
    .uchDilationW   = 0  ,
    .uchPadX        = 0  ,   
    .uchPadY        = 0  ,   
    .usGroupNum     = 1  ,
    .uchActValue    = 0  ,                  
    .plnMulBzp      = plnMulBzp ,
    .plnMultSc      = plnMultSc ,
    .puchShift      = puchShift
};
void run_nn_trans(){
    const mocnn_tensor *in_tensor = &my_in_tensor;
    const mocnn_tensor *out_tensor = &my_out_tensor;
    const mocnn_tensor *kernel_tensor = &my_kernel_tensor;
    const mocnn_conv_param *conv_param = &my_conv_param;

    MOCNN_TransposeConv(in_tensor, out_tensor, kernel_tensor, conv_param);
}

int main()
{
    run_nn_trans();
    return 0;
}
