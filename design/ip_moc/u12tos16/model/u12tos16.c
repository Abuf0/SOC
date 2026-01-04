#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"

int32_t MOCE_U12TOS16(const uint16_t* src, int16_t* dst, int32_t channel, int32_t imgsize){
    uint16_t x0 = 0;
    uint16_t x1 = 0;
    uint16_t x2 = 0;
    uint16_t x3 = 0;
    const uint16_t* srcdata = src;
    for(int32_t i=0; i < channel; i++){
        for(int32_t j=0; j < imgsize; j+=4){
            x0 = srcdata[0] & 0xFFF;
            x1 = srcdata[1] & 0xFFF;
            x2 = srcdata[2] & 0xFFF;
            x3 = ((srcdata[2] & 0xF000) >> 4) | ((srcdata[1] & 0xF000) >> 8) | (srcdata[0] >> 12);
            dst[j * channel + i] = ((int16_t)x0 - 2048);
            dst[(j+1) * channel + i] = ((int16_t)x1 - 2048);
            dst[(j+2) * channel + i] = ((int16_t)x2 - 2048);
            dst[(j+3) * channel + i] = ((int16_t)x3 - 2048);
            srcdata += 3;
        }
    }
    return 0;
}

void generate_fixed_random_uint16(uint16_t *dest, int n, int32_t seed) {
    srand(seed); // 或者放到外面，只初始化一次
    for (int i = 0; i < n; i++) {
        dest[i] = (uint16_t)((rand() % 65536));
    }
}
void generate_fixed_random_int16(int16_t *dest, int n, int32_t seed) {
    srand(seed); // 或者放到外面，只初始化一次
    for (int i = 0; i < n; i++) {
        dest[i] = (int16_t)((rand() % 65536) - 32768);
    }
}

void print_array(uint16_t *arr, int row, int colunm) {
    printf("[\n");
    for (int i = 0; i < row; ++i) {          // 行
            for (int j = 0; j < colunm; ++j) {     // 列
                printf("%5d ", arr[i * colunm + j]);  // 下标 = 行*列数 + 列
            }
            printf("\n");
        }
    printf("]\n\n");
}

void print_array_signed(int16_t *arr, int row, int colunm) {
    printf("[\n");
    for (int i = 0; i < row; ++i) {          // 行
            for (int j = 0; j < colunm; ++j) {     // 列
                printf("%5d ", arr[i * colunm + j]);  // 下标 = 行*列数 + 列
            }
            printf("\n");
        }
    printf("]\n\n");
}

#define N 2
#define CHN 3
#define IMG_SIZE 4*N
#define SRC_SIZE 3*N

uint16_t src[SRC_SIZE*CHN] = {0};
int16_t dst[CHN*IMG_SIZE] = {0};

int main(){
    generate_fixed_random_uint16(src, SRC_SIZE*CHN, 1);
    print_array(src, CHN, SRC_SIZE);
    MOCE_U12TOS16(src,dst,CHN,IMG_SIZE);
    print_array_signed(dst, IMG_SIZE, CHN);
    return 0;
}