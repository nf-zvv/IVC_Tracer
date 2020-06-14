;------------------------------------------------------------------------------
; Автоматическое снятие ВАХ солнечного модуля
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
; 04.12.18 Заменен АЦП на MCP3204, написаны соответствующие подпрограммы
; 06.12.18 Добавлена проверка наличия в EEPROM корректного числа
; 01.03.20 Вывод значений тока и напряжения изучамого ФЭП в натуральных единицах
; 01.03.20 Упрощен и улучшен код для работы с EEPROM
; 02.03.20 Добавлена возможность прямого (от ХХ к КЗ) и обратного (от КЗ к ХХ) 
;          хода ЦАП при автоматическом снятии ВАХ
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

.LISTMAC ; Включить разворачивание макросов




;------------------------------------------------------------------------------
; Глобальные регистры
; 
; r2  - нулевой регистр
; r7  - используется энкодером
;------------------------------------------------------------------------------
; Нулевой регистр
.def __zero_reg__ = r2
; Используется энкодером
.def __enc_reg__ = r7

.equ true  = 1
.equ false = 0


; Флаги
.equ enc_left_spin  = 0
.equ enc_right_spin = 1
.equ btn_press      = 2
.equ btn_long_press = 3
.equ update         = 4
;-------------------------------------------
.equ UART_IN_FULL   = 0		; Приемный буфер UART полон
;.equ UART_OUT_FULL  = 1		; Буфер отправки UART полон
.equ UART_STR_RCV   = 2		; Получена строка по UART
.equ UART_CR        = 3		; Флаг получения кода CR (0x0D) возврат каретки
;-------------------------------------------
;.equ adc_ok         = 6
;.equ need_adc       = 5
;.equ ADS1115_RDY	= 6
;-------------------------------------------

; Размеры буферов UART (255 max)
.equ MAXBUFF_IN	 =	64		; Размер входящего буфера

.equ IVC_MAX_RECORDS = 100

;-------------------------------------------
;                 Таймер T0                 |
;-------------------------------------------|
; время до переполнения таймера в милисекундах
#define period_T0 1
; вычисление начального значения
#define start_count_T0 (0x100-(period_T0*F_CPU/(64*1000)))
; настройка предделителя 64
#define T0_Clock_Select (0<<CS02)|(1<<CS01)|(1<<CS00)

;-------------------------------------------
;                 Таймер T1                 |
;-------------------------------------------|
; время до переполнения таймера в милисекундах
#define period_T1 500
; вычисление начального значения
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
; Подключение LCD1602 к МК ATmega16 |
;-----------------------------------|
;        МК        |       LCD      |
;-----------------------------------|
;  PB0 ( 1 выв.)   |   RS ( 4 выв.) |
;  PB1 ( 2 выв.)   |   RW ( 5 выв.) |
;  PB2 ( 3 выв.)   |   E  ( 6 выв.) |
;  PA7 (33 выв.)   |   D7 (14 выв.) |
;  PA6 (34 выв.)   |   D6 (13 выв.) |
;  PA5 (35 выв.)   |   D5 (12 выв.) |
;  PA4 (36 выв.)   |   D4 (11 выв.) |
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
EEPROM_TEST:		.db 0 ; для проверки, если равно 0xFF, то EEPROM чиста и надо проинициализировать
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
ButtonCounter:	.byte	2	; количество тиков при нажатой кнопке энкодера
Flags:			.byte	1	; флаги для энкодера
UART_Flags:		.byte	1	; флаги для UART
;------------------------
IVC_DAC_START:	.byte	2
IVC_DAC_END:	.byte	2
IVC_DAC_STEP:	.byte	2
;------------------------
; Калибровка
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
;                           Обработчики прерываний
;                             Interrupt Handlers
;==============================================================================

;------------------------------------------------------------------------------
; Обработчик UART
;------------------------------------------------------------------------------
.include "uart_irq.asm"

;------------------------------------------------------------------------------
;           Прерывание таймера T0 по переполнению
;              Обслуживание энкодера и кнопки
;             Переполнение таймера каждую 1 мс
;------------------------------------------------------------------------------
OVF0_IRQ:
			push	r16
			in		r16,SREG
			push	r16
			push	r17
			push	r24
			push	r25

			; переинициализация таймера
			ldi		r16,start_count_T0
			OutReg	TCNT0,r16

			;sbi		PORTB,1		; тестовый СД вкл.

			; поучение текущего состояния энкодера
			in		r16,ENC_PIN
			andi	r16,(1<<ENC_A)|(1<<ENC_B)
			swap	r16
			lsr 	r16
			lsr 	r16

			; если предыдущее состояние равно текущему - выходим
			mov		r17,__enc_reg__	; загружаем последовательность состояний
			andi	r17,0b00000011	; отделяем только последнее
			cp		r17,r16 		; сравниваем
			breq	OVF0_IRQ_EXIT	; не изменилось - выходим

			; если же состояние изменилось
			lsl		__enc_reg__		; два раза
			lsl		__enc_reg__		;   сдвигаем
			or		__enc_reg__,r16	; добавляем новое состояние на освободившееся место

			; сравниваем получившуюся последовательность
			mov		r17,__enc_reg__
			cpi		r17,0b11100001
			brne	next_spin
			; установка флага
			lds		r16,Flags
			ori		r16,(1<<enc_left_spin)
			sts		Flags,r16
			clr		__enc_reg__
next_spin:
			cpi		r17,0b11010010
			brne	OVF0_IRQ_EXIT
			; установка флага
			lds		r16,Flags
			ori		r16,(1<<enc_right_spin)
			sts		Flags,r16
			clr		__enc_reg__
			
OVF0_IRQ_EXIT:
			;cbi		PORTB,1		; тестовый СД выкл.

;--------------------------- Обработка нажатия на кнопку ---------------------------
			; До тех пор, пока флаг btn_long_press не сброшен, игнорируем нажание
			lds		r16,Flags
			sbrc	r16,btn_long_press
			rjmp	ovf0_exit	; если флаг установлен, то выходим
			; считываем состояние кнопки
			sbis	BUTTON_PIN,BUTTON
			rjmp	int1_low	; если кнопка нажата, переходим на int1_low
			; если кнопка не нажата (или уже отпущена?)
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
			brlo	too_little_ticks	; мало удерживали кнопку
			; итак, набралось достаточно тиков
			; считаем это коротким нажатием
			; устанавливаем флаг короткого нажатия
			lds		r16,Flags
			ori		r16,(1<<btn_press)
			sts		Flags,r16
			; и обнуляем ButtonCounter:
too_little_ticks:
			; если набралось до 164 тиков:
			; недостаточно долго держали, 
			; либо ложное срабатывание
			; обнуляем ButtonCounter
			;clr		r16
			sts		ButtonCounter+0,__zero_reg__
			sts		ButtonCounter+1,__zero_reg__
			rjmp	ovf0_exit
int1_low:
			; если кнопка нажата (INT1=0), то ButtonCounter++
			lds		r24,ButtonCounter+0
			lds		r25,ButtonCounter+1
			ldi		r16,low(1000)
			ldi		r17,high(1000)
			cp		r24,r16
			cpc		r25,r17
			brsh	long_button_press	; набралось много тиков (длинное нажатие)
			; если недостаточно, просто увеличиваем счетчик и выходим
			adiw	r24,1
			sts		ButtonCounter+0,r24
			sts		ButtonCounter+1,r25
			rjmp	ovf0_exit
long_button_press:
			; устанавливаем флаг длинного нажатия 
			; (удержание кнопки нажатой)
			; возведение флага
			lds		r16,Flags
			ori		r16,(1<<btn_long_press)
			sts		Flags,r16
			; обнуляем ButtonCounter
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
; Обработчик переполнения таймера T1
; Запрос на обновление времени из RTC
;------------------------------------------------------------------------------
OVF1_IRQ:
			push	r16
			in		r16,SREG
			push	r16
			;----------------
			; Усанавливаем флаг
			lds		r16,Flags
			ori		r16,(1<<update)
			sts		Flags,r16
			; переинициализация таймера
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
; Инициализация EEPROM
;------------------------------------------------------------------------------
EEPROM_PRELOAD:
			ldi 	r16,low(EEPROM_TEST)	; Загружаем адрес ячейки EEPROM
			ldi 	r17,high(EEPROM_TEST)	; из которой хотим прочитать байт
			rcall 	EERead 					; (OUT: r18)
			cpi		r18,0xFF
			breq	EEPROM_INIT		; если равно 0xFF - память пуста, надо инициализировать
			ret 					; иначе - выходим
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
; Восстановление переменных из EEPROM в RAM
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

			; Обнуление памяти и регистров (объем кода: 80 байт прошивки)
			.include "coreinit.inc"

			; Нулевой регистр
			clr		__zero_reg__

			; Аналоговый компаратор выключен
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
			; Инициализация UART
			;---------------------
			USART_INIT
			;---------------------

			; Инициализация индикатора
			INIT_LCD

			; Инициализация SPI
			rcall	SPI_INIT
			
			; Инициализация АЦП
			rcall	ADC_INIT

			; Инициализация ЦАП
			rcall	DAC_INIT

			;------------------------------------------------------------------
			; Инициализация таймера Т0
			;------------------------------------------------------------------
			; Переполнение таймера каждую 1 мс
			;clr		r16
			;out		TCCR0,r16
			; инициализация начального значения таймера
			ldi		r16,start_count_T0
			OutReg	TCNT0,r16
			; разрешение прерывания таймера T0 по переполнению
			InReg	r16,TIMSK
			ori		r16,(1<<TOIE0)
			OutReg	TIMSK,r16
			; Настройка предделителя 64
			ldi		r16,T0_Clock_Select
			OutReg	TCCR0,r16
			;------------------------------------------------------------------


			;------------------------------------------------------------------
			; Инициализация таймера Т1
			;------------------------------------------------------------------
			; инициализация начального значения таймера
			; от этого значения таймер будет считать до переполнения
			ldi		r16,high(start_count_T1)
			OutReg	TCNT1H,r16
			ldi		r16,low(start_count_T1)
			OutReg	TCNT1L,r16

			; разрешение прерывания таймера по переполнению
			InReg	r16,TIMSK
			ori		r16,(1<<TOIE1)
			OutReg	TIMSK,r16

			; Включить таймер Т1
			ldi		r16,5		; Установка предделителя 1024
			OutReg	TCCR1B,r16
			;------------------------------------------------------------------


			; Инициализация интерпретатора команд UART
			call	UART_PARSER_INIT

			; Восстановить переменные из EEPROM
			rcall	EEPROM_PRELOAD
			rcall	EEPROM_RESTORE_VAR

			sei ; Разрешить прерывания

			; Отправить 'Start' в UART
			;rcall	UART_START

			; Начальные значения
			sts		ButtonCounter+0,__zero_reg__
			sts		ButtonCounter+1,__zero_reg__

			; Начальные значения
			sts		DAC+0,__zero_reg__
			sts		DAC+1,__zero_reg__


;------------------------------------------------------------------------------
; Главный цикл. Проверяем флаги
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

			; на всякий случай от переполнения входного буфера
			lds		r16,UART_Flags
			sbrc	r16,UART_IN_FULL
			rcall	UART_RX_PARSE

			rjmp	main


;------------------------------------------------------------------------------
; Кратковременное нажалие на кнопку
;------------------------------------------------------------------------------
BTN_PRESS_EVENT:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			rcall	SCREEN_0
			rcall	SCREEN_1
			rcall	SCREEN_2
			rcall	SCREEN_3
			; Показать меню
			; 1. Шаг энкодера для ЦАП
			; 2. Начальное значение ЦАП для АСВАХ
			; 3. Конечное значение ЦАП для АСВАХ
			; 4. Шаг ЦАП для АСВАХ
			; Калибровочные коэффициенты
			ret

;------------------------------------------------------------------------------
; Шаг энкодера для ЦАП
;------------------------------------------------------------------------------
SCREEN_0:
			LCDCLR				; очистка экрана
			LCD_COORD 4,0		; курсор
			; Вывести строку на дисплей
			ldi		ZL,low(DAC_step_const*2)
			ldi		ZH,high(DAC_step_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; курсор
			WR_DATA '<'
			lds		XL,DAC_STEP+0
			lds		XH,DAC_STEP+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; обработка событий
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
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; очистка экрана
			ret

;------------------------------------------------------------------------------
; Начальное значение ЦАП для АСВАХ
;------------------------------------------------------------------------------
SCREEN_1:
			LCDCLR				; очистка экрана
			LCD_COORD 0,0		; курсор
			; Вывести строку на дисплей
			ldi		ZL,low(IVC_DAC_start_const*2)
			ldi		ZH,high(IVC_DAC_start_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; курсор
			WR_DATA '<'
			lds		XL,IVC_DAC_START+0
			lds		XH,IVC_DAC_START+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; обработка событий
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
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; очистка экрана
			ret


;------------------------------------------------------------------------------
; Конечное значение ЦАП для АСВАХ
;------------------------------------------------------------------------------
SCREEN_2:
			LCDCLR				; очистка экрана
			LCD_COORD 0,0		; курсор
			; Вывести строку на дисплей
			ldi		ZL,low(IVC_DAC_end_const*2)
			ldi		ZH,high(IVC_DAC_end_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; курсор
			WR_DATA '<'
			lds		XL,IVC_DAC_END+0
			lds		XH,IVC_DAC_END+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; обработка событий
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
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; очистка экрана
			ret


;------------------------------------------------------------------------------
; Шаг ЦАП для АСВАХ
;------------------------------------------------------------------------------
SCREEN_3:
			LCDCLR				; очистка экрана
			LCD_COORD 0,0		; курсор
			; Вывести строку на дисплей
			ldi		ZL,low(IVC_DAC_step_const*2)
			ldi		ZH,high(IVC_DAC_step_const*2)
			rcall	FLASH_CONST_TO_LCD
			LCD_COORD 5,1		; курсор
			WR_DATA '<'
			lds		XL,IVC_DAC_STEP+0
			lds		XH,IVC_DAC_STEP+1
			rcall	DEC4_TO_LCD
			WR_DATA '>'
			;ldi		r16,100
			;rcall	WaitMiliseconds
			; обработка событий
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
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << btn_press)
			sts		Flags,r16
			sei
			LCDCLR				; очистка экрана
			ret

;------------------------------------------------------------------------------
; IVC_DAC_START
;------------------------------------------------------------------------------
DEC_IVC_DAC_START:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_START+0		; уменьшаемое
			lds		r25,IVC_DAC_START+1
			lds		r26,DAC_STEP+0	; вычитаемое
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_IVC_DAC_START_TO_ZERO
			rcall	DECREMENT2	; результат в r25:r24
			rjmp	DEC_IVC_DAC_START_SET
DEC_IVC_DAC_START_TO_ZERO:
			; если уменьшаемое меньше вычитаемого, то просто обнуляем уменьшаемое
			clr		r24
			clr		r25
DEC_IVC_DAC_START_SET:
			sts		IVC_DAC_START+0,r24
			sts		IVC_DAC_START+1,r25
			LCD_COORD 6,1		; курсор
			lds		XL,IVC_DAC_START+0
			lds		XH,IVC_DAC_START+1
			rcall	DEC4_TO_LCD
DEC_IVC_DAC_START_EXIT:
			ret
;------------------------------------------------------------------------------
INC_IVC_DAC_START:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_START+0
			lds		r25,IVC_DAC_START+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; Прибавляем шаг к текущему значению ЦАП
			rcall	INCREMENT2	; результат в r25:r24
			; Проверяем, не превышает ли результат 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_IVC_DAC_START_SET
			; если превышает, то принудительно устанавливаем 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_IVC_DAC_START_SET:
			; Сохраняем результат
			sts		IVC_DAC_START+0,r24
			sts		IVC_DAC_START+1,r25
			; Выводим значение на дисплей
			LCD_COORD 6,1		; курсор
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
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_END+0		; уменьшаемое
			lds		r25,IVC_DAC_END+1
			lds		r26,DAC_STEP+0	; вычитаемое
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_IVC_DAC_END_TO_ZERO
			rcall	DECREMENT2	; результат в r25:r24
			rjmp	DEC_IVC_DAC_END_SET
DEC_IVC_DAC_END_TO_ZERO:
			; если уменьшаемое меньше вычитаемого, то просто обнуляем уменьшаемое
			clr		r24
			clr		r25
DEC_IVC_DAC_END_SET:
			sts		IVC_DAC_END+0,r24
			sts		IVC_DAC_END+1,r25
			LCD_COORD 6,1		; курсор
			lds		XL,IVC_DAC_END+0
			lds		XH,IVC_DAC_END+1
			rcall	DEC4_TO_LCD
DEC_IVC_DAC_END_EXIT:
			ret
;------------------------------------------------------------------------------
INC_IVC_DAC_END:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_END+0
			lds		r25,IVC_DAC_END+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; Прибавляем шаг к текущему значению ЦАП
			rcall	INCREMENT2	; результат в r25:r24
			; Проверяем, не превышает ли результат 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_IVC_DAC_END_SET
			; если превышает, то принудительно устанавливаем 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_IVC_DAC_END_SET:
			; Сохраняем результат
			sts		IVC_DAC_END+0,r24
			sts		IVC_DAC_END+1,r25
			; Выводим значение на дисплей
			LCD_COORD 6,1		; курсор
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
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_STEP+0		; уменьшаемое
			lds		r25,IVC_DAC_STEP+1
			lds		r26,DAC_STEP+0	; вычитаемое
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_IVC_DAC_STEP_TO_ZERO
			rcall	DECREMENT2	; результат в r25:r24
			rjmp	DEC_IVC_DAC_STEP_SET
DEC_IVC_DAC_STEP_TO_ZERO:
			; если уменьшаемое меньше вычитаемого, то просто обнуляем уменьшаемое
			clr		r24
			clr		r25
DEC_IVC_DAC_STEP_SET:
			sts		IVC_DAC_STEP+0,r24
			sts		IVC_DAC_STEP+1,r25
			LCD_COORD 6,1		; курсор
			lds		XL,IVC_DAC_STEP+0
			lds		XH,IVC_DAC_STEP+1
			rcall	DEC4_TO_LCD
DEC_IVC_DAC_STEP_EXIT:
			ret
;------------------------------------------------------------------------------
INC_IVC_DAC_STEP:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,IVC_DAC_STEP+0
			lds		r25,IVC_DAC_STEP+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; Прибавляем шаг к текущему значению ЦАП
			rcall	INCREMENT2	; результат в r25:r24
			; Проверяем, не превышает ли результат 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_IVC_DAC_STEP_SET
			; если превышает, то принудительно устанавливаем 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_IVC_DAC_STEP_SET:
			; Сохраняем результат
			sts		IVC_DAC_STEP+0,r24
			sts		IVC_DAC_STEP+1,r25
			; Выводим значение на дисплей
			LCD_COORD 6,1		; курсор
			lds		XL,IVC_DAC_STEP+0
			lds		XH,IVC_DAC_STEP+1
			rcall	DEC4_TO_LCD
INC_IVC_DAC_STEP_EXIT:
			ret
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Уменьшить значение шага на 1
;------------------------------------------------------------------------------
DEC_DAC_STEP:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC_STEP+0	; вычитаемое
			lds		r25,DAC_STEP+1
			ldi		r26,1
			ldi		r27,0
			cp		r24,r26
			cpc		r25,r27
			breq	DEC_DAC_STEP_EXIT
			rcall	DECREMENT2
			sts		DAC_STEP+0,r24
			sts		DAC_STEP+1,r25
			LCD_COORD 6,1		; курсор
			lds		XL,DAC_STEP+0
			lds		XH,DAC_STEP+1
			rcall	DEC4_TO_LCD
DEC_DAC_STEP_EXIT:
			ret


;------------------------------------------------------------------------------
; Увеличить значение шага на 1
;------------------------------------------------------------------------------
INC_DAC_STEP:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC_STEP+0
			lds		r25,DAC_STEP+1
			ldi		r26,1
			ldi		r27,0
			; Прибавляем шаг к текущему значению ЦАП
			rcall	INCREMENT2	; результат в r25:r24
			; Проверяем, не превышает ли результат 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_DAC_STEP_SET
			; если превышает, то принудительно устанавливаем 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_DAC_STEP_SET:
			; Сохраняем результат
			sts		DAC_STEP+0,r24
			sts		DAC_STEP+1,r25
			; Выводим значение на дисплей
			LCD_COORD 6,1		; курсор
			lds		XL,DAC_STEP+0
			lds		XH,DAC_STEP+1
			rcall	DEC4_TO_LCD
INC_DAC_STEP_EXIT:
			ret


;------------------------------------------------------------------------------
; Длительное нажалие на кнопку
; Запускает автоматическое снятие ВАХ солнечного модуля
; Дополнение от 29.02.2020:
;   Если начальное значение ЦАП будет больше конечного, тогда 
;   вычитать шаг из начального пока не будет достигнуто конечное.
;   Это сделано с оой целью, чтобы идти от точки КЗ к точке ХХ
; 03.03.2020 Проведены некоторые оптимизации после вышеуказанного дополнения
;
; Вызовы: FLASH_CONST_TO_LCD, DAC_SET, ADC_RUN, PRINT_IVC_DATA_TO_UART,
;         WaitMiliseconds, подпрограммя для работы с дисплеем
; Используются: r3*, r4*, r12*, r13*, r16*, r17*, r22*, r23*, r24*, r25*, X*, Y*, Z*
; Вход: -
; Выход: IVC_ARRAY
;------------------------------------------------------------------------------
BTN_LONG_PRESS_EVENT:
			; Отключаем таймер энкодера и кнопки
			clr		r16
			OutReg	TCCR0,r16
			cli
			; сброс флага
			lds		r16,Flags
			andi	r16,~((1 << btn_long_press) | (1 << btn_press))
			sts		Flags,r16
			; Сохраняем текущее значение ЦАП
			lds		r16,DAC+0
			push	r16
			lds		r16,DAC+1
			push	r16
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Текущее действие на дисплее
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			LCDCLR				; очистка экрана
			LCD_COORD 0,0		; курсор
			ldi		ZL,low(Send_data_to_PC_const*2)
			ldi		ZH,high(Send_data_to_PC_const*2)
			rcall	FLASH_CONST_TO_LCD
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Подготовка, инициализация переменных
; Измерения сохраняются в массив IVC_ARRAY
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			; Загружаем начальные значения
			lds		r22,IVC_DAC_START+0
			lds		r23,IVC_DAC_START+1
			lds		r24,IVC_DAC_STEP+0
			lds		r25,IVC_DAC_STEP+1
			lds		r12,IVC_DAC_END+0
			lds		r13,IVC_DAC_END+1
			; Массив, куда сохраняем результаты
			ldi		YL,low(IVC_ARRAY)
			ldi		YH,high(IVC_ARRAY)
			clr		r3	; счетчик измерений
			; Сравниваем начальное и конечное значение ЦАП
			cp		r22,r12
			cpc		r23,r13
			brlo	VAH_LOOP_FORWARD
			mov		r4,__zero_reg__ ; если IVC_DAC_START > IVC_DAC_END
			rjmp	VAH_LOOP
VAH_LOOP_FORWARD:
			ldi		r16,1           ; если IVC_DAC_START < IVC_DAC_END
			mov		r4,r16
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Цикл измерений
; Устанавливаем значение ЦАП и считываем показания тока и напряжения
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
VAH_LOOP:
			; 1. устанавливаем новое значение ЦАП
			sts		DAC+0,r22
			sts		DAC+1,r23
			rcall	DAC_SET
			; 2. задержка после смены значения (для завершения перех. процессов)
			lds		r16,VAH_DELAY
			;ldi		r16,50
			rcall	WaitMiliseconds		; [использует регистры r16 и X]
			; 3. считываем значение каналов АЦП
			rcall	ADC_RUN
			; 4. схораняем результат в память
			lds		r16,ADC_CH0+1
			st		Y+,r16
			lds		r16,ADC_CH0+0
			st		Y+,r16
			; 6. схораняем результат в IVC_ARRAY
			lds		r16,ADC_CH2+1
			st		Y+,r16
			lds		r16,ADC_CH2+0
			st		Y+,r16
			; Увеличиваем счетчик числа измерений
			inc		r3
			; Определяем направление изменения ЦАП
			tst		r4
			brne	VAH_LOOP_INC
			breq	VAH_LOOP_DEC
VAH_LOOP_INC:
			; Берём следующее значение
			; r23:r22 = r23:r22 + r25:r24
			add		r22,r24
			adc		r23,r25
			; Проверка (не дошли ли до конца?)
			cp		r22,r12		; не подошли ли к IVC_DAC_END
			cpc		r23,r13
			brlo	VAH_LOOP
			rjmp	VAH_LOOP_END
VAH_LOOP_DEC:
			; Берём следующее значение
			; r23:r22 = r23:r22 - r25:r24
			sub		r22,r24
			sbc		r23,r25
			; Проверка (не дошли ли до конца?)
			cp		r22,r12		; не подошли ли к IVC_DAC_END
			cpc		r23,r13
			brsh	VAH_LOOP
VAH_LOOP_END:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Вывести на дисплей количество снятых точек
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			LCD_COORD 2,1		; курсор
			mov		r16,r3
			rcall	Bin1ToBCD3
			mov		r17,BCD_1
			subi	r17,-0x30	; преобразовать цифру в ASCII код
			rcall	DATA_WR
			mov		r17,BCD_2
			subi	r17,-0x30	; преобразовать цифру в ASCII код
			rcall	DATA_WR
			mov		r17,BCD_3
			subi	r17,-0x30	; преобразовать цифру в ASCII код
			rcall	DATA_WR
			ldi		ZL,low(points_const*2)
			ldi		ZH,high(points_const*2)
			rcall	FLASH_CONST_TO_LCD
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Отправка результатов на компьютер по UART
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
			rcall	PRINT_IVC_DATA_TO_UART
			; Восстанавливаем значение ЦАП до экспримента
			pop		r16
			sts		DAC+1,r16
			pop		r16
			sts		DAC+0,r16
			rcall	DAC_SET
			; Небольшая задержка
			ldi		r16,250
			rcall	WaitMiliseconds		; использует регистры r16 и X
			ldi		r16,250
			rcall	WaitMiliseconds		; использует регистры r16 и X
			LCDCLR				; очистка экрана
			sei
			; Включаем таймер энкодера и кнопки
			ldi		r16,T0_Clock_Select
			OutReg	TCCR0,r16
			ret


;------------------------------------------------------------------------------
; Отправка результатов на компьютер по UART
; 
; Вызовы: DEC_TO_STR5, DEC_TO_STR7, Calculate_current, Calculate_voltage, 
;         STRING_TO_UART
; Используются:
; Вход: IVC_ARRAY
; Выход: <UART>
;------------------------------------------------------------------------------
PRINT_IVC_DATA_TO_UART:
			; Загружаем начальные значения
			lds		r22,IVC_DAC_START+0
			lds		r23,IVC_DAC_START+1
			lds		r24,IVC_DAC_STEP+0
			lds		r25,IVC_DAC_STEP+1
			lds		r12,IVC_DAC_END+0
			lds		r13,IVC_DAC_END+1
			; Массив с данными
			ldi		ZL,low(IVC_ARRAY)
			ldi		ZH,high(IVC_ARRAY)
			; Сравниваем начальное и конечное значение ЦАП
			cp		r22,r12
			cpc		r23,r13
			brlo	PRINT_IVC_DATA_TO_UART_FORWARD
			ldi		r16,0
			mov		r4,r16     ; если IVC_DAC_START > IVC_DAC_END
			rjmp	PRINT_IVC_DATA_TO_UART_LOOP
PRINT_IVC_DATA_TO_UART_FORWARD:
			ldi		r16,1
			mov		r4,r16     ; если IVC_DAC_START < IVC_DAC_END
PRINT_IVC_DATA_TO_UART_LOOP:
			; Подготавливаем для вывода DAC
			mov		XL,r22
			mov		XH,r23
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR5
			; Надо удалить последний символ в строке! Там 0 стоит
			ld		r16,-Y
			; Разделитель - табуляция
			ldi		r16,9
			st		Y+,r16
			; Подготавливаем для вывода ток
			ld		r16,Z+ ; Извлекаем младший байт АЦП
			ld		r17,Z+ ; Извлекаем старший байт АЦП
			rcall	Calculate_current ; (IN: r17:r16, OUT: r19:r18)
			; Преобразовать в строку
			mov		XL,r18
			mov		XH,r19
			;ldi		YL,low(STRING)
			;ldi		YH,high(STRING)
			rcall	DEC_TO_STR7
			; Надо удалить последний символ в строке! Там 0 стоит
			ld		r16,-Y
			; Разделитель - табуляция
			ldi		r16,9
			st		Y+,r16
			; Подготавливаем для вывода напряжение
			ld		r16,Z+	; младший байт АЦП
			ld		r17,Z+	; старший байт АЦП
			rcall	Calculate_voltage ; (IN: r17:r16, OUT: r19:r18)
			; Преобразовать в строку
			mov		XL,r18
			mov		XH,r19
			;ldi		YL,low(STRING)
			;ldi		YH,high(STRING)
			rcall	DEC_TO_STR7_VOLT
			; Надо удалить последний символ в строке! Там 0 стоит
			ld		r16,-Y
			; Конец строки
			ldi		r16,13
			st		Y+,r16
			ldi		r16,10
			st		Y+,r16
			clr		r16
			st		Y+,r16
			; Отправить число по UART
			ldi		XL,low(STRING)
			ldi		XH,high(STRING)
			rcall	STRING_TO_UART
			; Теперь нужно увеличить или уменьшить r23:r22
			; Проверить не превысило ли, или наоборот, не стало ли ниже конечного значения
			; И при необходимости вернуться на исходную метку
			tst		r4
			brne	PRINT_IVC_DATA_TO_UART_INC
			breq	PRINT_IVC_DATA_TO_UART_DEC
PRINT_IVC_DATA_TO_UART_INC:
			; Либо это:
			; r23:r22 = r23:r22 + r25:r24
			add		r22,r24
			adc		r23,r25
			; Сравниваем начальное и конечное значение ЦАП
			cp		r22,r12
			cpc		r23,r13
			brlo	PRINT_IVC_DATA_TO_UART_LOOP
			rjmp	PRINT_IVC_DATA_TO_UART_EXIT
PRINT_IVC_DATA_TO_UART_DEC:
			; Либо вот это:
			; r23:r22 = r23:r22 - r25:r24
			sub		r22,r24
			sbc		r23,r25
			; Сравниваем начальное и конечное значение ЦАП
			cp		r22,r12
			cpc		r23,r13
			brsh	PRINT_IVC_DATA_TO_UART_LOOP
PRINT_IVC_DATA_TO_UART_EXIT:
			ret


;------------------------------------------------------------------------------
; Уменьшение ЦАП
; - Уменьшает значение на шаг
; - Устанавливает новое значение (DAC_SET)
; - Выводит новое значение на дисплей
;------------------------------------------------------------------------------
DEC_DAC:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_left_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC+0		; уменьшаемое
			lds		r25,DAC+1
			lds		r26,DAC_STEP+0	; вычитаемое
			lds		r27,DAC_STEP+1
			cp		r24,r26
			cpc		r25,r27
			brlo	DEC_DAC_TO_ZERO
			rcall	DECREMENT2	; результат в r25:r24
			rjmp	DEC_DAC_SET
DEC_DAC_TO_ZERO:
			; если уменьшаемое меньше вычитаемого, то просто обнуляем уменьшаемое
			clr		r24
			clr		r25
DEC_DAC_SET:
			sts		DAC+0,r24
			sts		DAC+1,r25
			rcall	DAC_SET
			LCD_COORD 0,0		; курсор
			lds		XL,DAC+0
			lds		XH,DAC+1
			rcall	DEC4_TO_LCD
DEC_DAC_EXIT:
			ret


;------------------------------------------------------------------------------
; Увеличение ЦАП
; - Увеличивает значение на шаг
; - Устанавливает новое значение (DAC_SET)
; - Выводит новое значение на диспле
;------------------------------------------------------------------------------
INC_DAC:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << enc_right_spin)
			sts		Flags,r16
			sei
			lds		r24,DAC+0
			lds		r25,DAC+1
			lds		r26,DAC_STEP+0
			lds		r27,DAC_STEP+1
			; Прибавляем шаг к текущему значению ЦАП
			rcall	INCREMENT2	; результат в r25:r24
			; Проверяем, не превышает ли результат 4096
			ldi		r26,low(4096)
			ldi		r27,high(4096)
			cp		r24,r26
			cpc		r25,r27
			brlo	INC_DAC_SET
			; если превышает, то принудительно устанавливаем 4095
			ldi		r24,low(4095)
			ldi		r25,high(4095)
INC_DAC_SET:
			; Сохраняем результат
			sts		DAC+0,r24
			sts		DAC+1,r25
			; Передаем значение микросхеме
			rcall	DAC_SET
			; Выводим значение на дисплей
			LCD_COORD 0,0		; курсор
			lds		XL,DAC+0
			lds		XH,DAC+1
			rcall	DEC4_TO_LCD
INC_DAC_EXIT:
			ret


;------------------------------------------------------------------------------
; Обновить все значения на дисплее
;------------------------------------------------------------------------------
UPDATE_ALL:
			; сброс флага
			cli
			lds		r16,Flags
			andi	r16,~(1 << update)
			sts		Flags,r16
			sei
			; зажигаем светодиод
			sbi		LED_PORT,LED_PIN
			cli
			; Выводим значение ЦАП на дисплей
			LCD_COORD 0,0		; курсор
			lds		XL,DAC+0
			lds		XH,DAC+1
			rcall	DEC4_TO_LCD
; Считать АЦП0, АЦП1, АЦП2 с усреднением по 16 выборкам
			rcall	ADC_RUN
; значение нулевого канала АЦП (ток солнечного модуля)
			; Костыль BEGIN
			; Полная очистка экрана приводит к мерцаниям, поэтому
			; проще очистить последнее знакоместо для значения 
			; (т.к. строка м.б. переменной длины)
			; Либо позаботиться об этом в DEC_TO_STR7,
			; чтобы выдаваемая строка была фиксированной длины
			LCD_COORD 11,0		; курсор
			ldi		r17,' '		; пробел
			rcall	DATA_WR		; выводим
			; Костыль END
			; Подготавливаем для вывода ток
			lds		r16,ADC_CH0+1 ; Извлекаем младший байт АЦП
			lds		r17,ADC_CH0+0 ; Извлекаем стерший байт АЦП
			rcall	Calculate_current ; (IN: r17:r16, OUT: r19:r18)
			; Преобразовать в строку
			mov		XL,r18
			mov		XH,r19
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR7
			LCD_COORD 5,0		; курсор
			; Выводим строку на дисплей
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	STR_TO_LCD

; значение первого канала АЦП (напряжение аккумулятора)
			; переводим в миливольты
			lds		r16,ADC_CH1+1	; младший байт АЦП
			lds		r17,ADC_CH1+0	; старший байт АЦП
			ldi		r18,low(2442)
			ldi		r19,high(2442)
			rcall	mul16u		; in[r16-r19], out[r22-r25]
			rcall	Bin3BCD16	; in[r22-r24], out[r25-r28]
			LCD_COORD 0,1		; курсор
			rcall	BCD_TO_LCD_2

; значение второго канала АЦП (напряжение солнечного модуля)
			; Костыль BEGIN
			; Полная очистка экрана приводит к мерцаниям, поэтому
			; проще очистить последнее знакоместо для значения 
			; (т.к. строка м.б. переменной длины)
			; Либо позаботиться об этом в DEC_TO_STR7,
			; чтобы выдаваемая строка была фиксированной длины
			LCD_COORD 11,1		; курсор
			ldi		r17,' '		; пробел
			rcall	DATA_WR		; выводим
			; Костыль END
			; Подготавливаем для вывода напряжение
			lds		r16,ADC_CH2+1	; младший байт АЦП
			lds		r17,ADC_CH2+0	; старший байт АЦП
			rcall	Calculate_voltage ; (IN: r17:r16, OUT: r19:r18)
			; Преобразовать в строку
			mov		XL,r18
			mov		XH,r19
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			;rcall	DEC_TO_STR5
			rcall	DEC_TO_STR7_VOLT
			LCD_COORD 6,1		; курсор
			; Выводим строку на дисплей
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	STR_TO_LCD

			sei
			; гасим светодиод
			cbi		LED_PORT,LED_PIN
			ret


;------------------------------------------------------------------------------
; Преобразование кода АЦП в миллиамперы
;
; Current_mA = (((ADC_code * ADC_V_REF / 4096) - CH0_DELTA) * 1000) / ACS712_KI
; 
; Умножение на 1000 здесь необходимо из-за того, что коэффициент ACS712_KI 
; переводит значение из мВ в А, а нам нужны мА.
;
; MCP3204 - 12-битный АЦП. Максимальное значение ADC_code = 4095
; Опорное напряжение АЦП ADC_V_REF = 5000 мВ

; TODO: сделать округление (ADC_code * ADC_V_REF / 4096)
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
			; Преобразование кода АЦП в милливольты
			; Умножить на значение опорного напряжения в мВ
			lds		r18,ADC_V_REF+0
			lds		r19,ADC_V_REF+1
			rcall	mul16u   ; (IN: r17:r16, r19:r18, OUT: r25:r24:r23:r22)
			; Поделить на разрядность АЦП
			rcall	DIV_4096 ; (IN, OUT: r25:r24:r23:r22)
			; Вычесть смещение
			mov		r20,r22
			mov		r21,r23
			lds		r24,CH0_DELTA+0
			lds		r25,CH0_DELTA+1
			sub		r20,r24
			sbc		r21,r25
			; Умножение на 1000
			; IN: r21:r20, r19:r18
			; OUT: r25:r24:r23:r22
			ldi		r18,low(1000)
			ldi		r19,high(1000)
			rcall	muls16x16_32 ; (IN: r21:r20, r19:r18, OUT: r25:r24:r23:r22)
			; Деление
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
; Преобразование кода АЦП в милливольты
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
			; Преобразование кода АЦП в милливольты
			; Умножить на значение опорного напряжения в мВ
			lds		r18,ADC_V_REF+0
			lds		r19,ADC_V_REF+1
			rcall	mul16u   ; (IN: r17:r16, r19:r18, OUT: r25:r24:r23:r22)
			; Поделить на разрядность АЦП
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
; Вывод 4-значного десятичного числа на дисплей
; Вход: число в регистре X
;------------------------------------------------------------------------------
DEC4_TO_LCD:
			rcall	Bin2ToBCD4
			mov		r17,BCD_4
			subi	r17,-0x30	; преобразовать цифру в ASCII код
			rcall	DATA_WR
			mov		r17,BCD_5
			subi	r17,-0x30	; преобразовать цифру в ASCII код
			rcall	DATA_WR
			mov		r17,BCD_6
			subi	r17,-0x30	; преобразовать цифру в ASCII код
			rcall	DATA_WR
			mov		r17,BCD_7
			subi	r17,-0x30	; преобразовать цифру в ASCII код
			rcall	DATA_WR
			ret

;------------------------------------------------------------------------------
; Вывод 4-значного десятичного числа в UART
; Вход: число в регистре X
;------------------------------------------------------------------------------
;DEC4_TO_UART:
;			rcall	Bin2ToBCD4
;			mov		r16,BCD_4
;			subi	r16,-0x30	; преобразовать цифру в ASCII код
;			rcall	Buff_Push
;			mov		r16,BCD_5
;			subi	r16,-0x30	; преобразовать цифру в ASCII код
;			rcall	Buff_Push
;			mov		r16,BCD_6
;			subi	r16,-0x30	; преобразовать цифру в ASCII код
;			rcall	Buff_Push
;			mov		r16,BCD_7
;			subi	r16,-0x30	; преобразовать цифру в ASCII код
;			rcall	Buff_Push
;			ret


;-----------------------------------------------------------------------------
; Отправка на LCD константы из flash памяти
; Используются: r17*, Z*
; Вход: Z - указатель на строку
; Выход: LCD
;-----------------------------------------------------------------------------
FLASH_CONST_TO_LCD:
			lpm		r17,Z+					; изалеч очередной символ из flash
			tst		r17						; провериь, не 0 ли он
			breq	FLASH_CONST_TO_LCD_END	; если ноль, то строка кончилась
			rcall	DATA_WR					; поместить символ в буфер отправки
			rjmp	FLASH_CONST_TO_LCD
FLASH_CONST_TO_LCD_END:
			ret


;------------------------------------------------------------------------------
; Вывод null-ended строки на дисплей
; Используются: r17*, Y*
; Вход: Y - указатель на строку
; Выход: LCD
;------------------------------------------------------------------------------
STR_TO_LCD:
			ld		r17,Y+					; изалеч очередной символ
			tst		r17						; провериь, не 0 ли он
			breq	STR_TO_LCD_END			; если ноль, то строка кончилась
			rcall	DATA_WR					; поместить символ в буфер отправки
			rjmp	STR_TO_LCD
STR_TO_LCD_END:
			ret


;------------------------------------------------------------------------------
; Для вывода напряжения аккумулятора на дисплей
;------------------------------------------------------------------------------
BCD_TO_LCD_2:
			mov		r17,r28		; берем первую цифру
			andi	r17,0x0F	; обнуляем старшую тетраду
			subi	r17,-0x30	; переводим в ASCII код
			rcall	DATA_WR		; выводим

			ldi		r17,'.'
			rcall	DATA_WR		; выводим

			mov		r17,r27
			andi	r17,0xF0
			swap	r17
			subi	r17,-0x30	; переводим в ASCII код
			rcall	DATA_WR		; выводим

			mov		r17,r27
			andi	r17,0x0F
			subi	r17,-0x30	; переводим в ASCII код
			rcall	DATA_WR		; выводим
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
