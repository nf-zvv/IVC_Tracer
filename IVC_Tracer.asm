;------------------------------------------------------------------------------
; �������������� ������ ��� ���������� ������
; 
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;
; Hardware: 
; PinBoard II rev.3 by DiHalt
;
; Compile:
; avrasm2.exe -S labels.tmp -fI -W+ie -C V2E -o IVC_Tracer.hex -d IVC_Tracer.obj
;  -e IVC_Tracer.eep -m IVC_Tracer.map -l IVC_Tracer.lst IVC_Tracer.asm
;
; Burn flash via JTAG:
; avrdude -c jtag1 -P com4 -b 115200 -p m16 -U flash:w:IVC_Tracer.hex
;
; History
; =======
; 04.12.18 ������� ��� �� MCP3204, �������� ��������������� ������������
; 06.12.18 ��������� �������� ������� � EEPROM ����������� �����
; 01.03.20 ����� �������� ���� � ���������� ��������� ��� � ����������� ��������
; 01.03.20 ������� � ������� ��� ��� ������ � EEPROM
; 02.03.20 ��������� ����������� ������� (�� �� � ��) � ��������� (�� �� � ��) 
;          ���� ��� ��� �������������� ������ ���
; 
;------------------------------------------------------------------------------

#define F_CPU (11059200)

;.DEVICE ATmega16A
.NOLIST
.include "m16Adef.inc"
.include "macro.asm"
.include "eeprom_macro.asm"
.include "LCD4_macro.inc"
.include "uart_macro.asm"
.LIST

.LISTMAC ; �������� �������������� ��������




;------------------------------------------------------------------------------
; ���������� ��������
; 
; r2  - ������� �������
; r7  - ������������ ���������
;------------------------------------------------------------------------------
; ������� �������
.def __zero_reg__ = r2
; ������������ ���������
.def __enc_reg__ = r7

.equ true  = 1
.equ false = 0


; �����
.equ enc_left_spin  = 0
.equ enc_right_spin = 1
.equ btn_press      = 2
.equ btn_long_press = 3
.equ update         = 4
;-------------------------------------------
.equ UART_IN_FULL   = 0		; �������� ����� UART �����
;.equ UART_OUT_FULL  = 1		; ����� �������� UART �����
.equ UART_STR_RCV   = 2		; �������� ������ �� UART
.equ UART_CR        = 3		; ���� ��������� ���� CR (0x0D) ������� �������
;-------------------------------------------
;.equ adc_ok         = 6
;.equ need_adc       = 5
;.equ ADS1115_RDY	= 6
;-------------------------------------------

; ������� ������� UART (255 max)
.equ MAXBUFF_IN	 =	64		; ������ ��������� ������

.equ IVC_MAX_RECORDS = 100

;-------------------------------------------
;                 ������ T0                 |
;-------------------------------------------|
; ����� �� ������������ ������� � ������������
#define period_T0 1
; ���������� ���������� ��������
#define start_count_T0 (0x100-(period_T0*F_CPU/(64*1000)))
; ��������� ������������ 64
#define T0_Clock_Select (0<<CS02)|(1<<CS01)|(1<<CS00)

;-------------------------------------------
;                 ������ T1                 |
;-------------------------------------------|
; ����� �� ������������ ������� � ������������
#define period_T1 500
; ���������� ���������� ��������
#define start_count_T1 (0x10000-(period_T1*F_CPU/(1024*1000)))

;-------------------------------------------
;                    LED                    |
;-------------------------------------------|
.equ	LED_PORT	= PORTB
.equ	LED_PIN		= 3

;-------------------------------------------
;                    DAC                    |
;-------------------------------------------|
.equ	DAC_CS_PORT	= PORTB
.equ	DAC_CS_DDR	= DDRB
.equ	DAC_CS		= 4

;-------------------------------------------
;                  HW SPI                   |
;-------------------------------------------|
.equ SPI_PORT     = PORTB
.equ SPI_DDR      = DDRB
.equ SPI_PIN      = PINB
.equ SPI_SS       = 4
.equ SPI_MOSI     = 5
.equ SPI_MISO     = 6
.equ SPI_SCK      = 7


;-------------------------------------------
;                  BUTTON                   |
;-------------------------------------------|
.equ BUTTON_PORT  = PORTD
.equ BUTTON_DDR   = DDRD
.equ BUTTON_PIN   = PIND
.equ BUTTON       = PD7

;-------------------------------------------
;                 Encoder                   |
;-------------------------------------------|
.equ ENC_A        = PC6
.equ ENC_B        = PC7
.equ ENC_PORT     = PORTC
.equ ENC_DDR      = DDRC
.equ ENC_PIN      = PINC

;-----------------------------------
; ����������� LCD1602 � �� ATmega16 |
;-----------------------------------|
;        ��        |       LCD      |
;-----------------------------------|
;  PB0 ( 1 ���.)   |   RS ( 4 ���.) |
;  PB1 ( 2 ���.)   |   RW ( 5 ���.) |
;  PB2 ( 3 ���.)   |   E  ( 6 ���.) |
;  PA7 (33 ���.)   |   D7 (14 ���.) |
;  PA6 (34 ���.)   |   D6 (13 ���.) |
;  PA5 (35 ���.)   |   D5 (12 ���.) |
;  PA4 (36 ���.)   |   D4 (11 ���.) |
;-----------------------------------



#define Default_DAC_STEP       0x0005 ; 5
#define Default_IVC_DAC_START  0x0744 ; 1860
#define Default_IVC_DAC_END    0x092e ; 2350
#define Default_IVC_DAC_STEP   0x000a ; 10
#define Default_CH0_DELTA      0x09c1 ; 2497
#define Default_ADC_V_REF      0x1372 ; 4978
#define Default_ACS712_KI      0x00b9 ; 185
#define Default_RESDIV_KU      0x0001 ; 1
#define Default_VAH_DELAY      0x0032 ; 50

;===================================EEPROM=====================================
.eseg
.org 0x100
EEPROM_TEST:		.db 0 ; ��� ��������, ���� ����� 0xFF, �� EEPROM ����� � ���� �������������������
E_DAC_STEP: 		.dw Default_DAC_STEP
E_IVC_DAC_START:	.dw Default_IVC_DAC_START
E_IVC_DAC_END:		.dw Default_IVC_DAC_END
E_IVC_DAC_STEP:		.dw Default_IVC_DAC_STEP
E_CH0_DELTA:		.dw Default_CH0_DELTA
E_ADC_V_REF:		.dw Default_ADC_V_REF
E_ACS712_KI:		.dw Default_ACS712_KI
E_RESDIV_KU:		.dw Default_RESDIV_KU
E_VAH_DELAY:		.dw Default_VAH_DELAY

;====================================DATA======================================
.dseg
DAC:			.byte	2
DAC_STEP:		.byte	2
;------------------------
ButtonCounter:	.byte	2	; ���������� ����� ��� ������� ������ ��������
Flags:			.byte	1	; ����� ��� ��������
UART_Flags:		.byte	1	; ����� ��� UART
;------------------------
IVC_DAC_START:	.byte	2
IVC_DAC_END:	.byte	2
IVC_DAC_STEP:	.byte	2
;------------------------
; ����������
CH0_DELTA:		.byte	2
ADC_V_REF:		.byte	2
ACS712_KI:		.byte	2
RESDIV_KU:		.byte	2
;------------------------
VAH_DELAY:		.byte	2
;------------------------
; Zero-ended string
STRING:			.byte	30
;------------------------
IVC_ARRAY:		.byte	2*2*IVC_MAX_RECORDS
;------------------------

;====================================CODE======================================
.cseg
.org 0000
rjmp	RESET
.include "vectors_m16.inc"

;==============================================================================
;                           ����������� ����������
;                             Interrupt Handlers
;==============================================================================

;------------------------------------------------------------------------------
; ���������� UART
;------------------------------------------------------------------------------
.include "uart_irq.asm"

;------------------------------------------------------------------------------
;           ���������� ������� T0 �� ������������
;              ������������ �������� � ������
;             ������������ ������� ������ 1 ��
;------------------------------------------------------------------------------
OVF0_IRQ:
			push	r16
			in		r16,SREG
			push	r16
			push	r17
			push	r24
			push	r25

			; ����������������� �������
			ldi		r16,start_count_T0
			OutReg	TCNT0,r16

			;sbi		PORTB,1		; �������� �� ���.

			; �������� �������� ��������� ��������
			in		r16,ENC_PIN
			andi	r16,(1<<ENC_A)|(1<<ENC_B)
			swap	r16
			lsr 	r16
			lsr 	r16

			; ���� ���������� ��������� ����� �������� - �������
			mov		r17,__enc_reg__	; ��������� ������������������ ���������
			andi	r17,0b00000011	; �������� ������ ���������
			cp		r17,r16 		; ����������
			breq	OVF0_IRQ_EXIT	; �� ���������� - �������

			; ���� �� ��������� ����������
			lsl		__enc_reg__		; ��� ����
			lsl		__enc_reg__		;   ��������
			or		__enc_reg__,r16	; ��������� ����� ��������� �� �������������� �����

			; ���������� ������������ ������������������
			mov		r17,__enc_reg__
			cpi		r17,0b11100001
			brne	next_spin
			; ��������� �����
			lds		r16,Flags
			ori		r16,(1<<enc_left_spin)
			sts		Flags,r16
			clr		__enc_reg__
next_spin:
			cpi		r17,0b11010010
			brne	OVF0_IRQ_EXIT
			; ��������� �����
			lds		r16,Flags
			ori		r16,(1<<enc_right_spin)
			sts		Flags,r16
			clr		__enc_reg__
			
OVF0_IRQ_EXIT:
			;cbi		PORTB,1		; �������� �� ����.

;--------------------------- ��������� ������� �� ������ ---------------------------
			; �� ��� ���, ���� ���� btn_long_press �� �������, ���������� �������
			lds		r16,Flags
			sbrc	r16,btn_long_press
			rjmp	ovf0_exit	; ���� ���� ����������, �� �������
			; ��������� ��������� ������
			sbis	BUTTON_PIN,BUTTON
			rjmp	int1_low	; ���� ������ ������, ��������� �� int1_low
			; ���� ������ �� ������ (��� ��� ��������?)
			lds		r24,ButtonCounter+0
			lds		r25,ButtonCounter+1
			;ldi		r16,0
			;ldi		r17,0
			;cp		r24,r16
			;cpc		r25,r17
			;breq	ovf0_exit
			ldi		r16,200
			ldi		r17,0
			cp		r24,r16
			cpc		r25,r17
			brlo	too_little_ticks	; ���� ���������� ������
			; ����, ��������� ���������� �����
			; ������� ��� �������� ��������
			; ������������� ���� ��������� �������
			lds		r16,Flags
			ori		r16,(1<<btn_press)
			sts		Flags,r16
			; � �������� ButtonCounter:
too_little_ticks:
			; ���� ��������� �� 164 �����:
			; ������������ ����� �������, 
			; ���� ������ ������������
			; �������� ButtonCounter
			;clr		r16
			sts		ButtonCounter+0,__zero_reg__
			sts		ButtonCounter+1,__zero_reg__
			rjmp	ovf0_exit
int1_low:
			; ���� ������ ������ (INT1=0), �� ButtonCounter++
			lds		r24,ButtonCounter+0
			lds		r25,ButtonCounter+1
			ldi		r16,low(1000)
			ldi		r17,high(1000)
			cp		r24,r16
			cpc		r25,r17
			brsh	long_button_press	; ��������� ����� ����� (������� �������)
			; ���� ������������, ������ ����������� ������� � �������
			adiw	r24,1
			sts		ButtonCounter+0,r24
			sts		ButtonCounter+1,r25
			rjmp	ovf0_exit
long_button_press:
			; ������������� ���� �������� ������� 
			; (��������� ������ �������)
			; ���������� �����
			lds		r16,Flags
			ori		r16,(1<<btn_long_press)
			sts		Flags,r16
			; �������� ButtonCounter
			sts		ButtonCounter+0,__zero_reg__
			sts		ButtonCounter+1,__zero_reg__
ovf0_exit:
			pop		r25
			pop		r24
			pop		r17
			pop		r16
			out		SREG,r16
			pop		r16
			reti


;------------------------------------------------------------------------------
; ���������� ������������ ������� T1
; ������ �� ���������� ������� �� RTC
;------------------------------------------------------------------------------
OVF1_IRQ:
			push	r16
			in		r16,SREG
			push	r16
			;----------------
			; ������������ ����
			lds		r16,Flags
			ori		r16,(1<<update)
			sts		Flags,r16
			; ����������������� �������
			ldi		r16,high(start_count_T1)
			OutReg	TCNT1H,r16
			ldi		r16,low(start_count_T1)
			OutReg	TCNT1L,r16
			;----------------
			pop		r16
			out		SREG,r16
			pop		r16
			reti


;==============================================================================
; EEPROM code
;==============================================================================

;------------------------------------------------------------------------------
; ������������� EEPROM
;------------------------------------------------------------------------------
EEPROM_PRELOAD:
			ldi 	r16,low(EEPROM_TEST)	; ��������� ����� ������ EEPROM
			ldi 	r17,high(EEPROM_TEST)	; �� ������� ����� ��������� ����
			rcall 	EERead 					; (OUT: r18)
			cpi		r18,0xFF
			breq	EEPROM_INIT		; ���� ����� 0xFF - ������ �����, ���� ����������������
			ret 					; ����� - �������
EEPROM_INIT:
			ldi		r16,low(EEPROM_TEST)
			ldi		r17,high(EEPROM_TEST)
			clr		r18
			rcall	EEWrite
			EEPROM_WRITE_WORD E_DAC_STEP,Default_DAC_STEP
			EEPROM_WRITE_WORD E_IVC_DAC_START,Default_IVC_DAC_START
			EEPROM_WRITE_WORD E_IVC_DAC_END,Default_IVC_DAC_END
			EEPROM_WRITE_WORD E_IVC_DAC_STEP,Default_IVC_DAC_STEP
			EEPROM_WRITE_WORD E_CH0_DELTA,Default_CH0_DELTA
			EEPROM_WRITE_WORD E_ADC_V_REF,Default_ADC_V_REF
			EEPROM_WRITE_WORD E_ACS712_KI,Default_ACS712_KI
			EEPROM_WRITE_WORD E_RESDIV_KU,Default_RESDIV_KU
			EEPROM_WRITE_WORD E_VAH_DELAY,Default_VAH_DELAY
			ret

;------------------------------------------------------------------------------
; �������������� ���������� �� EEPROM � RAM
;------------------------------------------------------------------------------
EEPROM_RESTORE_VAR:
			EEPROM_READ_WORD E_DAC_STEP,DAC_STEP
			EEPROM_READ_WORD E_IVC_DAC_START,IVC_DAC_START
			EEPROM_READ_WORD E_IVC_DAC_END,IVC_DAC_END
			EEPROM_READ_WORD E_IVC_DAC_STEP,IVC_DAC_STEP
			EEPROM_READ_WORD E_CH0_DELTA,CH0_DELTA
			EEPROM_READ_WORD E_ADC_V_REF,ADC_V_REF
			EEPROM_READ_WORD E_ACS712_KI,ACS712_KI
			EEPROM_READ_WORD E_RESDIV_KU,RESDIV_KU
			EEPROM_READ_WORD E_VAH_DELAY,VAH_DELAY
			ret

;==============================================================================
; Main code
;==============================================================================
RESET:
			; Stack init
			ldi		r16, low(RAMEND)
			out		SPL, r16
			ldi		r16, high(RAMEND)
			out		SPH, r16

			; ��������� ������ � ��������� (����� ����: 80 ���� ��������)
			.include "coreinit.inc"

			; ������� �������
			clr		__zero_reg__

			; ���������� ���������� ��������
			ldi		r16,1<<ACD
			out		ACSR,r16

			; Port A Init
			ldi		r16,0b11110000
			out		DDRA,r16
			ldi		r16,0b00000000
			out		PORTA,r16

			; Port B Init
			ldi		r16,0b11111111
			out		DDRB,r16
			ldi		r16,0b00000000
			out		PORTB,r16

			; Port C Init
			ldi		r16,0b00000011
			out		DDRC,r16
			ldi		r16,0b11000011
			out		PORTC,r16

			; Port D Init
			ldi 	r16,0b00000010
			out 	DDRD,r16
			ldi 	r16,0b11000100
			out 	PORTD,r16

			sts		Flags,__zero_reg__
			sts		UART_Flags,__zero_reg__

			;---------------------
			; ������������� UART
			;---------------------
			USART_INIT
			;---------------------

			; ������������� ����������
			INIT_LCD

			; ������������� SPI
			rcall	SPI_INIT
			
			; ������������� ���
			rcall	ADC_INIT

			; ������������� ���
			rcall	DAC_INIT

			;------------------------------------------------------------------
			; ������������� ������� �0
			;------------------------------------------------------------------
			; ������������ ������� ������ 1 ��
			;clr		r16
			;out		TCCR0,r16
			; ������������� ���������� �������� �������
			ldi		r16,start_count_T0
			OutReg	TCNT0,r16
			; ���������� ���������� ������� T0 �� ������������
			InReg	r16,TIMSK
			ori		r16,(1<<TOIE0)
			OutReg	TIMSK,r16
			; ��������� ������������ 64
			ldi		r16,T0_Clock_Select
			OutReg	TCCR0,r16
			;------------------------------------------------------------------


			;------------------------------------------------------------------
			; ������������� ������� �1
			;------------------------------------------------------------------
			; ������������� ���������� �������� �������
			; �� ����� �������� ������ ����� ������� �� ������������
			ldi		r16,high(start_count_T1)
			OutReg	TCNT1H,r16
			ldi		r16,low(start_count_T1)
			OutReg	TCNT1L,r16

			; ���������� ���������� ������� �� ������������
			InReg	r16,TIMSK
			ori		r16,(1<<TOIE1)
			OutReg	TIMSK,r16

			; �������� ������ �1
			ldi		r16,5		; ��������� ������������ 1024
			OutReg	TCCR1B,r16
			;------------------------------------------------------------------


			; ������������� �������������� ������ UART
			call	UART_PARSER_INIT

			; ������������ ���������� �� EEPROM
			rcall	EEPROM_PRELOAD
			rcall	EEPROM_RESTORE_VAR

			sei ; ��������� ����������

			; ��������� 'Start' � UART
			;rcall	UART_START

			; ��������� ��������
			sts		ButtonCounter+0,__zero_reg__
			sts		ButtonCounter+1,__zero_reg__

			; ��������� ��������
			sts		DAC+0,__zero_reg__
			sts		DAC+1,__zero_reg__


;------------------------------------------------------------------------------
; ������� ����. ��������� �����
;------------------------------------------------------------------------------
main:
			lds		r16,Flags
			sbrc	r16,enc_left_spin
			rcall	DEC_DAC

			lds		r16,Flags
			sbrc	r16,enc_right_spin
			rcall	INC_DAC

			lds		r16,Flags
			sbrc	r16,btn_long_press
			rcall	BTN_LONG_PRESS_EVENT

			lds		r16,Flags
			sbrc	r16,btn_press
			rcall	BTN_PRESS_EVENT

			lds		r16,Flags
			sbrc	r16,update
			rcall	UPDATE_ALL

			lds		r16,UART_Flags
			sbrc	r16,UART_STR_RCV
			rcall	UART_RX_PARSE

			; �� ������ ������ �� ������������ �������� ������
			lds		r16,UART_Flags
			sbrc	r16,UART_IN_FULL
			rcall	UART_RX_PARSE

			rjmp	main


;------------------------------------------------------------------------------
; ��������������� ������� �� ������
;------------------------------------------------------------------------------
BTN_PRESS_EVENT:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			rcall	SCREEN_0
			rcall	SCREEN_1
			rcall	SCREEN_2
			rcall	SCREEN_3
			; �������� ����
			; 1. ��� �������� ��� ���
			; 2. ��������� �������� ��� ��� �����
			; 3. �������� �������� ��� ��� �����
			; 4. ��� ��� ��� �����
			; ������������� ������������
			ret

;------------------------------------------------------------------------------
; ��� �������� ��� ���
;------------------------------------------------------------------------------
SCREEN_0:
			LCDCLR				; ������� ������
			LCD_COORD 4,0		; ������
			; ������� ������ �� �������
			ldi		ZL,low(DAC_step_const*2)
			ldi		ZH,high(DAC_step_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; ������
			WR_DATA '<'
			lds		XL,DAC_STEP+0
			lds		XH,DAC_STEP+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; ��������� �������
SCREEN_0_EVENT_LOOP:
			lds		r16,Flags
			sbrc	r16,enc_left_spin
			rcall	DEC_DAC_STEP
			sbrc	r16,enc_right_spin
			rcall	INC_DAC_STEP
			sbrc	r16,btn_press
			rjmp	SCREEN_0_EXIT
			rjmp	SCREEN_0_EVENT_LOOP
SCREEN_0_EXIT:
			ldi		r16,low(E_DAC_STEP+0)
			ldi		r17,high(E_DAC_STEP+0)
			lds		r18,DAC_STEP+0
			rcall	EEWrite
			ldi		r16,low(E_DAC_STEP+1)
			ldi		r17,high(E_DAC_STEP+1)
			lds		r18,DAC_STEP+1
			rcall	EEWrite
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; ������� ������
			ret

;------------------------------------------------------------------------------
; ��������� �������� ��� ��� �����
;------------------------------------------------------------------------------
SCREEN_1:
			LCDCLR				; ������� ������
			LCD_COORD 0,0		; ������
			; ������� ������ �� �������
			ldi		ZL,low(IVC_DAC_start_const*2)
			ldi		ZH,high(IVC_DAC_start_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; ������
			WR_DATA '<'
			lds		XL,IVC_DAC_START+0
			lds		XH,IVC_DAC_START+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; ��������� �������
SCREEN_1_EVENT_LOOP:
			lds		r16,Flags
			sbrc	r16,enc_left_spin
			rcall	DEC_IVC_DAC_START
			sbrc	r16,enc_right_spin
			rcall	INC_IVC_DAC_START
			sbrc	r16,btn_press
			rjmp	SCREEN_1_EXIT
			rjmp	SCREEN_1_EVENT_LOOP
SCREEN_1_EXIT:
			ldi		r16,low(E_IVC_DAC_START+0)
			ldi		r17,high(E_IVC_DAC_START+0)
			lds		r18,IVC_DAC_START+0
			rcall	EEWrite
			ldi		r16,low(E_IVC_DAC_START+1)
			ldi		r17,high(E_IVC_DAC_START+1)
			lds		r18,IVC_DAC_START+1
			rcall	EEWrite
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; ������� ������
			ret


;------------------------------------------------------------------------------
; �������� �������� ��� ��� �����
;------------------------------------------------------------------------------
SCREEN_2:
			LCDCLR				; ������� ������
			LCD_COORD 0,0		; ������
			; ������� ������ �� �������
			ldi		ZL,low(IVC_DAC_end_const*2)
			ldi		ZH,high(IVC_DAC_end_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; ������
			WR_DATA '<'
			lds		XL,IVC_DAC_END+0
			lds		XH,IVC_DAC_END+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; ��������� �������
SCREEN_2_EVENT_LOOP:
			lds		r16,Flags
			sbrc	r16,enc_left_spin
			rcall	DEC_IVC_DAC_END
			sbrc	r16,enc_right_spin
			rcall	INC_IVC_DAC_END
			sbrc	r16,btn_press
			rjmp	SCREEN_2_EXIT
			rjmp	SCREEN_2_EVENT_LOOP
SCREEN_2_EXIT:
			ldi		r16,low(E_IVC_DAC_END+0)
			ldi		r17,high(E_IVC_DAC_END+0)
			lds		r18,IVC_DAC_END+0
			rcall	EEWrite
			ldi		r16,low(E_IVC_DAC_END+1)
			ldi		r17,high(E_IVC_DAC_END+1)
			lds		r18,IVC_DAC_END+1
			rcall	EEWrite
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; ������� ������
			ret


;------------------------------------------------------------------------------
; ��� ��� ��� �����
;------------------------------------------------------------------------------
SCREEN_3:
			LCDCLR				; ������� ������
			LCD_COORD 0,0		; ������
			; ������� ������ �� �������
			ldi		ZL,low(IVC_DAC_step_const*2)
			ldi		ZH,high(IVC_DAC_step_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; ������
			WR_DATA '<'
			lds		XL,IVC_DAC_STEP+0
			lds		XH,IVC_DAC_STEP+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; ��������� �������
SCREEN_3_EVENT_LOOP:
			lds		r16,Flags
			sbrc	r16,enc_left_spin
			rcall	DEC_IVC_DAC_STEP
			sbrc	r16,enc_right_spin
			rcall	INC_IVC_DAC_STEP
			sbrc	r16,btn_press
			rjmp	SCREEN_3_EXIT
			rjmp	SCREEN_3_EVENT_LOOP
SCREEN_3_EXIT:
			ldi		r16,low(E_IVC_DAC_STEP+0)
			ldi		r17,high(E_IVC_DAC_STEP+0)
			lds		r18,IVC_DAC_STEP+0
			rcall	EEWrite
			ldi		r16,low(E_IVC_DAC_STEP+1)
			ldi		r17,high(E_IVC_DAC_STEP+1)
			lds		r18,IVC_DAC_STEP+1
			rcall	EEWrite
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; ������� ������
			ret

;------------------------------------------------------------------------------
; IVC_DAC_START
;------------------------------------------------------------------------------
DEC_IVC_DAC_START:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_START+0		; �����������
			lds		r25,IVC_DAC_START+1
			lds		r26,DAC_STEP+0	; ����������
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_IVC_DAC_START_TO_ZERO
			rcall	DECREMENT2	; ��������� � r25:r24
			rjmp	DEC_IVC_DAC_START_SET
DEC_IVC_DAC_START_TO_ZERO:
			; ���� ����������� ������ �����������, �� ������ �������� �����������
			clr		r24
			clr		r25
DEC_IVC_DAC_START_SET:
			sts		IVC_DAC_START+0,r24
			sts		IVC_DAC_START+1,r25
			LCD_COORD 6,1		; ������
			lds		XL,IVC_DAC_START+0
			lds		XH,IVC_DAC_START+1
			rcall	DEC4_TO_LCD
DEC_IVC_DAC_START_EXIT:
			ret
;------------------------------------------------------------------------------
INC_IVC_DAC_START:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_START+0
			lds		r25,IVC_DAC_START+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; ���������� ��� � �������� �������� ���
			rcall	INCREMENT2	; ��������� � r25:r24
			; ���������, �� ��������� �� ��������� 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_IVC_DAC_START_SET
			; ���� ���������, �� ������������� ������������� 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_IVC_DAC_START_SET:
			; ��������� ���������
			sts		IVC_DAC_START+0,r24
			sts		IVC_DAC_START+1,r25
			; ������� �������� �� �������
			LCD_COORD 6,1		; ������
			lds		XL,IVC_DAC_START+0
			lds		XH,IVC_DAC_START+1
			rcall	DEC4_TO_LCD
INC_IVC_DAC_START_EXIT:
			ret
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; IVC_DAC_END
;------------------------------------------------------------------------------
DEC_IVC_DAC_END:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_END+0		; �����������
			lds		r25,IVC_DAC_END+1
			lds		r26,DAC_STEP+0	; ����������
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_IVC_DAC_END_TO_ZERO
			rcall	DECREMENT2	; ��������� � r25:r24
			rjmp	DEC_IVC_DAC_END_SET
DEC_IVC_DAC_END_TO_ZERO:
			; ���� ����������� ������ �����������, �� ������ �������� �����������
			clr		r24
			clr		r25
DEC_IVC_DAC_END_SET:
			sts		IVC_DAC_END+0,r24
			sts		IVC_DAC_END+1,r25
			LCD_COORD 6,1		; ������
			lds		XL,IVC_DAC_END+0
			lds		XH,IVC_DAC_END+1
			rcall	DEC4_TO_LCD
DEC_IVC_DAC_END_EXIT:
			ret
;------------------------------------------------------------------------------
INC_IVC_DAC_END:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_END+0
			lds		r25,IVC_DAC_END+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; ���������� ��� � �������� �������� ���
			rcall	INCREMENT2	; ��������� � r25:r24
			; ���������, �� ��������� �� ��������� 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_IVC_DAC_END_SET
			; ���� ���������, �� ������������� ������������� 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_IVC_DAC_END_SET:
			; ��������� ���������
			sts		IVC_DAC_END+0,r24
			sts		IVC_DAC_END+1,r25
			; ������� �������� �� �������
			LCD_COORD 6,1		; ������
			lds		XL,IVC_DAC_END+0
			lds		XH,IVC_DAC_END+1
			rcall	DEC4_TO_LCD
INC_IVC_DAC_END_EXIT:
			ret
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; IVC_DAC_STEP
;------------------------------------------------------------------------------
DEC_IVC_DAC_STEP:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_STEP+0		; �����������
			lds		r25,IVC_DAC_STEP+1
			lds		r26,DAC_STEP+0	; ����������
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_IVC_DAC_STEP_TO_ZERO
			rcall	DECREMENT2	; ��������� � r25:r24
			rjmp	DEC_IVC_DAC_STEP_SET
DEC_IVC_DAC_STEP_TO_ZERO:
			; ���� ����������� ������ �����������, �� ������ �������� �����������
			clr		r24
			clr		r25
DEC_IVC_DAC_STEP_SET:
			sts		IVC_DAC_STEP+0,r24
			sts		IVC_DAC_STEP+1,r25
			LCD_COORD 6,1		; ������
			lds		XL,IVC_DAC_STEP+0
			lds		XH,IVC_DAC_STEP+1
			rcall	DEC4_TO_LCD
DEC_IVC_DAC_STEP_EXIT:
			ret
;------------------------------------------------------------------------------
INC_IVC_DAC_STEP:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_STEP+0
			lds		r25,IVC_DAC_STEP+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; ���������� ��� � �������� �������� ���
			rcall	INCREMENT2	; ��������� � r25:r24
			; ���������, �� ��������� �� ��������� 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_IVC_DAC_STEP_SET
			; ���� ���������, �� ������������� ������������� 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_IVC_DAC_STEP_SET:
			; ��������� ���������
			sts		IVC_DAC_STEP+0,r24
			sts		IVC_DAC_STEP+1,r25
			; ������� �������� �� �������
			LCD_COORD 6,1		; ������
			lds		XL,IVC_DAC_STEP+0
			lds		XH,IVC_DAC_STEP+1
			rcall	DEC4_TO_LCD
INC_IVC_DAC_STEP_EXIT:
			ret
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; ��������� �������� ���� �� 1
;------------------------------------------------------------------------------
DEC_DAC_STEP:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC_STEP+0	; ����������
			lds		r25,DAC_STEP+1
			ldi		r26,1
			ldi		r27,0
			cp		r24,r26
			cpc		r25,r27
			breq	DEC_DAC_STEP_EXIT
			rcall	DECREMENT2
			sts		DAC_STEP+0,r24
			sts		DAC_STEP+1,r25
			LCD_COORD 6,1		; ������
			lds		XL,DAC_STEP+0
			lds		XH,DAC_STEP+1
			rcall	DEC4_TO_LCD
DEC_DAC_STEP_EXIT:
			ret


;------------------------------------------------------------------------------
; ��������� �������� ���� �� 1
;------------------------------------------------------------------------------
INC_DAC_STEP:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC_STEP+0
			lds		r25,DAC_STEP+1
			ldi		r26,1
			ldi		r27,0
			; ���������� ��� � �������� �������� ���
			rcall	INCREMENT2	; ��������� � r25:r24
			; ���������, �� ��������� �� ��������� 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_DAC_STEP_SET
			; ���� ���������, �� ������������� ������������� 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_DAC_STEP_SET:
			; ��������� ���������
			sts		DAC_STEP+0,r24
			sts		DAC_STEP+1,r25
			; ������� �������� �� �������
			LCD_COORD 6,1		; ������
			lds		XL,DAC_STEP+0
			lds		XH,DAC_STEP+1
			rcall	DEC4_TO_LCD
INC_DAC_STEP_EXIT:
			ret


;------------------------------------------------------------------------------
; ���������� ������� �� ������
; ��������� �������������� ������ ��� ���������� ������
; ���������� �� 29.02.2020:
;   ���� ��������� �������� ��� ����� ������ ���������, ����� 
;   �������� ��� �� ���������� ���� �� ����� ���������� ��������.
;   ��� ������� � ��� �����, ����� ���� �� ����� �� � ����� ��
; 03.03.2020 ��������� ��������� ����������� ����� �������������� ����������
;
; ������: FLASH_CONST_TO_LCD, DAC_SET, ADC_RUN, PRINT_IVC_DATA_TO_UART,
;         WaitMiliseconds, ������������ ��� ������ � ��������
; ������������: r3*, r4*, r12*, r13*, r16*, r17*, r22*, r23*, r24*, r25*, X*, Y*, Z*
; ����: -
; �����: IVC_ARRAY
;------------------------------------------------------------------------------
BTN_LONG_PRESS_EVENT:
			; ��������� ������ �������� � ������
			clr		r16
			OutReg	TCCR0,r16
			cli
			; ����� �����
			lds		r16,Flags
			andi	r16,~((1 << btn_long_press) | (1 << btn_press))
			sts		Flags,r16
			; ��������� ������� �������� ���
			lds		r16,DAC+0
			push	r16
			lds		r16,DAC+1
			push	r16
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; ������� �������� �� �������
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			LCDCLR				; ������� ������
			LCD_COORD 0,0		; ������
			ldi		ZL,low(Send_data_to_PC_const*2)
			ldi		ZH,high(Send_data_to_PC_const*2)
			rcall	FLASH_CONST_TO_LCD
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; ����������, ������������� ����������
; ��������� ����������� � ������ IVC_ARRAY
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			; ��������� ��������� ��������
			lds		r22,IVC_DAC_START+0
			lds		r23,IVC_DAC_START+1
			lds		r24,IVC_DAC_STEP+0
			lds		r25,IVC_DAC_STEP+1
			lds		r12,IVC_DAC_END+0
			lds		r13,IVC_DAC_END+1
			; ������, ���� ��������� ����������
			ldi		YL,low(IVC_ARRAY)
			ldi		YH,high(IVC_ARRAY)
			clr		r3	; ������� ���������
			; ���������� ��������� � �������� �������� ���
			cp		r22,r12
			cpc		r23,r13
			brlo	VAH_LOOP_FORWARD
			mov		r4,__zero_reg__ ; ���� IVC_DAC_START > IVC_DAC_END
			rjmp	VAH_LOOP
VAH_LOOP_FORWARD:
			ldi		r16,1           ; ���� IVC_DAC_START < IVC_DAC_END
			mov		r4,r16
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; ���� ���������
; ������������� �������� ��� � ��������� ��������� ���� � ����������
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
VAH_LOOP:
			; 1. ������������� ����� �������� ���
			sts		DAC+0,r22
			sts		DAC+1,r23
			rcall	DAC_SET
			; 2. �������� ����� ����� �������� (��� ���������� �����. ���������)
			lds		r16,VAH_DELAY
			;ldi		r16,50
			rcall	WaitMiliseconds		; [���������� �������� r16 � X]
			; 3. ��������� �������� ������� ���
			rcall	ADC_RUN
			; 4. ��������� ��������� � ������
			lds		r16,ADC_CH0+1
			st		Y+,r16
			lds		r16,ADC_CH0+0
			st		Y+,r16
			; 6. ��������� ��������� � IVC_ARRAY
			lds		r16,ADC_CH2+1
			st		Y+,r16
			lds		r16,ADC_CH2+0
			st		Y+,r16
			; ����������� ������� ����� ���������
			inc		r3
			; ���������� ����������� ��������� ���
			tst		r4
			brne	VAH_LOOP_INC
			breq	VAH_LOOP_DEC
VAH_LOOP_INC:
			; ���� ��������� ��������
			; r23:r22 = r23:r22 + r25:r24
			add		r22,r24
			adc		r23,r25
			; �������� (�� ����� �� �� �����?)
			cp		r22,r12		; �� ������� �� � IVC_DAC_END
			cpc		r23,r13
			brlo	VAH_LOOP
			rjmp	VAH_LOOP_END
VAH_LOOP_DEC:
			; ���� ��������� ��������
			; r23:r22 = r23:r22 - r25:r24
			sub		r22,r24
			sbc		r23,r25
			; �������� (�� ����� �� �� �����?)
			cp		r22,r12		; �� ������� �� � IVC_DAC_END
			cpc		r23,r13
			brsh	VAH_LOOP
VAH_LOOP_END:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; ������� �� ������� ���������� ������ �����
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			LCD_COORD 2,1		; ������
			mov		r16,r3
			rcall	Bin1ToBCD3
			mov		r17,BCD_1
			subi	r17,-0x30	; ������������� ����� � ASCII ���
			rcall	DATA_WR
			mov		r17,BCD_2
			subi	r17,-0x30	; ������������� ����� � ASCII ���
			rcall	DATA_WR
			mov		r17,BCD_3
			subi	r17,-0x30	; ������������� ����� � ASCII ���
			rcall	DATA_WR
			ldi		ZL,low(points_const*2)
			ldi		ZH,high(points_const*2)
			rcall	FLASH_CONST_TO_LCD
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; �������� ����������� �� ��������� �� UART
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			rcall	PRINT_IVC_DATA_TO_UART
			; ��������������� �������� ��� �� �����������
			pop		r16
			sts		DAC+1,r16
			pop		r16
			sts		DAC+0,r16
			rcall	DAC_SET
			; ��������� ��������
			ldi		r16,250
			rcall	WaitMiliseconds		; ���������� �������� r16 � X
			ldi		r16,250
			rcall	WaitMiliseconds		; ���������� �������� r16 � X
			LCDCLR				; ������� ������
			sei
			; �������� ������ �������� � ������
			ldi		r16,T0_Clock_Select
			OutReg	TCCR0,r16
			ret


;------------------------------------------------------------------------------
; �������� ����������� �� ��������� �� UART
; 
; ������: DEC_TO_STR5, DEC_TO_STR7, Calculate_current, Calculate_voltage, 
;         STRING_TO_UART
; ������������:
; ����: IVC_ARRAY
; �����: <UART>
;------------------------------------------------------------------------------
PRINT_IVC_DATA_TO_UART:
			; ��������� ��������� ��������
			lds		r22,IVC_DAC_START+0
			lds		r23,IVC_DAC_START+1
			lds		r24,IVC_DAC_STEP+0
			lds		r25,IVC_DAC_STEP+1
			lds		r12,IVC_DAC_END+0
			lds		r13,IVC_DAC_END+1
			; ������ � �������
			ldi		ZL,low(IVC_ARRAY)
			ldi		ZH,high(IVC_ARRAY)
			; ���������� ��������� � �������� �������� ���
			cp		r22,r12
			cpc		r23,r13
			brlo	PRINT_IVC_DATA_TO_UART_FORWARD
			ldi		r16,0
			mov		r4,r16     ; ���� IVC_DAC_START > IVC_DAC_END
			rjmp	PRINT_IVC_DATA_TO_UART_LOOP
PRINT_IVC_DATA_TO_UART_FORWARD:
			ldi		r16,1
			mov		r4,r16     ; ���� IVC_DAC_START < IVC_DAC_END
PRINT_IVC_DATA_TO_UART_LOOP:
			; �������������� ��� ������ DAC
			mov		XL,r22
			mov		XH,r23
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR5
			; ���� ������� ��������� ������ � ������! ��� 0 �����
			ld		r16,-Y
			; ����������� - ���������
			ldi		r16,9
			st		Y+,r16
			; �������������� ��� ������ ���
			ld		r16,Z+ ; ��������� ������� ���� ���
			ld		r17,Z+ ; ��������� ������� ���� ���
			rcall	Calculate_current ; (IN: r17:r16, OUT: r19:r18)
			; ������������� � ������
			mov		XL,r18
			mov		XH,r19
			;ldi		YL,low(STRING)
			;ldi		YH,high(STRING)
			rcall	DEC_TO_STR7
			; ���� ������� ��������� ������ � ������! ��� 0 �����
			ld		r16,-Y
			; ����������� - ���������
			ldi		r16,9
			st		Y+,r16
			; �������������� ��� ������ ����������
			ld		r16,Z+	; ������� ���� ���
			ld		r17,Z+	; ������� ���� ���
			rcall	Calculate_voltage ; (IN: r17:r16, OUT: r19:r18)
			; ������������� � ������
			mov		XL,r18
			mov		XH,r19
			;ldi		YL,low(STRING)
			;ldi		YH,high(STRING)
			rcall	DEC_TO_STR7_VOLT
			; ���� ������� ��������� ������ � ������! ��� 0 �����
			ld		r16,-Y
			; ����� ������
			ldi		r16,13
			st		Y+,r16
			ldi		r16,10
			st		Y+,r16
			clr		r16
			st		Y+,r16
			; ��������� ����� �� UART
			ldi		XL,low(STRING)
			ldi		XH,high(STRING)
			rcall	STRING_TO_UART
			; ������ ����� ��������� ��� ��������� r23:r22
			; ��������� �� ��������� ��, ��� ��������, �� ����� �� ���� ��������� ��������
			; � ��� ������������� ��������� �� �������� �����
			tst		r4
			brne	PRINT_IVC_DATA_TO_UART_INC
			breq	PRINT_IVC_DATA_TO_UART_DEC
PRINT_IVC_DATA_TO_UART_INC:
			; ���� ���:
			; r23:r22 = r23:r22 + r25:r24
			add		r22,r24
			adc		r23,r25
			; ���������� ��������� � �������� �������� ���
			cp		r22,r12
			cpc		r23,r13
			brlo	PRINT_IVC_DATA_TO_UART_LOOP
			rjmp	PRINT_IVC_DATA_TO_UART_EXIT
PRINT_IVC_DATA_TO_UART_DEC:
			; ���� ��� ���:
			; r23:r22 = r23:r22 - r25:r24
			sub		r22,r24
			sbc		r23,r25
			; ���������� ��������� � �������� �������� ���
			cp		r22,r12
			cpc		r23,r13
			brsh	PRINT_IVC_DATA_TO_UART_LOOP
PRINT_IVC_DATA_TO_UART_EXIT:
			ret


;------------------------------------------------------------------------------
; ���������� ���
; - ��������� �������� �� ���
; - ������������� ����� �������� (DAC_SET)
; - ������� ����� �������� �� �������
;------------------------------------------------------------------------------
DEC_DAC:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC+0		; �����������
			lds		r25,DAC+1
			lds		r26,DAC_STEP+0	; ����������
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_DAC_TO_ZERO
			rcall	DECREMENT2	; ��������� � r25:r24
			rjmp	DEC_DAC_SET
DEC_DAC_TO_ZERO:
			; ���� ����������� ������ �����������, �� ������ �������� �����������
			clr		r24
			clr		r25
DEC_DAC_SET:
			sts		DAC+0,r24
			sts		DAC+1,r25
			rcall	DAC_SET
			LCD_COORD 0,0		; ������
			lds		XL,DAC+0
			lds		XH,DAC+1
			rcall	DEC4_TO_LCD
DEC_DAC_EXIT:
			ret


;------------------------------------------------------------------------------
; ���������� ���
; - ����������� �������� �� ���
; - ������������� ����� �������� (DAC_SET)
; - ������� ����� �������� �� ������
;------------------------------------------------------------------------------
INC_DAC:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC+0
			lds		r25,DAC+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; ���������� ��� � �������� �������� ���
			rcall	INCREMENT2	; ��������� � r25:r24
			; ���������, �� ��������� �� ��������� 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_DAC_SET
			; ���� ���������, �� ������������� ������������� 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_DAC_SET:
			; ��������� ���������
			sts		DAC+0,r24
			sts		DAC+1,r25
			; �������� �������� ����������
			rcall	DAC_SET
			; ������� �������� �� �������
			LCD_COORD 0,0		; ������
			lds		XL,DAC+0
			lds		XH,DAC+1
			rcall	DEC4_TO_LCD
INC_DAC_EXIT:
			ret


;------------------------------------------------------------------------------
; �������� ��� �������� �� �������
;------------------------------------------------------------------------------
UPDATE_ALL:
			; ����� �����
			cli
			lds		r16,Flags
			andi	r16,~(1 << update)
			sts		Flags,r16
			sei
			; �������� ���������
			sbi		LED_PORT,LED_PIN
			cli
			; ������� �������� ��� �� �������
			LCD_COORD 0,0		; ������
			lds		XL,DAC+0
			lds		XH,DAC+1
			rcall	DEC4_TO_LCD
; ������� ���0, ���1, ���2 � ����������� �� 16 ��������
			rcall	ADC_RUN
; �������� �������� ������ ��� (��� ���������� ������)
			; ������� BEGIN
			; ������ ������� ������ �������� � ���������, �������
			; ����� �������� ��������� ���������� ��� �������� 
			; (�.�. ������ �.�. ���������� �����)
			; ���� ������������ �� ���� � DEC_TO_STR7,
			; ����� ���������� ������ ���� ������������� �����
			LCD_COORD 11,0		; ������
			ldi		r17,' '		; ������
			rcall	DATA_WR		; �������
			; ������� END
			; �������������� ��� ������ ���
			lds		r16,ADC_CH0+1 ; ��������� ������� ���� ���
			lds		r17,ADC_CH0+0 ; ��������� ������� ���� ���
			rcall	Calculate_current ; (IN: r17:r16, OUT: r19:r18)
			; ������������� � ������
			mov		XL,r18
			mov		XH,r19
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR7
			LCD_COORD 5,0		; ������
			; ������� ������ �� �������
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	STR_TO_LCD

; �������� ������� ������ ��� (���������� ������������)
			; ��������� � ����������
			lds		r16,ADC_CH1+1	; ������� ���� ���
			lds		r17,ADC_CH1+0	; ������� ���� ���
			ldi		r18,low(2442)
			ldi		r19,high(2442)
			rcall	mul16u		; in[r16-r19], out[r22-r25]
			rcall	Bin3BCD16	; in[r22-r24], out[r25-r28]
			LCD_COORD 0,1		; ������
			rcall	BCD_TO_LCD_2

; �������� ������� ������ ��� (���������� ���������� ������)
			; ������� BEGIN
			; ������ ������� ������ �������� � ���������, �������
			; ����� �������� ��������� ���������� ��� �������� 
			; (�.�. ������ �.�. ���������� �����)
			; ���� ������������ �� ���� � DEC_TO_STR7,
			; ����� ���������� ������ ���� ������������� �����
			LCD_COORD 11,1		; ������
			ldi		r17,' '		; ������
			rcall	DATA_WR		; �������
			; ������� END
			; �������������� ��� ������ ����������
			lds		r16,ADC_CH2+1	; ������� ���� ���
			lds		r17,ADC_CH2+0	; ������� ���� ���
			rcall	Calculate_voltage ; (IN: r17:r16, OUT: r19:r18)
			; ������������� � ������
			mov		XL,r18
			mov		XH,r19
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			;rcall	DEC_TO_STR5
			rcall	DEC_TO_STR7_VOLT
			LCD_COORD 6,1		; ������
			; ������� ������ �� �������
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	STR_TO_LCD

			sei
			; ����� ���������
			cbi		LED_PORT,LED_PIN
			ret


;------------------------------------------------------------------------------
; �������������� ���� ��� � �����������
;
; Current_mA = (((ADC_code * ADC_V_REF / 4096) - CH0_DELTA) * 1000) / ACS712_KI
; 
; ��������� �� 1000 ����� ���������� ��-�� ����, ��� ����������� ACS712_KI 
; ��������� �������� �� �� � �, � ��� ����� ��.
;
; MCP3204 - 12-������ ���. ������������ �������� ADC_code = 4095
; ������� ���������� ��� ADC_V_REF = 5000 ��

; TODO: ������� ���������� (ADC_code * ADC_V_REF / 4096)
;
; CALLS:
; USED: 
; IN: r17:r16
; OUT: r19:r18
;------------------------------------------------------------------------------
Calculate_current:
			push	r22
			push	r23
			push	r24
			push	r25
			; �������������� ���� ��� � �����������
			; �������� �� �������� �������� ���������� � ��
			lds		r18,ADC_V_REF+0
			lds		r19,ADC_V_REF+1
			rcall	mul16u   ; (IN: r17:r16, r19:r18, OUT: r25:r24:r23:r22)
			; �������� �� ����������� ���
			rcall	DIV_4096 ; (IN, OUT: r25:r24:r23:r22)
			; ������� ��������
			mov		r20,r22
			mov		r21,r23
			lds		r24,CH0_DELTA+0
			lds		r25,CH0_DELTA+1
			sub		r20,r24
			sbc		r21,r25
			; ��������� �� 1000
			; IN: r21:r20, r19:r18
			; OUT: r25:r24:r23:r22
			ldi		r18,low(1000)
			ldi		r19,high(1000)
			rcall	muls16x16_32 ; (IN: r21:r20, r19:r18, OUT: r25:r24:r23:r22)
			; �������
			lds		r18,ACS712_KI
			ldi		r19,0x00	; 0
			ldi		r20,0x00	; 0
			ldi		r21,0x00	; 0
			rcall	__divmodsi4 ; (OUT: r21:r20:r19:r18)
			pop		r25
			pop		r24
			pop		r23
			pop		r22
			ret


;------------------------------------------------------------------------------
; �������������� ���� ��� � �����������
; 
; Voltage_mV = ADC_code * ADC_V_REF / 4096 * RESDIV_KU
; 
; CALLS:
; USED: 
; IN: r17:r16
; OUT: r19:r18
;------------------------------------------------------------------------------
Calculate_voltage:
			push	r22
			push	r23
			push	r24
			push	r25
			; �������������� ���� ��� � �����������
			; �������� �� �������� �������� ���������� � ��
			lds		r18,ADC_V_REF+0
			lds		r19,ADC_V_REF+1
			rcall	mul16u   ; (IN: r17:r16, r19:r18, OUT: r25:r24:r23:r22)
			; �������� �� ����������� ���
			rcall	DIV_4096 ; (IN, OUT: r25:r24:r23:r22)
			mov		r16,r22
			mov		r17,r23
			lds		r18,RESDIV_KU
			clr		r19
			rcall	mul16u   ; (IN: r17:r16, r19:r18, OUT: r25:r24:r23:r22)
			mov		r18,r22
			mov		r19,r23
			pop		r25
			pop		r24
			pop		r23
			pop		r22
			ret



;------------------------------------------------------------------------------
; ����� 4-�������� ����������� ����� �� �������
; ����: ����� � �������� X
;------------------------------------------------------------------------------
DEC4_TO_LCD:
			rcall	Bin2ToBCD4
			mov		r17,BCD_4
			subi	r17,-0x30	; ������������� ����� � ASCII ���
			rcall	DATA_WR
			mov		r17,BCD_5
			subi	r17,-0x30	; ������������� ����� � ASCII ���
			rcall	DATA_WR
			mov		r17,BCD_6
			subi	r17,-0x30	; ������������� ����� � ASCII ���
			rcall	DATA_WR
			mov		r17,BCD_7
			subi	r17,-0x30	; ������������� ����� � ASCII ���
			rcall	DATA_WR
			ret

;------------------------------------------------------------------------------
; ����� 4-�������� ����������� ����� � UART
; ����: ����� � �������� X
;------------------------------------------------------------------------------
;DEC4_TO_UART:
;			rcall	Bin2ToBCD4
;			mov		r16,BCD_4
;			subi	r16,-0x30	; ������������� ����� � ASCII ���
;			rcall	Buff_Push
;			mov		r16,BCD_5
;			subi	r16,-0x30	; ������������� ����� � ASCII ���
;			rcall	Buff_Push
;			mov		r16,BCD_6
;			subi	r16,-0x30	; ������������� ����� � ASCII ���
;			rcall	Buff_Push
;			mov		r16,BCD_7
;			subi	r16,-0x30	; ������������� ����� � ASCII ���
;			rcall	Buff_Push
;			ret


;-----------------------------------------------------------------------------
; �������� �� LCD ��������� �� flash ������
; ������������: r17*, Z*
; ����: Z - ��������� �� ������
; �����: LCD
;-----------------------------------------------------------------------------
FLASH_CONST_TO_LCD:
			lpm		r17,Z+					; ������ ��������� ������ �� flash
			tst		r17						; ��������, �� 0 �� ��
			breq	FLASH_CONST_TO_LCD_END	; ���� ����, �� ������ ���������
			rcall	DATA_WR					; ��������� ������ � ����� ��������
			rjmp	FLASH_CONST_TO_LCD
FLASH_CONST_TO_LCD_END:
			ret


;------------------------------------------------------------------------------
; ����� null-ended ������ �� �������
; ������������: r17*, Y*
; ����: Y - ��������� �� ������
; �����: LCD
;------------------------------------------------------------------------------
STR_TO_LCD:
			ld		r17,Y+					; ������ ��������� ������
			tst		r17						; ��������, �� 0 �� ��
			breq	STR_TO_LCD_END			; ���� ����, �� ������ ���������
			rcall	DATA_WR					; ��������� ������ � ����� ��������
			rjmp	STR_TO_LCD
STR_TO_LCD_END:
			ret


;------------------------------------------------------------------------------
; ��� ������ ���������� ������������ �� �������
;------------------------------------------------------------------------------
BCD_TO_LCD_2:
			mov		r17,r28		; ����� ������ �����
			andi	r17,0x0F	; �������� ������� �������
			subi	r17,-0x30	; ��������� � ASCII ���
			rcall	DATA_WR		; �������

			ldi		r17,'.'
			rcall	DATA_WR		; �������

			mov		r17,r27
			andi	r17,0xF0
			swap	r17
			subi	r17,-0x30	; ��������� � ASCII ���
			rcall	DATA_WR		; �������

			mov		r17,r27
			andi	r17,0x0F
			subi	r17,-0x30	; ��������� � ASCII ���
			rcall	DATA_WR		; �������
			ret




.include "math.asm"
.include "LCD4.asm"

.include "spi_hw.asm"
.include "MCP3204.asm"
.include "MCP4921.asm"
.include "wait.asm"
.include "eeprom.asm"

.include "uart_funcs.asm"
.include "strings.asm"
.include "cmd.asm"
.include "cmd_func.asm"


DAC_step_const:			.db "DAC step",0,0
IVC_DAC_start_const:	.db "IVC DAC start",0
IVC_DAC_end_const:		.db "IVC DAC end",0
IVC_DAC_step_const:		.db "IVC DAC step",0,0
Send_data_to_PC_const:	.db "Send data to PC",0
points_const:			.db " point(s)",0
