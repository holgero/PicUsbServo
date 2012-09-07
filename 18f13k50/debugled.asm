; USB bootloader for PICs
; debugging with blinkenleds
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
; exported subroutines
	global	initDebugLeds
	global	blinkRedLed
	global	blinkYellowLed
	global	blinkGreenLed

;**************************************************************
; imported subroutines
; wait.asm
	extern	waitMilliSeconds

;**************************************************************
; debugled code
debugled_main	CODE

initDebugLeds
	clrf	LATB, ACCESS
	movlw	b'10001111'             ; LEDs on Port B, RB<4:6>
	movwf	TRISB, ACCESS
	movlw	b'01110000'             ; all LEDs off
	movwf	LATB, ACCESS
	return

blinkLed	macro	idx
	movf	LATB, W, ACCESS
	xorlw	( 1 << (idx+4) )
	movwf	LATB, ACCESS
	movlw	100
	call	waitMilliSeconds
	movf	LATB, W, ACCESS
	xorlw	( 1 << (idx+4) )
	movwf	LATB, ACCESS
	movlw	100
	call	waitMilliSeconds
		endm

blinkRedLed
;	blinkLed 0
	return
blinkYellowLed
;	blinkLed 1
	return
blinkGreenLed
;	blinkLed 2
	return

	END
