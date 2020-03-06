; Start coreinit.inc
RAM_Flush:	LDI	ZL,Low(SRAM_START)	; Адрес начала ОЗУ в индекс
			LDI	ZH,High(SRAM_START)
			CLR	R16					; Очищаем R16
Flush:		ST 	Z+,R16				; Сохраняем 0 в ячейку памяти
			CPI	ZH,High(RAMEND)		; Достигли конца оперативки?
			BRNE Flush				; Нет? Крутимся дальше!

			CPI	ZL,Low(RAMEND)		; А младший байт достиг конца?
			BRNE Flush
 
			CLR	ZL					; Очищаем индекс
			CLR	ZH
			CLR	R0
			CLR	R1
			CLR	R2
			CLR	R3
			CLR	R4
			CLR	R5
			CLR	R6
			CLR	R7
			CLR	R8
			CLR	R9
			CLR	R10
			CLR	R11
			CLR	R12
			CLR	R13
			CLR	R14
			CLR	R15
			CLR	R16
			CLR	R17
			CLR	R18
			CLR	R19
			CLR	R20
			CLR	R21
			CLR	R22
			CLR	R23
			CLR	R24
			CLR	R25
			CLR	R26
			CLR	R27
			CLR	R28
			CLR	R29
; End coreinit.inc

			;LDI	ZL, 30	; +-----------------------+
			;CLR	ZH		; |						  |
			;DEC	ZL		; | Очистка РОН (R00-R31) |
			;ST	Z, ZH		; |	[10 байт кода]		  |
			;BRNE	PC-2	; +-----------------------+

