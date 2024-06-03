#include "stdio.h"
#include "stdint.h"
#include "CMSDK_CM3.h"
#include "system_CMSDK_CM3.h"
int main(void)
{
printf("******************\n");
printf("cortex-m3 startup!\n");
printf("******************\n");
printf("test begin\n");
uint8_t x, y;
uint8_t diff, sum;
x = 3;
y = 2;
diff = x-y;
sum = x+y;
}