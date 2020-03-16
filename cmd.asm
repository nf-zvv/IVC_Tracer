;==============================================================================
; Интерпретатор команд
; 
;
; (C) 2017-2020 Vitaliy Zinoviev
; https://github.com/nf-zvv/IVC_Tracer
;
; History
; =======
; 24.04.2017
; 27.08.2017 подпрограммы FLASH_CONST_TO_UART, RAM_STR_TO_UART, UART_OK
;            перенесены в файл uart_funcs.asm
; 07.06.2018 ADD: подпрограмма ZEROING_BUFF - обнуление буфера
; 08.06.2018 ADD: отдельная подпрограмма вывода ошибок по коду ошибки
; 09.03.2020 
; 10.03.2020 косметические исправления
;            SPLIT_ARGS переименована в SPLIT_LINE
; 12.03.2020 Оптимизация. Вместо использования RAM для хранения таблицы 
;            "имя команды - адрес подпрограммы" теперь используется Flash
; 14.03.2020 Из подпрограммы DEFINE_CMD код поиска строки в массиве вынесен 
;            в отдельную подпрограмму LOCATE_STR
;==============================================================================
#ifndef _CMD_ASM_
#define _CMD_ASM_


.ifndef __zero_reg__
.def __zero_reg__ = r2
.endif

.equ	CMD_COUNT     = 7			; кол-во команд. Увеличить при добавлении новых!
.equ	ARG_COUNT_MAX = 2			; максимальное кол-во аргументов
.equ	CMDLINE_LEN   = 32

;-------------------------------------------------------
;                                                       |
;-------------------------------------------------------|
.dseg
CMD_ID:			.byte	1				; ID команды в списке CMD_LIST
ARG_COUNT:		.byte	1				; кол-во переданых аргументов
ARG_ADDR_LIST:	.byte	ARG_COUNT_MAX	; массив смещений аргументов
CMDLINE:		.byte	CMDLINE_LEN		; обработанная командная строка


.cseg
;------------------------------------------------------------------------------
; Распознавание введенной строки, ее исполнение, 
;   выдача сообщения об успехе или провале
; Вызовы: SPLIT_LINE, DEFINE_CMD, EXEC_CMD, UART_OK, FLASH_CONST_TO_UART
; Используются: r13, r16*, Z*
; Вход: 
; Выход: 
;------------------------------------------------------------------------------
UART_RX_PARSE:
			CLFL	UART_Flags,UART_STR_RCV	; сброс флага
			rcall	SPLIT_LINE		; разбивка входной строки
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
			; после выполнения EXEC_CMD сразу переходим на PRINT_ERROR
			; там выводится либо ОК, либо сообщение об ошибке
			; возврат из подпрограммы UART_RX_PARSE (ret) делается там же


;-----------------------------------------------------------------------------
; Вывод в терминал сообщений об ошибках
; 
; Коды ошибок:
;   0 - OK (нет ошибок)
;   1 - ошибка разбивки строки на аргуметы
;   2 - неизвестная команда
;   3 - некорректное число аргументов
;   4 - некорректное значение аргумента (ожидалось число)
;   5 - слишком много аргументов
;   6 - отсутствует аргумент
;   7 - неизвестная ошибка
;   8 - некорректное число
; 255 - ничего не выводить
; 
; Вызовы: 
; Используются: 
; Вход: r13 - код ошибки
; Выход: 
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
; Разбивка строки аргументов
; Поочередно считываем символы из кольцевого буфера UART
; Помещаем считанные символы в буфер CMDLINE
; Пробелы заменяем символами \0
; Заполняем массив адресов аргументов
; 
; Вызовы: ZEROING_BUFF, Buff_Pop, IS_CHAR
; Используются: r13*, r14*, r16*, r17*, r19*, X*, Y*
; Вход: входной буфер UART
; Выход: r13
;        r13 = 0 - ok
;        r13 = 1 - ложный вызов
;-----------------------------------------------------------------------------
SPLIT_LINE:
			; обнуление буферов
			ldi		r16,ARG_COUNT_MAX
			ldi		YL,low(ARG_ADDR_LIST)
			ldi		YH,high(ARG_ADDR_LIST)
			rcall	ZEROING_BUFF
			ldi		r16,CMDLINE_LEN
			ldi		YL,low(CMDLINE)
			ldi		YH,high(CMDLINE)
			rcall	ZEROING_BUFF

			; обнуление переменных
			sts		ARG_COUNT,__zero_reg__	; обнуляем кол-во аргументов
			clr		r18		; счетчик символов
			clr		r14		; предыдущий символ

			ldi		XL,low(CMDLINE)		; буфер для записи коммандной строки
			ldi		XH,high(CMDLINE)
			ldi		YL,low(ARG_ADDR_LIST)	; буфер смещений аргуметов
			ldi		YH,high(ARG_ADDR_LIST)
SPLIT_LINE_LOOP:
			rcall	Buff_Pop		; извлекаем символ из входного буфера UART
			cpi		r19,1			; если статус 1, то буфер пуст
			breq	SPLIT_LINE_END	; значит, выходим
			; получили первый символ (он находится в r16)
			; Проверяем на принадлежность к печатаемым знакам
			mov		r17,r16
			rcall	IS_CHAR
			tst		r16
			breq	_nonchar		; не символ - переходим
			st		X+,r17			; сохраняем символ в массив CMDLINE
			ldi		r16,0x20
			cp		r14,r16			; предыдущий символ был "пробел"?
			breq	is_arg_start
			rjmp	skip_arg_start
is_arg_start:
			lds		r16,ARG_COUNT	; загружаем прежднее число аргументов
			inc		r16				; увеличиваем кол-во найденных аргументов
			sts		ARG_COUNT,r16	; сохраняем обратно
			; записываем смещение аргумента в массив ARG_ADDR_LIST
			st		Y+,r18
skip_arg_start:
			mov		r14,r17		; предыдущим становится текущий
			inc		r18			; увеличиваем счетчик символов
			rjmp	SPLIT_LINE_LOOP
_nonchar:
			cpi		r17,0x20
			breq	space_rcv
			cpi		r17,13		; символ конца командной строки
			breq	enter_rcv
			cpi		r17,'_'
			breq	underline_rcv
			rjmp	SPLIT_LINE_LOOP
space_rcv:
			tst		r14					; если пробел в самом начале (r14=0)
			breq	SPLIT_LINE_LOOP		; - следующая итерация
			ldi		r16,0x20
			cp		r14,r16			; если пробел после пробела (r14=0x20)
			breq	SPLIT_LINE_LOOP		; - следующая итерация
			clr		r16
			st		X+,r16		; записываем 0 как символ конца аргумента
			mov		r14,r17		; предыдущим становится пробел
			inc		r18			; увеличиваем счетчик
			rjmp	SPLIT_LINE_LOOP
enter_rcv:
			tst		r18					; проверяем счетчик
			brne	SPLIT_LINE_success		; разбор строки успешен
			; нажали enter в самом начале - выходим
			; но установим статус ложного вызова:
			ldi		r16,1
			mov		r13,r16
			rjmp	SPLIT_LINE_LOOP
underline_rcv:
			st		X+,r17
			inc		r18			; увеличиваем счетчик
			rjmp	SPLIT_LINE_LOOP
SPLIT_LINE_success:
			; иначе - enter нажат в конце командной строки
			; добавим ноль - признак конца строки вместо enter'а
			st		X+,__zero_reg__		; записываем 0 как символ конца строки
			clr		r13
			;rjmp	SPLIT_LINE_LOOP
			; 10.03.2020 закомментировал строку выше:
			; зачем возвращаться, если уже получен enter?
			; только если с целью полностью опустошить буфер
			; Возможно здесь баг
			; Тогда надо опустошить буфер
			; А если по какой-то причине в буфере что-то есть, 
			; но enter не пришел? Например, при переолнении входящего буфера.
			; В любом случае надо опустошать буфер по завершении этой подпрограммы
EMPTY_BUFFER:
SPLIT_LINE_END:
			ret


;-----------------------------------------------------------------------------
; Обнуление буфера
; 
; Вызовы: 
; Используются: r16*, Y*
; Вход: Y - указатель на буфер
;       r16 - длина буфера
; Выход: 
;-----------------------------------------------------------------------------
ZEROING_BUFF:
			st		Y+,__zero_reg__
			dec		r16
			brne	ZEROING_BUFF
			ret


;-----------------------------------------------------------------------------
; Определить команду
; Ищет введенную команду среди известных
; Записывает в CMD_ID идентификатор обнаруженной команды
; 
; Вызовы: LOCATE_STR
; Используются: r13*, r18*, r19*, X*, Z*
; Вход: CMD_TABLE, CMDLINE
; Выход: CMD_ID, r13
;        r13 = 0 - ok
;        r13 = 2 - неизвестная команда
;-----------------------------------------------------------------------------
DEFINE_CMD:
			; Загружаем адрес таблицы
			ldi		ZL,low(CMD_TABLE*2)
			ldi		ZH,high(CMD_TABLE*2)
			ldi		XL,low(CMDLINE)		; буфер с командой,
			ldi		XH,high(CMDLINE)	; принятой по UART
			ldi		r19,CMD_COUNT		; количество элементов
			rcall	LOCATE_STR
			cpi		r18,-1
			breq	CMD_NOT_FOUND
			; команда найдена
			sts		CMD_ID,r18		; сохраняем ID найденной команды
			clr		r13		; статус успеха
			ret
CMD_NOT_FOUND:
			; команда не найдена
			ldi		r16,2		; статус "неизвестная команда"
			mov		r13,r16
			ret


;-----------------------------------------------------------------------------
; Поиск строки в массиве
; Ряд массива состоит из 4 байт. Первые два байта - указатель на строку
; Поиск строки осуществляется
; 
; Вызовы: STR_CMP
; Используются: r16*, r17*, r18*, r20*, r21*, r24*, r25*, X*, Z*
; Вход: X, Z - указатели на искомую строку (X) и таблицу (Z)
;       r19 - количество элементов
; Выход: r18 - индекс
;        если r18 = -1, то строка не найдена
;-----------------------------------------------------------------------------
LOCATE_STR:
			clr		r18		; счетчик
			movw	r24,ZL
			movw	r20,XL
LOCATE_STR_LOOP:
			movw	ZL,r24
			; Извлекаем адрес очередной команды
			lpm		r16,Z+
			lpm		r17,Z
			; Сравниваем полученную по UART команду с известными
			movw	XL,r20
			movw	ZL,r16
			rcall	STR_CMP
			tst		r16				; результат проверки
			breq	LOCATE_STR_FOUND		; если равны - переходим
			; Команда не совпала
			inc		r18				; если не равны, увеличиваем счетчик комманд
			adiw	r24,4
			cp		r18,r19	; не кончился ли список команд?
			brsh	LOCATE_STR_NOT_FOUND
			rjmp	LOCATE_STR_LOOP
LOCATE_STR_NOT_FOUND:
			ldi		r18,-1 ; строка не найдена
LOCATE_STR_FOUND:
			; Результат в регистре r18
			ret


;-----------------------------------------------------------------------------
; Передать управление команде
; Используются: r0*, r1*, r16*, r24*, r25*, Z*
; Вход: CMD_ID, CMD_LIST
; Выход: -
;-----------------------------------------------------------------------------
EXEC_CMD:
			; Загружаем адрес таблицы
			ldi		ZL,low(CMD_TABLE*2)
			ldi		ZH,high(CMD_TABLE*2)
			lds		r0,CMD_ID			; загружаем ID команды
			; Добавляем смещение
			ldi		r16,4
			mul		r0,r16
			add		ZL,r0
			adc		ZH,r1
			adiw	ZL,2	; позиционируемся на адрес подпрограммы
			lpm		r24,Z+
			lpm		r25,Z
			movw	ZL,r24	; теперь Z указывает на адрес подпрограммы
			ijmp			; косвенный переход к подпрограмме
			; передаем управление подпрограмме
			; в конце подпрограммы будет инструкция ret,
			; которая произведет возврат из EXEC_CMD


;-----------------------------------------------------------------------------
; Перемещает указатель на начало заданного аргумента
; Изпользует: r16*, X, Y*
; Вход: r16 - номер аргумента, начиная с 1
; Выход: Y, указывающий на начало строки аргумента
; 07.06.18 ADD: сохранение в стек регистра X
;-----------------------------------------------------------------------------
GET_ARGUMENT:
			push	XL
			push	XH
			ldi		YL,low(CMDLINE)		; коммандная строка
			ldi		YH,high(CMDLINE)	; 
			ldi		XL,low(ARG_ADDR_LIST)	; буфер смещений
			ldi		XH,high(ARG_ADDR_LIST)	; аргуметов
			dec		r16
			add		XL,r16				; позиционируем номер аргумента
			adc		XH,__zero_reg__		; <-- на случай переноса
			ld		r16,X				; загружаем смещение
			add		YL,r16				; переходим к началу заданного аргумента
			adc		YH,__zero_reg__		; <-- на случай переноса
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
