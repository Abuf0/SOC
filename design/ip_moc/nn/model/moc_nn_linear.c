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
                //printf("multres[%d][%d] = %d x %d = %d\n",i,j,puchIn[j] ,pchKerPt[j],puchIn[j] *pchKerPt[j]);
            }
            //printf("acc = %d\n", nSum);

            nSum = (int32_t)((plnOutMult[i] * nSum + plnOutMultBzp[i]) >> puchOutShift[i]);
            //printf("qu_res = %d\n", nSum);
            nSum = MAX(nSum, uchActMin);
            nSum = MIN(nSum, uchActMax);
            puchOut[i] = (uint8_t)nSum;
            //printf("puchOut[%d] = %d\n", i*nIb+i, puchOut[i]);
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

void generate_fixed_random_input_int8(int8_t *di, uint8_t *du, int ni, int nu, int li, int lu, int32_t seedi, int32_t seedu, uint64_t *di_64b, uint64_t *du_64b) {
    int di_64_len = (ni + 7) / 8;
    int du_64_len = (nu + 7) / 8;
    int ni_64 = di_64_len * 8;
    int nu_64 = du_64_len * 8;

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

void print_array_3_signed(int8_t *arr, int batch, int row, int colunm) {
    for (int n = 0; n < batch; n++){
        printf("[%d] = [\n", n);
        for (int i = 0; i < row; ++i) {          // 行
                for (int j = 0; j < colunm; ++j) {     // 列
                    printf("%5d ", arr[n*(row*colunm) + i * colunm + j]);  // 下标 = 行*列数 + 列
                }
                printf("\n");
            }
        printf("]\n\n");
    }
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

#define IN_BASE 0
#define K_BASE 0
#define SC_BASE 200*8
#define BZP_BASE 300*8
#define SHIFT_BASE 400*8
#define OUT_BASE 0

#define BATCH 2

#define IN_N BATCH
#define IN_H 3
#define IN_W 3
#define IN_C 2

#define OUT_N BATCH
#define OUT_H 5
#define OUT_W 5
#define OUT_C 1

#define IN_NUM IN_H*IN_W*IN_C
#define OUT_NUM OUT_H*OUT_W*OUT_C
#define IN_STEP  (((IN_NUM) + 7U) & (~7U))    // todo
#define OUT_STEP (((OUT_NUM) + 7U) & (~7U))   // todo

#define K_N BATCH
#define K_H IN_STEP
#define K_W OUT_NUM
#define K_C 1

uint8_t pData_in[IN_N*IN_STEP] = {0};
uint8_t pData_out[OUT_N*OUT_STEP]  = {0};
int8_t pKernel[OUT_NUM*IN_STEP]  = {0};
int64_t plnMulBzp[OUT_STEP]  = {0};
int64_t plnMultSc[OUT_STEP]  = {0};
uint32_t puchShift[OUT_STEP]  = {0};

uint64_t pData_in_64b[IN_N*IN_STEP/8] = {0};
uint64_t pKernel_64b[OUT_NUM*IN_STEP/8]  = {0};
uint64_t pData_out_64b[OUT_N*OUT_STEP/8] = {0};


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
    printf("start nn linear\n");
    printf("BATCH = %d, IN_NUM = %d, IN_STEP = %d, OUT_NUM = %d\n", BATCH, IN_NUM, IN_STEP, OUT_NUM);
    generate_fixed_random_input_int8(pKernel, pData_in, IN_NUM , IN_NUM, OUT_NUM, IN_N,2, 1, pKernel_64b, pData_in_64b);
    printf("pData_in = ");
    print_array(pData_in, IN_N, IN_STEP);

    printf("pKernel[n] = \n");
    print_array_signed(pKernel, IN_STEP, OUT_NUM);

    for(int i=0;i<OUT_NUM;i++){
        plnMulBzp[i] = 0;
        plnMultSc[i] = 1;
        puchShift[i] = 8;
    }

    printf("loading source data into files...\n");
    FILE *file_infeat_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/nn_linear/infeat_data.txt", "w");
    FILE *file_weight_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/nn_linear/weight_data.txt", "w");
    for (int i=0; i < IN_BASE/8; i++) {
        fprintf(file_infeat_data, "%016llx\n", 0);
    }
    for (int i = 0; i < (IN_STEP * IN_N)/8; i++) {
	    //fprintf(file_infeat_data, "%0x\n", pData_in[i]);
        fprintf(file_infeat_data, "%016llx\n", pData_in_64b[i]);
    }
    for (int i = 0; i < K_BASE/8; i++) {
        fprintf(file_weight_data, "%016llx\n", 0);
    }
    for (int i = 0; i < (IN_STEP * OUT_NUM)/8; i++) {
        //fprintf(file_weight_data, "%0x\n", pKernel[i]);
        fprintf(file_weight_data, "%016llx\n", pKernel_64b[i]);
    }
    for (int i = (IN_STEP * OUT_NUM )/8; i < SC_BASE/8; i++) {
        fprintf(file_weight_data, "%016llx\n", 0);
    }
    for (int i = 0; i < OUT_NUM; i++) {
        fprintf(file_weight_data, "%016llx\n", plnMultSc[i]);
    }
    for (int i = (SC_BASE/8 + OUT_NUM); i < BZP_BASE/8; i++) {
        fprintf(file_weight_data, "%016llx\n", 0);
    }
    for (int i = 0; i < OUT_NUM; i++) {
        fprintf(file_weight_data, "%016llx\n", plnMulBzp[i]);
    }
    for (int i = (BZP_BASE/8 + OUT_NUM); i < SHIFT_BASE/8; i++) {
        fprintf(file_weight_data, "%016llx\n", 0);
    }
    for (int i = 0; i < OUT_STEP/2; i++) {
        fprintf(file_weight_data, "%08llx%08llx\n", puchShift[i], puchShift[i+1]);
    }
    fclose(file_infeat_data);
    fclose(file_weight_data);



    MOCNN_Linear(in_tensor, out_tensor, kernel_tensor, linear_param);
    printf("pData_out = ");
    print_array(pData_out, OUT_N, OUT_STEP);

    int out_64_len = (OUT_STEP * OUT_N) / 8;
    memset(pData_out_64b, 0, (out_64_len) * sizeof(uint64_t));
    for (int i = 0; i < OUT_STEP * OUT_N; i++) {
        int group = i / 8;
        int byte_pos = i % 8;
        pData_out_64b[group] |= (uint64_t)pData_out[i] << (byte_pos * 8);
        //printf("du[%d]=%d, byte_pos = %d, du_64b[%d] = %016llx\n", i, pData_out[i], byte_pos, group, pData_out_64b[group]);
    }

    printf("loading dest data into files...\n");
    FILE *file_outfeat_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/nn_linear/outfeat_data.txt", "w");
    for (int i=0; i < OUT_BASE/8; i++) {
        fprintf(file_outfeat_data, "%016llx\n", 0);
    }
    for (int i = 0; i < (OUT_STEP * OUT_N)/8; i++) {
        fprintf(file_outfeat_data, "%016llx\n", pData_out_64b[i]);
    }
    fclose(file_outfeat_data);

}

int main()
{
    run_nn_linear();
    return 0;
}