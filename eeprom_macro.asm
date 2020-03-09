;------------------------------------------------------------------------------
; ����� �������� ��� ��������� ����������/���������� �������� �� EEPROM
; 
; 
; 
; 
;------------------------------------------------------------------------------

			; ������ ����� � EEPROM
			; ������ �������� - ����� � EEPROM
			; ������ �������� - ������������ ����
			.MACRO 	EEPROM_WRITE_BYTE
			ldi		r16,low(@0+0)
			ldi		r17,high(@0+0)
			ldi		r18,@1
			rcall	EEWrite
			.ENDMACRO

			; ������ ����� �� EEPROM � ������ RAM
			; ������ �������� - ����� � EEPROM
			; ������ �������� - ������ ������ RAM
			.MACRO 	EEPROM_READ_BYTE
			ldi		r16,low(@0+0)
			ldi		r17,high(@0+0)
			rcall	EERead
			sts		@1,r18
			.ENDMACRO

			; ������ ����� � EEPROM
			; ������ �������� - ����� � EEPROM
			; ������ �������� - ������������ �����
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

			; ������ ����� �� EEPROM � ������ RAM
			; ������ �������� - ����� � EEPROM
			; ������ �������� - ������ ������ RAM
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
