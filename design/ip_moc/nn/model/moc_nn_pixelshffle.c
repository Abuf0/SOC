#include "stdint.h"
#include "stdio.h"
#include "moc_nn.h"

int32_t MOCNN_PixelShuffle(const mocnn_tensor *pstInTensor, const mocnn_tensor *pstOutTensor, 
    const mocnn_pixelshffle_param * pstPixshffleParam)
    {    
        if(NULL == pstInTensor || NULL == pstOutTensor || NULL == pstPixshffleParam)
        {
            return MOCNN_NULL_PTR;
        }
    
        const uint8_t  uchBatchNum = pstInTensor ->nN; //输入数据的batch数
        const uint16_t usInW = pstInTensor ->nW;
        const uint16_t usInH = pstInTensor ->nH;
        const uint16_t usInC = pstInTensor ->nC;


        uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
        uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;
        if (NULL == puchInData || NULL == puchOutData)
        {
            return MOCNN_NULL_PTR;
        }

        uint8_t uchFactor = pstPixshffleParam->uchUpScFactor;
        printf("Factor : %d\n",uchFactor);

        if (0 == uchFactor)
        {
            return MOCNN_INVALID_PARAM;
        }
        uint16_t usOutH = usInH*uchFactor;
        uint16_t usOutW = usInW*uchFactor;
        uint16_t usOutC = usInC/ (uchFactor * uchFactor);

        if ((pstOutTensor->nH != usOutH) || (pstOutTensor->nW != usOutW) || (pstOutTensor->nC != usOutC))
        {
            return MOCNN_INVALID_PARAM;
        }

        printf("Entering pixelshuffle\n");
        for (uint8_t n = 0; n < uchBatchNum; ++n)
        {
            for (int32_t h = 0; h < usInH; ++h)
            {
                for (int32_t w = 0; w < usInW; ++w)
                {
                    for (int32_t c =0; c < usInC; ++c)
                    {
                        int32_t usCurrC = c / (uchFactor * uchFactor);
                        int32_t usSubH = (c / uchFactor) % uchFactor;
                        int32_t usSubW = c % uchFactor;

                        int32_t usCurrH = h * uchFactor + usSubH;
                        int32_t usCurrW = w * uchFactor + usSubW;

                        int32_t nInIdx = n * (usInH*usInW*usInC) + h * (usInW*usInC) + w * usInC + c;
                        int32_t nOutIdx = n * (usOutH*usOutW*usOutC) + usCurrH * (usOutW*usOutC) + usCurrW * usOutC + usCurrC;
                        printf("puchOutData[%d] = puchInData[%d]\n",nOutIdx,nInIdx);
                        puchOutData[nOutIdx] = puchInData[nInIdx];
                    }
                }
            }
        }
        return MOCNN_OK;
    }


const uint16_t in_N = 1;
const uint16_t in_C = 36;
const uint16_t in_H = 1;
const uint16_t in_W = 1;
const uint8_t Factor = 3;

uint8_t  pData_in[1][8][4][4];
uint8_t pData_out[1][8][4][4];

const mocnn_tensor my_in_tensor = {
    .nN     = in_N     ,
    .nC     = in_C     ,
    .nH     = in_H     ,
    .nW     = in_W     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     =in_N     ,
    .nC     =in_C/Factor/Factor     ,
    .nH     =in_H*Factor     ,
    .nW     =in_W*Factor     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_out
};

const mocnn_pixelshffle_param my_pixelshffle_param = {
    .uchUpScFactor     = Factor     
};

void run_nn_pixelshuffle(){
    const mocnn_tensor *in_tensor = &my_in_tensor;
    const mocnn_tensor *out_tensor = &my_out_tensor;
    const mocnn_pixelshffle_param *pixelshffle_param = &my_pixelshffle_param;

    MOCNN_PixelShuffle(in_tensor, out_tensor,pixelshffle_param);
}

int main()
{
    run_nn_pixelshuffle();
    return 0;
}