#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "moc_nn.h"


#define EPS 168
#define SHIFT_N 24

uint32_t SqrtU64(uint64_t ullX)
{
    uint64_t ullTemp = 0;
    uint32_t unVbit = 31;
    uint32_t unN = 0;
    uint64_t ullB = 0x80000000;
    if(ullX <= 1)
    {
        return (uint32_t)ullX;
    }
    do
    {
        ullTemp = ((unN << 1) + ullB) << unVbit;
        unVbit--;
        if(ullX >= ullTemp)
        {
            unN += (uint32_t)ullB;
            ullX -= ullTemp;
        }
        ullB >>= 1;
    } while (ullB);
    return unN;
}

int32_t MOCNN_Layernorm(const mocnn_tensor *pstInTensor, const mocnn_tensor *pstOutTensor,
    const mocnn_layernorm_param * pstLnParam)
    {
        printf("Entering LayerNorm\n");
    
        if(NULL == pstInTensor || NULL == pstOutTensor || NULL == pstLnParam)
        {
            return MOCNN_NULL_PTR;
        }
        if(0 == pstLnParam->nNormShape)
        {
            return MOCNN_INVALID_PARAM;
        }
    
        const uint8_t  uchBatchNum = pstInTensor ->nN; //输入数据的batch数
        const uint16_t usInW = pstInTensor ->nW;
        const uint16_t usInH = pstInTensor ->nH;
        const uint16_t usInC = pstInTensor ->nC;

        const uint8_t uchOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint
        const uint8_t uchInZP = pstInTensor ->nZP;    //输入数据的ZeroPoint

        int32_t nNormSize = pstLnParam->nNormShape;
        int32_t nTotalSize = (int32_t)usInW*usInH*usInC;

        int32_t nCount = nTotalSize / nNormSize;

        uint8_t uchActMin = 0;
        uint8_t uchActMax = 255;

        uint8_t *puchInData = (uint8_t *)pstInTensor-> pData;
        uint8_t *puchOutData = (uint8_t *)pstOutTensor-> pData;

        if (NULL == puchInData || NULL == puchOutData)
        {
            return MOCNN_NULL_PTR;
        }

        int64_t *plnMulBzp = pstLnParam->plnMulBzp;
        int64_t *plnMultSc = pstLnParam->plnMultSc;
        uint8_t *puchShift = pstLnParam->puchShift;

        if(NULL == plnMulBzp || NULL == plnMultSc || NULL == puchShift)
        {
            return MOCNN_NULL_PTR;
        }

        if(pstLnParam->uchActValue == 1)
        {
            uchActMin = uchOutZP;
        }

        int32_t nSizeInv = (1 << SHIFT_N) / nNormSize;
        printf("SizeInv = %d\n",nSizeInv);

        for(int32_t nIb = 0; nIb < uchBatchNum; nIb++)
        {
            printf("nIb : %d\n", nIb);
            for (int32_t i = 0; i < nCount; i++)
            {
                //printf("nCount : %d\n", i);
                //printf("puch + %d\n", i*nNormSize);
                uint8_t *puchIn = puchInData + i*nNormSize;
                uint8_t *puchOut = puchOutData + i*nNormSize;

                int32_t nSum = 0;
                int64_t nSqSum = 0;
                int32_t nData = 0;
                for(int32_t j = 0; j < nNormSize; j++)
                {
                    nData = puchIn[j] - (int32_t)uchInZP;
                    if(nIb == 1 && i==0) {
                        printf("puch-mod : %d\n",nData);
                        }
                    if(nIb == 0 && i==nCount-1) {
                        printf("puch-mod : %d\n",nData);
                        }
                    nSum += nData;
                    nSqSum += nData*nData;
                }
                printf("nSum = %d\nnSqSum = %d\n",nSum,nSqSum);
                int64_t nMean = (int64_t)nSum*nSizeInv;
                int64_t nVar = nSqSum * nSizeInv - (nMean*nMean >> SHIFT_N);

                int32_t nSqrtVar = SqrtU64(nVar + EPS);
                int32_t nSqrtInv = (1 << SHIFT_N) / nSqrtVar;
                printf("nMean = %lld\nVar = %lld\nSqrtVar = %d\nSqrtInv = %d\n\n",nMean,nVar,nSqrtVar,nSqrtInv);


                for(int32_t j = 0; j < nNormSize; j++)
                {
                    nData = (puchIn[j] - (int32_t)uchInZP) << (SHIFT_N >> 1);
                    nData -= (nMean >> (SHIFT_N >> 1));
                    if(nIb == 1 && i==0) {
                    printf("puch-mean : %d\n",nData);
                    }
                    if(nIb == 1 && i==0) {
                        printf("nData * %lld * %d + %lld >> %d\n", plnMultSc[j], nSqrtInv, plnMulBzp[j], puchShift[j]);
                        printf("((nData*plnMultSc[j] * nSqrtInv)) = %lld\n", ((nData*plnMultSc[j] * nSqrtInv)));
                        }
                    nData = (int32_t)((((nData*  nSqrtInv * plnMultSc[j]) >> SHIFT_N) + plnMulBzp[j]) >> puchShift[j]);
                    //printf("nData * %lld * %d + %lld >> %d\n", plnMultSc[j], nSqrtInv, plnMulBzp[j], puchShift[j]);
                    nData = MAX(nData, uchActMin);
                    nData = MIN(nData, uchActMax);
                    puchOut[j] = nData;
                    //printf("puchOut[%d] : %d\n", j, puchOut[j]);

                }
            }
            puchInData += (int32_t)usInW * usInH * usInC;
            puchOutData += (int32_t)usInW * usInH * usInC;
        }
        printf("Exiting LayerNorm\n");
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
#define in_H 2
#define in_W 2
#define in_C 30
#define in_NormShape 15
#define rg_src_data_base 8 
#define rg_dest_data_base 0 
#define rg_coef_base 0 


uint8_t pData_out[in_N*in_C*in_H*in_W];
uint8_t pData_in[in_N*in_C*in_H*in_W];
int64_t plnMulBzp_in[in_NormShape];
int64_t plnMultSc_in[in_NormShape];
uint8_t puchShift_in[in_NormShape];

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

const mocnn_layernorm_param my_layernorm_param = {
    .uchActValue = 0    ,
    .nNormShape  = in_NormShape ,
    .plnMulBzp   = plnMulBzp_in    ,
    .plnMultSc   = plnMultSc_in    ,
    .puchShift   = puchShift_in 
};

void run_nn_layernorm(){
    const mocnn_tensor *in_tensor = &my_in_tensor;
    const mocnn_tensor *out_tensor = &my_out_tensor;
    const mocnn_layernorm_param *layernorm_tensor = &my_layernorm_param;

    // 初始化随机数种子
    srand(1);
    uint8_t source_data[in_N*in_H*in_W*in_C];

    // 生成随机数据存储到 source_data
    for (int i = 0; i < in_N*in_C*in_H*in_W; i++) {
        source_data[i] = (uint8_t)(rand() % 256);
        pData_in[i] = source_data[i];
    }

    for(int i = 0; i < in_NormShape; i++) {
        //plnMulBzp_in[i] = 0;//(int64_t)(rand() % 1024);
        //plnMultSc_in[i] = 100;//(int64_t)(rand() % 1024);
        //puchShift_in[i] = 0;//(uint8_t)(rand() % 256);
        plnMulBzp_in[i] = (int64_t)(rand() % 10);
        plnMultSc_in[i] = (int64_t)(rand() % 10) + 100;
        puchShift_in[i] = (uint8_t)(rand() % 2);
    }


    FILE *file_input_dec   = fopen("layernorm/layernorm_input_decimal.txt", "w");
    FILE *file_input_bin   = fopen("layernorm/layernorm_input_binary.txt", "w");
    FILE *file_coef_dec    = fopen("layernorm/layernorm_coef_decimal.txt", "w");
    FILE *file_coef_bin    = fopen("layernorm/layernorm_coef_binary.txt", "w");
    FILE *file_output_dec  = fopen("layernorm/layernorm_output_decimal.txt", "w");
    FILE *file_output_bin  = fopen("layernorm/layernorm_output_binary.txt", "w");

    if (!file_input_dec || !file_input_bin || !file_output_dec || !file_output_bin || !file_coef_dec || !file_coef_bin) {
        printf("Error opening file for writing.\n");
        return;
    }
    char binary_str[9];
    char binary_str_64[65];

    // **写入输入数据**
    if((rg_src_data_base % 8 != 0)){    // || (rg_dest_data_base % 8 != 0)){
        printf("Error data base address.\n");
        return;
    }
    if(((in_C*in_H*in_W) % in_NormShape != 0)){    // || (rg_dest_data_base % 8 != 0)){
        printf("Error config.\n");
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
    for (int i = 0; i < in_N*in_C*in_H*in_W/8; i++) {
        for(int j=0;j<8;j++){
            fprintf(file_input_dec, "%d\n", pData_in[i*8+j]);
            int_to_binary(pData_in[i*8+7-j], binary_str);
            fprintf(file_input_bin, "%s", binary_str);
        }
        fprintf(file_input_bin, "\n");
        
    }
    // coef data
    for (int i = 0; i < rg_coef_base; i++){
        fprintf(file_coef_dec, "%d\t", 0);
        int64_to_binary(0, binary_str_64);
        fprintf(file_coef_bin, "%s", binary_str_64);
        fprintf(file_coef_dec, "%d\t", 0);
        int64_to_binary(0, binary_str_64);
        fprintf(file_coef_bin, "%s", binary_str_64);
        fprintf(file_coef_dec, "%d\t", 0);
        int_to_binary(0, binary_str);
        fprintf(file_coef_bin, "%s", binary_str);
        fprintf(file_coef_dec, "\n");
        fprintf(file_coef_bin, "\n");
    }
    for (int j = 0; j < in_NormShape; j++) {
        fprintf(file_coef_dec, "%d\t", plnMultSc_in[j]);
        int64_to_binary(plnMultSc_in[j], binary_str_64);
        fprintf(file_coef_bin, "%s", binary_str_64);
        fprintf(file_coef_dec, "%d\t", plnMulBzp_in[j]);
        int64_to_binary(plnMulBzp_in[j], binary_str_64);
        fprintf(file_coef_bin, "%s", binary_str_64);
        fprintf(file_coef_dec, "%d\t", puchShift_in[j]);
        int_to_binary(puchShift_in[j], binary_str);
        fprintf(file_coef_bin, "%s", binary_str);
        fprintf(file_coef_dec, "\n");
        fprintf(file_coef_bin, "\n");
        
    }


    MOCNN_Layernorm(in_tensor, out_tensor, layernorm_tensor);

    // output data
    for (int i = 0; i < in_N*in_C*in_H*in_W/8; i++) {
        for(int j=0;j<8;j++){
            fprintf(file_output_dec, "%3d\n", pData_out[i*8+j]);
            int_to_binary(pData_out[i*8+j], binary_str);
            fprintf(file_output_bin, "%s\n", binary_str);
        }
    }

    fclose(file_input_dec);
    fclose(file_input_bin);
    fclose(file_output_dec);
    fclose(file_output_bin);
}

int main()
{
    run_nn_layernorm();
    //for(uint64_t i = 123; i < 124; i++){
    //    SqrtU64(i);
    //}
    return 0;
}