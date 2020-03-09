;------------------------------------------------------------------------------
; Обработчик прерывания UART по приёму байта
; для работы через кольцевой буфер приёма
; 
; 
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;------------------------------------------------------------------------------
#ifndef _UART_IRQ_ASM_
#define _UART_IRQ_ASM_

.ifndef __zero_reg__
.def __zero_reg__ = r2
.endif

;-------------------------------------------------------
;          Буфер для работы с UART                      |
;-------------------------------------------------------|
.dseg
IN_buff:	.byte	MAXBUFF_IN
IN_PTR_S:	.byte	1
IN_PTR_E:	.byte	1
;-------------------------------------------------------


.cseg
;-------------------------------------------------------
;           Получение байта по UART
;-------------------------------------------------------
RX_OK:
			push	r16
			in		r16,SREG
			push	r16
			push	r17
			push	r18
			push	XL
			push	XH
			;----------------
			#if defined(__ATmega168__) || defined(__ATmega328P__) || defined(__ATmega1284P__)
			InReg	r17,UDR0			; Забираем данные
			#elif defined(__ATmega8__) || defined(__ATmega16A__) || defined(__ATmega16__)
			InReg	r17,UDR				; Забираем данные
			#else
			#error "Unsupported part:" __PART_NAME__
			#endif // part specific code
			
			;OutReg	UDR0,R17			; Отправляем его в USART (эхо)
		
			cpi		r17,0x0A		; Line Feed (Перевод строки)
			breq	RX_OK_EXIT		; просто игнорируем LF (0x0A)
			cpi		r17,0x0D		; Carriage Return (Перевод каретки)
			breq	CR_rcv
			CLFL	UART_Flags,UART_CR	; сброс флага, символ - не Enter
			rjmp	SAVE_TO_BUFFER	; иначе - просто сохраняем символ в буфер

; если получили ENTER (CR, Перевод каретки)
CR_rcv:		
			; Проверка флага
			; если очередной раз пришел Enter, то игнорируем его
			; (защита от многократных посылок CR)
			BRFS	UART_Flags,UART_CR,RX_OK_EXIT
			; если предыдущий символ не CR, то устанавливаем флаги UART_STR_RCV и UART_CR
			STFL	UART_Flags,UART_STR_RCV
			STFL	UART_Flags,UART_CR
SAVE_TO_BUFFER:
			LDI		XL,low(IN_buff)		; Берем адрес начала буффера
			LDI		XH,high(IN_buff)
			LDS		R16,IN_PTR_E		; Берем смещение точки записи

			ADD		XL,R16				; Сложением адреса со смещением
			ADC		XH,__zero_reg__		; получаем адрес точки записи

			ST		X,R17				; сохраняем байт в кольцо
			INC		R16					; Увеличиваем смещение

			CPI		R16,MAXBUFF_IN		; Если достигли конца 
			BRNE	NoEnd
			CLR		R16					; переставляем на начало
NoEnd:
			LDS		R17,IN_PTR_S		; Берем смещение точки чтения
			CP		R16,R17				; Дошли до непрочитанных данных?
			BRNE	RX_OUT				; Если нет, то просто выходим

RX_FULL:	; Если да, то буффер переполнен.
			STFL	UART_Flags,UART_IN_FULL	; Записываем флаг наполненности
			
RX_OUT:		STS		IN_PTR_E,R16		; Сохраняем смещение. Выходим
RX_OK_EXIT:
			;----------------
			pop		XH
			pop		XL
			pop		r18
			pop		r17
			pop		r16
			out		SREG,r16
			pop		r16
			reti

#endif  /* _UART_IRQ_ASM_ */

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
