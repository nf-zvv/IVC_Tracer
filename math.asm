;------------------------------------------------------------------------------
; Математические подпрограммы
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Signed multiply of two 16bits numbers with 32bits result
; Cycles : 19 + ret
; Words  : 15 + ret
; Register usage: r0 to r2 and r16 to r23 (11 registers)
; Note: The routine is non-destructive to the operands.
; IN: r21:r20, r19:r18
; OUT: r25:r24:r23:r22
;------------------------------------------------------------------------------
muls16x16_32:
			clr		r2
			muls	r19, r21		; (signed)ah * (signed)bh
			movw	r25:r24, r1:r0
			mul		r18, r20		; al * bl
			movw	r23:r22, r1:r0
			mulsu	r19, r20		; (signed)ah * bl
			sbc		r25, r2
			add		r23, r0
			adc		r24, r1
			adc		r25, r2
			mulsu	r21, r18		; (signed)bh * al
			sbc		r25, r2
			add		r23, r0
			adc		r24, r1
			adc		r25, r2
			ret

;------------------------------------------------------------------------------
; Беззнаковое умножение 16 бит
; 16bit * 16 bit = 32 bit
; Вход:
; r16 low  first
; r17 high first
; r18 low  second
; r19 high second
; Выход:
; res0 - r22
; res1 - r23
; res2 - r24
; res3 - r25
; (17 тактов)
;------------------------------------------------------------------------------
.def res0 = r22
.def res1 = r23
.def res2 = r24
.def res3 = r25
mul16u:
			mul		r16,r18			;умножить мл. байт множимого на мл. байт множителя
			movw	res0,r0 		;скопировать r0:r1 в 1-й, 2-й байты результата
			mul		r17,r19 		;умножить ст. байт множимого на ст. байт множителя
			movw	res2,r0			;скопировать r0:r1 в 3-й, 4-й байты результата
			mul		r16,r19 		;умножить мл. байт множимого на ст. байт множителя
			clr		r16				;очистить ненужный регистр для сложений с флагом "C"
			add		res1,r0			;сложить r0:r1:r16 с 2-м, 3-м, 4-м байтами результата
			adc		res2,r1			;...
			adc		res3,r16			;...
			mul		r17,r18 		;умножить ст. байт множимого на мл. байт множителя
			add		res1,r0			;сложить r0:r1:r16 с 2-м, 3-м, 4-м байтами результата
			adc		res2,r1			;...
			adc		res3,r16
			ret


;------------------------------------------------------------------------------
; Signed Division 32/32 = 32+32
;
; USED: r0,r1,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27
; IN: r25:r24:r23:r22 - Dividend
;     r21:r20:r19:r18 - Divisor
; OUT: r21:r20:r19:r18 - Result
;      r25:r24:r23:r22 - Remainder
;------------------------------------------------------------------------------
__divmodsi4:
			mov		r0, r21
			bst		r25, 7
			brtc	__divmodsi4_1
			com		r0
			rcall	__negsi2
__divmodsi4_1:
			sbrc	r21, 7
			rcall	__divmodsi4_neg2
			rcall	__udivmodsi4
			sbrc	r0, 7
			rcall	__divmodsi4_neg2
			brtc	__divmodsi4_exit
			rjmp		__negsi2
__divmodsi4_neg2:
			com		r21
			com		r20
			com		r19
			neg		r18
			sbci	r19, 0xFF	; 255
			sbci	r20, 0xFF	; 255
			sbci	r21, 0xFF	; 255
__divmodsi4_exit:
			ret

;------------------------------------------------------------------------------
; Change sign 32 bit
; 
; USED: 
; IN: r25:r24:r23:r22
; OUT: r25:r24:r23:r22
;------------------------------------------------------------------------------
__negsi2:
			com		r25
			com		r24
			com		r23
			neg		r22
			sbci	r23, 0xFF	; 255
			sbci	r24, 0xFF	; 255
			sbci	r25, 0xFF	; 255
			ret

;------------------------------------------------------------------------------
; Unsigned Division 32/32 = 32+32
;
; USED: r0,r1,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27
;
; IN: r25:r24:r23:r22 - Dividend
;     r21:r20:r19:r18 - Divisor
; OUT: r21:r20:r19:r18 - Result
;      r25:r24:r23:r22 - Remainder
;------------------------------------------------------------------------------
__udivmodsi4:
			push	r30
			push	r31
			ldi		r26, 0x21	; 33
			mov		r1, r26
			sub		r26, r26
			sub		r27, r27
			movw	r30, r26
			rjmp	__udivmodsi4_ep
__udivmodsi4_loop:
			adc		r26, r26
			adc		r27, r27
			adc		r30, r30
			adc		r31, r31
			cp		r26, r18
			cpc		r27, r19
			cpc		r30, r20
			cpc		r31, r21
			brcs	__udivmodsi4_ep
			sub		r26, r18
			sbc		r27, r19
			sbc		r30, r20
			sbc		r31, r21
__udivmodsi4_ep:
			adc		r22, r22
			adc		r23, r23
			adc		r24, r24
			adc		r25, r25
			dec		r1
			brne	__udivmodsi4_loop
			com		r22
			com		r23
			com		r24
			com		r25
			movw	r18, r22
			movw	r20, r24
			movw	r22, r26
			movw	r24, r30
			pop		r31
			pop		r30
			ret



;------------------------------------------------------------------------------
; input: r16 - fractional part (дробная часть)
; output: X(r27:r26)
; used: X(r27:r26),Y(r29:r28)
;------------------------------------------------------------------------------
fract_part:
			clr		r26
			clr		r27
			lsr		r16
			brcc	next_bit_1
			ldi		r26,low(625)
			ldi		r27,high(625)
next_bit_1:
			lsr		r16
			brcc	next_bit_2
			ldi		r28,low(1250)
			ldi		r29,high(1250)
			rcall	add16bit
next_bit_2:
			lsr		r16
			brcc	next_bit_3
			ldi		r28,low(2500)
			ldi		r29,high(2500)
			rcall	add16bit
next_bit_3:
			lsr		r16
			brcc	next_bit_4
			ldi		r28,low(5000)
			ldi		r29,high(5000)
			rcall	add16bit
next_bit_4:
			ret


;--------------------------------------------------------------
; 16bit adder
; input: r27:r26 and r29:r28
; output: r27:r26
;--------------------------------------------------------------
add16bit:
			add		r26,r28
			adc		r27,r29
			ret



;-----------------------------------------------------------------------------
; Инкремент двухбайтовой переменной на заданный шаг
; Используются: 
; Вход: 
;       r23:r22 - инкрементируемое число
;       r25:r24 - шаг инкремента
; Выход: r23:r22
;-----------------------------------------------------------------------------
INCREMENT:
			add		r22,r24
			adc		r23,r25
			ret

INCREMENT2:
			add		r24,r26
			adc		r25,r27
			ret

;-----------------------------------------------------------------------------
; Декремент двухбайтовой переменной на заданный шаг
;   r23:r22 = r23:r22 - r25:r24
; Используются: 
; Вход: 
;       r23:r22 - декрементируемое число
;       r25:r24 - шаг декремента
; Выход: r23:r22
;-----------------------------------------------------------------------------
DECREMENT:
;Преобразовываем вычитание в сложение:
;1. Найти дополнение вычитаемого R25:R24 до 1
;2. Найти дополнение вычитаемого R25:R24 до 2
;3. Сложить уменьшаемое R23:R22 и дополнение вычитаемого R25:R24 до 2
			com		r24
			com		r25
			adiw	r25:r24,1	; дополнение шестнадцатиричного числа R27:R26 до 2
			add		r22,r24
			adc		r23,r25
			ret

DECREMENT2:
			com		r26
			com		r27
			adiw	r27:r26,1	; дополнение шестнадцатиричного числа R27:R26 до 2
			add		r24,r26
			adc		r25,r27
			ret

DECREMENT3:
			sub		r22,r24
			sbc		r23,r25
			ret


;------------------------------------------------------------------------------
; Деление 4-байтового числа на 4096 путем серии сдвигов вправо
;
; USED: r16*, r22*, r23*, r24*, r25*
; CALL: -
; IN: r25:r24:r23:r22
; OUT: r25:r24:r23:r22
;------------------------------------------------------------------------------
DIV_4096:
			ldi		r16,12
DIV_4096_LOOP:
			lsr		r25
			ror		r24
			ror		r23
			ror		r22
			dec		r16
			brne	DIV_4096_LOOP
			ret


;------------------------------------------------------------------------------
; Convert unsigned number to string
; 
; USED: r16*, r26*, r27*, r28*, r29*
; CALL: 
; IN: X - число [0 - 9999], [0x0000 - 0x270F]
;     Y - pointer to null-terminating string
; OUT: Y - pointer to null-terminating string
;------------------------------------------------------------------------------
DEC_TO_STR5:
			LDI		r16, -1
DEC_TO_STR5_1:
			INC		r16
			SUBI	r26, Low(1000)
			SBCI	r27, High(1000)
			BRSH	DEC_TO_STR5_1
			SUBI	r26, Low(-1000)
			SBCI	r27, High(-1000)
			SUBI	r16,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r16		; сохранить код цифры
			LDI		r16, -1
DEC_TO_STR5_2:
			INC		r16
			SUBI	r26, Low(100)
			SBCI	r27, High(100)
			BRSH	DEC_TO_STR5_2
			SUBI	r26, -100
			SUBI	r16,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r16		; сохранить код цифры
			LDI		r16, -1
DEC_TO_STR5_3:
			INC		r16
			SUBI	r26, 10
			BRSH	DEC_TO_STR5_3
			SUBI	r16,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r16		; сохранить код цифры
			SUBI	r26,-10
			SUBI	r26,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r26		; сохранить код цифры
			CLR		r16
			ST		Y+,r16		; \0 - null-terminating string
			ret


;------------------------------------------------------------------------------
; Convert signed number to string
; 
; USED: r16*, r26*, r27*, r28*, r29*
; CALL: 
; IN: X - число [0..65535], [0x0000..0xFFFF]
;     Y - pointer to null-terminating string
; OUT: Y - pointer to null-terminating string
;------------------------------------------------------------------------------
DEC_TO_STR7:
			; определить знак
			SBRC	r27,7
			RJMP	DEC_TO_STR7_SIGN
			LDI		r16,' '
			ST		Y+,r16
			RJMP	DEC_TO_STR7_START
DEC_TO_STR7_SIGN:
			ldi		r16,'-'
			st		Y+,r16
			; смена знака
			com		r26
			com		r27
			subi	r26,low(-1)
			sbci	r27,high(-1)
DEC_TO_STR7_START:
			LDI		r16, -1
DEC_TO_STR7_0:
			INC		r16
			SUBI	r26, Low(10000)
			SBCI	r27, High(10000)
			BRSH	DEC_TO_STR7_0
			SUBI	r26, Low(-10000)
			SBCI	r27, High(-10000)
			tst		r16 ; проверка на незначащий ноль
			breq	DEC_TO_STR7_SKIP_ZERO ; отбрасываем ноль
			SUBI	r16,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r16		; сохранить код цифры
DEC_TO_STR7_SKIP_ZERO:
			LDI		r16, -1
DEC_TO_STR7_1:
			INC		r16
			SUBI	r26, Low(1000)
			SBCI	r27, High(1000)
			BRSH	DEC_TO_STR7_1
			SUBI	r26, Low(-1000)
			SBCI	r27, High(-1000)
			SUBI	r16,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r16		; сохранить код цифры
			ldi		r16,'.'
			ST		Y+,r16		; сохранить код разделительной точки
			LDI		r16, -1
DEC_TO_STR7_2:
			INC		r16
			SUBI	r26, Low(100)
			SBCI	r27, High(100)
			BRSH	DEC_TO_STR7_2
			SUBI	r26, -100
			SUBI	r16,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r16		; сохранить код цифры
			LDI		r16, -1
DEC_TO_STR7_3:
			INC		r16
			SUBI	r26, 10
			BRSH	DEC_TO_STR7_3
			SUBI	r16,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r16		; сохранить код цифры
			SUBI	r26,-10
			SUBI	r26,-0x30	; преобразовать цифру в ASCII код
			ST		Y+,r26		; сохранить код цифры
			CLR		r16
			ST		Y+,r16		; \0 - null-terminating string
			RET



;--------------------------------------------------------------
; Преобразование двоичного однобайтового числа в BCD формат
; Вход: r16
; Выход: r8-r10 (BCD_1 - BCD_3)
;--------------------------------------------------------------
.def BCD_1 = r4
.def BCD_2 = r5
.def BCD_3 = r6
Bin1ToBCD3:
			LDIL	BCD_1, -1
Bin1ToBCD3_1:
			INC		BCD_1
			SUBI	r16, 100
			BRSH	Bin1ToBCD3_1
			SUBI	r16, -100
			LDIL	BCD_2, -1
Bin1ToBCD3_2:
			INC		BCD_2
			SUBI	r16, 10
			BRSH	Bin1ToBCD3_2
			SUBI	r16, -10
			MOV		BCD_3,r16
			RET

;------------------------------------------------------------------------------
; Преобразование двоичного двухбайтового числа в BCD формат
; Вход: X(r27:r26)
; Выход: r11-r14 (BCD_4 - BCD_7)
;------------------------------------------------------------------------------
.def BCD_4 = r22
.def BCD_5 = r23
.def BCD_6 = r24
.def BCD_7 = r25
Bin2ToBCD4:
			LDIL	BCD_4, -1
Bin2ToBCD4_1:
			INC		BCD_4
			SUBI	r26, Low(1000)
			SBCI	r27, High(1000)
			BRSH	Bin2ToBCD4_1
			SUBI	r26, Low(-1000)
			SBCI	r27, High(-1000)
			LDIL	BCD_5, -1
Bin2ToBCD4_2:
			INC		BCD_5
			SUBI	r26, Low(100)
			SBCI	r27, High(100)
			BRSH	Bin2ToBCD4_2
			SUBI	r26, -100
			LDIL	BCD_6, -1
Bin2ToBCD4_3:
			INC		BCD_6
			SUBI	r26, 10
			BRSH	Bin2ToBCD4_3
			SUBI	r26, -10
			MOV		BCD_7,r26
			RET


;------------------------------------------------------------------------------
; 2BIN to 5BCD
; 16-bit binary to 5-digit packed BCD conversion (0..65535)
; "shift-plus-3" method
;
; Source: https://www.avrfreaks.net/forum/16bit-binary-bcd
;
; IN: r17:r16 = HEX value
; OUT: r20:r19:r18 = BCD value
;------------------------------------------------------------------------------
hexToBcd:
			push	r16
			push    r17
			push    r21
			push    r22
			push    xl
			push    xh
			clr     r18
			clr     r19
			clr     r20
			clr     xh
			ldi     r21, 16
hexToBcd1:
			ldi     xl, 20 + 1
hexToBcd2:
			ld      r22, -x
			subi    r22, -3
			sbrc    r22, 3
			st      x, r22
			ld      r22, x
			subi    r22, -0x30
			sbrc    r22, 7
			st      x, r22
			cpi     xl, 18
			brne    hexToBcd2
			lsl     r16
			rol     r17
			rol     r18
			rol     r19
			rol     r20
			dec     r21
			brne    hexToBcd1
			pop     xh
			pop     xl
			pop     r22
			pop     r21
			pop     r17
			pop     r16
			ret

;------------------------------------------------------------------------------
;*
;* Bin3BCD == 24-bit Binary to BCD conversion
;*
;* fbin0:fbin1:fbin2  >>>  tBCD0:tBCD1:tBCD2:tBCD3
;*	  hex			     dec
;*     r16r17r18      >>>	r20r21r22r23
;*
;------------------------------------------------------------------------------
.def	fbin0	=r22	; binary value byte 0 (LSB)
.def	fbin1	=r23	; binary value byte 1
.def	fbin2	=r24	; binary value byte 2 (MSB)
.def	tBCD0	=r25	; BCD value digits 0 and 1
.def	tBCD1	=r26	; BCD value digits 2 and 3
.def	tBCD2	=r27	; BCD value digits 4 and 5
.def	tBCD3	=r28	; BCD value digits 6 and 7 (MSD)

Bin3BCD16:
			ldi	tBCD3,0xfa		;initialize digits 7 and 6
binbcd_107:
			subi	tBCD3,-0x10		;
			subi	fbin0,byte1(10000*1000) ;subit fbin,10^7
			sbci	fbin1,byte2(10000*1000) ;
			sbci	fbin2,byte3(10000*1000) ;
			brcc	binbcd_107		;
binbcd_106:	dec		tBCD3			;
			subi	fbin0,byte1(-10000*100) ;addit fbin,10^6
			sbci	fbin1,byte2(-10000*100) ;
			sbci	fbin2,byte3(-10000*100) ;
			brcs	binbcd_106		;
			ldi		tBCD2,0xfa		;initialize digits 5 and 4
binbcd_105:	subi	tBCD2,-0x10		;
			subi	fbin0,byte1(10000*10)	;subit fbin,10^5
			sbci	fbin1,byte2(10000*10)	;
			sbci	fbin2,byte3(10000*10)	;
			brcc	binbcd_105		;
binbcd_104:	dec		tBCD2			;
			subi	fbin0,byte1(-10000)	;addit fbin,10^4
			sbci	fbin1,byte2(-10000)	;
			sbci	fbin2,byte3(-10000)	;
			brcs	binbcd_104		;
			ldi		tBCD1,0xfa		;initialize digits 3 and 2
binbcd_103:	subi	tBCD1,-0x10		;
			subi	fbin0,byte1(1000)	;subiw fbin,10^3
			sbci	fbin1,byte2(1000)	;
			brcc	binbcd_103		;
binbcd_102:	dec		tBCD1			;
			subi	fbin0,byte1(-100)	;addiw fbin,10^2
			sbci	fbin1,byte2(-100)	;
			brcs	binbcd_102		;
			ldi		tBCD0,0xfa		;initialize digits 1 and 0
binbcd_101:	subi	tBCD0,-0x10		;
			subi	fbin0,10		;subi fbin,10^1
			brcc	binbcd_101		;
			add		tBCD0,fbin0		;LSD
			ret				;

;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
