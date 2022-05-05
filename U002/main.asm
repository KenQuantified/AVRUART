.eseg
.org 0x0000
.db "U002"	;Ident

.cseg
;define SRAM storage location for received data
.equ Ident = 0x1400		;eeprom 0x0000, location of ident
.equ RxIdent = 0x6000	;Rx ident storage location
.equ URx = 0x6010		;rx data storage location
.equ Res = 0x6020		;response storage
.def RxC = r19			;receiver counter register
.def TxC = r20			;transmit counter register
.def RState = r21		;State register
.def RC = r16			;common register
.def RI = r17			;interrupt register

;setup interrupt vectors
.org 0x0000
rjmp init
.org NMI_vect
reti
.org BOD_VLM_vect
reti
.org RTC_CNT_vect
reti
.org RTC_PIT_vect
reti
.org CCL_CCL_vect
reti
.org PORTA_PORT_vect
reti
.org TCA0_OVF_vect
rjmp reset
.org TCA0_HUNF_vect
reti
.org TCA0_LCMP0_vect
reti
.org TCA0_LCMP1_vect
reti
.org TCA0_LCMP2_vect
reti
.org TCB0_INT_vect
reti
.org TCB1_INT_vect
reti
.org TCD0_OVF_vect
reti
.org TCD0_TRIG_vect
reti
.org TWI0_TWIS_vect
reti
.org TWI0_TWIM_vect
reti
.org SPI0_INT_vect
reti
.org USART0_RXC_vect
rjmp receivedata
.org USART0_DRE_vect
rjmp transmitdata
.org USART0_TXC_vect
reti
.org PORTD_PORT_vect
reti
.org AC0_AC_vect
reti
.org ADC0_RESRDY_vect
reti
.org ADC0_WCMP_vect
reti
.org ZCD0_ZCD_vect
reti
.org PTC_PTC_vect
reti
.org AC1_AC_vect
reti
.org PORTC_PORT_vect
reti
.org TCB2_INT_vect
reti
.org USART1_RXC_vect
reti
.org USART1_DRE_vect
reti
.org USART1_TXC_vect
reti
.org PORTF_PORT_vect
reti
.org NVMCTRL_EE_vect
reti
.org SPI1_INT_vect
reti
.org USART2_RXC_vect
reti
.org USART2_DRE_vect
reti
.org USART2_TXC_vect
reti
.org AC2_AC_vect
reti

init:
    ;init uart
	;set baud rate
	ldi RC, 140 ;this should be 250 kbps
	ldi XH, High(USART0_BAUDL)
	ldi XL, Low(USART0_BAUDL)
	st X, RC
	;set frame format and mode of operation
	ldi RC, 0b00000011 ;CMODE = Async, PMODE = Disabled, 1 Stop Bit, 8 Bit Transfer
	ldi XH, High(USART0_CTRLC)
	ldi XL, Low(USART0_CTRLC)
	st X, RC
	;configure TxD as output
	ldi RC, 0b00000001 ;PA0 set to output
	ldi XH, High(PORTA_DIRSET)
	ldi XL, Low(PORTA_DIRSET)
	st X, RC
	;enable peripheral in debug
	ldi RC, 0b00000001 ;dbg on
	ldi XH, High(USART0_DBGCTRL)
	ldi XL, Low(USART0_DBGCTRL)
	st X, RC
	;Enable the Tx and Rx
	ldi RC, 0b11000000 ;enable the transmitter and receiver
	ldi XH, High(USART0_CTRLB)
	ldi XL, Low(USART0_CTRLB)
	st X, RC

	;sleepcontrol config
	ldi RC, 0b00000001
	ldi XH, High(SLPCTRL_CTRLA)
	ldi XL, Low(SLPCTRL_CTRLA)
	st X, RC

	;init clock/counter
	ldi RC, 0b00000001 ;enable debug run
	ldi XH, High(TCA0_SINGLE_DBGCTRL)
	ldi XL, Low(TCA0_SINGLE_DBGCTRL)
	st X, RC
	ldi RC, 0b00000001 ;enable overflow interrupt
	ldi XH, High(TCA0_SINGLE_INTCTRL)
	ldi XL, Low(TCA0_SINGLE_INTCTRL)
	st X, RC
	ldi RC, 0b00000000 ;set normal mode
	ldi XH, High(TCA0_SINGLE_CTRLB)
	ldi XL, Low(TCA0_SINGLE_CTRLB)
	st X, RC
	ldi RC, 0b11111111 ;slightly shorter timer period than U001
	ldi XH, High(TCA0_SINGLE_PER)
	ldi XL, Low(TCA0_SINGLE_PER)
	st X, RC
	
	;enable interrupts for rx
	ldi RC, 0b10000000 ;enable rx interrupt
	ldi XH, High(USART0_CTRLA)
	ldi XL, Low(USART0_CTRLA)
	st X, RC

	ldi RState, 0x00
	ldi RxC, 0x00

	call configureclock

	sei
	rjmp runloop

reset:
	ldi RC, 0xD8
	ldi XH, High(CPU_CCP)
	ldi XL, Low(CPU_CCP)
	st X, RC
	ldi RC, 0b00000001
	ldi XH, High(RSTCTRL_SWRR)
	ldi XL, Low(RSTCTRL_SWRR)
	st X, RC

configureclock:
	ldi RC, 0b00001011 ;clock/256 and enable
	ldi XH, High(TCA0_SINGLE_CTRLA)
	ldi XL, Low(TCA0_SINGLE_CTRLA)
	st X, RC
	ldi RC, 0b00000001 ;clear ovf flag
	ldi XH, High(TCA0_SINGLE_INTFLAGS)
	ldi XL, Low(TCA0_SINGLE_INTFLAGS)
	st X, RC
	ldi RC, 0b00001000 ;restart counter
	ldi XH, High(TCA0_SINGLE_CTRLESET)
	ldi XL, Low(TCA0_SINGLE_CTRLESET)
	st X, RC

	ret

runloop:
	cli
	;state 0 wait to receive ident
	cpi RState, 0x01 ;state 1 validate ident
	breq validateident
	;state 2 transmit ident
	cpi RState, 0x03 ;state 3 transitory
	breq swaptoreceive
	;state 4 receive data
	cpi RState, 0x05 ;state 5 process data
	breq procdata
	;state 6 transmit response
	cpi RState, 0x07 ;state 7 turn off transmitter
	breq swaptoreceive ;let's use this function to set the clock for a reset after 1 second
	sei
	sleep
	rjmp runloop

procdata:
	ldi XH, High(URx)
	ldi XL, Low(URx)
	ld RC, X+ ;U002 will do (N1 + N2) - N3 so we will as well.
	mov RI, RC
	ld RC, X+
	add RI, RC
	ld RC, X
	sub RI, RC

	ldi XH, High(Res)
	ldi XL, Low(Res)
	st X, RI
	
	ldi RC, 0b00100000 ;transmit interrupts
	ldi XH, High(USART0_CTRLA)
	ldi XL, Low(USART0_CTRLA)
	st X, RC

	ldi TxC, 0x00
	inc RState

	rjmp runloop

swaptoreceive:
	;change interrupts
	ldi RC, 0b10000000
	ldi XH, High(USART0_CTRLA)
	ldi XL, Low(USART0_CTRLA)
	st X, RC

	call configureclock

	inc RState
	ldi RxC, 0x00

	rjmp runloop

validateident:
	ldi XH, High(RxIdent)
	ldi XL, Low(RxIdent)
	ld RC, X+
	ldi RI, 'U'
	cpse RC, RI
	rjmp reset
	ld RC, X+
	ldi RI, '0'
	cpse RC, RI
	rjmp reset
	ld RC, X+
	ldi RI, '0'
	cpse RC, RI
	rjmp reset
	ld RC, X+
	ldi RI, '1'
	cpse RC, RI
	rjmp reset

	;turn off the counter
	ldi RC, 0b00000000 ;disable
	ldi XH, High(TCA0_SINGLE_CTRLA)
	ldi XL, Low(TCA0_SINGLE_CTRLA)
	st X, RC
	ldi RC, 0b00000001 ;clear ovf flag
	ldi XH, High(TCA0_SINGLE_INTFLAGS)
	ldi XL, Low(TCA0_SINGLE_INTFLAGS)
	st X, RC

	inc RState

	;enable interrupts for tx
	ldi TxC, 0x00
	ldi RC, 0b00100000 ;enable tx interrupt
	ldi XH, High(USART0_CTRLA)
	ldi XL, Low(USART0_CTRLA)
	st X, RC

	rjmp runloop


transmitdata:
	cpi RState, 0x02
	breq transmitident
	cpi RState, 0x06
	breq transmitbytes

	reti

transmitident:
	ldi YH, High(Ident)
	ldi YL, Low(Ident)
	add YL, TxC
	ld RI, Y
	ldi YH, High(USART0_TXDATAL)
	ldi YL, Low(USART0_TXDATAL)
	st Y, RI

	inc TxC

	cpi TxC, 0x04
	breq advancestate
	
	reti

advancestate:
	inc RState
	reti

transmitbytes:
	break
	ldi YH, High(Res)
	ldi YL, Low(Res)
	add YL, TxC
	ld RI, Y
	ldi YH, High(USART0_TXDATAL)
	ldi YL, Low(USART0_TXDATAL)
	st Y, RI
	break
	inc RState ;we only have one byte to send so advance state right after

	reti

receivedata:
	cpi RState, 0x04
	breq receivebytes
	cpi RState, 0x00
	breq receiveident

	reti

receiveident:
	ldi YH, High(USART0_RXDATAL)
	ldi YL, Low(USART0_RXDATAL)
	ld RI, Y
	ldi YH, High(RxIdent)
	ldi YL, Low(RxIdent)
	add YL, RxC
	st Y, RI

	inc RxC

	cpi RxC, 0x04
	breq advancestate
	
	reti

receivebytes:
	ldi YH, High(USART0_RXDATAL)
	ldi YL, Low(USART0_RXDATAL)
	ld RI, Y
	ldi YH, High(URx)
	ldi YL, Low(URx)
	add YL, RxC
	st Y, RI

	inc RxC
	cpi RxC, 0x03
	breq advancestate

	reti