;------------------------------------------------------------------------------
; ������� ��� ������ � UART
; 
; ������� Buff_Pop ��� ������ � ��������� ������� UART
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
;           = 1 - ������ ����� (������ ������ ������), 
;           = 0 - � ������ ���� ������
;------------------------------------------------------------------------------
Buff_Pop:
			push	XL
			push	XH
			push	r18
			LDI		XL,low(IN_buff)		; ����� ����� ������ �������
			LDI		XH,high(IN_buff)
			LDS		R16,IN_PTR_E		; ����� �������� ����� ������
			LDS		R18,IN_PTR_S		; ����� �������� ����� ������			

			; ���� ���� ������������
			; ���� ������ ����������, �� ��������� ������
			; ����� ��������� �����. ��� ���� ������.
			BRFS	UART_Flags,UART_IN_FULL,NeedPop

			CP		R18,R16				; ��������� ������ ������ ��������� ������?
			BRNE	NeedPop				; ���! ������ �� ����. �������� ������

			LDI		R19,1				; ��� ������ - ������ ������!

			RJMP	Buff_Pop_END		; �������s

NeedPop:
			; ���������� ���� ������������
			CLFL	UART_Flags,UART_IN_FULL

			ADD		XL,R18				; ��������� ������ �� ���������
			ADC		XH,__zero_reg__		; �������� ����� ����� ������

			LD		R16,X				; ����� ���� �� �������
			CLR		R19					; ����� ���� ������

			INC		R18					; ����������� �������� ��������� ������

			CPI		R18,MAXBUFF_IN		; �������� ����� ������?
			BRNE	Buff_Pop_OUT		; ���? 
			
			CLR		R18					; ��? ����������, ����������� �� 0

Buff_Pop_OUT:	
			STS		IN_PTR_S,R18		; ��������� ���������
Buff_Pop_END:
			pop		r18
			pop		XH
			pop		XL
			ret


;-----------------------------------------------
; UART SENT
;     �������� ������� � UART
; ������������ �������� - r16 (�� ���.)
; ������� ������� - r16
; �������� ������� - ���
;-----------------------------------------------
uart_snt:
			SBIS 	UCSRA,UDRE		; ������� ���� ��� ����� ����������
			RJMP	uart_snt 		; ���� ���������� - ����� UDRE
 			OUT		UDR,r16		; ���� ����!
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
; ����� ��������� "OK" � ��������
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
