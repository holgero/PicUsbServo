; USB bootloader for PICs
; boot routine and configuration
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
	extern	enableUSBInterrupts
	extern	sleepUsbSuspended
	extern	USB_received

;**************************************************************
; imported variables
; usb.asm
	extern	LED_states

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
realResetvector			ORG	0x0000
	goto	bootmain
realHiprio_interruptvector	ORG	0x0008
	goto	hiprio_interruptvector
realLowprio_interruptvector	ORG	0x0018
	goto	lowprio_interruptvector

;**************************************************************
; bootmain code
bootmain_code		CODE

bootmain
	clrf	WPUB, ACCESS
	clrf	WPUA, ACCESS
	bcf	INTCON2, RABPU, ACCESS
	bsf	WPUB, WPUB7, ACCESS
	nop
	btfss	PORTB, RB7		; test jumper on RB7
	goto	bootLoaderActive
	bsf	INTCON2, RABPU, ACCESS
	movlw	0xff
	movwf	WPUB, ACCESS
	movwf	WPUA, ACCESS
	movlw	0x00
	goto	resetvector		; run the application

bootLoaderActive
	call	InitUSB			; initialize the USB module
	call	WaitConfiguredUSB

bootMainLoop
	call	ServiceUSB
	goto	bootMainLoop

			END
