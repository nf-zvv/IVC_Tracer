;------------------------------------------------------------------------------
; Реализация команд
; 
; Список команд:
;   clear  - очистка экрана
;   reboot - перезагрузка
;   pwm    - установка и считывание значения ШИМ
;   adc    - считывание значения канала АЦП
;   cal    - калибровка
;
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;
; History
; =======
; 19.02.2018 Подпрограмма fill_cmd_list переименована в init_cmd_list
; 12.03.2018 В подпрограмму init_cmd_list добавлено обнуление буферов UART
;            Подпрограмма init_cmd_list переименована в UART_PARSER_INIT
; 
;------------------------------------------------------------------------------

; Макрос добавления команды с список доступных команд
; Использование: ADD_CMD cmd_name_const,cmd_addr
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
; Заполнение массива команд-адресов
; Вызовы: -
; Используются: X*, Z*
; Вход: -
; Выход: CMD_LIST
;------------------------------------------------------------------------------
UART_PARSER_INIT:
			; Иницилизация буферов UART
			; Обнуляем указатели
			sts		IN_PTR_S,__zero_reg__
			sts		IN_PTR_E,__zero_reg__
			;sts		OUT_PTR_S,__zero_reg__
			;sts		OUT_PTR_E,__zero_reg__

			ldi		XL,low(CMD_LIST)		; Берем адрес начала буфера
			ldi		XH,high(CMD_LIST)

			ADD_CMD	cmd_clear_const,cmd_clear
			ADD_CMD	cmd_reboot_const,cmd_reboot
			ADD_CMD	cmd_echo_const,cmd_echo
			ADD_CMD	cmd_meow_const,cmd_meow
			ADD_CMD	cmd_set_const,cmd_set
			ADD_CMD	cmd_get_const,cmd_get
			;ADD_CMD	cmd_pwm_const,cmd_pwm
			;ADD_CMD	cmd_adc_const,cmd_adc
			;ADD_CMD	cmd_adc2_const,cmd_adc2
			;ADD_CMD	cmd_dac_const,cmd_dac
			;ADD_CMD	cmd_vah_const,cmd_vah
			;ADD_CMD	cmd_start_const,cmd_start

			; Не забыть увеличить кол-во команд в переменной CMD_COUNT в файле cmd.asm
			ret



;------------------------------------------------------------------------------
; Очистка экрана
;
; Отправляемые в терминал команды:
;   <ESC>[H   - Cursor home
;   <ESC>[2J  - Erase screen
;
; Вызовы: FLASH_CONST_TO_UART
; Используются: r13*, r16*
; Вход: -
; Выход: -
;------------------------------------------------------------------------------
cmd_clear:
			ldi		ZL,low(clear_seq_const*2)
			ldi		ZH,high(clear_seq_const*2)
			rcall	FLASH_CONST_TO_UART
			ldi		r16,255		; не выводить сообщение 'ОК'
			mov		r13,r16
			ret


;------------------------------------------------------------------------------
; Перезагрузка
; 
;------------------------------------------------------------------------------
cmd_reboot:
			jmp 0x0000


;------------------------------------------------------------------------------
; Выводит Meow в терминал
; 
;------------------------------------------------------------------------------
cmd_meow:
			ldi		ZL,low(meow_const*2)
			ldi		ZH,high(meow_const*2)
			rcall	FLASH_CONST_TO_UART
			ldi		r16,255		; не выводить сообщение 'ОК'
			mov		r13,r16
			ret


;------------------------------------------------------------------------------
; Команда Эхо
; Выводит в терминал то же, что и ввели в ее первом аргументе
; 
;------------------------------------------------------------------------------
cmd_echo:
			lds		r16,ARG_COUNT		; кол-во аргументов
			tst		r16
			brne	cmd_echo_max_arg_tst
			rjmp	cmd_no_args	; нет аргументов
cmd_echo_max_arg_tst:
			cpi		r16,1
			breq	cmd_echo_next
			rjmp	cmd_too_many_args
cmd_echo_next:
			ldi		r16,1			; берем первый аргумент
			rcall	GET_ARGUMENT
			movw	X,Y
			rcall	STRING_TO_UART
			clr		r13				; успешный результат
			ret

;------------------------------------------------------------------------------
; Общие для всех переходы для генерации сообщения об ошибках
;------------------------------------------------------------------------------
cmd_invalid_arg_count:
			ldi		r16,3	; код ошибки: "некорректное число аргументов"
			mov		r13,r16
			ret
cmd_no_args:
			ldi		r16,6	; код ошибки: "отсутствуют аргументы"
			mov		r13,r16
			ret
cmd_too_many_args:
			ldi		r16,5	; код ошибки: "слишком много аргументов"
			mov		r13,r16
			ret



;------------------------------------------------------------------------------
; Установка нового значения переменной
; 
; Команда имеет два аргумента: имя переменной и значение
;------------------------------------------------------------------------------
cmd_set:
			lds		r16,ARG_COUNT		; кол-во аргументов
			tst		r16
			brne	cmd_set_max_arg_tst
			rjmp	cmd_no_args	; нет аргументов
cmd_set_max_arg_tst:
			cpi		r16,2
			breq	cmd_set_next
			rjmp	cmd_invalid_arg_count
cmd_set_next:
			; надо написать подпрограмму, аналогичную DEFINE_CMD
			; для распознавания переменной
			; Создать массив адресов переменных
			; Но ведь переменные итак лежат в памяти друг за другом
			; Зная адрес первой переменной можно получить доступ к остальным прибавив смещение
			; Хорошо. Но как быть с однобайтовой переменной?
			; Всё равно нужен список имен переменных во Flash, для того, 
			; чтобы сравнивать с ним полученное по UART имя
			; Надо сделать все переменные двухбайтовыми, чтобы был универсальный доступ
			ret


;------------------------------------------------------------------------------
; Получение переменной
; вывод значения переменной в терминал
;------------------------------------------------------------------------------
cmd_get:
			lds		r16,ARG_COUNT		; кол-во аргументов
			tst		r16
			brne	cmd_get_max_arg_tst
			rjmp	cmd_no_args	; нет аргументов
cmd_get_max_arg_tst:
			cpi		r16,1
			breq	cmd_get_next
			rjmp	cmd_too_many_args
cmd_get_next:
			ldi		r16,1			; берем первый аргумент
			rcall	GET_ARGUMENT	; (Y - poimter to zero ending argument string)
			rcall	DEFINE_VAR
			tst		r13
			breq	cmd_get_VAR_FOUND
			ldi		r16,4	; код ошибки: "некорректное значение аргумента"
			mov		r13,r16
			ret
cmd_get_VAR_FOUND:
			
			ret



;-----------------------------------------------------------------------------
; Определить переменную
; Ищет переменную среди известных
; Записывает в VAR_ID идентификатор обнаруженной переменной
; 
; Вызовы: STR_CMP
; Используются: r0*, r1*, r13*, r16*, r18*, r24*, r25*, X*, Z*
; Вход: Y - указатель на имя полученной переменной
; Выход: VAR_ID, r13
;        r13 = 0 - ok
;        r13 = 2 - неизвестная команда
;-----------------------------------------------------------------------------
.equ	VAR_COUNT     = 6			; кол-во команд. Увеличить при добавлении новых!
DEFINE_VAR:
			clr		r18			; счетчик ID переменных
DEF_VAR_LOOP:
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			mov		r0,r18
			ldi		r16,4	; строка из 4 байт
			mul		r0,r16
			add		ZL,r0
			adc		ZH,r1
			lpm		r24,Z+
			lpm		r25,Z
			movw	ZL,r24
			movw	XL,YL
			rcall	STR_CMP
			tst		r16				; результат проверки
			breq	VAR_FOUND		; если равны - переходим
			inc		r18				; если не равны, увеличиваем счетчик комманд
			cpi		r18,VAR_COUNT	; не кончился ли список команд?
			brne	DEF_VAR_LOOP	; нет, не кончился, еще итерация
			rjmp	VAR_NOT_FOUND	; кончился, команда не найдена
VAR_FOUND:
			sts		VAR_ID,r18		; сохраняем ID найденной команды
			clr		r13		; статус успеха
			ret
VAR_NOT_FOUND:
			; команда не найдена
			ldi		r16,2		; статус "неизвестная команда"
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
cmd_set_const:				.db "set",0
cmd_get_const:				.db "get",0
;cmd_pwm_const:				.db "pwm",0
;cmd_adc_const:				.db "adc",0
;cmd_adc2_const:				.db "adc2",0,0
;cmd_dac_const:				.db "dac",0
;cmd_vah_const:				.db "vah",0
;cmd_start_const:			.db "start",0
meow_const:					.db "Meow",0,0
clear_seq_const:			.db 27, "[", "H", 27, "[", "2J",0

; Имена переменных
IVC_DAC_START_const:		.db "IVC_DAC_START",0
IVC_DAC_END_const:			.db "IVC_DAC_END",0
IVC_DAC_STEP_const:			.db "IVC_DAC_STEP",0,0
CH0_DELTA_const:			.db "CH0_DELTA",0
ADC_V_REF_const:			.db "ADC_V_REF",0
ACS712_KI_const:			.db "ACS712_KI",0

; Таблица адресов имен команд и адресов подпрограмм
CMD_TABLE:					.db low(cmd_clear_const*2), high(cmd_clear_const*2), low(cmd_clear), high(cmd_clear)
							.db low(cmd_reboot_const*2),high(cmd_reboot_const*2),low(cmd_reboot),high(cmd_reboot)
							.db low(cmd_echo_const*2),  high(cmd_echo_const*2),  low(cmd_echo),  high(cmd_echo)
							.db low(cmd_meow_const*2),  high(cmd_meow_const*2),  low(cmd_meow),  high(cmd_meow)
							.db low(cmd_set_const*2),   high(cmd_set_const*2),   low(cmd_set),   high(cmd_set)
							.db low(cmd_get_const*2),   high(cmd_get_const*2),   low(cmd_get),   high(cmd_get)

; Таблица адресов имен переменных во Flash и адресов значений в RAM
VAR_TABLE:					.db low(IVC_DAC_START_const*2),high(IVC_DAC_START_const*2),low(IVC_DAC_START),high(IVC_DAC_START)
							.db low(IVC_DAC_END_const*2),  high(IVC_DAC_END_const*2),  low(IVC_DAC_END),   high(IVC_DAC_END)
							.db low(IVC_DAC_STEP_const*2), high(IVC_DAC_STEP_const*2), low(IVC_DAC_STEP),  high(IVC_DAC_STEP)
							.db low(CH0_DELTA_const*2),    high(CH0_DELTA_const*2),    low(CH0_DELTA),     high(CH0_DELTA)
							.db low(ADC_V_REF_const*2),    high(ADC_V_REF_const*2),    low(ADC_V_REF),     high(ADC_V_REF)
							.db low(ACS712_KI_const*2),    high(ACS712_KI_const*2),    low(ACS712_KI),     high(ACS712_KI)

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
