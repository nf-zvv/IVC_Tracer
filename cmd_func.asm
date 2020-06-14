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
; 10.03.2020 ADD: SET и GET команды
; 11.03.2020 CMD_TABLE. Использование Flash вместо RAM
;------------------------------------------------------------------------------
#ifndef _CMD_FUNC_ASM_
#define _CMD_FUNC_ASM_

.equ	VAR_COUNT     = 9			; кол-во переменных (для команд SET и GET)

.dseg
VAR_ID:		.byte 1


.cseg
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

			; Теперь это бесполезная подпрограмма

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
			ldi		r16,1			; берем первый аргумент
			rcall	GET_ARGUMENT	; (Y - pointer to zero ending argument string)
			movw	XL,YL
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			ldi		r19,VAR_COUNT
			rcall	LOCATE_STR
			cpi		r18,-1
			breq	cmd_set_error_arg
			; Переменная найдена!
			sts		VAR_ID,r18		; сохраняем ID найденной переменной
			ldi		r16,2			; берем второй аргумент
			rcall	GET_ARGUMENT	; (OUT: Y - pointer to zero-ended argument string)
			rcall	STR_TO_UINT16	; (IN: Y; OUT: r25:r24)
			tst		r13
			brne	cmd_set_error_num
			; Загружаем адрес таблицы
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			lds		r0,VAR_ID			; загружаем ID переменной
			; Добавляем смещение
			ldi		r16,4
			mul		r0,r16
			add		ZL,r0
			adc		ZH,r1
			adiw	ZL,2	; позиционируемся на адрес переменной в RAM
			lpm		XL,Z+
			lpm		XH,Z	; теперь X указывает на значение переменной в RAM
			; сохраняем второй аргумент по найденному адресу
			st		X+,r24
			st		X,r25
			; Выводим значение в терминал
			rcall	GET_VAR_KEY_VAL ; (IN: VAR_ID)
			; Сохраняем в EEPROM
			rcall	EEPROM_SAVE_CALIBRATIONS
			clr		r13
			ret
cmd_set_error_arg:
			ldi		r16,4	; код ошибки: "некорректное значение аргумента"
			mov		r13,r16
			ret
cmd_set_error_num:
			ldi		r16,8	; код ошибки: "некорректное число"
			mov		r13,r16
			ret


;------------------------------------------------------------------------------
; Получение переменной
; вывод значения переменной в терминал
;------------------------------------------------------------------------------
cmd_get:
			lds		r16,ARG_COUNT		; кол-во аргументов
			tst		r16
			brne	cmd_get_max_arg_tst
			rjmp	cmd_get_all	; нет аргументов - выдаем все переменные
cmd_get_max_arg_tst:
			cpi		r16,1
			breq	cmd_get_next
			rjmp	cmd_too_many_args
cmd_get_next:
			ldi		r16,1			; берем первый аргумент
			rcall	GET_ARGUMENT	; (Y - pointer to zero ending argument string)
			; Сначала проверяем, не запрошены ли все переменные одновременно
			movw	XL,YL
			ldi		ZL,low(ALL_const*2)		; аргумент ALL
			ldi		ZH,high(ALL_const*2)
			rcall	STR_CMP
			tst		r16				; результат проверки
			brne	cmd_get_single_var
cmd_get_all:
			; Выдаём все переменные
			rcall	GET_ALL_VARS
			rjmp	cmd_get_success
cmd_get_single_var:
			movw	XL,YL
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			ldi		r19,VAR_COUNT
			rcall	LOCATE_STR
			cpi		r18,-1
			breq	cmd_get_VAR_NOT_FOUND
			; Переменная найдена!
			sts		VAR_ID,r18		; сохраняем ID найденной переменной
			movw	XL,YL
			rcall	STRING_TO_UART ; (IN: X)
			ldi		r16,'='
			rcall	uart_snt
			; Загружаем адрес таблицы
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			lds		r0,VAR_ID			; загружаем ID переменной
			; Добавляем смещение
			ldi		r16,4
			mul		r0,r16
			add		ZL,r0
			adc		ZH,r1
			adiw	ZL,2	; позиционируемся на адрес переменной в RAM
			lpm		XL,Z+
			lpm		XH,Z	; теперь X указывает на значение переменной в RAM
			; извлекаем значение
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
			ldi		r16,4	; код ошибки: "некорректное значение аргумента"
			mov		r13,r16
			ret


;------------------------------------------------------------------------------
; Запуск процесса автоматического снятия ВАХ
; Результаты выдаются в терминал
;------------------------------------------------------------------------------
cmd_start:
			rcall	BTN_LONG_PRESS_EVENT
			clr		r13
			ret


;------------------------------------------------------------------------------
; Получение текущего или установка нового значения ЦАП
; 
;------------------------------------------------------------------------------
cmd_dac:
			lds		r16,ARG_COUNT		; кол-во аргументов
			tst		r16
			brne	cmd_dac_max_arg_tst
			rjmp	cmd_dac_show	; нет аргументов - выводим текущее значение
cmd_dac_max_arg_tst:
			cpi		r16,1
			breq	cmd_dac_next
			rjmp	cmd_too_many_args
cmd_dac_next:
			ldi		r16,1			; берем первый аргумент
			rcall	GET_ARGUMENT	; (Y - pointer to zero ending argument string)
			rcall	STR_TO_UINT16	; (IN: Y; OUT: r25:r24)
			tst		r13
			brne	cmd_dac_error_num
			sts		DAC+0,r24
			sts		DAC+1,r25
			rcall	DAC_SET
			rjmp	cmd_dac_success
cmd_dac_show:
			ldi		ZL,low(DAC_const*2)
			ldi		ZH,high(DAC_const*2)
			rcall	FLASH_CONST_TO_UART ; (IN: Z)
			lds		XL,DAC+0
			lds		XH,DAC+1
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR5 ; (IN: X; OUT: Y)
			ldi		XL,low(STRING)
			ldi		XH,high(STRING)
			rcall	STRING_TO_UART ; (IN: X)
			rcall	UART_LF_CR
			rjmp	cmd_dac_success
cmd_dac_error_num:
			ldi		r16,8	; код ошибки: "некорректное число"
			mov		r13,r16
			ret
cmd_dac_success:
			clr		r13
			ret


;------------------------------------------------------------------------------
; Получение всех переменных
; вывод значений переменных в терминал
;
; Вызовы: FLASH_CONST_TO_UART, STRING_TO_UART, UART_LF_CR, uart_snt, DEC_TO_STR5
; Используются: r16*, r17*, r19*, r24*, r25*, X*, Y*, Z*
; Вход: VAR_TABLE
;       r19 - количество элементов
; Выход: 
;------------------------------------------------------------------------------
GET_ALL_VARS:
			ldi		r24,low(VAR_TABLE*2)
			ldi		r25,high(VAR_TABLE*2)
			ldi		r19,VAR_COUNT
GET_ALL_VARS_LOOP:
			movw	ZL,r24
			; Извлекаем адрес имени переменной
			lpm		r16,Z+
			lpm		r17,Z+
			; Извлекаем адрес значения переменной
			lpm		YL,Z+
			lpm		YH,Z
			movw	ZL,r16
			rcall	FLASH_CONST_TO_UART ; (IN: Z)
			ldi		r16,'='
			rcall	uart_snt
			; Извлекаем значение
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
			brne	GET_ALL_VARS_LOOP
			ret


;------------------------------------------------------------------------------
; Вывод пары "имя=значение" переменной в UART
;
;
; Вызовы: FLASH_CONST_TO_UART, STRING_TO_UART, UART_LF_CR, uart_snt, DEC_TO_STR5
; Используются: r0*, r1*, r16*, r17*, X*, Y*, Z*
; Вход: VAR_ID
; Выход: 
;------------------------------------------------------------------------------
GET_VAR_KEY_VAL:
			; Загружаем адрес таблицы
			ldi		ZL,low(VAR_TABLE*2)
			ldi		ZH,high(VAR_TABLE*2)
			lds		r0,VAR_ID			; загружаем ID переменной
			; Добавляем смещение
			ldi		r16,4
			mul		r0,r16
			add		ZL,r0
			adc		ZH,r1
			; Извлекаем адрес имени переменной
			lpm		r16,Z+
			lpm		r17,Z+
			; Извлекаем адрес значения переменной
			lpm		YL,Z+
			lpm		YH,Z
			movw	ZL,r16
			rcall	FLASH_CONST_TO_UART ; (IN: Z)
			ldi		r16,'='
			rcall	uart_snt
			; Извлекаем значение
			ld		XL,Y+
			ld		XH,Y
			ldi		YL,low(STRING)
			ldi		YH,high(STRING)
			rcall	DEC_TO_STR5 ; (IN: X; OUT: Y)
			ldi		XL,low(STRING)
			ldi		XH,high(STRING)
			rcall	STRING_TO_UART ; (IN: X)
			rcall	UART_LF_CR
			ret

;------------------------------------------------------------------------------
; Сохранение переменных в EEPROM
; 
; С целью экономии числа перезаписей EEPROM добавлена проверка перед записью
;------------------------------------------------------------------------------
EEPROM_SAVE_CALIBRATIONS:
			; DAC_STEP
			ldi		r16,low(E_DAC_STEP+0)
			ldi		r17,high(E_DAC_STEP+0)
			rcall	EERead
			lds		r19,DAC_STEP+0
			cp		r18,r19
			breq	test_next_byte_1
			mov		r18,r19
			rcall	EEWrite
test_next_byte_1:
			ldi		r16,low(E_DAC_STEP+1)
			ldi		r17,high(E_DAC_STEP+1)
			rcall	EERead
			lds		r19,DAC_STEP+1
			cp		r18,r19
			breq	test_next_byte_2
			mov		r18,r19
			rcall	EEWrite
test_next_byte_2:
			; IVC_DAC_START
			ldi		r16,low(E_IVC_DAC_START+0)
			ldi		r17,high(E_IVC_DAC_START+0)
			rcall	EERead
			lds		r19,IVC_DAC_START+0
			cp		r18,r19
			breq	test_next_byte_3
			mov		r18,r19
			rcall	EEWrite
test_next_byte_3:
			ldi		r16,low(E_IVC_DAC_START+1)
			ldi		r17,high(E_IVC_DAC_START+1)
			rcall	EERead
			lds		r19,IVC_DAC_START+1
			cp		r18,r19
			breq	test_next_byte_4
			mov		r18,r19
			rcall	EEWrite
test_next_byte_4:
			; IVC_DAC_END
			ldi		r16,low(E_IVC_DAC_END+0)
			ldi		r17,high(E_IVC_DAC_END+0)
			rcall	EERead
			lds		r19,IVC_DAC_END+0
			cp		r18,r19
			breq	test_next_byte_5
			mov		r18,r19
			rcall	EEWrite
test_next_byte_5:
			ldi		r16,low(E_IVC_DAC_END+1)
			ldi		r17,high(E_IVC_DAC_END+1)
			rcall	EERead
			lds		r19,IVC_DAC_END+1
			cp		r18,r19
			breq	test_next_byte_6
			mov		r18,r19
			rcall	EEWrite
test_next_byte_6:
			; IVC_DAC_STEP
			ldi		r16,low(E_IVC_DAC_STEP+0)
			ldi		r17,high(E_IVC_DAC_STEP+0)
			rcall	EERead
			lds		r19,IVC_DAC_STEP+0
			cp		r18,r19
			breq	test_next_byte_7
			mov		r18,r19
			rcall	EEWrite
test_next_byte_7:
			ldi		r16,low(E_IVC_DAC_STEP+1)
			ldi		r17,high(E_IVC_DAC_STEP+1)
			rcall	EERead
			lds		r19,IVC_DAC_STEP+1
			cp		r18,r19
			breq	test_next_byte_8
			mov		r18,r19
			rcall	EEWrite
test_next_byte_8:
			; CH0_DELTA
			ldi		r16,low(E_CH0_DELTA+0)
			ldi		r17,high(E_CH0_DELTA+0)
			rcall	EERead
			lds		r19,CH0_DELTA+0
			cp		r18,r19
			breq	test_next_byte_9
			mov		r18,r19
			rcall	EEWrite
test_next_byte_9:
			ldi		r16,low(E_CH0_DELTA+1)
			ldi		r17,high(E_CH0_DELTA+1)
			rcall	EERead
			lds		r19,CH0_DELTA+1
			cp		r18,r19
			breq	test_next_byte_10
			mov		r18,r19
			rcall	EEWrite
test_next_byte_10:
			; ADC_V_REF
			ldi		r16,low(E_ADC_V_REF+0)
			ldi		r17,high(E_ADC_V_REF+0)
			rcall	EERead
			lds		r19,ADC_V_REF+0
			cp		r18,r19
			breq	test_next_byte_11
			mov		r18,r19
			rcall	EEWrite
test_next_byte_11:
			ldi		r16,low(E_ADC_V_REF+1)
			ldi		r17,high(E_ADC_V_REF+1)
			rcall	EERead
			lds		r19,ADC_V_REF+1
			cp		r18,r19
			breq	test_next_byte_12
			mov		r18,r19
			rcall	EEWrite
test_next_byte_12:
			; ACS712_KI
			ldi		r16,low(E_ACS712_KI)
			ldi		r17,high(E_ACS712_KI)
			rcall	EERead
			lds		r19,ACS712_KI
			cp		r18,r19
			breq	test_next_byte_13
			mov		r18,r19
			rcall	EEWrite
test_next_byte_13:
			; RESDIV_KU
			ldi		r16,low(E_RESDIV_KU)
			ldi		r17,high(E_RESDIV_KU)
			rcall	EERead
			lds		r19,RESDIV_KU
			cp		r18,r19
			breq	test_next_byte_14
			mov		r18,r19
			rcall	EEWrite
test_next_byte_14:
			; VAH_DELAY
			ldi		r16,low(E_VAH_DELAY)
			ldi		r17,high(E_VAH_DELAY)
			rcall	EERead
			lds		r19,VAH_DELAY
			cp		r18,r19
			breq	test_next_byte_15
			mov		r18,r19
			rcall	EEWrite
test_next_byte_15:
			ret



; === Мысль ===
; 16.03.2020
; Сделать отдельные подпрограммы:
; - поиск переменной по имени (на выходе VAR_ID)
; - получение имени по VAR_ID (на выходе указатель на zero-ended строку)
; - получение значения по VAR_ID (на выходе двухбайтовое значение)
; - установка нового значения по VAR_ID
; - получение пары "имя=значение" по VAR_ID (вывод в терминал)
; Добавить адреса EEPROM в таблицу переменных,
; чтобы потом сохранять/считывать также по VAR_ID


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
;cmd_adc_const:				.db "adc",0
cmd_start_const:			.db "start",0
cmd_dac_const:				.db "dac",0
meow_const:					.db "Meow! ^_^",0
clear_seq_const:			.db 27, "[", "H", 27, "[", "2", "J",0

; Имена переменных
DAC_STEP_var_name:			.db "DAC_STEP",0,0
IVC_DAC_START_var_name:		.db "IVC_DAC_START",0
IVC_DAC_END_var_name:		.db "IVC_DAC_END",0
IVC_DAC_STEP_var_name:		.db "IVC_DAC_STEP",0,0
CH0_DELTA_var_name:			.db "CH0_DELTA",0
ADC_V_REF_var_name:			.db "ADC_V_REF",0
ACS712_KI_var_name:			.db "ACS712_KI",0
RESDIV_KU_var_name:			.db "RESDIV_KU",0
VAH_DELAY_var_name:			.db "VAH_DELAY",0

ALL_const:					.db "ALL",0
DAC_const:					.db "DAC=",0,0

; Таблица адресов имен команд и адресов подпрограмм
CMD_TABLE:
.db low(cmd_clear_const*2), high(cmd_clear_const*2), low(cmd_clear), high(cmd_clear)
.db low(cmd_reboot_const*2),high(cmd_reboot_const*2),low(cmd_reboot),high(cmd_reboot)
.db low(cmd_echo_const*2),  high(cmd_echo_const*2),  low(cmd_echo),  high(cmd_echo)
.db low(cmd_meow_const*2),  high(cmd_meow_const*2),  low(cmd_meow),  high(cmd_meow)
.db low(cmd_set_const*2),   high(cmd_set_const*2),   low(cmd_set),   high(cmd_set)
.db low(cmd_get_const*2),   high(cmd_get_const*2),   low(cmd_get),   high(cmd_get)
.db low(cmd_start_const*2), high(cmd_start_const*2), low(cmd_start), high(cmd_start)
.db low(cmd_dac_const*2),   high(cmd_dac_const*2),   low(cmd_dac),   high(cmd_dac)

; Таблица адресов имен переменных во Flash и адресов значений в RAM
VAR_TABLE:
.db low(DAC_STEP_var_name*2),     high(DAC_STEP_var_name*2),     low(DAC_STEP),     high(DAC_STEP)
.db low(IVC_DAC_START_var_name*2),high(IVC_DAC_START_var_name*2),low(IVC_DAC_START),high(IVC_DAC_START)
.db low(IVC_DAC_END_var_name*2),  high(IVC_DAC_END_var_name*2),  low(IVC_DAC_END),  high(IVC_DAC_END)
.db low(IVC_DAC_STEP_var_name*2), high(IVC_DAC_STEP_var_name*2), low(IVC_DAC_STEP), high(IVC_DAC_STEP)
.db low(CH0_DELTA_var_name*2),    high(CH0_DELTA_var_name*2),    low(CH0_DELTA),    high(CH0_DELTA)
.db low(ADC_V_REF_var_name*2),    high(ADC_V_REF_var_name*2),    low(ADC_V_REF),    high(ADC_V_REF)
.db low(ACS712_KI_var_name*2),    high(ACS712_KI_var_name*2),    low(ACS712_KI),    high(ACS712_KI)
.db low(RESDIV_KU_var_name*2),    high(RESDIV_KU_var_name*2),    low(RESDIV_KU),    high(RESDIV_KU)
.db low(VAH_DELAY_var_name*2),    high(VAH_DELAY_var_name*2),    low(VAH_DELAY),    high(VAH_DELAY)

#endif  /* _CMD_FUNC_ASM_ */

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
