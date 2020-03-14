;------------------------------------------------------------------------------
; ���������� ���������� UART �� ����� �����
; ��� ������ ����� ��������� ����� �����
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
;          ����� ��� ������ � UART                      |
;-------------------------------------------------------|
.dseg
IN_buff:	.byte	MAXBUFF_IN
IN_PTR_S:	.byte	1
IN_PTR_E:	.byte	1
;-------------------------------------------------------


.cseg
;-------------------------------------------------------
;           ��������� ����� �� UART
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
			InReg	r17,UDR0			; �������� ������
			#elif defined(__ATmega8__) || defined(__ATmega16A__) || defined(__ATmega16__)
			InReg	r17,UDR				; �������� ������
			#else
			#error "Unsupported part:" __PART_NAME__
			#endif // part specific code
			
			;OutReg	UDR0,R17			; ���������� ��� � USART (���)
		
			cpi		r17,0x0A		; Line Feed (������� ������)
			breq	RX_OK_EXIT		; ������ ���������� LF (0x0A)
			cpi		r17,0x0D		; Carriage Return (������� �������)
			breq	CR_rcv
			CLFL	UART_Flags,UART_CR	; ����� �����, ������ - �� Enter
			rjmp	SAVE_TO_BUFFER	; ����� - ������ ��������� ������ � �����

; ���� �������� ENTER (CR, ������� �������)
CR_rcv:		
			; �������� �����
			; ���� ��������� ��� ������ Enter, �� ���������� ���
			; (������ �� ������������ ������� CR)
			BRFS	UART_Flags,UART_CR,RX_OK_EXIT
			; ���� ���������� ������ �� CR, �� ������������� ����� UART_STR_RCV � UART_CR
			STFL	UART_Flags,UART_STR_RCV
			STFL	UART_Flags,UART_CR
SAVE_TO_BUFFER:
			LDI		XL,low(IN_buff)		; ����� ����� ������ �������
			LDI		XH,high(IN_buff)
			LDS		R16,IN_PTR_E		; ����� �������� ����� ������

			ADD		XL,R16				; ��������� ������ �� ���������
			ADC		XH,__zero_reg__		; �������� ����� ����� ������

			ST		X,R17				; ��������� ���� � ������
			INC		R16					; ����������� ��������

			CPI		R16,MAXBUFF_IN		; ���� �������� ����� 
			BRNE	NoEnd
			CLR		R16					; ������������ �� ������
NoEnd:
			LDS		R17,IN_PTR_S		; ����� �������� ����� ������
			CP		R16,R17				; ����� �� ������������� ������?
			BRNE	RX_OUT				; ���� ���, �� ������ �������

RX_FULL:	; ���� ��, �� ������ ����������.
			STFL	UART_Flags,UART_IN_FULL	; ���������� ���� �������������
			
RX_OUT:		STS		IN_PTR_E,R16		; ��������� ��������. �������
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
