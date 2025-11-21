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

    const uint8_t uchOutZP = pstOutTensor ->nZP;  //输出数据的ZeroPoint

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

    int32_t nInFeaNum = pstLinearParam->nInFeatures;    // HWC
    int32_t nOutFeaNum = pstLinearParam->nOutFeatures;  // HWC

    int32_t nInFeaNumStep = pstLinearParam->nInFeaStep; // HWC 补齐
    int32_t nOutFeaNumStep = pstLinearParam->nOutFeaStep;   // HWC 补齐

    uint8_t *puchOut = puchOutData;
    uint8_t *puchIn = puchInData;
    uint8_t *pchKer = pchKerData;

    const uint8_t  uchBatchNum = pstLinearParam ->nBatchNum; //输入数据的batch数


    for(uint8_t nIb = 0; nIb < uchBatchNum; nIb++)
    {
        printf("Ib: %d\n",nIb);
        for (int32_t i = 0; i < nOutFeaNum; i++)
        {
            int8_t *pchKerPt = pchKer + i*nInFeaNumStep;
            //printf("pchKerPt = pchKer + %d*nInFeaNumStep\n",i);

            int32_t nSum = 0;
            for (int32_t j = 0; j < nInFeaNumStep; j++)
            {
                nSum += (int32_t)puchIn[j] *pchKerPt[j];
                //printf("nSum += (puchIn[%d]*pchKerPt[%d]\n",j + nIb*nInFeaNumStep,j + i*nInFeaNumStep);
            }

            nSum = (int32_t)((plnOutMult[i] * nSum + plnOutMultBzp[i]) >> puchOutShift[i]);
            nSum = MAX(nSum, uchActMin);
            nSum = MIN(nSum, uchActMax);
            puchOut[i] = (uint8_t)nSum;
            //printf("\n");
        }
        puchOut += nOutFeaNumStep;
        puchIn += nInFeaNumStep;
    }
    return MOCNN_OK;
}

// Test datasheet
int32_t get_fixed_random_number() { 
    return ((rand() << 16) | rand()) & 0xFFFFFFFF; 
} 
void generate_fixed_random_input(uint8_t *dest, int n, int32_t seed) {
    srand(seed); // 或者放到外面，只初始化一次
    for (int i = 0; i < n; i++) {
        dest[i] = get_fixed_random_number();
    }
}

void generate_fixed_random_input_int8(int8_t *di, uint8_t *du, int ni, int nu, int32_t seedi, int32_t seedu) {
    srand(seedi); // 或者放到外面，只初始化一次
    for (int i = 0; i < ni; i++) {
        di[i] = (int8_t)((rand() % 256) - 128);
    }
    srand(seedu);
    for (int i = 0; i < nu; i++) {
        du[i] = (uint8_t)(rand() % 256);
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

void print_bin(int32_t *arr, int row, int colunm) {
    printf("[\n");
    for (int i = 0; i < row; ++i) {          // 行
            for (int j = 0; j < colunm; ++j) {     // 列
                printf("%0x\n ", arr[i * colunm + j]);  // 下标 = 行*列数 + 列
            }
        }
    printf("]\n\n");
}

#define BATCH 2
#define IN_N BATCH
#define IN_H 2
#define IN_W 2
#define IN_C 4

#define OUT_N BATCH
#define OUT_H 4
#define OUT_W 4
#define OUT_C 2

#define IN_NUM IN_H*IN_W*IN_C
#define OUT_NUM OUT_H*OUT_W*OUT_C
#define IN_STEP IN_NUM      // todo
#define OUT_STEP OUT_NUM    // todo

#define K_N BATCH
#define K_H IN_STEP
#define K_W OUT_NUM
#define K_C 1

uint8_t pData_in[IN_N*IN_STEP] = {0};
uint8_t pData_out[OUT_N*OUT_STEP]  = {0};
int8_t pKernel[K_N*OUT_NUM*IN_STEP]  = {0};
uint64_t plnMulBzp[OUT_STEP]  = {0};
uint64_t plnMultSc[OUT_STEP]  = {0};
uint32_t puchShift[OUT_STEP]  = {0};


const mocnn_tensor my_in_tensor = {
    .nN     = IN_N  ,
    .nH     = IN_H  ,
    .nW     = IN_W  ,
    .nC     = IN_C  ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_in
};

const mocnn_tensor my_out_tensor = {
    .nN     = OUT_N ,
    .nH     = OUT_H ,
    .nW     = OUT_W ,
    .nC     = OUT_C ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pData_out
};

const mocnn_tensor my_kernel_tensor = {
    .nN     = K_N   ,
    .nC     = K_H   ,
    .nH     = K_W   ,
    .nW     = K_C   ,
    .nScale = 1     ,
    .nZP    = 0     ,
    .pData  = pKernel
};

const mocnn_linear_param my_linear_param = {
    .nBatchNum      = BATCH    , 
    .nInFeatures    = IN_NUM   ,
    .nOutFeatures   = OUT_NUM  ,
    .nInFeaStep     = IN_STEP  ,
    .nOutFeaStep    = OUT_STEP ,
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
    //generate_fixed_random_input(pData_in, IN_N * IN_STEP, 1);
    //generate_fixed_random_input(pKernel, OUT_NUM * IN_STEP, 2);
    generate_fixed_random_input_int8(pKernel, pData_in, OUT_NUM * IN_STEP, IN_N * IN_STEP, 2, 1);
    printf("pData_in = ");
    print_array(pData_in, IN_N, IN_STEP);
    for(int i=0;i<K_N;i++){
        printf("pKernel[%d] = ", i);
        print_array_signed(pKernel, IN_STEP, OUT_NUM);
    }

    for(int i=0;i<OUT_STEP;i++){
        plnMulBzp[i] = 0;
        plnMultSc[i] = 1;
        puchShift[i] = 8;
    }
    MOCNN_Linear(in_tensor, out_tensor, kernel_tensor, linear_param);
    printf("pData_out = ");
    print_array(pData_out, OUT_N, OUT_NUM);
}

int main()
{
    run_nn_linear();
    return 0;
}