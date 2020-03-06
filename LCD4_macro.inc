;===============================================================================================
; LCD Init
			.equ 	LCD_CLR          	= 0      ; DB0: clear display
			.equ 	LCD_HOME         	= 1      ; DB1: return to home position

			.equ  	LCD_ENTRY_MODE   	= 2      ; DB2: set entry mode
			.equ 	LCD_ENTRY_INC    	= 1      ;   DB1: increment
			.equ 	LCD_ENTRY_SHIFT  	= 0      ;   DB2: shift

			.equ 	LCD_ON		      	= 3      ; DB3: turn lcd/cursor on
			.equ  	LCD_ON_DISPLAY   	= 2      ;   DB2: turn display on
			.equ  	LCD_ON_CURSOR     	= 1      ;   DB1: turn cursor on
			.equ  	LCD_ON_BLINK      	= 0      ;   DB0: blinking cursor

			.equ  	LCD_MOVE          	= 4      ; DB4: move cursor/display
			.equ 	LCD_MOVE_DISP       = 3      ;   DB3: move display (0-> move cursor)
			.equ  	LCD_MOVE_RIGHT      = 2      ;   DB2: move right (0-> left)

			.equ  	LCD_F		        = 5      ; DB5: function set
			.equ 	LCD_F_8B		   	= 4      ;   DB4: set 8BIT mode (0->4BIT mode)
			.equ  	LCD_F_2L			= 3      ;   DB3: two lines (0->one line)
			.equ  	LCD_F_10D			= 2      ;   DB2: 5x10 font (0->5x7 font)
			.equ  	LCD_CGRAM           = 6      ; DB6: set CG RAM address
			.equ  	LCD_DDRAM           = 7      ; DB7: set DD RAM address
 
			.equ	SCR_L				= 0b00011000	; Сдвиг экрана влево
			.equ	SCR_R				= 0b00011100	; Сдвиг экрана вправо
			
			.equ	CUR_L				= 0b00010000 	; Сдвиг курсора влево
			.equ	CUR_R				= 0b00010100	; Сдвиг курсора вправо
			

; Init Config
			.MACRO	INIT_LCD							; Инициализация LCD
			RCALL	InitHW								; Настроить контрольный порт

			RCALL	LCD_DELAY							; Подождать

			WR_CMD	(1<<LCD_F)|(0<<LCD_F_8B)				; Выдать функции в порт. Команда инициализации адресации ДВА РАЗА!!!
			WR_CMD	(1<<LCD_F)|(0<<LCD_F_8B)|(1<<LCD_F_2L) 	; Так как на 4 байтах нельзя передать сразу второй байт
			WR_CMD	(1<<LCD_CLR)															;0x01
			WR_CMD	(1<<LCD_ENTRY_MODE)|(1<<LCD_ENTRY_INC)									;0x06
			WR_CMD	(1<<LCD_ON)|(1<<LCD_ON_DISPLAY)|(0<<LCD_ON_CURSOR)|(0<<LCD_ON_BLINK)	;0x0C
			WR_CMD	(1<<LCD_HOME)		
			.ENDM

;===============================================================================================
;Write Data
			.MACRO	WR_DATA
			LDI		R17,@0
			RCALL	DATA_WR
			.ENDM
;===============================================================================================
;Write CMD
			.MACRO	WR_CMD
			LDI		R17,@0
			RCALL	CMD_WR
			.ENDM
;===============================================================================================
; Read Data
			.MACRO	RD_DATA
			RCALL	DATA_RD
			.ENDM
;===============================================================================================
; Read CMD
			.MACRO	RD_CMD
			RCALL	CMD_RD
			.ENDM

;===============================================================================================
;Set COORD
;Syntax LCD_COORD X,Y
			.MACRO LCD_COORD
			LDI		R17,(1<<LCD_DDRAM)|(@0+0x40*@1)
			RCALL	CMD_WR
			.ENDM
;===============================================================================================
;Shift SCREEN/CURSOR
			.MACRO	SHIFT
			LDI		R17,@0
			RCALL	CMD_WR
			.ENDM

;===============================================================================================
;LCD Clear

			.MACRO	LCDCLR
			LDI 	R17,(1<<LCD_CLR)
			RCALL	CMD_WR
			.ENDM

;===============================================================================================
;Write CGRAM
			.MACRO WR_CGADR
			LDI		R17,(1<<LCD_CGRAM)|(@0)
			RCALL	CMD_WR
			.ENDM

;Write DDRAM
			.MACRO WR_DDADR
			LDI		R17,(1<<LCD_DDRAM)|(@0)
			RCALL	CMD_WR
			.ENDM

			
