; ***** INTERRUPT VECTORS ************************************************
; ***** ATmega16 *********************************************************
.org	INT0addr	;External Interrupt0
reti
.org	INT1addr	;External Interrupt1
reti
.org	OC2addr		;Output Compare2 Interrupt
reti
.org	OVF2addr	;Overflow2 Interrupt
reti
.org	ICP1addr	;Input Capture1 Interrupt
reti
.org	OC1Aaddr	;Output Compare1A Interrupt
reti
.org	OC1Baddr	;Output Compare1B Interrupt
reti
.org	OVF1addr	;Overflow1 Interrupt
rjmp	OVF1_IRQ
.org	OVF0addr	;Overflow0 Interrupt
rjmp	OVF0_IRQ
.org	SPIaddr		;SPI Interrupt
reti
.org	URXCaddr	;UART Receive Complete Interrupt
;rjmp	RX_OK
reti
.org	UDREaddr	;UART Data Register Empty Interrupt
;rjmp	UD_OK
reti
.org	UTXCaddr	;UART Transmit Complete Interrupt
;rjmp	TX_OK
reti
.org	ADCCaddr	;ADC Interrupt
reti	;rjmp	ADC_IRQ
.org	ERDYaddr	;EEPROM Interrupt
reti
.org	ACIaddr		;Analog Comparator Interrupt
reti
.org	TWIaddr   	;Irq. for Two-Wire Interface
reti
.org	INT2addr   	;External Interrupt2
reti
.org	OC0addr   	;Output Compare0 Interrupt
reti
.org	SPMRaddr	;Store Program Memory Ready Interrupt
reti
; ***** INTERRUPT VECTORS ************************************************
