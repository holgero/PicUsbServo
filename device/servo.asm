; Pic Usb Servo
; USB connected device which controls a servo
; template file for new assembler sources
;
; Copyright (C) 2013 Holger Oehm
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include <p18f2550.inc>
;**************************************************************
; hardware: uses pins RC3:RC7 as output for servos
; pulses should occur at about 50 Hz and have a length of
; 1 ms to 2 ms corresponding to minimum and maximum amplitude

;**************************************************************
; imported subroutines
	extern	waitMilliSeconds

; exported subroutines
	global	initServo
	global	sendServoImpulse
	global	setServoAddress

; local definitions
servo_udata		UDATA
position		RES 5
loopCounter		RES 1
positionCounter		RES 5
			UDATA_OVR
waitLoopCntL		RES 1

; local macros
compareServoPos	macro	index
	movf	positionCounter+index, F, BANKED
	bz	servo#v(index)isDone
	decf	positionCounter+index, F, BANKED
	skpnz
servo#v(index)isDone
	bcf	LATC, 3+index, ACCESS
		endm

;**************************************************************
; Code section
	CODE

initServo
	banksel	position
	movlw	0x80
	movwf	position+0, BANKED
	movwf	position+1, BANKED
	movwf	position+2, BANKED
	movwf	position+3, BANKED
	movwf	position+4, BANKED
	clrf	LATC, ACCESS
	movlw	b'00000111'	; set RC3:7 to output
	movwf	TRISC, ACCESS
	return

sendServoImpulse
	banksel	position
	call	setServoAddress
	movf	POSTINC0, W, ACCESS
	movwf	positionCounter+0, BANKED
	movf	POSTINC0, W, ACCESS
	movwf	positionCounter+1, BANKED
	movf	POSTINC0, W, ACCESS
	movwf	positionCounter+2, BANKED
	movf	POSTINC0, W, ACCESS
	movwf	positionCounter+3, BANKED
	movf	POSTINC0, W, ACCESS
	movwf	positionCounter+4, BANKED
	movlw	0xff
	movwf	loopCounter, BANKED
	movlw	b'11111000'
	movwf	LATC, ACCESS
	movlw	0x01
	call	waitMilliSeconds

outerLoop
	compareServoPos	0
	compareServoPos	1
	compareServoPos	2
	compareServoPos	3
	compareServoPos	4

	call	wait256thMs
	banksel	position
	decfsz	loopCounter, BANKED
	goto	outerLoop

zeroPos
	movlw	b'00000000'
	movwf	LATC, ACCESS
	return

setServoAddress
	movlw	low(position)
	movwf	FSR0L, ACCESS
	movlw	high(position)
	movwf	FSR0H, ACCESS
	return

wait256thMs				;	2	-	2
	banksel	waitLoopCntL
	movlw	D'20'			;	1	-	3
	movwf	waitLoopCntL, BANKED	;	1	-	4
innerLoop
	decfsz	waitLoopCntL, BANKED	;	1	13	17,45
	goto	innerLoop		;	2	26	43
	return				;	2	-	48

	END
