; USB bootloader for PICs
; initialization and configuration
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

#include <p18f2550.inc>

;**************************************************************
; configuration
        config PLLDIV   = 5		; crystal 20 Mhz
        config CPUDIV   = OSC3_PLL4	; cpu     24 MHz
        config USBDIV   = 2		; USB clock from PLL/2
        config FOSC     = HSPLL_HS	; HS, PLL enabled, HS used by USB
        config FCMEN    = OFF
        config IESO     = OFF
        config PWRT     = OFF
        config BOR      = ON
        config BORV     = 3
        config VREGEN   = ON		; USB voltage regulator enable
        config WDT      = OFF
        config WDTPS    = 32768
        config MCLRE    = ON
        config LPT1OSC  = OFF
        config PBADEN   = OFF
        config CCP2MX   = ON
        config STVREN   = ON
        config LVP      = OFF
        config DEBUG    = OFF
        config XINST    = OFF
        config CP0      = OFF
        config CP1      = OFF
        config CP2      = OFF
        config CP3      = OFF
        config WRT3     = OFF
        config EBTR3    = OFF
        config CPB      = OFF
        config CPD      = OFF
        config WRT0     = OFF
        config WRT1     = OFF
        config WRT2     = OFF
        config WRTB     = ON		; write protect the boot block
        config WRTC     = OFF
        config WRTD     = OFF
        config EBTR0    = OFF
        config EBTR1    = OFF
        config EBTR2    = OFF
;**************************************************************
; imported subroutines
; usb.asm
	extern	InitUSB
	extern	WaitConfiguredUSB
	extern	ServiceUSB
; bootloader.asm
	extern	initBootLoader
	extern	bootLoaderMain
; debugled.asm
	extern	initDebugLeds
	extern	blinkRedLed
; eeprom.asm
	extern	readEEbyte
	extern	writeEEbyte
; wait.asm
	extern	waitSeconds

;**************************************************************
; local definitions
resetvector		EQU	0x0800
hiprio_interruptvector	EQU	0x0808
lowprio_interruptvector	EQU	0x0818
EE_MARK_ADDR		EQU	0x12
EE_MARK_VALUE		EQU	0x2A

;**************************************************************
; local data
bootmain_udata		UDATA

;**************************************************************
; reset and interrupt vectors
realResetVector		ORG	0x0000
	bcf	INTCON2, RBPU, ACCESS
	btfss	PORTB, RB7		; test jumper on RB7
	bra	bootLoaderActive
	bra	preBootMain
interruptHi		ORG	0x0008
	goto	hiprio_interruptvector
preBootMain
	movlw	EE_MARK_ADDR
	call	readEEbyte
	sublw	EE_MARK_VALUE
	bz	bootLoaderActive
	bra	restoreStateAndRun
interruptLo		ORG	0x0018
	goto	lowprio_interruptvector

;**************************************************************
; bootmain code
boot_main		CODE	0x001C

setEEmark
	movlw	EE_MARK_VALUE
	movwf	EEDATA, ACCESS
	movlw	EE_MARK_ADDR
	movwf	EEADR, ACCESS
	call	writeEEbyte
	bcf	UCON, USBEN, ACCESS	; drop from USB
	movlw	1			; and wait a sec
	call	waitSeconds
	reset				; re-start

clearEEmark
	clrf	EEDATA, ACCESS
	movlw	EE_MARK_ADDR
	movwf	EEADR, ACCESS
	goto	writeEEbyte

restoreStateAndRun
	bsf	INTCON2, RBPU, ACCESS
	clrf	EEADR, ACCESS
	clrf	EEDATA, ACCESS
	movlw	0x00
	goto	resetvector		; run the application

bootLoaderActive
	bsf	INTCON2, RBPU, ACCESS	; switch off pull ups
	call	InitUSB			; initialize the USB module
	call	WaitConfiguredUSB
	call	initBootLoader
	call	clearEEmark		; clear the EEPROM mark, so the next time the application can run again

; debug code
	call	initDebugLeds
; debug code end

bootMainLoop
; debug code
	call	blinkRedLed
; debug code end
	call	ServiceUSB		; the usual USB stuff, services EP0
	call	bootLoaderMain		; services EP1
	goto	bootMainLoop

			END
