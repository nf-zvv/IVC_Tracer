;------------------------------------------------------------------------------
; Функции для работы с UART
; 
; Функция Buff_Pop для работы с кольцевым буфером UART
; 
; 
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;------------------------------------------------------------------------------
#ifndef _UART_FUNCS_ASM_
#define _UART_FUNCS_ASM_

.ifndef __zero_reg__
.def __zero_reg__ = r2
.endif

;------------------------------------------------------------------------------
; Read from loop Buffer
; USED: r16*,r18,r19*,XL,XH
; IN: NONE
; OUT: 	R16 - Data,
;       R19
;           = 1 - пустой буфер (больше нечего читать), 
;           = 0 - в буфере есть данные
;------------------------------------------------------------------------------
Buff_Pop:
			push	XL
			push	XH
			push	r18
			LDI		XL,low(IN_buff)		; Берем адрес начала буффера
			LDI		XH,high(IN_buff)
			LDS		R16,IN_PTR_E		; Берем смещение точки записи
			LDS		R18,IN_PTR_S		; Берем смещение точки чтения			

			; Берм флаг переполнения
			; Если буффер переполнен, то указатель начала
			; равен указателю конца. Это надо учесть.
			BRFS	UART_Flags,UART_IN_FULL,NeedPop

			CP		R18,R16				; Указатель чтения достиг указателя записи?
			BRNE	NeedPop				; Нет! Буффер не пуст. Работаем дальше

			LDI		R19,1				; Код ошибки - пустой буффер!

			RJMP	Buff_Pop_END		; Выходимs

NeedPop:
			; Сбрасываем флаг переполнения
			CLFL	UART_Flags,UART_IN_FULL

			ADD		XL,R18				; Сложением адреса со смещением
			ADC		XH,__zero_reg__		; получаем адрес точки чтения

			LD		R16,X				; Берем байт из буффера
			CLR		R19					; Сброс кода ошибки

			INC		R18					; Увеличиваем смещение указателя чтения

			CPI		R18,MAXBUFF_IN		; Достигли конца кольца?
			BRNE	Buff_Pop_OUT		; Нет? 
			
			CLR		R18					; Да? Сбрасываем, переставляя на 0

Buff_Pop_OUT:	
			STS		IN_PTR_S,R18		; Сохраняем указатель
Buff_Pop_END:
			pop		r18
			pop		XH
			pop		XL
			ret


;-----------------------------------------------
; UART SENT
;     отправка символа в UART
; используемые регистры - r16 (не изм.)
; входной регистр - r16
; выходной регистр - нет
;-----------------------------------------------
uart_snt:
			SBIS 	UCSRA,UDRE		; Пропуск если нет флага готовности
			RJMP	uart_snt 		; ждем готовности - флага UDRE
 			OUT		UDR,r16		; шлем байт!
			RET


;------------------------------------------------------------------------------
; Send null-terminated RAM string to UART
;
; USED: r16*, X*
; CALL: uart_snt
; IN: X - pointer to null-terminated string
; OUT: -
;------------------------------------------------------------------------------
STRING_TO_UART:
			ld		r16,X+
			tst		r16
			breq	STRING_TO_UART_END	; end of string
			; Send data
			rcall	uart_snt
			rjmp	STRING_TO_UART
STRING_TO_UART_END:
			ret


;------------------------------------------------------------------------------
; Send null-terminated Flash string to UART
;
; USED: r16*, Z*
; CALL: uart_snt
; IN: Z - pointer to null-terminated string
; OUT: -
;------------------------------------------------------------------------------
FLASH_CONST_TO_UART:
			lpm		r16,Z+
			tst		r16
			breq	STRING_TO_UART_END	; end of string
			; Send data
			rcall	uart_snt
			rjmp	FLASH_CONST_TO_UART
FLASH_CONST_TO_UART_END:
			ret


;------------------------------------------------------------------------------
; Вывод сообщения "OK" в терминал
;------------------------------------------------------------------------------
UART_OK:
			ldi		r16,'O'
			rcall	uart_snt
			ldi		r16,'K'
			rcall	uart_snt
			ldi		r16,10
			rcall	uart_snt
			ldi		r16,13
			rcall	uart_snt
			ret


UART_LF_CR:
			ldi		r16,10
			rcall	uart_snt
			ldi		r16,13
			rcall	uart_snt
			ret



#endif  /* _UART_FUNCS_ASM_ */

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
