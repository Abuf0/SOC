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
int32_t MOCNN_Linear(const mocnn_tensor * pstInTensor, const mocnn_tensor * pstOutTensor,
    const mocnn_tensor * pstKerTensor, const mocnn_linear_param * pstLinearParam)
{
    printf("Entering NN Linear\n");

    if(NULL == pstInTensor || NULL == pstOutTensor || NULL == pstKerTensor || NULL == pstLinearParam)
    {
        return MOCNN_NULL_PTR;
    }

    const uint8_t  uchBatchNum = pstInTensor ->nN; //输入数据的batch数
    const uint16_t usInW = pstInTensor ->nW;
    const uint16_t usInH = pstInTensor ->nH;
    const uint16_t usInC = pstInTensor ->nC;
        
    const uint8_t uchOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint
    const uint8_t uchInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint

    uint8_t uchActMin = 0;    //conv_params->activation.min
    uint8_t uchActMax = 255;  //conv_params->activation.max


    if (pstLinearParam->uchActValue == 1)
    {
        uchActMin = uchOutZP;
    }
    //量化系数顶点数据
    int64_t *plnOutMultBzp = pstLinearParam ->plnMulBzp;
    int64_t *plnOutMult = pstLinearParam ->plnMultSc;
    int32_t *puchOutShift = pstLinearParam ->puchShift;

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

    int32_t nInFeaNum = pstLinearParam->nInFeatures;
    int32_t nOutFeaNum = pstLinearParam->nOutFeatures;

    int32_t nTotalInSize = (int32_t)uchBatchNum*usInW*usInH*usInC;

    int32_t nBatchNum = nTotalInSize / nInFeaNum;

    uint8_t *puchOut = puchOutData;
    uint8_t *puchIn = puchInData;
    uint8_t *pchKer = pchKerData;
    printf("N = %d, H = %d, W = %d, C = %d, M = %d\n",uchBatchNum,usInH,usInW,usInC,nOutFeaNum);
    printf("nBatchNum = %d, nOutFeaNum = %d, nInFeaNum = %d\n",nBatchNum,nOutFeaNum,nInFeaNum);
    for(uint8_t nIb = 0; nIb < uchBatchNum; nIb++)
    {
        printf("Ib: %d\n",nIb);
        for (int32_t i = 0; i < nOutFeaNum; i++)
        {
            printf("i: %d\n",i);
            printf("pchKerPt = pchKer + %d*nInFeaNum\n",i);
            int8_t *pchKerPt = pchKer + i*nInFeaNum;
            int32_t nSum;
            for (int32_t j = 0; j < nInFeaNum; j++)
            {
                nSum += (puchIn[j] - (int16_t)uchInZP)*pchKerPt[j];
                printf("nSum += (puchIn[%d] - (int16_t)uchInZP)*pchKerPt[%d]\n",j,j);
            }

            nSum = (int32_t)((plnOutMult[i] * nSum + plnOutMultBzp[i]) >> puchOutShift[i]);
            nSum = MAX(nSum, uchActMin);
            nSum = MIN(nSum, uchActMax);
            puchOut[i] = (uint8_t)nSum;
        }
        puchOut += nOutFeaNum;
        puchIn += nInFeaNum;
    }
    return MOCNN_OK;
}

uint8_t pData_in[10][4][8][8];
uint8_t pData_out[10][4][8][8];
uint8_t pKernel[20][4][8][8];
uint64_t plnMulBzp[20];
uint64_t plnMultSc[20];
uint32_t puchShift[20];

const mocnn_tensor my_in_tensor = {
    .nN     = 10    ,
    .nC     = 4     ,
    .nH     = 8     ,
    .nW     = 8     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     = 20    ,
    .nC     = 4     ,
    .nH     = 8     ,
    .nW     = 8     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_out
};

const mocnn_tensor my_kernel_tensor = {
    .nN     = 20    ,
    .nC     = 4     ,
    .nH     = 8     ,
    .nW     = 8     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pKernel
};

const mocnn_linear_param my_linear_param = {
    .nInFeatures    = 10    ,
    .nOutFeatures   = 20    ,
    .uchActValue    = 0     ,
    .plnMulBzp      = plnMulBzp ,
    .plnMultSc      = plnMultSc ,
    .puchShift      = puchShift
};
void run_nn_linear(){
    const mocnn_tensor *in_tensor = &my_in_tensor;
    const mocnn_tensor *out_tensor = &my_out_tensor;
    const mocnn_tensor *kernel_tensor = &my_kernel_tensor;
    const mocnn_linear_param *linear_param = &my_linear_param;

    MOCNN_Linear(in_tensor, out_tensor, kernel_tensor, linear_param);
}

int main()
{
    run_nn_linear();
    return 0;
}