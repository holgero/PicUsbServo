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

#include <p18f13k50.inc>

;**************************************************************
; configuration
	config USBDIV	= ON
	config FOSC	= HS
	config PLLEN	= ON
        config FCMEN	= OFF
        config IESO     = OFF
	config WDTEN	= OFF
        config WDTPS    = 32768
        config MCLRE    = ON
        config STVREN   = ON
        config LVP      = OFF
        config XINST    = OFF
        config CP0      = OFF
        config CP1      = OFF
        config CPB      = OFF
        config CPD      = OFF
        config WRT0     = OFF
        config WRT1     = OFF
        config WRTB     = OFF
        config WRTC     = OFF
        config WRTD     = OFF
        config EBTR0    = OFF
        config EBTR1    = OFF
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

;**************************************************************
; local definitions
resetvector		EQU	0x0800
hiprio_interruptvector	EQU	0x0808
lowprio_interruptvector	EQU	0x0818
;**************************************************************
; local data
bootmain_udata		UDATA

;**************************************************************
; reset and interrupt vectors
realResetVector		ORG	0x0000
	clrf	WPUB, ACCESS
	clrf	WPUA, ACCESS
	bcf	INTCON2, RABPU, ACCESS
	bra	preBootMain
interruptHi		ORG	0x0008
	goto	hiprio_interruptvector
preBootMain
	bsf	WPUB, WPUB7, ACCESS
	nop
	btfss	PORTB, RB7		; test jumper on RB7
	bra	bootLoaderActive
	bsf	INTCON2, RABPU, ACCESS
	bra	runApplication
interruptLo		ORG	0x0018
	goto	lowprio_interruptvector

;**************************************************************
; bootmain code
boot_main		CODE	0x001C

runApplication
	; restore values at reset
	movlw	0xff
	movwf	WPUB, ACCESS
	movwf	WPUA, ACCESS
	movlw	0x00
	goto	resetvector		; run the application

bootLoaderActive
	call	InitUSB			; initialize the USB module
	call	WaitConfiguredUSB
	call	initBootLoader

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
