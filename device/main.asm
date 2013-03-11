; Pic Usb Servo
; USB connected device which controls a servo
; main routine and configuration
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

#include <p18f13k50.inc>

;**************************************************************
; configuration
	config CPUDIV	= NOCLKDIV	;    No CPU System Clock divide
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
; exported subroutines
	global	main
	global	highPriorityInterrupt
	global	lowPriorityInterrupt

;**************************************************************
; imported subroutines
; usb.asm
	extern	InitUSB
	extern	WaitConfiguredUSB
	extern	ServiceUSB
	extern	enableUSBInterrupts
	extern	sleepUsbSuspended
; servo.asm
	extern	initServo
	extern	sendServoImpulse
	extern	setServoAddress
; wait.asm
	extern	waitMilliSeconds
	extern	USB_received

;**************************************************************
; imported variables
; usb.asm
	extern	USB_data

;**************************************************************
; local definitions
; system clock at 48 MHz Sytem -> CPU at 12 MHz
; preload value = 0xFFFF - (12000000 / prescaler / 50)
;		= 0xFFFF - 0x03AA = 0xFC55
#define TIMER0H_VAL	0xFC
#define TIMER0L_VAL	0x55

;**************************************************************
; local data
main_udata		UDATA
; low prio interrupt has to save registers for itself
STATUS_temp_LP		RES	1
BSR_temp_LP		RES	1
FSR0H_temp_LP		RES	1
FSR0L_temp_LP		RES	1
FSR1H_temp_LP		RES	1
FSR1L_temp_LP		RES	1
FSR2H_temp_LP		RES	1
FSR2L_temp_LP		RES	1
; high prio interrupt needs to save only FSRn
FSR0H_temp_HP		RES	1
FSR0L_temp_HP		RES	1
FSR1H_temp_HP		RES	1
FSR1L_temp_HP		RES	1
FSR2H_temp_HP		RES	1
FSR2L_temp_HP		RES	1
;**************************************************************
; local data in accessbank
main_accessbank		UDATA_ACS
W_temp_LP		RES	1

;**************************************************************
; vectors
resetvector		ORG	0x0800
	goto	main
hiprio_interruptvector	ORG	0x0808
	goto	highPriorityInterrupt
lowprio_interruptvector	ORG	0x0818
	goto	lowPriorityInterrupt

;**************************************************************
; main code
main_code		CODE

highPriorityInterrupt
	movff	FSR0H, FSR0H_temp_HP
	movff	FSR0L, FSR0L_temp_HP
	movff	FSR1H, FSR1H_temp_HP
	movff	FSR1L, FSR1L_temp_HP
	movff	FSR2H, FSR2H_temp_HP
	movff	FSR2L, FSR2L_temp_HP

;	call	HPinterruptHandler

	movff	FSR2L_temp_HP, FSR2L
	movff	FSR2H_temp_HP, FSR2H
	movff	FSR1L_temp_HP, FSR1L
	movff	FSR1H_temp_HP, FSR1H
	movff	FSR0L_temp_HP, FSR0L
	movff	FSR0H_temp_HP, FSR0H
	retfie	FAST

lowPriorityInterrupt
	movff	STATUS, STATUS_temp_LP
	movwf	W_temp_LP, ACCESS
	movff	BSR, BSR_temp_LP
	movff	FSR0H, FSR0H_temp_LP
	movff	FSR0L, FSR0L_temp_LP
	movff	FSR1H, FSR1H_temp_LP
	movff	FSR1L, FSR1L_temp_LP
	movff	FSR2H, FSR2H_temp_LP
	movff	FSR2L, FSR2L_temp_LP

;	dispatch interrupt
	btfss	PIR2, USBIF, ACCESS
	goto	dispatchLowPrioInterrupt_usbDone
	call	ServiceUSB
	bcf	PIR2, USBIF, ACCESS

dispatchLowPrioInterrupt_usbDone

	movff	FSR2L_temp_LP, FSR2L
	movff	FSR2H_temp_LP, FSR2H
	movff	FSR1L_temp_LP, FSR1L
	movff	FSR1H_temp_LP, FSR1H
	movff	FSR0L_temp_LP, FSR0L
	movff	FSR0H_temp_LP, FSR0H
	movff	BSR_temp_LP, BSR
	movf	W_temp_LP, W, ACCESS
	movff	STATUS_temp_LP, STATUS
	retfie

main
	movlw	3			; wait a bit: 3 ms
	call	waitMilliSeconds

	call	initServo
	call	setupTimer0
	call	InitUSB			; initialize the USB module
	call	WaitConfiguredUSB

	; set up interrupt configuration
	clrf	INTCON, ACCESS		; all interrupts off
	clrf	INTCON3, ACCESS		; external interrupts off
	clrf	PIR1, ACCESS		; clear interrupt sources
	clrf	PIR2, ACCESS		; clear interrupt sources
	clrf	PIE1, ACCESS		; disable external interrupts
	clrf	PIE2, ACCESS		; disable external interrupts
	clrf	IPR1, ACCESS		; set priority to low
	clrf	IPR2, ACCESS		; set priority to low
	
	bsf	RCON, IPEN, ACCESS	; enable interrupt priority
	
	call	enableUSBInterrupts	; enable interrupts from the usb module
	bsf	PIE2, USBIF		; enable USB interrupts
	bsf	INTCON, GIEH		; enable high prio interrupt vector
	bsf	INTCON, GIEL		; enable low prio interrupt vector
	
mainLoop
	banksel	USB_received
	bcf	USB_received,0,BANKED
waitTimerLoop
	btfss	INTCON, T0IF, ACCESS
	goto	waitTimerLoop

	call	setupTimer0

	; sleep as long as we are in suspend mode
	call	sleepUsbSuspended

	banksel	USB_received
	btfsc	USB_received,0,BANKED
	goto	commandFromHost
	call	sendServoImpulse
	goto	mainLoop

commandFromHost
	banksel	USB_data
	movf	USB_data + 7, W, BANKED
	sublw	0x42			; command to start bootloader
	bnz	noBootCommand
	goto	0x001c			; run bootloader, triggers a reset and never comes back

noBootCommand
	movf	USB_data + 7, W, BANKED
	sublw	0x01			; command to set servo
	bnz	mainLoop		; ignore everything else
	call	setServoAddress
	movf	USB_data+0, W, BANKED
	movwf	POSTINC0, ACCESS
	movf	USB_data+1, W, BANKED
	movwf	POSTINC0, ACCESS
	movf	USB_data+2, W, BANKED
	movwf	POSTINC0, ACCESS
	movf	USB_data+3, W, BANKED
	movwf	POSTINC0, ACCESS
	movf	USB_data+4, W, BANKED
	movwf	POSTINC0, ACCESS
	goto	mainLoop

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
