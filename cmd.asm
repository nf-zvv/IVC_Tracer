;==============================================================================
; ������������� ������
; 
;
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;
; History
; =======
; 24.04.2017
; 27.08.2017 ������������ FLASH_CONST_TO_UART, RAM_STR_TO_UART, UART_OK
;            ���������� � ���� uart_funcs.asm
; 07.06.2018 ADD: ������������ ZEROING_BUFF - ��������� ������
; 08.06.2018 ADD: ��������� ������������ ������ ������ �� ���� ������
; 09.03.2020 
; 10.03.2020 ������������� �����������
;            SPLIT_ARGS ������������� � SPLIT_LINE
; 12.03.2020 �����������. ������ ������������� RAM ��� �������� ������� 
;            "��� ������� - ����� ������������" ������ ������������ Flash
; 14.03.2020 �� ������������ DEFINE_CMD ��� ������ ������ � ������� ������� 
;            � ��������� ������������ LOCATE_STR
;==============================================================================
#ifndef _CMD_ASM_
#define _CMD_ASM_


.ifndef __zero_reg__
.def __zero_reg__ = r2
.endif

.equ	CMD_COUNT     = 7			; ���-�� ������. ��������� ��� ���������� �����!
.equ	ARG_COUNT_MAX = 2			; ������������ ���-�� ����������
.equ	CMDLINE_LEN   = 32

;-------------------------------------------------------
;                                                       |
;-------------------------------------------------------|
.dseg
CMD_ID:			.byte	1				; ID ������� � ������ CMD_LIST
ARG_COUNT:		.byte	1				; ���-�� ��������� ����������
ARG_ADDR_LIST:	.byte	ARG_COUNT_MAX	; ������ �������� ����������
CMDLINE:		.byte	CMDLINE_LEN		; ������������ ��������� ������


.cseg
;------------------------------------------------------------------------------
; ������������� ��������� ������, �� ����������, 
;   ������ ��������� �� ������ ��� �������
; ������: SPLIT_LINE, DEFINE_CMD, EXEC_CMD, UART_OK, FLASH_CONST_TO_UART
; ������������: r13, r16*, Z*
; ����: 
; �����: 
;------------------------------------------------------------------------------
UART_RX_PARSE:
			CLFL	UART_Flags,UART_STR_RCV	; ����� �����
			rcall	SPLIT_LINE		; �������� ������� ������
			tst		r13
			breq	SPLIT_LINE_OK
			rjmp	PRINT_ERROR
SPLIT_LINE_OK:
			rcall	DEFINE_CMD
			tst		r13
			breq	DEFINE_CMD_OK
			rjmp	PRINT_ERROR
DEFINE_CMD_OK:			
			rcall	EXEC_CMD
			; ����� ���������� EXEC_CMD ����� ��������� �� PRINT_ERROR
			; ��� ��������� ���� ��, ���� ��������� �� ������
			; ������� �� ������������ UART_RX_PARSE (ret) �������� ��� ��


;-----------------------------------------------------------------------------
; ����� � �������� ��������� �� �������
; 
; ���� ������:
;   0 - OK (��� ������)
;   1 - ������ �������� ������ �� ��������
;   2 - ����������� �������
;   3 - ������������ ����� ����������
;   4 - ������������ �������� ��������� (��������� �����)
;   5 - ������� ����� ����������
;   6 - ����������� ��������
;   7 - ����������� ������
;   8 - ������������ �����
; 255 - ������ �� ��������
; 
; ������: 
; ������������: 
; ����: r13 - ��� ������
; �����: 
;-----------------------------------------------------------------------------
PRINT_ERROR:
			mov		r16,r13
			tst		r16
			brne	error_1
			rcall	UART_OK
			rjmp	PRINT_ERROR_EXIT
error_1:
			cpi		r16,1
			brne	error_2
			ldi		ZL,low(SPLIT_LINE_fail_const*2)
			ldi		ZH,high(SPLIT_LINE_fail_const*2)
			rjmp	print_error_
error_2:
			cpi		r16,2
			brne	error_3
			ldi		ZL,low(unknown_cmd_const*2)
			ldi		ZH,high(unknown_cmd_const*2)
			rjmp	print_error_
error_3:
			cpi		r16,3
			brne	error_4
			ldi		ZL,low(invalid_arg_count_const*2)
			ldi		ZH,high(invalid_arg_count_const*2)
			rjmp	print_error_
error_4:
			cpi		r16,4
			brne	error_5
			ldi		ZL,low(invalid_argument_const*2)
			ldi		ZH,high(invalid_argument_const*2)
			rjmp	print_error_
error_5:
			cpi		r16,5
			brne	error_6
			ldi		ZL,low(too_many_arguments_const*2)
			ldi		ZH,high(too_many_arguments_const*2)
			rjmp	print_error_
error_6:
			cpi		r16,6
			brne	error_7
			ldi		ZL,low(no_arguments_const*2)
			ldi		ZH,high(no_arguments_const*2)
			rjmp	print_error_
error_7:
			cpi		r16,7
			brne	error_8
			ldi		ZL,low(unknown_error_const*2)
			ldi		ZH,high(unknown_error_const*2)
			rjmp	print_error_
error_8:
			cpi		r16,8
			brne	error_255
			ldi		ZL,low(invalid_num_param_const*2)
			ldi		ZH,high(invalid_num_param_const*2)
			rjmp	print_error_
error_255:
			rjmp	PRINT_ERROR_EXIT
print_error_:
			rcall	FLASH_CONST_TO_UART
			rcall	UART_LF_CR
PRINT_ERROR_EXIT:
			ret

;-----------------------------------------------------------------------------
; �������� ������ ����������
; ���������� ��������� ������� �� ���������� ������ UART
; �������� ��������� ������� � ����� CMDLINE
; ������� �������� ��������� \0
; ��������� ������ ������� ����������
; 
; ������: ZEROING_BUFF, Buff_Pop, IS_CHAR
; ������������: r13*, r14*, r16*, r17*, r19*, X*, Y*
; ����: ������� ����� UART
; �����: r13
;        r13 = 0 - ok
;        r13 = 1 - ������ �����
;-----------------------------------------------------------------------------
SPLIT_LINE:
			; ��������� �������
			ldi		r16,ARG_COUNT_MAX
			ldi		YL,low(ARG_ADDR_LIST)
			ldi		YH,high(ARG_ADDR_LIST)
			rcall	ZEROING_BUFF
			ldi		r16,CMDLINE_LEN
			ldi		YL,low(CMDLINE)
			ldi		YH,high(CMDLINE)
			rcall	ZEROING_BUFF

			; ��������� ����������
			sts		ARG_COUNT,__zero_reg__	; �������� ���-�� ����������
			clr		r18		; ������� ��������
			clr		r14		; ���������� ������

			ldi		XL,low(CMDLINE)		; ����� ��� ������ ���������� ������
			ldi		XH,high(CMDLINE)
			ldi		YL,low(ARG_ADDR_LIST)	; ����� �������� ���������
			ldi		YH,high(ARG_ADDR_LIST)
SPLIT_LINE_LOOP:
			rcall	Buff_Pop		; ��������� ������ �� �������� ������ UART
			cpi		r19,1			; ���� ������ 1, �� ����� ����
			breq	SPLIT_LINE_END	; ������, �������
			; �������� ������ ������ (�� ��������� � r16)
			; ��������� �� �������������� � ���������� ������
			mov		r17,r16
			rcall	IS_CHAR
			tst		r16
			breq	_nonchar		; �� ������ - ���������
			st		X+,r17			; ��������� ������ � ������ CMDLINE
			ldi		r16,0x20
			cp		r14,r16			; ���������� ������ ��� "������"?
			breq	is_arg_start
			rjmp	skip_arg_start
is_arg_start:
			lds		r16,ARG_COUNT	; ��������� �������� ����� ����������
			inc		r16				; ����������� ���-�� ��������� ����������
			sts		ARG_COUNT,r16	; ��������� �������
			; ���������� �������� ��������� � ������ ARG_ADDR_LIST
			st		Y+,r18
skip_arg_start:
			mov		r14,r17		; ���������� ���������� �������
			inc		r18			; ����������� ������� ��������
			rjmp	SPLIT_LINE_LOOP
_nonchar:
			cpi		r17,0x20
			breq	space_rcv
			cpi		r17,13		; ������ ����� ��������� ������
			breq	enter_rcv
			cpi		r17,'_'
			breq	underline_rcv
			rjmp	SPLIT_LINE_LOOP
space_rcv:
			tst		r14					; ���� ������ � ����� ������ (r14=0)
			breq	SPLIT_LINE_LOOP		; - ��������� ��������
			ldi		r16,0x20
			cp		r14,r16			; ���� ������ ����� ������� (r14=0x20)
			breq	SPLIT_LINE_LOOP		; - ��������� ��������
			clr		r16
			st		X+,r16		; ���������� 0 ��� ������ ����� ���������
			mov		r14,r17		; ���������� ���������� ������
			inc		r18			; ����������� �������
			rjmp	SPLIT_LINE_LOOP
enter_rcv:
			tst		r18					; ��������� �������
			brne	SPLIT_LINE_success		; ������ ������ �������
			; ������ enter � ����� ������ - �������
			; �� ��������� ������ ������� ������:
			ldi		r16,1
			mov		r13,r16
			rjmp	SPLIT_LINE_LOOP
underline_rcv:
			st		X+,r17
			inc		r18			; ����������� �������
			rjmp	SPLIT_LINE_LOOP
SPLIT_LINE_success:
			; ����� - enter ����� � ����� ��������� ������
			; ������� ���� - ������� ����� ������ ������ enter'�
			st		X+,__zero_reg__		; ���������� 0 ��� ������ ����� ������
			clr		r13
			;rjmp	SPLIT_LINE_LOOP
			; 10.03.2020 ��������������� ������ ����:
			; ����� ������������, ���� ��� ������� enter?
			; ������ ���� � ����� ��������� ���������� �����
			; �������� ����� ���
			; ����� ���� ���������� �����
			; � ���� �� �����-�� ������� � ������ ���-�� ����, 
			; �� enter �� ������? ��������, ��� ����������� ��������� ������.
			; � ����� ������ ���� ���������� ����� �� ���������� ���� ������������
EMPTY_BUFFER:
SPLIT_LINE_END:
			ret


;-----------------------------------------------------------------------------
; ��������� ������
; 
; ������: 
; ������������: r16*, Y*
; ����: Y - ��������� �� �����
;       r16 - ����� ������
; �����: 
;-----------------------------------------------------------------------------
ZEROING_BUFF:
			st		Y+,__zero_reg__
			dec		r16
			brne	ZEROING_BUFF
			ret


;-----------------------------------------------------------------------------
; ���������� �������
; ���� ��������� ������� ����� ���������
; ���������� � CMD_ID ������������� ������������ �������
; 
; ������: LOCATE_STR
; ������������: r13*, r18*, r19*, X*, Z*
; ����: CMD_TABLE, CMDLINE
; �����: CMD_ID, r13
;        r13 = 0 - ok
;        r13 = 2 - ����������� �������
;-----------------------------------------------------------------------------
DEFINE_CMD:
			; ��������� ����� �������
			ldi		ZL,low(CMD_TABLE*2)
			ldi		ZH,high(CMD_TABLE*2)
			ldi		XL,low(CMDLINE)		; ����� � ��������,
			ldi		XH,high(CMDLINE)	; �������� �� UART
			ldi		r19,CMD_COUNT		; ���������� ���������
			rcall	LOCATE_STR
			cpi		r18,-1
			breq	CMD_NOT_FOUND
			; ������� �������
			sts		CMD_ID,r18		; ��������� ID ��������� �������
			clr		r13		; ������ ������
			ret
CMD_NOT_FOUND:
			; ������� �� �������
			ldi		r16,2		; ������ "����������� �������"
			mov		r13,r16
			ret


;-----------------------------------------------------------------------------
; ����� ������ � �������
; ��� ������� ������� �� 4 ����. ������ ��� ����� - ��������� �� ������
; ����� ������ ��������������
; 
; ������: STR_CMP
; ������������: r16*, r17*, r18*, r20*, r21*, r24*, r25*, X*, Z*
; ����: X, Z - ��������� �� ������� ������ (X) � ������� (Z)
;       r19 - ���������� ���������
; �����: r18 - ������
;        ���� r18 = -1, �� ������ �� �������
;-----------------------------------------------------------------------------
LOCATE_STR:
			clr		r18		; �������
			movw	r24,ZL
			movw	r20,XL
LOCATE_STR_LOOP:
			movw	ZL,r24
			; ��������� ����� ��������� �������
			lpm		r16,Z+
			lpm		r17,Z
			; ���������� ���������� �� UART ������� � ����������
			movw	XL,r20
			movw	ZL,r16
			rcall	STR_CMP
			tst		r16				; ��������� ��������
			breq	LOCATE_STR_FOUND		; ���� ����� - ���������
			; ������� �� �������
			inc		r18				; ���� �� �����, ����������� ������� �������
			adiw	r24,4
			cp		r18,r19	; �� �������� �� ������ ������?
			brsh	LOCATE_STR_NOT_FOUND
			rjmp	LOCATE_STR_LOOP
LOCATE_STR_NOT_FOUND:
			ldi		r18,-1 ; ������ �� �������
LOCATE_STR_FOUND:
			; ��������� � �������� r18
			ret


;-----------------------------------------------------------------------------
; �������� ���������� �������
; ������������: r0*, r1*, r16*, r24*, r25*, Z*
; ����: CMD_ID, CMD_LIST
; �����: -
;-----------------------------------------------------------------------------
EXEC_CMD:
			; ��������� ����� �������
			ldi		ZL,low(CMD_TABLE*2)
			ldi		ZH,high(CMD_TABLE*2)
			lds		r0,CMD_ID			; ��������� ID �������
			; ��������� ��������
			ldi		r16,4
			mul		r0,r16
			add		ZL,r0
			adc		ZH,r1
			adiw	ZL,2	; ��������������� �� ����� ������������
			lpm		r24,Z+
			lpm		r25,Z
			movw	ZL,r24	; ������ Z ��������� �� ����� ������������
			ijmp			; ��������� ������� � ������������
			; �������� ���������� ������������
			; � ����� ������������ ����� ���������� ret,
			; ������� ���������� ������� �� EXEC_CMD


;-----------------------------------------------------------------------------
; ���������� ��������� �� ������ ��������� ���������
; ����������: r16*, X, Y*
; ����: r16 - ����� ���������, ������� � 1
; �����: Y, ����������� �� ������ ������ ���������
; 07.06.18 ADD: ���������� � ���� �������� X
;-----------------------------------------------------------------------------
GET_ARGUMENT:
			push	XL
			push	XH
			ldi		YL,low(CMDLINE)		; ���������� ������
			ldi		YH,high(CMDLINE)	; 
			ldi		XL,low(ARG_ADDR_LIST)	; ����� ��������
			ldi		XH,high(ARG_ADDR_LIST)	; ���������
			dec		r16
			add		XL,r16				; ������������� ����� ���������
			adc		XH,__zero_reg__		; <-- �� ������ ��������
			ld		r16,X				; ��������� ��������
			add		YL,r16				; ��������� � ������ ��������� ���������
			adc		YH,__zero_reg__		; <-- �� ������ ��������
			pop		XH
			pop		XL
			ret



;------------------------------------------------------------------------------
; 
; Constants
; 
;------------------------------------------------------------------------------
unknown_cmd_const:			.db "Unknown command",0
SPLIT_LINE_fail_const:		.db "Split arguments failed",0,0
cmd_error_const:			.db "Command error",0
invalid_argument_const:		.db "Invalid argument",0,0
invalid_arg_count_const:	.db "Invalid argument count",0,0
too_many_arguments_const:	.db "Too many arguments",0,0
no_arguments_const:			.db "No arguments",0,0
unknown_error_const:		.db "Unknown error",0
invalid_num_param_const:	.db "Invalid numeric parameter",0

#endif  /* _CMD_ASM_ */

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
