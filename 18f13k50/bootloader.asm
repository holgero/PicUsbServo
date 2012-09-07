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
outSize	RES	1

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

	call	usbEP1OUTgetBytesInit	; set FSR0 to receive buffer
	call	usbEP1INsetBytesInit	; set FSR1 to send buffer
	movf	INDF0, W, ACCESS	; first byte is command
	bz	readVersion		; 0: read version
	addlw	0xff
	bz	readFlash		; 1: read flash

	call	echoBytes		; unknown command, for now just echo 

commandExecuted
	banksel	outSize
	movf	outSize,W,BANKED
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

readFlash
	call	echoBytes		; we send back the structure
	call	usbEP1OUTgetBytesInit	; set FSR0 to receive buffer again
	movf	POSTINC0, W, ACCESS	; command (=1)
	movf	POSTINC0, W, ACCESS	; len
	banksel	inSize
	addwf	inSize,W,BANKED		; add size of structure
	movwf	outSize,BANKED		; store result size
	banksel	loop_t
	movwf	loop_t,BANKED		; store also as loop counter
	; set table read pointer to address
	movf	POSTINC0, W, ACCESS	; addressL
	movwf	TBLPTRL, ACCESS
	movf	POSTINC0, W, ACCESS	; addressH
	movwf	TBLPTRH, ACCESS
	movf	POSTINC0, W, ACCESS	; addressU
	movwf	TBLPTRU, ACCESS

copyFlashLoop
	tblrd*+
	movf	TABLAT, W, ACCESS
	movwf	POSTINC1, ACCESS
	decfsz	loop_t, BANKED
	bra	copyFlashLoop
	bra	commandExecuted

readVersion
	clrf	POSTINC1, ACCESS	; 0
	clrf	POSTINC1, ACCESS	; 0
	movlw	D'2'			; minor version
	movwf	POSTINC1, ACCESS
	movlw	D'1'			; major version
	movwf	POSTINC1, ACCESS
	movlw	4
	banksel	outSize
	movwf	outSize,BANKED
	bra	commandExecuted

; first implementation: echo everything that comes in on EP1 OUT to EP1 IN
echoBytes
	banksel	inSize
	movf	inSize,W,BANKED
	movwf	outSize,BANKED
	banksel	loop_t
	movwf	loop_t, BANKED
copyLoop
	movf	POSTINC0, W, ACCESS
	movwf	POSTINC1, ACCESS
	decfsz	loop_t, BANKED
	bra	copyLoop
	return

		END
