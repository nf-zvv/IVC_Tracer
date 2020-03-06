;------------------------------------------------------------------------------
; Набор макросов для упрощения сохранения/считывания констант из EEPROM
; 
; 
; 
; 
;------------------------------------------------------------------------------

			; Запись байта в EEPROM
			; Первый параметр - адрес в EEPROM
			; Второй параметр - записываемый байт
			.MACRO 	EEPROM_WRITE_BYTE
			ldi		r16,low(@0+0)
			ldi		r17,high(@0+0)
			ldi		r18,@1
			rcall	EEWrite
			.ENDMACRO

			; Чтение байта из EEPROM в память RAM
			; Первый параметр - адрес в EEPROM
			; Второй параметр - ячейка памяти RAM
			.MACRO 	EEPROM_READ_BYTE
			ldi		r16,low(@0+0)
			ldi		r17,high(@0+0)
			rcall	EERead
			sts		@1,r18
			.ENDMACRO

			; Запись слова в EEPROM
			; Первый параметр - адрес в EEPROM
			; Второй параметр - записываемое слово
			.MACRO 	EEPROM_WRITE_WORD
			ldi		r16,low(@0+0)
			ldi		r17,high(@0+0)
			ldi		r18,low(@1)
			rcall	EEWrite
			ldi		r16,low(@0+1)
			ldi		r17,high(@0+1)
			ldi		r18,high(@1)
			rcall	EEWrite
			.ENDMACRO

			; Чтение слова из EEPROM в память RAM
			; Первый параметр - адрес в EEPROM
			; Второй параметр - ячейка памяти RAM
			.MACRO 	EEPROM_READ_WORD
			ldi		r16,low(@0+0)
			ldi		r17,high(@0+0)
			rcall	EERead
			sts		@1+0,r18
			ldi		r16,low(@0+1)
			ldi		r17,high(@0+1)
			rcall	EERead
			sts		@1+1,r18
			.ENDMACRO
