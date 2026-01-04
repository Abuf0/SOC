#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"

#define MOCE_MIN(a,b) ((a) < (b) ? (a) : (b))
#define MOCE_MAX(a,b) ((a) > (b) ? (a) : (b))
#define MOCE_CLIP(val, min_val, max_val) (MOCE_MIN(MOCE_MAX(val, min_val), max_val))

typedef enum emMOCEDataType
{
    MOCE_UBYTE  = 1,    // uint8
    MOCE_BYTE   = 2,    // int8
    MOCE_USHORT = 3,    // uint16
    MOCE_SHORT  = 4,    // int16
    MOCE_UWORD  = 5,    // uint32
    MOCE_WORD   = 6,    // int32
}MOCE_DATA_TYPE;

typedef enum emMOCEBorderType
{
    MOCE_BORDER_TYPE_REPLICATE, //aaaaa|abcdefg|ggggg
}MOCE_BORDER_TYPE;

#define GENERATE_MAKE_BORDER_FUNC(Data_T, FuncName) \
static int32_t FuncName(const Data_T* pkunSrc, Data_T* punDst, const uint16_t uskHeight,    \
    const uint16_t uskWidth, const uint16_t uskTop, const uint16_t uskBottom,   \
    const uint16_t uskLeft, const uint16_t uskRight,    \
    MOCE_BORDER_TYPE emMOCEBorderType, const uint32_t unkValue) \
{\
    int32_t i, j;\
    const Data_T* pkunSrcTmp = pkunSrc;\
    Data_T* punDstTmp = punDst;\
    int32_t nDstStep = uskWidth + uskLeft + uskRight;\
    punDstTmp = punDst + nDstStep * uskTop;\
    uint32_t unBorVal;\
    for(i=0; i < uskHeight; i++)\
    {\
        unBorVal = pkunSrcTmp[0];\
        for(j = 0; j < uskLeft; j++)\
        {\
            punDstTmp[j] = unBorVal;\
        }\
        punDstTmp += uskLeft;\
        memcpy(punDstTmp, pkunSrcTmp, uskWidth * sizeof(Data_T));\
        punDstTmp += uskWidth;\
        pkunSrcTmp += uskWidth;\
        unBorVal = pkunSrcTmp[-1];\
        for(j = 0; j < uskRight; ++j)   \
        {\
            punDstTmp[j] = unBorVal;    \
        }\
        punDstTmp += uskRight;  \
    }\
    Data_T* punDstTmp1 = punDst + nDstStep * uskTop;    \
    Data_T* punDstTmp2 = punDst;\
    int32_t nCpyLen = (int32_t)(nDstStep * sizeof(Data_T)); \
    for(i=0; i < uskTop; ++i)\
    {\
        memcpy(punDstTmp2, punDstTmp1, nCpyLen);    \
        punDstTmp2 += nDstStep; \
    }\
    punDstTmp1 = punDst + nDstStep * (uskTop + uskHeight - 1);    \
    punDstTmp2 = punDstTmp1 + nDstStep;\
    for(i=0; i < uskBottom; ++i)\
    {\
        memcpy(punDstTmp2, punDstTmp1, nCpyLen);    \
        punDstTmp2 += nDstStep; \
    }\
    return 0;\
}
GENERATE_MAKE_BORDER_FUNC(uint32_t, MOCE_MakeBorderU32);
GENERATE_MAKE_BORDER_FUNC(uint16_t, MOCE_MakeBorderU16);
GENERATE_MAKE_BORDER_FUNC(uint8_t, MOCE_MakeBorderU8);


static void DataWiden(int64_t *pdst, void *psrc, int32_t num, MOCE_DATA_TYPE dType){
    if(dType == MOCE_UBYTE){
        uint8_t *puch = psrc;
        for(int32_t i = 0; i < num ; i++){
            *pdst++ = *puch++;
        }
    }
    else if(dType == MOCE_BYTE){
        int8_t *puch = psrc;
        for(int32_t i = 0; i < num ; i++){
            *pdst++ = *puch++;
        }        
    }
    else if(dType == MOCE_USHORT){
        uint16_t *puch = psrc;
        for(int32_t i = 0; i < num ; i++){
            *pdst++ = *puch++;
        }        
    }
    else if(dType == MOCE_SHORT){
        int16_t *puch = psrc;
        for(int32_t i = 0; i < num ; i++){
            *pdst++ = *puch++;
        }        
    }
    else if(dType == MOCE_UWORD){
        uint32_t *puch = psrc;
        for(int32_t i = 0; i < num ; i++){
            *pdst++ = *puch++;
        }        
    }
    if(dType == MOCE_WORD){
        int32_t *puch = psrc;
        for(int32_t i = 0; i < num ; i++){
            *pdst++ = *puch++;
        }        
    }
    else {
        return;
    }
}

static void DataNarrow(void *pdst, int64_t *psrc, int32_t num, MOCE_DATA_TYPE dType){
    if(dType == MOCE_UBYTE){
        uint8_t *puch = pdst;
        for(int32_t i = 0; i < num ; i++){
            puch[i] = MOCE_CLIP(psrc[i], 0, UINT8_MAX);
        }
    }
    else if(dType == MOCE_BYTE){
        int8_t *pch = pdst;
        for(int32_t i = 0; i < num ; i++){
            pch[i] = MOCE_CLIP(psrc[i], INT8_MIN, INT8_MAX);
        }        
    }
    else if(dType == MOCE_USHORT){
        uint16_t *pus = pdst;
        for(int32_t i = 0; i < num ; i++){
            pus[i] = MOCE_CLIP(psrc[i], 0, UINT16_MAX);
        }        
    }
    else if(dType == MOCE_SHORT){
        int16_t *ps = pdst;
        for(int32_t i = 0; i < num ; i++){
            ps[i] = MOCE_CLIP(psrc[i], INT16_MIN, INT16_MAX);
        }        
    }
    else if(dType == MOCE_UWORD){
        uint32_t *pun = pdst;
        for(int32_t i = 0; i < num ; i++){
            pun[i] = MOCE_CLIP(psrc[i], 0, UINT32_MAX);
        }        
    }
    if(dType == MOCE_WORD){
        int32_t *pn = pdst;
        for(int32_t i = 0; i < num ; i++){
            pn[i] = MOCE_CLIP(psrc[i], INT32_MIN, INT32_MAX);
        }        
    }
    else {
        return;
    }
}

void MOCE_BoxFilterKernel(void *input, void *output, uint16_t width, uint16_t height, uint8_t rx, uint8_t ry, MOCE_DATA_TYPE dType, int64_t **linebuffer, int64_t *outbuffer, int64_t *psum){
   int32_t winsizex = 2 * rx + 1;
   int32_t winsizey = 2 * ry + 1;
   int32_t winarea = winsizex * winsizey;
   int32_t halfwinarea = winarea >> 1;
   int32_t typesize = 0;
    if(MOCE_WORD == dType || MOCE_UWORD == dType) { typesize = 4;}
    else if(MOCE_SHORT == dType || MOCE_USHORT == dType) { typesize = 2;}
    else { typesize = 1;}
    for(int32_t i = 0; i < winsizey; i++){
        DataWiden(linebuffer[i], (uint8_t*)input + i * width * typesize, width, dType);
    }

    for (int32_t j = 0; j < width; j++){
        psum[j] = 0;
        for(int32_t i = 0; i < winsizey; i++){
            psum[j] += linebuffer[i][j];
        }
    }

    for (int32_t y = 0; y < height - 2 * ry; y++){
        int64_t filter_sum = 0;
        for (int32_t x = 0; x < width - 2 * rx; x++){
            if(x==0){
                filter_sum = 0;
                for (int32_t k = 0; k < winsizex; k++){
                    filter_sum += psum[k];
                }
            }
            else {
                filter_sum = filter_sum - psum[x-1] + psum[x + winsizex - 1];
            }
            outbuffer[x] = (filter_sum + halfwinarea) / (winarea);
        }
        // write out
        int32_t outw = (width - 2 * rx);
        DataNarrow((uint8_t*)output + y * outw * typesize, outbuffer, outw, dType);
        if(y + winsizey < height){
            int32_t idx = y % winsizey;
            for(int32_t j = 0; j < width; j++){
                psum[j] -= linebuffer[idx][j];
            }

            DataWiden(linebuffer[idx], (uint8_t*)input + (y + winsizey) * width * typesize, width, dType);

            for(int32_t j = 0; j < width; j++){
                psum[j] += linebuffer[idx][j];
            }
        }



    }

}

void MOCE_BoxFilter(void *input, void *output, uint16_t width, uint16_t height, uint8_t rx, uint8_t ry, MOCE_DATA_TYPE dType){
    uint16_t wext = width + 2 * rx;
    uint16_t hext = height + 2 * ry;
    int32_t typesize = 0;
    if(MOCE_WORD == dType || MOCE_UWORD == dType) { typesize = 4;}
    else if(MOCE_SHORT == dType || MOCE_USHORT == dType) { typesize = 2;}
    else { typesize = 1;}
    // img padding
    void *pimgext = malloc(wext * hext * typesize);
    if(typesize == 4){
        MOCE_MakeBorderU32((uint32_t *)input, (uint32_t *)pimgext, height, width, ry, ry, rx, rx, MOCE_BORDER_TYPE_REPLICATE, 0);
    } else if(typesize == 2){
        MOCE_MakeBorderU16((uint16_t *)input, (uint16_t *)pimgext, height, width, ry, ry, rx, rx, MOCE_BORDER_TYPE_REPLICATE, 0);
    } else {
        MOCE_MakeBorderU8((uint8_t *)input, (uint8_t *)pimgext, height, width, ry, ry, rx, rx, MOCE_BORDER_TYPE_REPLICATE, 0);
    }
    // malloc line buffer, signed 33bit / pixel, use int64_t for C implemention
    int32_t winsizex = 2 * rx + 1;
    int32_t winsizey = 2 * ry + 1;
    int64_t **linebuffer = (int64_t **)malloc(winsizey * sizeof(int64_t *));
    for (int32_t i = 0; i < winsizey; i++){
        linebuffer[i] = (int64_t *)malloc(wext * sizeof(int64_t));
    }
    int64_t *outbuffer = (int64_t *)malloc(wext * sizeof(int64_t));
    // sum buffer signed 40 bit / pixel, use int64_t for C implemention
    int64_t *psum = (int64_t *)malloc(wext * sizeof(int64_t));
    // do filtering
    MOCE_BoxFilterKernel(pimgext, output ,wext, hext, rx, ry, dType, linebuffer, outbuffer, psum);

    free(pimgext);
    for(int32_t i = 0; i < winsizey; i++){
        free(linebuffer[i]);
    }
    free(linebuffer);
    free(outbuffer);
    free(psum);
}



#define WIDTH 12
#define HEIGHT 12
#define DATA_TYPE int32_t
#define RX 5
#define RY 5

int main()
{
    DATA_TYPE src1[WIDTH * HEIGHT];
    DATA_TYPE dst1[WIDTH * HEIGHT];
    DATA_TYPE dst2[WIDTH * HEIGHT];
    memset(src1, 0, WIDTH * HEIGHT * sizeof(DATA_TYPE));
    for(int32_t i = 0; i < WIDTH * HEIGHT; i++){
        src1[i] = i;//rand() % 101 - 50;//16384 + 8192;
    }

    //MOCE_BoxFilter(src1, dst1, WIDTH, HEIGHT, RX, RY, MOCE_BORDER_TYPE_REPLICATE, 0, MOCE_SHORT);
    MOCE_BoxFilter(src1, dst1, WIDTH, HEIGHT, RX, RY, MOCE_SHORT);

    printf("src_data = \n");
    for (int row = 0; row < HEIGHT; row++){
        for (int col = 0; col < WIDTH; col++){
            printf("%d\t", src1[row * WIDTH + col]);
        }
        printf("\n");
    }

    printf("\ndst_data = \n");
    for (int row = 0; row < HEIGHT; row++){
        for (int col = 0; col < WIDTH; col++){
            printf("%d\t", dst1[row * WIDTH + col]);
        }
        printf("\n");
    }
    printf("\n");
    //int32_t res = memcmp(dst1, dst2, WIDTH * HEIGHT * sizeof(DATA_TYPE));
    //if(res){
    //    printf("test fail\n");
    //}
    //else {
    //    printf("test success\n");
    //}
    //getchar();

    return 0;
}