#include "CortexM3.h"

int main(void) {
    printf("******************\n");
    printf("cortex-m3 startup!\n");
    printf("******************\n");
    printf("lcd initial begin\n");
    uint8_t i;
    for(i = 0;i < 10;i++) {
        printf(".");
        delay(50000000);
    }
    printf("\n");
    printf("lcd working......\n");
    char buf;
    uint16_t x, y;
	uint8_t dx, dy;
    x  = y  = 0;
	dx = dy = 20;
    LCD_Fill(x, y, x + dx, y + dy, RED);
    while(1) {
        buf = uart_ReceiveChar( UART);
        LCD_Fill(x, y, x + dx, y + dy,WHITE);
        if(buf == 'w' || buf == 'W') {
            if(y >= 20) {
                y -= dy;
            }
        } else if(buf == 's' || buf == 'S') {
            if(y <= 280) {
                y += dy;
            }
        } else if(buf == 'a' || buf == 'A') {
            if(x >= 20) {
                x -= dx;
            }
        } else if(buf == 'd' || buf == 'D') {
            if(x <= 200) {
                x += dx;
            }
        }
        LCD_Fill(x, y, x + dx, y + dy, RED);
    }

}

