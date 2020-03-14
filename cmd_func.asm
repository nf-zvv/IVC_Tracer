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
; 
;------------------------------------------------------------------------------

; ������ ���������� ������� � ������ ��������� ������
; �������������: ADD_CMD cmd_name_const,cmd_addr
.MACRO 	ADD_CMD
			ldi		ZL,low(@0*2)
			ldi		ZH,high(@0*2)
			st		X+,ZH
			st		X+,ZL
			ldi		ZL,low(@1)
			ldi		ZH,high(@1)
			st		X+,ZH
			st		X+,ZL
.ENDMACRO

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

			ldi		XL,low(CMD_LIST)		; ����� ����� ������ ������
			ldi		XH,high(CMD_LIST)

			ADD_CMD	cmd_clear_const,cmd_clear
			ADD_CMD	cmd_reboot_const,cmd_reboot
			ADD_CMD	cmd_echo_const,cmd_echo
			ADD_CMD	cmd_meow_const,cmd_meow
			;ADD_CMD	cmd_pwm_const,cmd_pwm
			;ADD_CMD	cmd_adc_const,cmd_adc
			;ADD_CMD	cmd_adc2_const,cmd_adc2
			;ADD_CMD	cmd_dac_const,cmd_dac
			;ADD_CMD	cmd_vah_const,cmd_vah
			;ADD_CMD	cmd_start_const,cmd_start

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


cmd_no_args:
			ldi		r16,6	; ��� ������: "����������� ���������"
			mov		r13,r16
			ret
cmd_too_many_args:
			ldi		r16,5	; ��� ������: "������� ����� ����������"
			mov		r13,r16
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
;cmd_pwm_const:				.db "pwm",0
;cmd_adc_const:				.db "adc",0
;cmd_adc2_const:				.db "adc2",0,0
;cmd_dac_const:				.db "dac",0
;cmd_vah_const:				.db "vah",0
;cmd_start_const:			.db "start",0
meow_const:					.db "Meow",0,0
clear_seq_const:			.db 27, "[H", 27, "[2J",0

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
