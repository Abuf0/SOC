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
        printf("Error!! VaH = %d, VaW = %d\n",usVaH,usVaW );
        return MOCNN_INVALID_PARAM;
    }
    printf("Entering NN trans\n");
    for(uint8_t nIb = 0; nIb < uchBatchNum; nIb++)
    {
        printf("nIb : %d\n",nIb);
        for (int32_t nOc = 0; nOc < usOutC; nOc++)
        {
            //printf("nOutC : %d\n",nOc);
            for (int32_t nOuty = 0; nOuty < usOutH; nOuty+=2)
            {
                //printf("nOutH : %d\n",nOuty);
                for (int nOutx = 0; nOutx < usOutW; nOutx+=2)
                {
                    //printf("nOutW : %d\n",nOutx);
                    int32_t nSum00 = 0;
                    int32_t nSum01 = 0;
                    int32_t nSum10 = 0;
                    int32_t nSum11 = 0;

                    //printf("puchIn[%d][%d][ALL]\n", (nOuty >> 1), (nOutx >> 1));
                    //printf("pchKPt[%d]为始2x2\n", nOc, (nOuty >> 1), (nOutx >> 1));

                    uint8_t* puchInPt = puchInData + ((nOuty >> 1)*usInW + (nOutx >> 1))*nInCStep;
                    int8_t* pchKPt = pchKerData + nOc * nKernelCStep * uchKernelW * uchKernelH;

                    for(uint16_t nCh = 0; nCh < usInC; nCh++)
                    {
                        //printf("nCh : %d\n",nCh);
                        nSum00 += (int32_t)puchInPt[nCh] * pchKPt[nCh];
                        if(nOutx == 0 && nOuty == 0){
                        printf("nSum10 += %d * %d\n",puchInPt[nCh], pchKPt[nKernelCStep * 2 + nCh]);
                        }
                        nSum01 += (int32_t)puchInPt[nCh] * pchKPt[nKernelCStep + nCh];
                        nSum10 += (int32_t)puchInPt[nCh] * pchKPt[nKernelCStep * 2 + nCh];
                        nSum11 += (int32_t)puchInPt[nCh] * pchKPt[nKernelCStep * 3 + nCh];
                    }

                    if(nOutx == 0 && nOuty == 0){
                        printf("SUM10 = %d, ", nSum10);
                    }

                    nSum00 = (int32_t)((plnOutMult[nOc] * nSum00 + plnOutMultBzp[nOc * 4]) >> puchOutShift[nOc]);
                    nSum00 = MIN(MAX(nSum00, uchActMin), uchActMax);
                    nSum01 = (int32_t)((plnOutMult[nOc] * nSum01 + plnOutMultBzp[nOc * 4 + 1]) >> puchOutShift[nOc]);
                    nSum01 = MIN(MAX(nSum01, uchActMin), uchActMax);
                    nSum10 = (int32_t)((plnOutMult[nOc] * nSum10 + plnOutMultBzp[nOc * 4 + 2]) >> puchOutShift[nOc]);
                    nSum10 = MIN(MAX(nSum10, uchActMin), uchActMax);
                    nSum11 = (int32_t)((plnOutMult[nOc] * nSum11 + plnOutMultBzp[nOc * 4 + 3]) >> puchOutShift[nOc]);
                    nSum11 = MIN(MAX(nSum11, uchActMin), uchActMax);

                    if(nOutx == 0 && nOuty == 0){
                        printf("puch10 = %d\n", nSum10);
                    }


                    //printf("puchout[%d][%d][%d]为始2x2\n", nOuty, nOutx, nOc);
                    //printf("puchoutdata[%d] done\n\n", nOc + (nOuty*usOutW + nOutx)*nOutCStep);

                    puchOutData[nOc + (nOuty*usOutW + nOutx)*nOutCStep] = (uint8_t)nSum00;
                    puchOutData[nOc + (nOuty*usOutW + nOutx + 1)*nOutCStep] = (uint8_t)nSum01;
                    puchOutData[nOc + ((nOuty+1)*usOutW + nOutx)*nOutCStep] = (uint8_t)nSum10;
                    puchOutData[nOc + ((nOuty+1)*usOutW + nOutx + 1)*nOutCStep] = (uint8_t)nSum11;
                
                    if(nOutx == 0 && nOuty == 0){
                        printf("puchOutData[%d] = %d\n", nOc + ((nOuty+1)*usOutW + nOutx)*nOutCStep, (uint8_t)nSum10);
                    }

                }
            }
        }
        puchInData += ((int32_t)usInW * usInH * nInCStep);
        puchOutData += ((int32_t)usOutW * usOutH * nOutCStep);
    }
    return MOCNN_OK;
}

void generate_fixed_random_input_uint8(uint8_t *du, int nu, int lu, int32_t seedu, uint64_t *du_64b) {
    int du_64_len = (nu + 7) / 8;
    int nu_64 = du_64_len * 8;

    srand(seedu);
    for (int k = 0; k < lu; k++){
        for (int i = 0; i < nu_64; i++) {
            if(i >= nu){
                du[k*nu_64 + i] = 0;
            } else {
                du[k*nu_64 + i] = (uint8_t)(rand() % 256);
            }
        }
    }


    // 4. du拼接：8个uint8_t → 1个64位值（小端）
    memset(du_64b, 0, (du_64_len * lu) * sizeof(uint64_t));
    for(int k=0; k < lu; k++){
        for (int i = 0; i < nu_64; i++) {
            int group = i / 8;
            int byte_pos = i % 8;
            du_64b[group+k*du_64_len] |= (uint64_t)du[k*nu_64 + i] << (byte_pos * 8);
            //printf("du[%d]=%d, byte_pos = %d, du_64b[%d] = %llx\n", i, du[i], byte_pos, group, du_64b[group]);
        }
    }

}

void generate_fixed_random_input_int8(int8_t *di, int ni, int li, int32_t seedi, uint64_t *di_64b) {
    int di_64_len = (ni + 7) / 8;
    int ni_64 = di_64_len * 8;

    srand(seedi); // 或者放到外面，只初始化一次
    for (int k = 0; k < li; k++){
        for (int i = 0; i < ni_64; i++) {
            if(i >= ni){
                di[k*ni_64 + i] = 0;
            } else {
                di[k*ni_64 + i] = (int8_t)((rand() % 256) - 128);
            }
        }
    }
// 2. 计算64位数组长度（向上取整）

    // 3. di拼接：8个int8_t → 1个64位值（小端：低索引→低字节）
    memset(di_64b, 0, (di_64_len * li) * sizeof(uint64_t));
    for(int k=0; k < li; k++){
        for (int i = 0; i < ni_64; i++) {
            int group = i / 8;
            int byte_pos = i % 8;
            uint8_t raw_byte = (uint8_t)di[k*ni_64 + i];  // 保留int8_t原始二进制位
            di_64b[group+k*di_64_len] |= (uint64_t)raw_byte << (byte_pos * 8);
        }
    }


}

void print_array(uint8_t *arr, int row, int colunm) {
    printf("[\n");
    for (int i = 0; i < row; ++i) {          // 行
            for (int j = 0; j < colunm; ++j) {     // 列
                printf("%5d ", arr[i * colunm + j]);  // 下标 = 行*列数 + 列
            }
            printf("\n");
        }
    printf("]\n\n");
}

void print_array_signed(int8_t *arr, int row, int colunm) {
    printf("[\n");
    for (int i = 0; i < row; ++i) {          // 行
            for (int j = 0; j < colunm; ++j) {     // 列
                printf("%5d ", arr[i * colunm + j]);  // 下标 = 行*列数 + 列
            }
            printf("\n");
        }
    printf("]\n\n");
}

#define IN_BASE 0       // TODO
#define K_BASE 0        // TODO
#define PARAM_BASE 0    // TODO    
#define OUT_BASE 0      // TODO

#define BATCH 2         // TODO

#define IN_N BATCH
#define IN_H 3         // TODO
#define IN_W 4         // TODO
#define IN_C 11         // TODO
#define IN_CSTEP  (((IN_C) + 7U) & (~7U))   

#define OUT_N BATCH
#define OUT_H 2*IN_H
#define OUT_W 2*IN_W
#define OUT_C 17         // TODO
#define OUT_CSTEP  (((OUT_C) + 7U) & (~7U))   

#define K_N OUT_C
#define K_H 2
#define K_W 2
#define K_C IN_C
#define K_CSTEP  (((K_C) + 7U) & (~7U))   

uint8_t pData_in[IN_N*IN_H*IN_W*IN_CSTEP];
uint8_t pData_out[OUT_N*OUT_H*OUT_W*OUT_CSTEP];
uint8_t pKernel[K_N*K_H*K_W*K_CSTEP];
int64_t plnMulBzp[OUT_C*4];
int64_t plnMultSc[OUT_C*4];
uint8_t puchShift[OUT_C*4];

uint64_t pData_in_64b[IN_N*IN_H*IN_W*IN_CSTEP/8] = {0};
uint64_t pKernel_64b[K_N*K_H*K_W*K_CSTEP/8] = {0};
uint64_t pData_out_64b[OUT_N*OUT_H*OUT_W*OUT_CSTEP/8]  = {0};

const mocnn_tensor my_in_tensor = {
    .nN     = IN_N     ,
    .nC     = IN_C     ,
    .nH     = IN_H     ,
    .nW     = IN_W     ,
    .nCStep = IN_CSTEP     ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     = OUT_N     ,
    .nC     = OUT_C     ,
    .nH     = OUT_H     ,
    .nW     = OUT_W     ,
    .nCStep = OUT_CSTEP ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_out
};

const mocnn_tensor my_kernel_tensor = {
    .nN     = K_N      ,
    .nC     = K_C       ,
    .nH     = K_H       ,
    .nW     = K_W       ,
    .nCStep = K_CSTEP   ,
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

    printf("start trans conv\n");
    //printf("BATCH = %d, IN_NUM = %d, IN_STEP = %d, OUT_NUM = %d\n", BATCH, IN_NUM, IN_STEP, OUT_NUM);
    generate_fixed_random_input_uint8(pData_in, IN_C , IN_N * IN_H * IN_W ,3, pData_in_64b);
    generate_fixed_random_input_int8(pKernel, K_C , K_N * K_H * K_W ,2, pKernel_64b);
    printf("pData_in = ");
    print_array(pData_in, IN_N * IN_H * IN_W, IN_CSTEP);
    printf("pKernel[n] = \n");
    print_array_signed(pKernel, K_N * K_H * K_W, K_CSTEP);

    for(int i=0;i<OUT_C*4;i++){
        //plnMulBzp[4*i] = 0;
        //plnMulBzp[4*i+1] = 0;
        //plnMulBzp[4*i+2] = 0;
        //plnMulBzp[4*i+3] = 0;
        plnMulBzp[i] = (rand() % 32) - 16;//0;
        plnMultSc[i] = (rand() % 4) - 2;//1;
        puchShift[i] = (rand() % 3) + 8;//8;
    }

    printf("loading source data into files...\n");
    FILE *file_infeat_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/nn_transconv/infeat_data.txt", "w");
    FILE *file_weight_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/nn_transconv/weight_data.txt", "w");
    FILE *file_param_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/nn_transconv/param_data.txt", "w");

    for (int i=0; i < IN_BASE/8; i++) {
        fprintf(file_infeat_data, "%016llx\n", 0);
    }
    for (int i = 0; i < (IN_N*IN_H*IN_W*IN_CSTEP)/8; i++) {
	    //fprintf(file_infeat_data, "%0x\n", pData_in[i]);
        fprintf(file_infeat_data, "%016llx\n", pData_in_64b[i]);
    }
    for (int i = 0; i < K_BASE/8; i++) {
        fprintf(file_weight_data, "%016llx\n", 0);
    }
    for (int i = 0; i < (K_N*K_H*K_W*K_CSTEP)/8; i++) {
        //fprintf(file_weight_data, "%0x\n", pKernel[i]);
        fprintf(file_weight_data, "%016llx\n", pKernel_64b[i]);
    }
    for (int i = 0; i < PARAM_BASE/8; i++) {
        fprintf(file_param_data, "%016llx%016llx%02x\n", 0, 0, 0);
    }
    for (int i = 0; i < OUT_C*4; i++) {
        fprintf(file_param_data, "%016llx%016llx%02x\n", plnMultSc[i], plnMulBzp[i], puchShift[i]);
        //printf( "%016llx%016llx%02x\n", plnMultSc[i], plnMulBzp[i], puchShift[i]);
    }
    fclose(file_infeat_data);
    fclose(file_weight_data);
    fclose(file_param_data);

    MOCNN_TransposeConv(in_tensor, out_tensor, kernel_tensor, conv_param);

    printf("pData_out = \n");
    print_array(pData_out,OUT_N * OUT_H * OUT_W, OUT_CSTEP);

    int out_64_len = (OUT_N * OUT_H*OUT_W*OUT_CSTEP) / 8;
    memset(pData_out_64b, 0, (out_64_len) * sizeof(uint64_t));
    for (int i = 0; i < (OUT_N * OUT_H*OUT_W*OUT_CSTEP); i++) {
        int group = i / 8;
        int byte_pos = i % 8;
        pData_out_64b[group] |= (uint64_t)pData_out[i] << (byte_pos * 8);
        //printf("du[%d]=%d, byte_pos = %d, du_64b[%d] = %016llx\n", i, pData_out[i], byte_pos, group, pData_out_64b[group]);
    }

    printf("loading dest data into files...\n");
    FILE *file_outfeat_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/nn_transconv/outfeat_data.txt", "w");
    for (int i=0; i < OUT_BASE/8; i++) {
        fprintf(file_outfeat_data, "%016llx\n", 0);
    }
    for (int i = 0; i < (OUT_N * OUT_H*OUT_W*OUT_CSTEP)/8; i++) {
        fprintf(file_outfeat_data, "%016llx\n", pData_out_64b[i]);
    }
    fclose(file_outfeat_data);

}

int main()
{
    run_nn_trans();
    return 0;
}
