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
; imported subroutines
	extern	waitMilliSeconds
; exported subroutines
	global	initServo
	global	sendServoImpulse
	global	setServo

; local definitions
servo_udata		UDATA
position		RES	1
			UDATA_OVR
waitLoopCntH		RES 1
waitLoopCntL		RES 1

;**************************************************************
; Code section
	CODE

initServo
	banksel	position
	movlw	0x80
	movwf	position, BANKED
	clrf	LATB, ACCESS
	movlw	b'10111111'	; set RB6 to output
	movwf	TRISB, ACCESS
	return

sendServoImpulse
	movlw	b'01000000'
	movwf	LATB, ACCESS
	movlw	0x01
	call	waitMilliSeconds
	banksel	position
	movf	position, W
	bz	zeroPos
	call	wait256thMs
zeroPos
	movlw	b'00000000'
	movwf	LATB, ACCESS
	banksel	position
	movf	position, W
	sublw	0x00
	call	wait256thMs
	return

setServo
	banksel	position
	movwf	position, BANKED
	return

wait256thMs				;	2	-	2
	banksel	waitLoopCntH		;	1	-	3
	movwf	waitLoopCntH, BANKED	;	1	-	4
outerLoop
	movlw	D'28'			;	1	-	5
	movwf	waitLoopCntL, BANKED	;	1	-	6
innerLoop
	decfsz	waitLoopCntL, BANKED	;	1	13	19,47
	goto	innerLoop		;	2	26	45
	decfsz	waitLoopCntH, BANKED	;	1	-	48
	goto	outerLoop		;	2	-	48
	return				;	2	-	50

	END
