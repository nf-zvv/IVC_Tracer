;------------------------------------------------------------------------------
; Макросы для работы с UART
; 
; 
; 
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;------------------------------------------------------------------------------


;USART INIT
			.MACRO	USART_INIT
			.equ XTAL 			= F_CPU
			.equ baudrate 		= 19200
			.equ bauddivider 	= XTAL/(16*baudrate)-1
			#if defined(__ATmega168__) || defined(__ATmega328P__) || defined(__ATmega1284P__)
			ldi		r16,low(bauddivider)
			OutReg 	UBRR0L,r16
			ldi		r16,high(bauddivider)
			OutReg 	UBRR0H,r16
			ldi		r16,0
			OutReg 	UCSR0A,r16
			ldi		r16,(1<<RXEN0)|(1<<TXEN0)|(1<<RXCIE0)|(0<<TXCIE0)|(0<<UDRIE0) ; Прерывание на прием разрешено, прием-передача разрешены
			OutReg 	UCSR0B,r16
			; Формат кадра - 8 бит данных, 1 стоп-бит
			ldi		r16,(0<<USBS0)|(3<<UCSZ00)
			OutReg 	UCSR0C,r16
			#elif defined(__ATmega8__) || defined(__ATmega16A__) || defined(__ATmega16__)
			ldi		r16,low(bauddivider)
			OutReg	UBRRL,r16
			ldi		r16,high(bauddivider)
			OutReg	UBRRH,r16
			ldi		r16,0
			OutReg	UCSRA,r16
			ldi		r16,(1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(0<<TXCIE)|(0<<UDRIE) ; Прерывание на прием разрешено, прием-передача разрешены
			OutReg	UCSRB,r16
			; Формат кадра - 8 бит данных, 1 стоп-бит
			; Без установки бита URSEL приемо-передатчик не работал
			; URSEL всегда равен 1. Служит для выбора регистра UCSRC, иначе UBRRH.
			ldi		r16,(1<<URSEL)|(0<<USBS)|(1<<UCSZ1)|(1<<UCSZ0)
			OutReg	UCSRC,r16
			#else
			#error "Unsupported part:" __PART_NAME__
			#endif // part specific code
			.ENDM



			; Сбросить флаг
			; @0 - имя ячейки памяти
			; @1 - имя флага
			.MACRO	CLFL
			lds		r19,@0
			andi	r19,~(1 << @1)
			sts		@0,r19
			.ENDM

			; Установить флаг
			; @0 - имя ячейки памяти
			; @1 - имя флага
			.MACRO	STFL
			lds		r19,@0
			ori		r19,(1 << @1)
			sts		@0,r19
			.ENDM

			; Перейти, если флаг установлен
			; Branch if Flag is Set
			; @0 - имя ячейки памяти
			; @1 - имя флага
			; @2 - метка
			.MACRO	BRFS
			lds		r19,@0
			sbrc	r19,@1
			rjmp	@2
			.ENDM

			; Перейти, если флаг очищен
			; Branch if Flag is Clear
			; @0 - имя ячейки памяти
			; @1 - имя флага
			; @2 - метка
			.MACRO	BRFC
			lds		r19,@0
			sbrs	r19,@1
			rjmp	@2
			.ENDM


