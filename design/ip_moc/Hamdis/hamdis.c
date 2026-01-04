#include "hamdis.h"
#define VALPOS_DIM 2
#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define MAX(a,b) ((a) > (b) ? (a) : (b))

static uint8_t PopCnt_U32(uint32_t unBinary)
{
    uint8_t count =0;
    for(int32_t i=0;i<32;i++)
    {
        count += (unBinary >> i) & 1;
    }
    return count;
}

int32_t HammDistance(const int32_t* pnA, const int32_t* pnB, int32_t nDim)
{
    int32_t nScore1;
    //printf("pnA[0] = %d, pnB[0] = %d\n",pnA[0], pnB[0]);
    uint32_t nX1 = pnA[0] ^ pnB[0];
    nScore1 = PopCnt_U32(nX1);
    //printf("nX1 = %d, score1 = %d\n",nX1, nScore1);
    if(nDim==2)
    {
        uint32_t nX2 = pnA[1] ^ pnB[1];
        //printf("pnA[1] = %d, pnB[1] = %d\n",pnA[1], pnB[1]);
        nScore1 += PopCnt_U32(nX2);
        //printf("nX2 = %d, score1 = %d\n",nX2, nScore1);
    }
    if(nDim==3)
    {
        uint32_t nX2 = pnA[1] ^ pnB[1];
        //printf("pnA[1] = %d, pnB[1] = %d\n",pnA[1], pnB[1]);
        nScore1 += PopCnt_U32(nX2);
        //printf("nX2 = %d, score1 = %d\n",nX2, nScore1);
        uint32_t nX3 = pnA[2] ^ pnB[2];
        //printf("pnA[2] = %d, pnB[2] = %d\n",pnA[2], pnB[2]);
        nScore1 += PopCnt_U32(nX3);
        //printf("nX3 = %d, score1 = %d\n",nX3, nScore1);
    }
    return (nScore1);

}

void hamdis(const fpKeyPoint_t *pstFeat1, const fpKeyPoint_t *pstFeat2, fFixedType_t *pnMinData, fFixedType_t *pnMinPos,
            const int32_t*pnKeymapPara, int32_t nIStart, int32_t nIEnd, int32_t nJStart, int32_t nJEnd,
            uint16_t *pusDisArr, const int32_t nTh, const int32_t nDesBitLen, const int32_t nBitQMode)
{

    int32_t nPos1 = 0;
    int32_t nPos2 = nDesBitLen / 32 / 2;
    int32_t nPos3 = nDesBitLen / 32;
    int32_t nPos4 = nPos3 + nPos2;
    int32_t nHalfDesBitLen = nDesBitLen/2;
    int32_t nCalcNum = nDesBitLen /32 / 2;
    int32_t i;
    int32_t j;
    int32_t nDist1, nDist2, nTempData, nTempData1,nTempData2 = 0;
    int32_t nHammDist1= 0;
    int32_t nHammDist2=0;
    //printf("hamdis start\n");
    for(i = nIStart; i < nIEnd; i++){
        //printf("i=%d, ",i);
        const int32_t *pnFeat1Lsh = pstFeat1[i].lsh_des;
        int32_t nC = 1;
        for(j=nJStart;j<nJEnd;j++){
            //printf("j=%d, ",j);
            const int32_t *pnFeat2Lsh = pstFeat2[j].lsh_des;
            nTempData=0;
            nTempData1=0;
            printf("feat1 = %0x, feat2 = %0x\n",pnFeat1Lsh+nPos1, pnFeat2Lsh+nPos1);
            nTempData1=HammDistance(pnFeat1Lsh+nPos1,pnFeat2Lsh+nPos1,nCalcNum);\
            printf("score_pos1 = %d\n",nTempData1);
            if(nTempData1 >pnKeymapPara[0] ){
                continue;
            }
            printf("feat1 = %0x, feat2 = %0x\n",pnFeat1Lsh+nPos2, pnFeat2Lsh+nPos2);
            nDist1=HammDistance(pnFeat1Lsh+nPos2,pnFeat2Lsh+nPos2,nCalcNum);
            printf("score_pos2 = %d\n",nDist1);

            nHammDist2 = nTempData1 + (nHalfDesBitLen - nDist1);
            nHammDist1 = nTempData1 + nDist1;
            printf("Hammdist1 = %d\n", nHammDist1);
            printf("Hammdist2 = %d\n", nHammDist2);

            nTempData = MIN(nHammDist1,nHammDist2);

            if(nBitQMode==2){
                nHammDist1 = 2*nHammDist1;
                nHammDist2 = 2*nHammDist2;
                if(MIN(nHammDist1,nHammDist2) >pnKeymapPara[1] ){
                    continue;
                }
                nTempData1=HammDistance(pnFeat1Lsh+nPos3,pnFeat2Lsh+nPos3,nCalcNum);
                printf("score_pos3 = %d\n",nTempData1);
                //printf("%d, %d, %d\n", nHammDist1+nTempData1, nHammDist2+nTempData1,pnKeymapPara[2] );
                if(MIN(nHammDist1+nTempData1,nHammDist2+nTempData1) >pnKeymapPara[2] ){
                    continue;
                }
                nDist1=HammDistance(pnFeat1Lsh+nPos4,pnFeat2Lsh+nPos4,nCalcNum);
                printf("score_pos4 = %d\n",nDist1);
                nHammDist2 += nTempData1 + (nHalfDesBitLen - nDist1);
                nHammDist1 += nTempData1 + nDist1;
                printf("Hammdist1_lat = %d\n", nHammDist1);
                printf("Hammdist2_lat = %d\n", nHammDist2);

                nTempData = MAX(MIN(nHammDist1,nHammDist2),0);
                nTempData = MIN(nTempData,255);
                printf("nTempData = %d\n", nTempData);
            }
            printf("tempdata = %d\n", nTempData);
            if(nTempData <= pnKeymapPara[3] && (nC < nTh)){
                pusDisArr[i*nTh+nC] = (uint16_t)((j << 8) + nTempData);
                printf("pusDisArr[%d] = %d\n\n\n", i*nTh+nC, pusDisArr[i*nTh+nC]);
                nC++;
            }
            if(nTempData < pnMinData[VALPOS_DIM * i]){
                printf("min update, nTemp = %d, mindata = %d\n", nTempData, pnMinData[VALPOS_DIM * i]);
                pnMinData[VALPOS_DIM * i + 1] = pnMinData[VALPOS_DIM * i];
                pnMinPos[VALPOS_DIM * i + 1] = pnMinPos[VALPOS_DIM * i];
                pnMinData[VALPOS_DIM * i] = nTempData;
                pnMinPos[VALPOS_DIM * i] = j;
            }
            else if(nTempData < pnMinData[VALPOS_DIM * i + 1]){
                pnMinData[VALPOS_DIM * i + 1] = nTempData;
                pnMinPos[VALPOS_DIM * i + 1] = j;
            }
        }
            pusDisArr[i*nTh + 0] = (uint16_t)(nC);
    }
}

// Test datasheet
int32_t get_fixed_random_number() { 
    return ((rand() << 16) | rand()) & 0xFFFFFFFF; 
} 
void generate_fixed_random_input(int32_t *dest, int n, int32_t seed) {
    srand(seed); // 或者放到外面，只初始化一次
    for (int i = 0; i < n; i++) {
        dest[i] = get_fixed_random_number();
    }
}

void print_array(const int32_t *arr, int row, int colunm) {
    printf("[\n");
    for (int i = 0; i < row; ++i) {          // 行
            for (int j = 0; j < colunm; ++j) {     // 列
                printf("%11d ", arr[i * colunm + j]);  // 下标 = 行*列数 + 列
            }
            printf("\n");
        }
    printf("]\n\n");
}

void print_bin(const int32_t *arr, int row, int colunm) {
    printf("[\n");
    for (int i = 0; i < row; ++i) {          // 行
            for (int j = 0; j < colunm; ++j) {     // 列
                printf("%0x\n ", arr[i * colunm + j]);  // 下标 = 行*列数 + 列
            }
        }
    printf("]\n\n");
}

#define INUM 37
#define JNUM 128
#define BITLEN 192
#define BITQMODE 2
#define NTH 20

#define TEMP_BASE 0
#define SAMP_BASE 0
#define DIST_BASE 0
#define MIN_BASE 2000

#define PARAM_0 58   //96    
#define PARAM_1 164 //384 
#define PARAM_2 230   //480
#define PARAM_3 376   //576

#define ISEED 875
#define JSEED 3421

#define DEBUG
#define DES_LEN 12
#define IWD INUM * DES_LEN
#define JWD JNUM * DES_LEN
#define IS 0
#define IE IS+INUM
#define JS 0
#define JE JS+JNUM



int main(void) {
    int32_t DesArr1[IWD] = { 0 };
    int32_t DesArr2[JWD] = { 0 };

    generate_fixed_random_input(DesArr1 , IWD, ISEED);
    generate_fixed_random_input(DesArr2 , JWD, JSEED);
    
    //printf("DesArr1\n");
    //for(int i = 0; i < 5*12; i++) {
    //    printf("[%d] = %d\n", i, DesArr1[i]);
    //}

    fpKeyPoint_t stFeat1[INUM] = {0};
    fpKeyPoint_t stFeat2[JNUM] = {0};

    for(int i=0;i<INUM;i++){
        memcpy(stFeat1[i].lsh_des, DesArr1 + i*DES_LEN, DES_LEN*sizeof(int32_t));
    }
    for(int j=0;j<JNUM;j++){
        memcpy(stFeat2[j].lsh_des, DesArr2 + j*DES_LEN, DES_LEN*sizeof(int32_t));
    }

    // memcpy(stFeat1[0].lsh_des, DesArr1 + 0*12, 12*sizeof(int32_t));
    // memcpy(stFeat1[1].lsh_des, DesArr1 + 1*12, 12*sizeof(int32_t));
    // memcpy(stFeat1[2].lsh_des, DesArr1 + 2*12, 12*sizeof(int32_t));
    // memcpy(stFeat1[3].lsh_des, DesArr1 + 3*12, 12*sizeof(int32_t));
    // memcpy(stFeat1[4].lsh_des, DesArr1 + 4*12, 12*sizeof(int32_t));

    // memcpy(stFeat2[0].lsh_des, DesArr2 + 0*12, 12*sizeof(int32_t));
    // memcpy(stFeat2[1].lsh_des, DesArr2 + 1*12, 12*sizeof(int32_t));
    // memcpy(stFeat2[2].lsh_des, DesArr2 + 2*12, 12*sizeof(int32_t));
    // memcpy(stFeat2[3].lsh_des, DesArr2 + 3*12, 12*sizeof(int32_t));
    // memcpy(stFeat2[4].lsh_des, DesArr2 + 4*12, 12*sizeof(int32_t));

    #ifdef DEBUG
    printf("Data_1 = ");
    print_array(DesArr1, INUM, DES_LEN);
    print_bin(DesArr1, INUM, DES_LEN);
    printf("Data_2 = ");
    print_array(DesArr2, JNUM, DES_LEN);
    print_bin(DesArr2, JNUM, DES_LEN);
    #endif

    fFixedType_t MniDataArr[INUM*2];
    fFixedType_t MniPosArr[INUM*2];
    

    for(int32_t i = 0; i<INUM*2; i++){
        MniDataArr[i] = 255;//8*32;
        MniPosArr[i] = 255;//-1;
    }
    int32_t KeymapPara[4] = {PARAM_0,PARAM_1,PARAM_2,PARAM_3};
    uint16_t DisArr[INUM*NTH] = {0};

    // 64-1bit
    hamdis(stFeat1, stFeat2, MniDataArr, MniPosArr, KeymapPara, IS,IE,JS,JE, DisArr, NTH, BITLEN, BITQMODE );
    
    printf("MniDataArr = ");
    print_array(MniDataArr, 1, INUM*2);
    printf("MniPosArr = ");
    print_array(MniPosArr, 1, INUM*2);
    printf("DisArr = ");
    printf("[\n");
    for (int i = IS; i < IE; ++i) {          // 行
        for (int j = 0; j < NTH; ++j) {     // 列
            printf("%11d ", DisArr[i * NTH + j]);  // 下标 = 行*列数 + 列
        }
        printf("\n");
    }
    printf("]\n\n");
    

    FILE *file_temp_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/temp_data.txt", "w");
    FILE *file_samp_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/samp_data.txt", "w");
    for (int i=0; i < IS * DES_LEN; i++) {
        fprintf(file_temp_data, "%0x\n", 0);
    }
    for (int i = IS * DES_LEN; i < IE * DES_LEN; i++) {
	    fprintf(file_temp_data, "%0x\n", DesArr1[i]);
    }
    for (int i = 0; i < JS * DES_LEN; i++) {
        fprintf(file_samp_data, "%0x\n", 0);
    }
    for (int i = JS * DES_LEN; i < JE * DES_LEN; i++) {
        fprintf(file_samp_data, "%0x\n", DesArr2[i]);
    }
    fclose(file_temp_data);
    fclose(file_samp_data);


    FILE *file_dist_res   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/dist_res_ref.txt", "w");
    FILE *file_min_data   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/mindata_res_ref.txt", "w");
    FILE *file_min_pos   = fopen("D:/Learn/IC/project/Spinalhdl/NPU/src/main/scala/minpos_res_ref.txt", "w");

    for (int i = 0; i < IS*NTH; i++) {
	    fprintf(file_dist_res, "%d\n", 0);
    }
    for (int i = IS*NTH; i < IE*NTH; i++) {
	    fprintf(file_dist_res, "%d\n", DisArr[i-IS*NTH]);
    }
    for (int i = 0; i < IS * 2; i++) {
        fprintf(file_min_data, "%d\n", 255);
    }
    for (int i = IS*2; i < IE * 2; i++) {
        fprintf(file_min_data, "%d\n", MniDataArr[i-IS*2]);
    }
    for (int i = 0; i < IS * 2; i++) {
        fprintf(file_min_pos, "%d\n", 255);
    }
    for (int i = IS*2; i < IE * 2; i++) {
        fprintf(file_min_pos, "%d\n", MniPosArr[i-IS*2]);
    }
    fclose(file_dist_res);
    fclose(file_min_data);
    fclose(file_min_pos);

}