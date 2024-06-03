#include "CortexM3.h"


/****************************UART*******************************/

extern uint32_t  uart_init( UART_TypeDef * UART, uint32_t divider, uint32_t tx_en,
                           uint32_t rx_en, uint32_t tx_irq_en, uint32_t rx_irq_en, uint32_t tx_ovrirq_en, uint32_t rx_ovrirq_en);

  /**
   * @brief Returns whether the UART RX Buffer is Full.
   */

 extern uint32_t  uart_GetRxBufferFull( UART_TypeDef * UART);

  /**
   * @brief Returns whether the UART TX Buffer is Full.
   */

 extern uint32_t  uart_GetTxBufferFull( UART_TypeDef * UART);

  /**
   * @brief Sends a character to the UART TX Buffer.
   */


 extern void  uart_SendChar( UART_TypeDef * UART, char txchar);

  /**
   * @brief Receives a character from the UART RX Buffer.
   */

 extern char  uart_ReceiveChar( UART_TypeDef * UART);

  /**
   * @brief Returns UART Overrun status.
   */

 extern uint32_t  uart_GetOverrunStatus( UART_TypeDef * UART);

  /**
   * @brief Clears UART Overrun status Returns new UART Overrun status.
   */

 extern uint32_t  uart_ClearOverrunStatus( UART_TypeDef * UART);

  /**
   * @brief Returns UART Baud rate Divider value.
   */

 extern uint32_t  uart_GetBaudDivider( UART_TypeDef * UART);

  /**
   * @brief Return UART TX Interrupt Status.
   */

 extern uint32_t  uart_GetTxIRQStatus( UART_TypeDef * UART);

  /**
   * @brief Return UART RX Interrupt Status.
   */

 extern uint32_t  uart_GetRxIRQStatus( UART_TypeDef * UART);

  /**
   * @brief Clear UART TX Interrupt request.
   */

 extern void  uart_ClearTxIRQ( UART_TypeDef * UART);

  /**
   * @brief Clear UART RX Interrupt request.
   */

 extern void  uart_ClearRxIRQ( UART_TypeDef * UART);

  /**
   * @brief Set CM3DS_MPS2 Timer for multi-shoot mode with internal clock
   */

 /**************************************SYSTICK*******************************************/

extern void delay(uint32_t time);
extern void Set_SysTick_CTRL(uint32_t ctrl);
extern void Set_SysTick_LOAD(uint32_t load);
extern uint32_t Read_SysTick_VALUE(void);
extern void Set_SysTick_VALUE(uint32_t value);
extern void Set_SysTick_CALIB(uint32_t calib);
extern uint32_t Timer_Ini(void);
extern uint8_t Timer_Stop(uint32_t *duration_t,uint32_t start_t);

 /**************************************LCD*******************************************/

extern void LCD_Init(void);									
extern void LCD_DisplayOn(void);													
extern void LCD_DisplayOff(void);													
extern void LCD_Clear(uint16_t Color);	 											
extern void LCD_SetCursor(uint16_t Xpos, uint16_t Ypos);							
extern void LCD_DrawPoint(uint16_t x,uint16_t y);									
extern void LCD_Fast_DrawPoint(uint16_t x,uint16_t y,uint16_t color);							
extern uint16_t  LCD_ReadPoint(uint16_t x,uint16_t y); 										
extern void LCD_Draw_Circle(uint16_t x0,uint16_t y0,uint8_t r);						 		
extern void LCD_DrawLine(uint16_t x1, uint16_t y1, uint16_t x2, uint16_t y2);					
extern void LCD_DrawRectangle(uint16_t x1, uint16_t y1, uint16_t x2, uint16_t y2);		   		
extern void LCD_Fill(uint16_t sx,uint16_t sy,uint16_t ex,uint16_t ey,uint16_t color);		   	
extern void LCD_Color_Fill(uint16_t sx,uint16_t sy,uint16_t ex,uint16_t ey,uint16_t *color);	
extern void LCD_ShowChar(uint16_t x,uint16_t y,uint8_t num,uint8_t size,uint8_t mode);			
extern void LCD_ShowNum(uint16_t x,uint16_t y,uint32_t num,uint8_t len,uint8_t size);  					
extern void LCD_ShowxNum(uint16_t x,uint16_t y,uint32_t num,uint8_t len,uint8_t size,uint8_t mode);				
extern void LCD_ShowString(uint16_t x,uint16_t y,uint16_t width,uint16_t height,uint8_t size,uint8_t *p);		

extern void LCD_WriteReg(uint16_t LCD_Reg, uint16_t LCD_RegValue);
extern uint16_t LCD_ReadReg(uint16_t LCD_Reg);
extern void LCD_WriteRAM_Prepare(void);
extern void LCD_WriteRAM(uint16_t RGB_Code);
extern void LCD_SSD_BackLightSet(uint8_t pwm);							
extern void LCD_Scan_Dir(uint8_t dir);									
extern void LCD_Display_Dir(uint8_t dir);
extern void LCD_Set_Window(uint16_t sx,uint16_t sy,uint16_t width,uint16_t height);