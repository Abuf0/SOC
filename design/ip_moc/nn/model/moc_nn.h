//#ifndef _MOC_NN_H_
//#define _MOC_NN_H_

#include <stdint.h>
#include <string.h>
//#ifdef __cplusplus
//extern "C" {
//#endif

#define MOCNN_OK                ((int32_t)0x00)
#define MOCNN_FAIL              ((int32_t)0x01)
#define MOCNN_NULL_PTR          ((int32_t)0x02)
#define MOCNN_INVALID_PARAM     ((int32_t)0x03)
#define MOCNN_OUT_OF_MEM        ((int32_t)0x04)
#define MOCNN_NO_IMPLEMENT      ((int32_t)0x05)
#define MOCNN_INVALID_LAYOUT    ((int32_t)0x06)

#define MIN(a,b)    (a<b ? a : b)
#define MAX(a,b)    (a>b ? a : b)

#define FLOAT32_QUANT 0

    typedef struct
    {
        int32_t nN; // 1~128
        int32_t nC; // max 512?(128)
        int32_t nH; // 包括padding
        int32_t nW; // max 256
        int32_t nScale;
        int32_t nZP;
        int32_t nMuliSc;
        uint8_t uchShift;
        int32_t nCStep;

        void *  pData;
    } mocnn_tensor;

    typedef struct
    {
        uint8_t uchKernelH;
        uint8_t uchKernelW;
        uint8_t uchStrideH;
        uint8_t uchStrideW;

        uint8_t uchDilationH;   // 空洞卷积
        uint8_t uchDilationW;

        uint8_t uchPadX;
        uint8_t uchPadY;

        uint16_t usGroupNum;  // 卷积分组数量
        uint16_t usChPerGroup;
        uint8_t uchActValue;  // 卷积之后是否跟着激活函数

    #if FLOAT32_QUANT
        float *pfScaleSum;
        float *pfBzp;
    #else
        int64_t *plnMulBzp;
        int64_t *plnMultSc;
        uint8_t *puchShift;
    #endif

    } mocnn_conv_param;

    typedef struct
    {
        int32_t nBatchNum;
        int32_t nInFeatures;    // = C*H*W
        int32_t nOutFeatures;
        int32_t nInFeaStep;     // = H*W
        int32_t nOutFeaStep;

        uint8_t uchActValue;  // 0-1

    #if FLOAT32_QUANT
        float *pfScaleSum;
        float *pfBzp;
    #else

        int64_t *plnMulBzp;
        int64_t *plnMultSc;
        uint8_t *puchShift;
    #endif

    } mocnn_linear_param;

    typedef struct
    {
        uint8_t uchOpType;
        uint8_t uchActValue;
    } mocnn_elementwise_param;
    
    typedef struct
    {
        uint8_t uchUpScFactor;  // 0~3

    } mocnn_pixelshffle_param;

    typedef struct
    {
        uint8_t uchDim; // 范围0-3，CHW
        int64_t llMulBzp;
        int64_t llMultSc;
        int64_t uchShift;   // 0-64

    } mocnn_activation_param;

    typedef struct
    {
        uint8_t uchActValue; // 范围0-1
        int32_t nNormShape; // 最大是C*H*W

    #if FLOAT32_QUANT
        float *pfScaleSum;
        float *pfBzp;
    #else
        int64_t *plnMulBzp;
        int64_t *plnMultSc;   
        uint8_t *puchShift; // 0-64
    #endif

    } mocnn_layernorm_param;

    int32_t MOCNN_Conv(
        const mocnn_tensor *pstInTensor,
        const mocnn_tensor *pstOutTensor,
        const mocnn_tensor *pstKerTensor,
        const mocnn_conv_param *pstConvParam
    );
    
    int32_t MOCNN_ConvOpt(
        const mocnn_tensor *pstInTensor,
        const mocnn_tensor *pstOutTensor,
        const mocnn_tensor *pstKerTensor,
        const mocnn_conv_param *pstConvParam
    );

    int32_t MOCNN_DWConv(
        const mocnn_tensor *pstInTensor,
        const mocnn_tensor *pstOutTensor,
        const mocnn_tensor *pstKerTensor,
        const mocnn_conv_param *pstConvParam
    );

    int32_t MOCNN_TransposeConv(
        const mocnn_tensor *pstInTensor,
        const mocnn_tensor *pstOutTensor,
        const mocnn_tensor *pstKerTensor,
        const mocnn_conv_param *pstConvParam
    );

    int32_t MOCNN_Linear(
        const mocnn_tensor *pstInTensor,
        const mocnn_tensor *pstOutTensor,
        const mocnn_tensor *pstKerTensor,
        const mocnn_linear_param *pstLinearParam
    );

    int32_t MOCNN_Elementwise(
        const mocnn_tensor *pstInTensor0, 
        const mocnn_tensor *pstInTensor1,
        const mocnn_tensor *pstOutTensor, 
        const mocnn_elementwise_param * pstElewiseParam
    );
    
    int32_t MOCNN_Softmax(
        const mocnn_tensor *pstInTensor, 
        const mocnn_tensor *pstOutTensor, 
        const mocnn_activation_param * pstSoftmaxParam
    );
//#ifdef __cplusplus
//}
//#endif
//#endif