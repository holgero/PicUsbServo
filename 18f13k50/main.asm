; USB bootloader for PICs
; main routine
; Copyright (C) 2012 Holger Oehm
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

#include <p18f13k50.inc>

;**************************************************************
; imported subroutines

;**************************************************************
; imported variables

;**************************************************************
; local definitions
#define TIMER0H_VAL         0xFE
#define TIMER0L_VAL         0x20

;**************************************************************
; local data
main_udata		UDATA
counterL		RES	1
counterH		RES	1
blinkenLights		RES	1

;**************************************************************
; vectors
resetvector		ORG	0x0800
	goto	main
hiprio_interruptvector	ORG	0x0808
	goto	$
lowprio_interruptvector	ORG	0x0818
	goto	$

;**************************************************************
; main code
main_code		CODE	0x0820

main
	clrf	LATB, ACCESS
	movlw	b'10001111'		; LEDs on Port B, RB<4:6>
	movwf	TRISB, ACCESS
	call	setupTimer0
	; start by switching off all LEDs
	movlw	b'01110000'
	movwf	LATB,ACCESS

waitTimerLoop
	btfss	INTCON, T0IF, ACCESS
	goto	waitTimerLoop
	call	setupTimer0

	; first divider: 10ms * 256 = 2.5s
	banksel	counterL
	incfsz	counterL, BANKED
	goto	waitTimerLoop
	incf	blinkenLights,F,BANKED
	btfsc	blinkenLights,1,BANKED	; changes every time: blinking period is 5.2s
	bsf	LATB, 5, ACCESS		; yellow off
	btfss	blinkenLights,1,BANKED	; changes every time: blinking period is 5.2s
	bcf	LATB, 5, ACCESS		; yellow on
	goto	waitTimerLoop

setupTimer0
	bcf	INTCON, T0IF, ACCESS	; clear Timer0 interrupt flag
	; reload start value
	movlw	TIMER0H_VAL
	movwf	TMR0H, ACCESS
	movlw	TIMER0L_VAL
	movwf	TMR0L, ACCESS
	; configure timer0: enable, 16 bit, internal clock, 256 prescaler
	movlw	( 1 << TMR0ON ) | ( b'0111' )
	movwf	T0CON, ACCESS

	return

			END
