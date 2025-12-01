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
    const int32_t nInCStep = pstInTensor ->nCStep;
    const uint8_t  uchKernelW = pstConvParam ->uchKernelW;
    const uint8_t  uchKernelH = pstConvParam ->uchKernelH;
    const uint16_t usKernelC = pstKerTensor ->nC;
    const int32_t nKernelCStep = pstKerTensor ->nCStep;
    const uint16_t usOutW = pstOutTensor ->nW;
    const uint16_t usOutH = pstOutTensor ->nH;
    const uint16_t usOutC = pstOutTensor ->nC;
    const int32_t nOutCStep = pstOutTensor ->nCStep;

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
    uint8_t *puchOutShift = pstConvParam ->puchShift;

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
        printf("VaH = %d, VaW = %d\n",usVaH,usVaW );
        return MOCNN_INVALID_PARAM;
    }
    printf("Entering NN trans\n");
    for(uint8_t nIb = 0; nIb < uchBatchNum; nIb++)
    {
        printf("nIb : %d\n",nIb);
        for (int32_t nOc = 0; nOc < usOutC; nOc++)
        {
            printf("nOutC : %d\n",nOc);
            for (int32_t nOuty = 0; nOuty < usOutH; nOuty+=2)
            {
                printf("nOutH : %d\n",nOuty);
                for (int nOutx = 0; nOutx < usOutW; nOutx+=2)
                {
                    printf("nOutW : %d\n",nOutx);
                    int32_t nSum00 = 0;
                    int32_t nSum01 = 0;
                    int32_t nSum10 = 0;
                    int32_t nSum11 = 0;

                    printf("puchIn[%d][%d][ALL]\n", (nOuty >> 1), (nOutx >> 1));
                    printf("pchKPt[%d]为始2x2\n", nOc, (nOuty >> 1), (nOutx >> 1));

                    uint8_t* puchInPt = puchInData + ((nOuty >> 1)*usInW + (nOutx >> 1))*nInCStep;
                    int8_t* pchKPt = pchKerData + nOc * nKernelCStep * uchKernelW * uchKernelH;

                    for(uint16_t nCh = 0; nCh < usInC; nCh++)
                    {
                        //printf("nCh : %d\n",nCh);
                        nSum00 += (int32_t)puchInPt[nCh] * pchKPt[nCh];
                        nSum01 += (int32_t)puchInPt[nCh] * pchKPt[nKernelCStep + nCh];
                        nSum10 += (int32_t)puchInPt[nCh] * pchKPt[nKernelCStep * 2 + nCh];
                        nSum11 += (int32_t)puchInPt[nCh] * pchKPt[nKernelCStep * 3 + nCh];
                    }

                    nSum00 = (int32_t)((plnOutMult[nOc] * nSum00 + plnOutMultBzp[nOc * 4]) >> puchOutShift[nOc]);
                    nSum00 = MIN(MAX(nSum00, uchActMin), uchActMax);
                    nSum01 = (int32_t)((plnOutMult[nOc] * nSum01 + plnOutMultBzp[nOc * 4 + 1]) >> puchOutShift[nOc]);
                    nSum01 = MIN(MAX(nSum01, uchActMin), uchActMax);
                    nSum10 = (int32_t)((plnOutMult[nOc] * nSum10 + plnOutMultBzp[nOc * 4 + 2]) >> puchOutShift[nOc]);
                    nSum10 = MIN(MAX(nSum10, uchActMin), uchActMax);
                    nSum11 = (int32_t)((plnOutMult[nOc] * nSum11 + plnOutMultBzp[nOc * 4 + 3]) >> puchOutShift[nOc]);
                    nSum11 = MIN(MAX(nSum11, uchActMin), uchActMax);

                    printf("puchout[%d][%d][%d]为始2x2\n", nOuty, nOutx, nOc);

                    puchOutData[nOc + (nOuty*usOutW + nOutx)*nOutCStep] = (uint8_t)nSum00;
                    puchOutData[nOc + (nOuty*usOutW + nOutx + 1)*nOutCStep] = (uint8_t)nSum01;
                    puchOutData[nOc + ((nOuty+1)*usOutW + nOutx)*nOutCStep] = (uint8_t)nSum10;
                    puchOutData[nOc + ((nOuty+1)*usOutW + nOutx + 1)*nOutCStep] = (uint8_t)nSum11;

                }
            }
        }
        puchInData += ((int32_t)usInW * usInH * nInCStep);
        puchOutData += ((int32_t)usOutW * usOutH * nOutCStep);
    }
    return MOCNN_OK;
}

uint8_t pData_in[2][4][8][8];
uint8_t pData_out[2][10][6][6];
uint8_t pKernel[10][4][3][3];
uint64_t plnMulBzp[20];
uint64_t plnMultSc[20];
uint8_t puchShift[20];

const mocnn_tensor my_in_tensor = {
    .nN     = 1     ,
    .nC     = 2     ,
    .nH     = 2     ,
    .nW     = 2     ,
    .nCStep = 8     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     = 1     ,
    .nC     = 3     ,
    .nH     = 4     ,
    .nW     = 4     ,
    .nCStep = 8     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_out
};

const mocnn_tensor my_kernel_tensor = {
    .nN     = 1    ,
    .nC     = 2     ,
    .nH     = 2     ,
    .nW     = 2     ,
    .nCStep = 8     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pKernel
};

const mocnn_conv_param my_conv_param = {
    .uchKernelH     = 2  ,
    .uchKernelW     = 2  ,
    .uchStrideH     = 2  ,
    .uchStrideW     = 2  ,
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
