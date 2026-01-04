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

    const uint8_t uchBatchNum = pstInTensor ->nN; //输入数据的batch数
    const uint16_t usInW = pstInTensor ->nW;
    const uint16_t usInH = pstInTensor ->nH;
    const uint16_t usInC = pstInTensor ->nC;
    const int32_t nInCStep = pstInTensor ->nCStep;

    const uint8_t uchKernelW = pstConvParam ->uchKernelW;
    const uint8_t uchKernelH = pstConvParam ->uchKernelH;
    const uint16_t usKernelC = pstKerTensor ->nC;
    const int32_t nKernelCStep = pstKerTensor ->nCStep;

    const uint16_t usOutW = pstOutTensor ->nW;
    const uint16_t usOutH = pstOutTensor ->nH;
    const uint16_t usOutC = pstOutTensor ->nC;
    const int32_t nOutCStep = pstOutTensor ->nCStep;

    const int32_t uchPadX = pstConvParam ->uchPadX;
    const int32_t uchPadY = pstConvParam ->uchPadY;
    const int32_t uchStrideW = pstConvParam ->uchStrideW;
    const int32_t uchStrideH = pstConvParam ->uchStrideH;
    const int32_t uchDilationW = pstConvParam ->uchDilationW;
    const int32_t uchDilationH = pstConvParam ->uchDilationH;
    const int32_t uchOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint
    const int32_t uchInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint

    //卷积分组数
    //const int32_t usGroups = usInC / MAX(usKernelC, 1);
    const uint16_t usGroups = pstConvParam ->usGroupNum;

    //每次需要计算的卷积数据个数
    const uint16_t usKernelNum = uchKernelW * uchKernelH * nKernelCStep;

    //每个分组下卷积输出通道数
    //const int32_t usOutputChPerGroup = usOutC / MAX(usGroups, 1);
    const uint16_t usOutputChPerGroup = pstConvParam ->usChPerGroup;

    //分组卷积输出结果的偏移量
    const uint16_t nGrpOft = nOutCStep - usOutputChPerGroup;
    printf("nOutCStep=%d\n",nOutCStep);
    printf("usOutputChPerGroup=%d\n",usOutputChPerGroup);
    printf("nGrpOft=%d\n",nGrpOft);

    //量化输出的截断值
    int32_t uchActMin = 0;    //conv_params->activation.min
    int32_t uchActMax = 255;  //conv_params->activation.max
    //量化系数顶点数据
    int64_t *plnOutMultBzp = pstConvParam ->plnMulBzp;
    int64_t *plnOutMult = pstConvParam ->plnMultSc;
    uint8_t *puchOutShift = pstConvParam ->puchShift;
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
        const uint8_t *puchShiftPt = puchOutShift;

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
                    //printf("x=%d, y=%d\n",nOutx,nOuty);
                    for (int32_t nKy = 0; nKy < uchKernelH; nKy++)
                    {
                        for (int32_t nKx = 0; nKx < uchKernelW; nKx++)
                        {
                            const int32_t nPosY = nBaseY + uchDilationH * nKy;
                            const int32_t nPosX = nBaseX + uchDilationW * nKx;

                            //此处使用Input ZeroPoint进行padding
                            if (nPosY < 0 || nPosY >= usInH || nPosX < 0 || nPosX >= usInW)
                            {
                                memset(puchIm2ColPt, (uint8_t)uchInZP, sizeof(uint8_t)* nKernelCStep);
                            }
                            else //将数据进行复制进行im2col
                            {
                                memcpy(puchIm2ColPt, puchInData + (nPosY * usInW + nPosX) * nInCStep + nGidx * nKernelCStep, sizeof(uint8_t)* nKernelCStep);
                            }
                            puchIm2ColPt += nKernelCStep;
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
                            int32_t nInValue = *puchInPt++; //- uchInZP;

                            nSum += chKerValue * nInValue;
                            nCalCount--;
                        }
                        //将卷积累加和进行量化后输出
                        printf("Sum=%d\t",nSum);
                        int32_t nData = (int32_t)((plnMultPt[i] * nSum + plnMulBzpPt[i]) >> puchShiftPt[i]);
                        printf("Data=%d\n",nData);
                        nData = MAX(nData, uchActMin);
                        nData = MIN(nData, uchActMax);
                        *puchOut++ = (uint8_t)nData;
                    }
                    puchOut += nGrpOft;
                }
            }
            //指向下一组输出通道
            pchFilterPt += (int32_t)usOutputChPerGroup * usKernelNum;
            plnMulBzpPt += usOutputChPerGroup;
            plnMultPt += usOutputChPerGroup;
            puchShiftPt += usOutputChPerGroup;
        }
        //指向下一batch
        puchInData += ((int32_t)usInW * usInH * nInCStep);
        puchOutData += ((int32_t)usOutW * usOutH * nOutCStep);
    }
    free(puchBuf);
    return MOCNN_OK;
}

// **转换数值为二进制字符串**
void int_to_binary(uint8_t num, char *binary_str) {
    for (int i = 7; i >= 0; i--) {
        binary_str[7 - i] = (num & (1 << i)) ? '1' : '0';
    }
    binary_str[8] = '\0';
}

void int64_to_binary(int64_t num, char *binary_str) {
    for (int i = 63; i >= 0; i--) {
        binary_str[63 - i] = (num & ((int64_t)1 << i)) ? '1' : '0';
    }
    binary_str[64] = '\0';

}

#define in_N 2
#define in_H 10
#define in_W 10
#define in_C 20
#define in_CStep 24

#define kn_H 3
#define kn_W 3
#define kn_C 20
#define kn_CStep 24

#define out_H 8
#define out_W 8
#define out_C 44
#define out_CStep 48

#define std_H 1
#define std_W 1

#define pad_X 0
#define pad_Y 0

#define GroupNum  ( in_C/MAX(kn_C, 1) )
#define OutChPerGroup  ( out_C/MAX(GroupNum, 1) )

#define rg_src_data_base 8 
#define rg_dest_data_base 0 
#define rg_coef_base 0 


uint8_t pData_out[in_N*out_C*out_H*out_W];
uint8_t pData_in[in_N*in_C*in_H*in_W];
uint8_t pData_ker[kn_CStep*kn_H*kn_W*out_CStep];
int64_t plnMulBzp_in[OutChPerGroup];
int64_t plnMultSc_in[OutChPerGroup];
uint8_t puchShift_in[OutChPerGroup];

const mocnn_tensor my_in_tensor = {
    .nN     = in_N     ,
    .nC     = in_C     ,
    .nH     = in_H     ,
    .nW     = in_W     ,
    .nCStep = in_CStep ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .nMuliSc = 100000000   ,
    .uchShift = 30  ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     = in_N      ,
    .nC     = out_C     ,
    .nH     = out_H     ,
    .nW     = out_W     ,
    .nCStep = out_CStep ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .nMuliSc = 100000000   ,
    .uchShift = 30  ,
    .pData  = pData_out
};

const mocnn_tensor my_ker_tensor = {
    .nC     = kn_C       ,
    .nCStep = kn_CStep   ,
    .pData  = pData_ker
};

const mocnn_conv_param my_conv_param = {
    .uchActValue = 0                ,
    .uchKernelH  = kn_H             ,
    .uchKernelW  = kn_W             ,
    .uchStrideH  = std_H            ,
    .uchStrideW  = std_W            ,
    .uchPadX     = pad_X            ,
    .uchPadY     = pad_Y            ,
    .usGroupNum  = GroupNum         ,
    .usChPerGroup = OutChPerGroup   ,
    .plnMulBzp   = plnMulBzp_in     ,
    .plnMultSc   = plnMultSc_in     ,
    .puchShift   = puchShift_in 
};


void run_nn_conv(){
    const mocnn_tensor *in_tensor = &my_in_tensor;
    const mocnn_tensor *out_tensor = &my_out_tensor;
    const mocnn_tensor *ker_tensor = &my_ker_tensor;
    const mocnn_conv_param *conv_tensor = &my_conv_param;

    // 初始化随机数种子
    srand(1);
    uint8_t source_data[in_N*in_H*in_W*in_CStep];

    // 生成随机数据存储到 source_data
    for (int i = 0; i < in_N*in_CStep*in_H*in_W; i++) {
        source_data[i] = (uint8_t)(rand() % 256);
        pData_in[i] = source_data[i];
    }

    for (int i = 0; i < kn_CStep*kn_H*kn_W*out_CStep; i++) {
        pData_ker[i] = (uint8_t)(rand() % 256);
    }

    for(int i = 0; i < OutChPerGroup; i++) {
        plnMulBzp_in[i] = 100000000;  
        plnMultSc_in[i] = 400;
        puchShift_in[i] = 20;  
        //plnMulBzp_in[i] = (int64_t)(rand() % 1024);
        //plnMultSc_in[i] = (int64_t)(rand() % 1024);
        //puchShift_in[i] = (uint8_t)(rand() % 256);
    }


    FILE *file_input_dec   = fopen("conv/conv_input_decimal.txt", "w");
    FILE *file_input_bin   = fopen("conv/conv_input_binary.txt", "w");
    FILE *file_coef_dec    = fopen("conv/conv_coef_decimal.txt", "w");
    FILE *file_coef_bin    = fopen("conv/conv_coef_binary.txt", "w");
    FILE *file_param_dec    = fopen("conv/conv_param_decimal.txt", "w");
    FILE *file_param_bin    = fopen("conv/conv_param_binary.txt", "w");
    FILE *file_output_dec  = fopen("conv/conv_output_decimal.txt", "w");
    FILE *file_output_bin  = fopen("conv/conv_output_binary.txt", "w");

    if (!file_input_dec || !file_input_bin || !file_output_dec || !file_output_bin || !file_coef_dec || !file_coef_bin || !file_param_dec || !file_param_bin ) {
        printf("Error opening file for writing.\n");
        return;
    }
    char binary_str[9];
    char binary_str_64[65];

    // **写入输入数据**
    if((rg_src_data_base % 8 != 0) || (rg_dest_data_base % 8 != 0)){    // || (rg_dest_data_base % 8 != 0)){
        printf("Error src data base address.\n");
        return;
    }
    for (int i = 0; i < rg_src_data_base/8; i++){
        for(int j=0;j<8;j++){
            fprintf(file_input_dec, "%d\n", 0);
            int_to_binary(0, binary_str);
            fprintf(file_input_bin, "%s", binary_str);
        }
        fprintf(file_input_bin, "\n");
    }
    for (int i = 0; i < in_N*in_CStep*in_H*in_W/8; i++) {
        for(int j=0;j<8;j++){
            fprintf(file_input_dec, "%d\n", pData_in[i*8+j]);
            int_to_binary(pData_in[i*8+7-j], binary_str);
            fprintf(file_input_bin, "%s", binary_str);
        }
        fprintf(file_input_bin, "\n");
        
    }
    // coef data
    if((rg_coef_base % 8 != 0)){    
        printf("Error coef data base address.\n");
        return;
    }
    for (int i = 0; i < rg_coef_base/8; i++){
        for(int j=0;j<8;j++){
            fprintf(file_coef_dec, "%d\n", 0);
            int_to_binary(0, binary_str);
            fprintf(file_coef_bin, "%s", binary_str);
        }
        fprintf(file_coef_bin, "\n");
    }
    for (int i = 0; i < kn_CStep*kn_H*kn_W*out_CStep/8; i++) {
        for(int j=0;j<8;j++){
            fprintf(file_coef_dec, "%d\n", pData_ker[i*8+j]);
            int_to_binary(pData_ker[i*8+7-j], binary_str);
            fprintf(file_coef_bin, "%s", binary_str);
        }
        fprintf(file_coef_bin, "\n");
        
    }

    for (int j = 0; j < OutChPerGroup; j++) {
        fprintf(file_param_dec, "%d\t", plnMultSc_in[j]);
        int64_to_binary(plnMultSc_in[j], binary_str_64);
        fprintf(file_param_bin, "%s", binary_str_64);
        fprintf(file_param_dec, "%d\t", plnMulBzp_in[j]);
        int64_to_binary(plnMulBzp_in[j], binary_str_64);
        fprintf(file_param_bin, "%s", binary_str_64);
        fprintf(file_param_dec, "%d\t", puchShift_in[j]);
        int_to_binary(puchShift_in[j], binary_str);
        fprintf(file_param_bin, "%s", binary_str);
        fprintf(file_param_dec, "\n");
        fprintf(file_param_bin, "\n");
        
    }


    MOCNN_Conv(in_tensor, out_tensor, ker_tensor, conv_tensor);

    // output data
    for (int i = 0; i < in_N*in_CStep*in_H*in_W/8; i++) {
        for(int j=0;j<8;j++){
            fprintf(file_output_dec, "%3d\n", pData_out[i*8+j]);
            int_to_binary(pData_out[i*8+j], binary_str);
            fprintf(file_output_bin, "%s\n", binary_str);
        }
    }

    fclose(file_input_dec);
    fclose(file_input_bin);
    fclose(file_coef_dec);
    fclose(file_coef_bin);
    fclose(file_param_dec);
    fclose(file_param_bin);
    fclose(file_output_dec);
    fclose(file_output_bin);
}

int main()
{
    run_nn_conv();
    //for(uint64_t i = 123; i < 124; i++){
    //    SqrtU64(i);
    //}
    return 0;
}