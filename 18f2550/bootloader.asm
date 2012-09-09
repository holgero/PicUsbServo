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
	extern	usbEP1OUTreceive
	extern	usbEP1INisBusy
	extern	usbEP1INsend
	extern	usbEP1bufferToFsr0
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
loopH_t	RES	1

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

	call	usbEP1bufferToFsr0	; set FSR0 to EP1 in/out buffer

	; special commands (0xff reset, 0x32 update leds)
	movf	INDF0, W, ACCESS	; get command byte
	sublw	0xff			; check for reset command
	bz	resetCommand
	movf	INDF0, W, ACCESS	; get command byte
	sublw	0x32			; update led
	bz	updateLed
	movf	INDF0, W, ACCESS	; get command byte
	sublw	0x07			; range check
	bnc	returnWithoutAnswer	; out of range command, just return

	call	dispatchFlashCommand

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

resetCommand				; not implemented
updateLed				; not implemented
returnWithoutAnswer
	call	usbEP1OUTreceive	; activate EP1 OUT again (next receive)

endBootLoaderMain
	return

dispatchFlashCommand
	movlw	upper(jumpTable)
	movwf	PCLATU, ACCESS
	movlw	high(jumpTable)
	movwf	PCLATH, ACCESS
	rlncf	INDF0, W, ACCESS	; get command byte (*2)
	rlncf	WREG, W, ACCESS		; 4 times (goto commmands occupy 4 bytes)
	addlw	low(jumpTable)
	movwf	PCL, ACCESS		; bye bye

readVersion
	clrf	POSTINC0, ACCESS	; 0
	clrf	POSTINC0, ACCESS	; 0
	movlw	D'2'			; minor version
	movwf	POSTINC0, ACCESS
	movlw	D'1'			; major version
	movwf	POSTINC0, ACCESS
	movlw	4
	banksel	outSize
	movwf	outSize,BANKED
	return

readFlash
readConfig
	movf	POSTINC0, W, ACCESS	; command
	movf	POSTINC0, W, ACCESS	; len
	banksel	loop_t
	movwf	loop_t,BANKED		; store as loop counter
	banksel	inSize
	addwf	inSize,W,BANKED		; add size of structure
	movwf	outSize,BANKED		; store result size
	call	setTablePointerFromFsr0
copyFlashLoop
	tblrd*+
	movf	TABLAT, W, ACCESS
	movwf	POSTINC0, ACCESS
	decfsz	loop_t, BANKED
	bra	copyFlashLoop
	return

eraseFlash
	movf	POSTINC0, W, ACCESS	; command
	movf	POSTINC0, W, ACCESS	; len: number of 64 byte blocks to erase
	banksel	loop_t
	movwf	loop_t,BANKED		; store as loop counter
	call	setTablePointerFromFsr0
	bra	doEraseSequence
eraseNextBlock
	movlw	0x40			; 64 bytes per block
	addwf	TBLPTRL, F, ACCESS
	bnc	doEraseSequence
	incf	TBLPTRH, F, ACCESS
	bnc	doEraseSequence
	incf	TBLPTRU, F, ACCESS
doEraseSequence
	bsf	EECON1, EEPGD, ACCESS
	bcf	EECON1, CFGS, ACCESS
	bsf	EECON1, WREN, ACCESS
	bsf	EECON1, FREE, ACCESS
	; required sequence for erasing program memory
	movlw	0x55
	movwf	EECON2, ACCESS
	movlw	0xaa
	movwf	EECON2, ACCESS
	bsf	EECON1, WR, ACCESS
	; required sequence end
	decfsz	loop_t, BANKED
	bra	eraseNextBlock
	bcf	EECON1, WREN, ACCESS	; disable write to program memory again

answerSuccess
	movlw	0x01			; answer is just the command byte
	banksel	outSize
	movwf	outSize
	return

writeFlash
	; write block size for 18f2550 is 16 byte
	movf	POSTINC0, W, ACCESS	; command
	movf	POSTINC0, W, ACCESS	; len: number of bytes to write
	banksel	loop_t
	andlw	0xf0			; mask out low bits
	movwf	loopH_t,BANKED		; count 8 byte blocks
	swapf	loopH_t,F,BANKED	; same as 4 shifts to the right
	call	setTablePointerFromFsr0
	movf	TBLPTRL, W, ACCESS	; make sure the address is aligned
	andlw	0xf0
	movwf	TBLPTRL, ACCESS
	tblrd*-				; decrement by one (needed for the write loop)

write8ByteBlock
	movlw	0x10			; 16 bytes per block
	movwf	loop_t

writeToHoldingRegisters
	movf	POSTINC0, W, ACCESS
	movwf	TABLAT, ACCESS
	tblwt+*				; use pre-increment, so that after the last write
					; the pointer stays within the current block
	decfsz	loop_t
	bra	writeToHoldingRegisters

	; setup EECON1 for writing to program memory
	bsf	EECON1, EEPGD, ACCESS
	bcf	EECON1, CFGS, ACCESS
	bsf	EECON1, WREN, ACCESS
	bcf	EECON1, FREE, ACCESS
	; required sequence for writing program memory
	movlw	0x55
	movwf	EECON2, ACCESS
	movlw	0xaa
	movwf	EECON2, ACCESS
	bsf	EECON1, WR, ACCESS
	; required sequence end
	decfsz	loopH_t
	bra	write8ByteBlock
	bcf	EECON1, WREN, ACCESS	; disable write to program memory again
	bra	answerSuccess
	
; unimplemented commands simply echo everything that comes in on EP1 OUT to EP1 IN
readEEdata
writeEEdata
writeConfig
	banksel	inSize
	movf	inSize,W,BANKED
	movwf	outSize,BANKED
	return

setTablePointerFromFsr0
	movf	POSTINC0, W, ACCESS	; addressL
	movwf	TBLPTRL, ACCESS
	movf	POSTINC0, W, ACCESS	; addressH
	movwf	TBLPTRH, ACCESS
	movf	POSTINC0, W, ACCESS	; addressU
	movwf	TBLPTRU, ACCESS
	return

jump_table_code	CODE	0x07e0	; 8 gotos a 2 words occupy 16 words
jumpTable
	goto	readVersion	; 0
	goto	readFlash	; 1
	goto	writeFlash	; 2
	goto	eraseFlash	; 3
	goto	readEEdata	; 4
	goto	writeEEdata	; 5
	goto	readConfig	; 6
	goto	writeConfig	; 7
		END
