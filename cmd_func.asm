;------------------------------------------------------------------------------
; ���������� ������
; 
; ������ ������:
;   clear  - ������� ������
;   reboot - ������������
;   pwm    - ��������� � ���������� �������� ���
;   adc    - ���������� �������� ������ ���
;   cal    - ����������
;
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;
; History
; =======
; 19.02.2018 ������������ fill_cmd_list ������������� � init_cmd_list
; 12.03.2018 � ������������ init_cmd_list ��������� ��������� ������� UART
;            ������������ init_cmd_list ������������� � UART_PARSER_INIT
; 10.03.2020 ADD: SET � GET �������
; 11.03.2020 CMD_TABLE. ������������� Flash ������ RAM
;------------------------------------------------------------------------------
#ifndef _CMD_FUNC_ASM_
#define _CMD_FUNC_ASM_

.equ	VAR_COUNT     = 6			; ���-�� ���������� (��� ������ SET � GET)

.dseg
VAR_ID:		.byte 1


.cseg
;------------------------------------------------------------------------------
; ���������� ������� ������-�������
; ������: -
; ������������: X*, Z*
; ����: -
; �����: CMD_LIST
;------------------------------------------------------------------------------
UART_PARSER_INIT:
			; ������������ ������� UART
			; �������� ���������
			sts		IN_PTR_S,__zero_reg__
			sts		IN_PTR_E,__zero_reg__
			;sts		OUT_PTR_S,__zero_reg__
			;sts		OUT_PTR_E,__zero_reg__

			; ������ ��� ����������� ������������

			; �� ������ ��������� ���-�� ������ � ���������� CMD_COUNT � ����� cmd.asm
			ret


;------------------------------------------------------------------------------
; ������� ������
;
; ������������ � �������� �������:
;   <ESC>[H   - Cursor home
;   <ESC>[2J  - Erase screen
;
; ������: FLASH_CONST_TO_UART
; ������������: r13*, r16*
; ����: -
; �����: -
;------------------------------------------------------------------------------
cmd_clear:
			ldi		ZL,low(clear_seq_const*2)
			ldi		ZH,high(clear_seq_const*2)
			rcall	FLASH_CONST_TO_UART
			ldi		r16,255		; �� �������� ��������� '��'
			mov		r13,r16
			ret


;------------------------------------------------------------------------------
; ������������
; 
;------------------------------------------------------------------------------
cmd_reboot:
			jmp 0x0000


;------------------------------------------------------------------------------
; ������� Meow � ��������
; 
;------------------------------------------------------------------------------
cmd_meow:
			ldi		ZL,low(meow_const*2)
			ldi		ZH,high(meow_const*2)
			rcall	FLASH_CONST_TO_UART
			ldi		r16,255		; �� �������� ��������� '��'
			mov		r13,r16
			ret


;------------------------------------------------------------------------------
; ������� ���
; ������� � �������� �� ��, ��� � ����� � �� ������ ���������
; 
;------------------------------------------------------------------------------
cmd_echo:
			lds		r16,ARG_COUNT		; ���-�� ����������
			tst		r16
			brne	cmd_echo_max_arg_tst
			rjmp	cmd_no_args	; ��� ����������
cmd_echo_max_arg_tst:
			cpi		r16,1
			breq	cmd_echo_next
			rjmp	cmd_too_many_args
cmd_echo_next:
			ldi		r16,1			; ����� ������ ��������
			rcall	GET_ARGUMENT
			movw	X,Y
			rcall	STRING_TO_UART
			clr		r13				; �������� ���������
			ret

;------------------------------------------------------------------------------
; ����� ��� ���� �������� ��� ��������� ��������� �� �������
;------------------------------------------------------------------------------
cmd_invalid_arg_count:
			ldi		r16,3	; ��� ������: "������������ ����� ����������"
			mov		r13,r16
			ret
cmd_no_args:
			ldi		r16,6	; ��� ������: "����������� ���������"
			mov		r13,r16
			ret
cmd_too_many_args:
			ldi		r16,5	; ��� ������: "������� ����� ����������"
			mov		r13,r16
			ret



;------------------------------------------------------------------------------
; ��������� ������ �������� ����������
; 
; ������� ����� ��� ���������: ��� ���������� � ��������
;------------------------------------------------------------------------------
cmd_set:
			lds		r16,ARG_COUNT		; ���-�� ����������
			tst		r16
			brne	cmd_set_max_arg_tst
			rjmp	cmd_no_args	; ��� ����������
cmd_set_max_arg_tst:
			cpi		r16,2
			breq	cmd_set_next
			rjmp	cmd_invalid_arg_count
cmd_set_next:
			; ���� �������� ������������, ����������� DEFINE_CMD
			; ��� ������������� ����������
			; ������� ������ ������� ����������
			; �� ���� ���������� ���� ����� � ������ ���� �� ������
			; ���� ����� ������ ���������� ����� �������� ������ � ��������� �������� ��������
			; ������. �� ��� ���� � ������������ ����������?
			; �� ����� ����� ������ ���� ���������� �� Flash, ��� ����, 
			; ����� ���������� � ��� ���������� �� UART ���
			; ���� ������� ��� ���������� �������������, ����� ��� ������������� ������
			ret


;------------------------------------------------------------------------------
; ��������� ����������
; ����� �������� ���������� � ��������
;------------------------------------------------------------------------------
cmd_get:
			lds		r16,ARG_COUNT		; ���-�� ����������
			tst		r16
			brne	cmd_get_max_arg_tst
			rjmp	cmd_no_args	; ��� ����������
cmd_get_max_arg_tst:
			cpi		r16,1
			breq	cmd_get_next
			rjmp	cmd_too_many_args
cmd_get_next:
			ldi		r16,1			; ����� ������ ��������
			rcall	GET_ARGUMENT	; (Y - pointer to zero ending argument string)
			; ������� ���������, �� ��������� �� ��� ���������� ������������
			movw	XL,YL
			ldi		ZL,low(ALL_const*2)		; �������� ALL
			ldi		ZH,high(ALL_const*2)
			rcall	STR_CMP
			tst		r16				; ��������� ��������
			brne	cmd_get_single_var
			; ����� ��� ����������
			rcall	GET_ALL
			rjmp	cmd_get_success
cmd_get_single_var:
			movw	XL,YL
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			ldi		r19,VAR_COUNT
			rcall	LOCATE_STR
			cpi		r18,-1
			breq	cmd_get_VAR_NOT_FOUND
			; ���������� �������!
			sts		VAR_ID,r18		; ��������� ID ��������� ����������
			movw	XL,YL
			rcall	STRING_TO_UART ; (IN: X)
			ldi		r16,'='
			rcall	uart_snt
			; ��������� ����� �������
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			lds		r0,VAR_ID			; ��������� ID ����������
			; ��������� ��������
			ldi		r16,4
			mul		r0,r16
			add		ZL,r0
			adc		ZH,r1
			adiw	ZL,2	; ��������������� �� ����� ���������� � RAM
			lpm		XL,Z+
			lpm		XH,Z	; ������ X ��������� �� �������� ���������� � RAM
			; ��������� ��������
			ld		r24,X+
			ld		r25,X
			movw	XL,r24
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR5 ; (IN: X; OUT: Y)
			ldi		XL,low(STRING)
			ldi		XH,high(STRING)
			rcall	STRING_TO_UART ; (IN: X)
			rcall	UART_LF_CR
cmd_get_success:
			clr		r13
			ret
cmd_get_VAR_NOT_FOUND:
			ldi		r16,4	; ��� ������: "������������ �������� ���������"
			mov		r13,r16
			ret


;------------------------------------------------------------------------------
; ��������� ���� ����������
; ����� �������� ���������� � ��������
;
; ������: FLASH_CONST_TO_UART, STRING_TO_UART, UART_LF_CR, uart_snt
; ������������: r16*, r17*, r19*, r24*, r25*, X*, Y*, Z*
; ����: VAR_TABLE
;       r19 - ���������� ���������
; �����: 
;------------------------------------------------------------------------------
GET_ALL:
			ldi		r24,low(VAR_TABLE*2)
			ldi		r25,high(VAR_TABLE*2)
			ldi		r19,VAR_COUNT
GET_ALL_LOOP:
			movw	ZL,r24
			; ��������� ����� ����� ����������
			lpm		r16,Z+
			lpm		r17,Z+
			; ��������� ����� �������� ����������
			lpm		YL,Z+
			lpm		YH,Z
			movw	ZL,r16
			rcall	FLASH_CONST_TO_UART ; (IN: Z)
			ldi		r16,'='
			rcall	uart_snt
			; ��������� ��������
			ld		XL,Y+
			ld		XH,Y
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR5 ; (IN: X; OUT: Y)
			ldi		XL,low(STRING)
			ldi		XH,high(STRING)
			rcall	STRING_TO_UART ; (IN: X)
			rcall	UART_LF_CR
			adiw	r24,4
			dec		r19
			brne	GET_ALL_LOOP
			ret





;------------------------------------------------------------------------------
; 
; Includes
; 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; 
; Constants
; 
;------------------------------------------------------------------------------
cmd_clear_const:			.db "clear",0
cmd_reboot_const:			.db "reboot",0,0
cmd_echo_const:				.db "echo",0,0
cmd_meow_const:				.db "meow",0,0
cmd_set_const:				.db "set",0
cmd_get_const:				.db "get",0
;cmd_pwm_const:				.db "pwm",0
;cmd_adc_const:				.db "adc",0
;cmd_adc2_const:				.db "adc2",0,0
;cmd_dac_const:				.db "dac",0
;cmd_vah_const:				.db "vah",0
;cmd_start_const:			.db "start",0
meow_const:					.db "Meow! ^_^",0
clear_seq_const:			.db 27, "[", "H", 27, "[", "2", "J",0

; ����� ����������
IVC_DAC_START_var_name:		.db "IVC_DAC_START",0
IVC_DAC_END_var_name:		.db "IVC_DAC_END",0
IVC_DAC_STEP_var_name:		.db "IVC_DAC_STEP",0,0
CH0_DELTA_var_name:			.db "CH0_DELTA",0
ADC_V_REF_var_name:			.db "ADC_V_REF",0
ACS712_KI_var_name:			.db "ACS712_KI",0
ALL_const:					.db "ALL",0

; ������� ������� ���� ������ � ������� �����������
CMD_TABLE:
.db low(cmd_clear_const*2), high(cmd_clear_const*2), low(cmd_clear), high(cmd_clear)
.db low(cmd_reboot_const*2),high(cmd_reboot_const*2),low(cmd_reboot),high(cmd_reboot)
.db low(cmd_echo_const*2),  high(cmd_echo_const*2),  low(cmd_echo),  high(cmd_echo)
.db low(cmd_meow_const*2),  high(cmd_meow_const*2),  low(cmd_meow),  high(cmd_meow)
.db low(cmd_set_const*2),   high(cmd_set_const*2),   low(cmd_set),   high(cmd_set)
.db low(cmd_get_const*2),   high(cmd_get_const*2),   low(cmd_get),   high(cmd_get)

; ������� ������� ���� ���������� �� Flash � ������� �������� � RAM
VAR_TABLE:
.db low(IVC_DAC_START_var_name*2),high(IVC_DAC_START_var_name*2),low(IVC_DAC_START),high(IVC_DAC_START)
.db low(IVC_DAC_END_var_name*2),  high(IVC_DAC_END_var_name*2),  low(IVC_DAC_END),  high(IVC_DAC_END)
.db low(IVC_DAC_STEP_var_name*2), high(IVC_DAC_STEP_var_name*2), low(IVC_DAC_STEP), high(IVC_DAC_STEP)
.db low(CH0_DELTA_var_name*2),    high(CH0_DELTA_var_name*2),    low(CH0_DELTA),    high(CH0_DELTA)
.db low(ADC_V_REF_var_name*2),    high(ADC_V_REF_var_name*2),    low(ADC_V_REF),    high(ADC_V_REF)
.db low(ACS712_KI_var_name*2),    high(ACS712_KI_var_name*2),    low(ACS712_KI),    high(ACS712_KI)

#endif  /* _CMD_FUNC_ASM_ */

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
