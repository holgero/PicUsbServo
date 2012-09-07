; USB bootloader for PICs
; bootloader main routine and commands implementation
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
; imported subroutines
; usb.asm
	extern	usbEP1OUTgetByteCount
	extern	usbEP1OUTgetBytesInit
	extern	usbEP1OUTreceive
	extern	usbEP1INisBusy
	extern	usbEP1INsetBytesInit
	extern	usbEP1INsend
; debugled.asm
	extern	blinkYellowLed
	extern	blinkGreenLed

; exported subroutines
	global	initBootLoader
	global	bootLoaderMain

;**************************************************************
; local definitions

;**************************************************************
; local data
bootLoader_udata	UDATA
state	RES	1
inSize	RES	1

; local temp data
			UDATA_OVR
loop_t	RES	1

;**************************************************************
; Code section
bootLoader_code	CODE

initBootLoader
	banksel	state
	clrf	state, BANKED
	return

bootLoaderMain
	banksel	state
	tstfsz	state, BANKED
	bra	sendingAnswer
	call	usbEP1OUTgetByteCount
	banksel	inSize
	movwf	inSize,BANKED
	movf	inSize,F,BANKED		; sets status flags
	bz	endBootLoaderMain	; no message arrived, we are done

; debug code
	call	blinkYellowLed
; debug code end

; first step: echo everything that comes in on EP1 OUT to EP1 IN
	call	usbEP1OUTgetBytesInit
	call	usbEP1INsetBytesInit
	banksel	inSize
	movf	inSize,W,BANKED
	banksel	loop_t
	movwf	loop_t, BANKED
copyLoop
	movf	POSTINC0, W, ACCESS
	movwf	POSTINC1, ACCESS
	decfsz	loop_t, BANKED
	bra	copyLoop

	banksel	inSize
	movf	inSize,W,BANKED
	call	usbEP1INsend		; send answer on EP1 IN
	movlw	0x01
	banksel	state
	movwf	state,BANKED		; we are sending
	bra	endBootLoaderMain

sendingAnswer
; debug code
	call	blinkGreenLed
; debug code end
	call	usbEP1INisBusy
	bnz	endBootLoaderMain	; not yet sent, wait until next call
	banksel	state
	clrf	state, BANKED		; no longer sending, prepare next receive
	call	usbEP1OUTreceive	; activate EP1 OUT again (next receive)

endBootLoaderMain
	return

		END
