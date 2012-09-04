; USB bootloader for PICs
; the usb firmware
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

;**************************************************************
; includes
#include <p18f13k50.inc>
#include "descriptor.inc"

;**************************************************************
; PIC18F1xK50: the following SFRs are not in the access bank!
;UEP0 - UEP7: 0x0F53 -  0x0F5A
;UEIE             EQU  H'0F5B'
;UADDR            EQU  H'0F5C'
;UFRML            EQU  H'0F5D'
;UFRMH            EQU  H'0F5E'
;UEIR             EQU  H'0F5F'
;**************************************************************


;**************************************************************
; exported subroutines
	global	InitUSB
	global	ServiceUSB
	global	WaitConfiguredUSB

;**************************************************************
; imported subroutines
;	descriptor.asm
	extern	copyNextDescriptorByte
	extern	getIndexedString
	extern	getDeviceDescriptor
	extern	getConfigurationDescriptor

;**************************************************************
; local definitions
; usb states
POWERED_STATE		EQU	0x00
DEFAULT_STATE		EQU	0x01
ADDRESS_STATE		EQU	0x02
CONFIG_STATE		EQU	0x03

; endpoint types
ENDPT_IN		EQU	(1<<EPHSHK) | (1<<EPINEN)
ENDPT_OUT		EQU	(1<<EPHSHK) | (1<<EPOUTEN)
ENDPT_INOUT		EQU	(1<<EPHSHK) | (1<<EPCONDIS) | (1<<EPOUTEN) | (1<<EPINEN)
ENDPT_CONTROL		EQU	(1<<EPHSHK) | (1<<EPOUTEN) | (1<<EPINEN)

; tokens
TOKEN_OUT		EQU	(0x01<<2)
TOKEN_IN		EQU	(0x09<<2)
TOKEN_SETUP		EQU	(0x0D<<2)

; usb addresses
USBMEMORY		EQU	0x0200
; USB buffer table
; buffer 0 and 1 are used for EP0 IN and OUT
BD0STAT			EQU	( USBMEMORY + 0x00 )
BD0CNT			EQU	( USBMEMORY + 0x01 )
BD0ADRL			EQU	( USBMEMORY + 0x02 )
BD0ADRH			EQU	( USBMEMORY + 0x03 )
BD1STAT			EQU	( USBMEMORY + 0x04 )
BD1CNT			EQU	( USBMEMORY + 0x05 )
BD1ADRL			EQU	( USBMEMORY + 0x06 )
BD1ADRH			EQU	( USBMEMORY + 0x07 )
; buffer 2 and 3 are used for EP1 IN and OUT
BD2STAT			EQU	( USBMEMORY + 0x08 )
BD2CNT			EQU	( USBMEMORY + 0x09 )
BD2ADRL			EQU	( USBMEMORY + 0x0A )
BD2ADRH			EQU	( USBMEMORY + 0x0B )
BD3STAT			EQU	( USBMEMORY + 0x0C )
BD3CNT			EQU	( USBMEMORY + 0x0D )
BD3ADRL			EQU	( USBMEMORY + 0x0E )
BD3ADRH			EQU	( USBMEMORY + 0x0F )
; Register location after last buffer descriptor register
USB_Buffer		EQU	( USBMEMORY + 0x0080 )

; BDSTAT bits
UOWN			EQU     7
DTS			EQU	6
DTSEN			EQU     3

; offsets from the beginning of the Buffer Descriptor
ADDRESSL		EQU	0x02
ADDRESSH		EQU	0x03

; offsets into the setup data record
bmRequestType		EQU	0x00
bRequest		EQU	0x01
wValue			EQU	0x02
wIndex			EQU	0x04
wLength			EQU	0x06

; USB requests
NO_REQUEST		EQU	0xFF
GET_STATUS		EQU	0x00
CLEAR_FEATURE		EQU	0x01
SET_FEATURE		EQU	0x03
SET_ADDRESS		EQU	0x05
GET_DESCRIPTOR		EQU	0x06
SET_DESCRIPTOR		EQU	0x07
GET_CONFIGURATION	EQU	0x08
SET_CONFIGURATION	EQU	0x09
GET_INTERFACE		EQU	0x0A
SET_INTERFACE		EQU	0x0B

; HID Class requests
GET_REPORT		EQU	0x01
GET_IDLE		EQU	0x02
GET_PROTOCOL		EQU	0x03
SET_REPORT		EQU	0x09
SET_IDLE		EQU	0x0A
SET_PROTOCOL		EQU	0x0B
HID_SET_REPORT		EQU	0x21

; endpoints
EP0			EQU	0x00 << 3
EP1			EQU	0x01 << 3
EP2			EQU	0x02 << 3

; request targets
STANDARD		EQU	0x00 << 5
CLASS			EQU	0x01 << 5
VENDOR			EQU	0x02 << 5

RECIPIENT_DEVICE	EQU	0x00
RECIPIENT_INTERFACE	EQU	0x01
RECIPIENT_ENDPOINT	EQU	0x02

; request codes
WAKEUP_REQUEST		EQU	0x01
;**************************************************************
; local data
usb_udata		UDATA
USB_buffer_desc		RES	4
USB_buffer_data		RES	8
USB_curr_config		RES	1
USB_device_status	RES	1
USB_protocol		RES	1
USB_idle_rate		RES	1
USB_dev_req		RES	1
USB_address_pending	RES	1
USB_bytes_left		RES	1
USB_loop_index		RES	1
USB_packet_length	RES	1
USB_USTAT		RES	1
USB_USWSTAT		RES	1
USB_received		RES	1
LED_states		RES	5

;**************************************************************
; code section
usb_code		CODE

InitUSB
	clrf	UIE, ACCESS		; mask all USB interrupts
	clrf	UIR, ACCESS		; clear all USB interrupt flags
	clrf	UCFG, ACCESS		; disable eye pattern and ping-pong buffers
	bsf	UCFG, FSEN, ACCESS	; full speed transfer
	bsf	UCFG, UPUEN, ACCESS	; internal pull-up resistors
	clrf	UCON, ACCESS
	bsf	UCON, USBEN, ACCESS	; enable USB module
	banksel	USB_curr_config
	clrf	USB_curr_config, BANKED
	clrf	USB_idle_rate, BANKED
	clrf	USB_USWSTAT, BANKED	; default to powered state
	movlw	0x01
	movwf	USB_device_status, BANKED
	movwf	USB_protocol, BANKED	; default protocol to report protocol initially
	movlw	NO_REQUEST
	movwf	USB_dev_req, BANKED	; No device requests in process
	return

ServiceUSB
	; * URSTIF (usb reset) -> resetUSB
	; * TRNIF (usb transaction complete) -> processUSBTransaction
	; * IDLEIF (3ms idle on usb) -> suspendUSB
	; * ACTVIF (activity on interface) -> resumeUSB
	banksel	UEIR
	btfsc	UIR, UERRIF, ACCESS
	clrf	UEIR, BANKED

	btfsc	UIR, SOFIF, ACCESS
	bcf	UIR, SOFIF, ACCESS

	btfsc	UIR, IDLEIF, ACCESS
	bra	suspendUSB

	btfsc	UIR, ACTVIF, ACCESS
	bra	resumeUSB

	btfsc	UIR, STALLIF, ACCESS
	bcf	UIR, STALLIF, ACCESS

	btfsc	UIR, URSTIF, ACCESS
	bra	resetUSB

	btfsc	UIR, TRNIF, ACCESS
	; USB transaction complete, process it
	bra	processUSBTransaction

	return


resumeUSB
	bcf	UCON, SUSPND, ACCESS	; leave suspend
clearActivityBitLoop
	bcf	UIR, ACTVIF, ACCESS
	btfsc	UIR, ACTVIF, ACCESS
	bra	clearActivityBitLoop
	return

suspendUSB
	bcf	UIR, IDLEIF, ACCESS
	bsf	UCON, SUSPND, ACCESS	; suspend USB
	return

resetUSB
	banksel		USB_curr_config
	clrf		USB_curr_config, BANKED
	bcf		UIR, TRNIF, ACCESS	; clear TRNIF four times to clear out the USTAT FIFO
	bcf 		UIR, TRNIF, ACCESS
	bcf		UIR, TRNIF, ACCESS
	bcf		UIR, TRNIF, ACCESS
	banksel		UEP0
	clrf		UEP0, BANKED	; clear all EP control registers to disable all endpoints
	clrf		UEP1, BANKED
	clrf		UEP2, BANKED
	clrf		UEP3, BANKED
	clrf		UEP4, BANKED
	clrf		UEP5, BANKED
	clrf		UEP6, BANKED
	clrf		UEP7, BANKED

	banksel		BD0CNT
	; set up endpoint EP0 OUT
	movlw		0x08
	movwf		BD0CNT, BANKED
	movlw		low USB_Buffer
	movwf		BD0ADRL, BANKED
	movlw		high USB_Buffer
	movwf		BD0ADRH, BANKED		; ...set up its address
	clrf		BD0STAT, BANKED
	bsf		BD0STAT, UOWN, BANKED	; set UOWN: USB can write
	; set up endpoint EP0 IN
	movlw		0x08
	movwf		BD1CNT, BANKED
	movlw		low (USB_Buffer+0x08)
	movwf		BD1ADRL, BANKED
	movlw		high (USB_Buffer+0x08)
	movwf		BD1ADRH, BANKED		; ...set up its address
	clrf		BD1STAT, BANKED
	bsf		BD1STAT, DTSEN, BANKED	; enable Data Toggle Synchronization

	banksel		UADDR
	clrf		UADDR, BANKED		; set USB Address to 0
	clrf		UIR, ACCESS		; clear all the USB interrupt flags
	movlw		ENDPT_CONTROL
	movwf		UEP0, BANKED		; EP0 is a control pipe and requires an ACK
	movlw		0xFF			; enable all error interrupts
	movwf		UEIE, BANKED
	banksel		USB_USWSTAT
	movlw		DEFAULT_STATE
	movwf		USB_USWSTAT, BANKED
	movlw		0x01
	movwf		USB_device_status, BANKED ; self powered, remote wakeup disabled
	return

	; dispatch request codes to specific labels
dispatchRequest	macro	requestCode, requestLabel
	xorlw	requestCode
	btfsc	STATUS,Z,ACCESS
	bra	requestLabel
	xorlw	requestCode
	endm

processUSBTransaction
	movlw		high( USBMEMORY )
	movwf		FSR0H, ACCESS
	movf		USTAT, W, ACCESS
	andlw		0x7C				; mask out bits 0, 1, and 7 of USTAT
	; result is 0x00 for endpoint 0 and 0x08 for endpoint 1
	movwf		FSR0L, ACCESS
	banksel		USB_buffer_desc
	movf		POSTINC0, W
	movwf		USB_buffer_desc, BANKED
	movf		POSTINC0, W
	movwf		USB_buffer_desc+1, BANKED
	movf		POSTINC0, W
	movwf		USB_buffer_desc+2, BANKED
	movf		POSTINC0, W
	movwf		USB_buffer_desc+3, BANKED
	movf		USTAT, W, ACCESS
	movwf		USB_USTAT, BANKED		; save the USB status register
	bcf		UIR, TRNIF, ACCESS		; clear TRNIF interrupt flag
	movf		USB_buffer_desc, W, BANKED
	andlw		0x3C				; extract PID bits
	dispatchRequest	TOKEN_SETUP, processSetupToken
	dispatchRequest	TOKEN_IN, processInToken
	dispatchRequest	TOKEN_OUT, processOutToken
	return

processSetupToken
	banksel	USB_buffer_data
	movf	USB_buffer_desc+ADDRESSH, W, BANKED
	movwf	FSR0H, ACCESS
	movf	USB_buffer_desc+ADDRESSL, W, BANKED
	movwf	FSR0L, ACCESS
	movf	POSTINC0, W
	movwf	USB_buffer_data, BANKED
	movf	POSTINC0, W
	movwf	USB_buffer_data+1, BANKED
	movf	POSTINC0, W
	movwf	USB_buffer_data+2, BANKED
	movf	POSTINC0, W
	movwf	USB_buffer_data+3, BANKED
	movf	POSTINC0, W
	movwf	USB_buffer_data+4, BANKED
	movf	POSTINC0, W
	movwf	USB_buffer_data+5, BANKED
	movf	POSTINC0, W
	movwf	USB_buffer_data+6, BANKED
	movf	POSTINC0, W
	movwf	USB_buffer_data+7, BANKED
	banksel	BD0CNT
	movlw	0x08
	movwf	BD0CNT, BANKED		; reset the byte count
	clrf	BD1STAT, BANKED		; return the in buffer to us (dequeue any pending requests)
	bsf	BD1STAT, DTSEN, BANKED
	banksel	USB_buffer_data+bmRequestType
	movf	USB_buffer_data+bmRequestType,W,BANKED
	sublw	HID_SET_REPORT
	btfss	STATUS,Z,ACCESS		; skip if request type is HID_SET_REPORT
	bra	setupTokenOtherRequestTypes
	movlw	0xC8
	bra	setupTokenAllRequestTypes
setupTokenOtherRequestTypes
	movlw	0x88
setupTokenAllRequestTypes
	banksel	BD0STAT
	movwf	BD0STAT, BANKED	; set EP0 OUT UOWN back to USB and DATA0/DATA1 packet according to request type
	bcf	UCON, PKTDIS, ACCESS	; assuming there is nothing to dequeue, clear the packet disable bit
	banksel	USB_dev_req
	movlw	NO_REQUEST
	movwf	USB_dev_req, BANKED			; clear the device request in process
	movf	USB_buffer_data+bmRequestType, W, BANKED
	andlw	0x60					; extract request type bits
	dispatchRequest	STANDARD, standardRequests
	dispatchRequest	CLASS, classRequests
	bra	standardRequestsError

standardRequests
	movf	USB_buffer_data+bRequest, W, BANKED
	dispatchRequest	SET_ADDRESS, setAddressRequest
	dispatchRequest	GET_DESCRIPTOR, getDescriptorRequest
	dispatchRequest	GET_CONFIGURATION, getConfigurationRequest
	dispatchRequest	SET_CONFIGURATION, setConfigurationRequest

standardRequestsError
	banksel		UEP0
	bsf		UEP0, EPSTALL, BANKED	; set EP0 protocol stall bit to signify Request Error
	return

sendAnswerOk
	banksel		BD1CNT
	clrf		BD1CNT, BANKED	; set byte count to 0
sendAnswer
	movlw		0xC8
	movwf		BD1STAT, BANKED	; send packet as DATA1, set UOWN bit
	return

setConfigurationRequest
	movf	USB_buffer_data+wValue,W,BANKED
	addlw	0xff				; check is zero based: 0..NUM_CONFIG-1 are valid
	call	getConfigurationDescriptor	; see if requested configuration is valid
	btfsc	STATUS,Z,ACCESS
	bra	standardRequestsError	; nope, total length was Zero: invalid
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_curr_config, BANKED
	btfss	STATUS,Z,ACCESS		; skip if value is zero
	bra	setConfiguredState
	; set address state
	movlw	ADDRESS_STATE
	movwf	USB_USWSTAT, BANKED
	bra	sendAnswerOk
setConfiguredState
	; we always set up the same configuration
	movlw	CONFIG_STATE
	movwf	USB_USWSTAT, BANKED

	; set up endpoint EP1 OUT
	movlw	0x40
	movwf	BD2CNT, BANKED
	movlw	low (USB_Buffer+0x10)
	movwf	BD2ADRL, BANKED
	movlw	high (USB_Buffer+0x10)
	movwf	BD2ADRH, BANKED		; ...set up its address
	clrf	BD2STAT, BANKED
	bsf	BD2STAT, UOWN, BANKED	; set UOWN: USB can write
	; set up endpoint EP1 IN
	movlw	0x40
	movwf	BD3CNT, BANKED
	movlw	low (USB_Buffer+0x50)
	movwf	BD3ADRL, BANKED
	movlw	high (USB_Buffer+0x50)
	movwf	BD3ADRH, BANKED		; ...set up its address
	clrf	BD3STAT, BANKED
	bsf	BD3STAT, DTS, BANKED	; data1 packet
	bsf	BD3STAT, DTSEN, BANKED	; enable Data Toggle Synchronization

	movlw	(1<<EPHSHK) | (1<<EPCONDIS) | (1<<EPOUTEN) | (1<<EPINEN)
	banksel	UEP1
	movwf	UEP1, BANKED		; enable EP1 for bulk in and out transfers
	bra	sendAnswerOk

getConfigurationRequest
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED
	movwf	FSR0L, ACCESS
	banksel	USB_curr_config
	movf	USB_curr_config, W, BANKED
	movwf	INDF0			; copy current device configuration to EP0 IN buffer
	banksel	BD1CNT
	movlw	0x01
	movwf	BD1CNT, BANKED		; set EP0 IN byte count to 1
	bra	sendAnswer

setAddressRequest
	btfsc	USB_buffer_data+wValue, 7, BANKED 
	bra	standardRequestsError	; new device address illegal
	movlw	SET_ADDRESS
	movwf	USB_dev_req, BANKED	; processing a SET_ADDRESS request
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_address_pending, BANKED	; save new address
	bra	sendAnswerOk

getDescriptorRequest
	movlw	GET_DESCRIPTOR
	movwf	USB_dev_req, BANKED	; processing a GET_DESCRIPTOR request
	movf	USB_buffer_data+(wValue+1), W, BANKED
	dispatchRequest	DEVICE, getDeviceDescriptorRequest
	dispatchRequest	CONFIGURATION, getConfigurationDescriptorRequest
	dispatchRequest	STRING, getStringDescriptorRequest
	bra	standardRequestsError

getDeviceDescriptorRequest
	call	getDeviceDescriptor	; returns length of Device
	movwf	USB_bytes_left, BANKED
	bra	sendDescriptorRequestAnswer

getConfigurationDescriptorRequest
	movf	USB_buffer_data+wValue, W, BANKED
	call	getConfigurationDescriptor	; get total length
	btfsc	STATUS, Z, ACCESS	; is descriptor index valid?
	bra	standardRequestsError	; nope, Z is set
	banksel	USB_bytes_left
	movwf	USB_bytes_left, BANKED
	bra 	sendDescriptorRequestAnswer

getStringDescriptorRequest
	movf	USB_buffer_data+wValue, W, BANKED	; string no
normalStringDescriptorRequest
	sublw	2
	btfss	STATUS,C
	bra	standardRequestsError	; string index > 2
	; all right string index <= 2
	movf	USB_buffer_data+wValue, W, BANKED	; string no
	call	getIndexedString	; get length
	movwf	USB_bytes_left, BANKED
	bra	sendDescriptorRequestAnswer

classRequests
	movf	USB_buffer_data+bRequest, W, BANKED
	dispatchRequest	GET_REPORT, classGetReport
	dispatchRequest	SET_REPORT, classSetReport
	dispatchRequest	GET_PROTOCOL, classGetProtocol
	dispatchRequest	SET_PROTOCOL, classSetProtocol
	dispatchRequest	GET_IDLE, classGetIdle
	dispatchRequest	SET_IDLE, classSetIdle
	bra	standardRequestsError

classGetReport				; report current LED_state
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED	; put EP1 IN buffer pointer...
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED
	movwf	FSR0L, ACCESS		; ...into FSR0
	banksel LED_states
	movf	LED_states, W, BANKED	; red led
	movwf	POSTINC0
	movf	LED_states+1, W, BANKED	; yellow led
	movwf	POSTINC0
	movf	LED_states+2, W, BANKED	; green led
	movwf	POSTINC0
	movf	LED_states+3, W, BANKED	; blue led
	movwf	POSTINC0
	movf	LED_states+4, W, BANKED	; white led
	movwf	INDF0			; ...to EP0 IN buffer
	banksel	BD1CNT
	movlw	0x05
	movwf	BD1CNT, BANKED		; set EP0 IN buffer byte count
	bra	sendAnswer

classSetReport
	movlw	SET_REPORT
	movwf	USB_dev_req, BANKED	; processing a SET_REPORT request
	return

classGetProtocol
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED	; put EP0 IN buffer pointer...
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED
	movwf	FSR0L, ACCESS		; ...into FSR0
	banksel	USB_protocol
	movf	USB_protocol, W, BANKED
	movwf	INDF0
	banksel	BD1CNT
	movlw	0x01
	movwf	BD1CNT, BANKED		; set byte count to 1
	bra	sendAnswer

classSetProtocol
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_protocol, BANKED	; update the new protocol value
	bra	sendAnswerOk

classGetIdle
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED	; put EP0 IN buffer pointer...
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED
	movwf	FSR0L, ACCESS		; ...into FSR0
	banksel	USB_idle_rate
	movf	USB_idle_rate, W, BANKED
	movwf	INDF0
	banksel	BD1CNT
	movlw	0x01
	movwf	BD1CNT, BANKED		; set byte count to 1
	bra	sendAnswer

classSetIdle
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_idle_rate, BANKED	; update the new idle rate
	bra	sendAnswerOk

processInToken
	banksel	USB_USTAT
	movf	USB_USTAT, W, BANKED
	andlw	0x18			; extract the EP bits
	sublw	EP0
	btfss	STATUS, Z, ACCESS	; skip if it is EP0
	return
	movf	USB_dev_req, W, BANKED
	sublw	GET_DESCRIPTOR
	btfsc	STATUS, Z, ACCESS	; skip if not GET_DESCRIPTOR
	bra	SendDescriptorPacket
	movf	USB_dev_req, W, BANKED
	sublw	SET_ADDRESS
	btfss	STATUS, Z, ACCESS	; skip if it is SET_ADDRESS
	return				; not SET_ADDRESS: just return
	movf	USB_address_pending, W, BANKED
	banksel	UADDR
	movwf	UADDR, BANKED
	movlw	ADDRESS_STATE
	btfsc	STATUS, Z, ACCESS	; skip if USB_address_pending was not zero
	movlw	DEFAULT_STATE		; zero value corresponds to default state
	banksel	USB_USWSTAT
	movwf	USB_USWSTAT, BANKED
	return

processOutToken
	banksel	USB_USTAT
	movf	USB_USTAT, W, BANKED
	andlw	0x18			; extract the EP bits
	sublw	EP0
	btfss	STATUS, Z, ACCESS	; skip if it is EP0
	return
	movf	USB_dev_req, W, BANKED
	sublw	SET_REPORT		; is the request SET_REPORT?
	btfsc	STATUS,Z,ACCESS		; skip if not
	call	setReport
	banksel	BD0CNT
	movlw	0x08
	movwf	BD0CNT, BANKED
	movlw	0x88
	movwf	BD0STAT, BANKED
	bra	sendAnswerOk

setReport
	movlw	NO_REQUEST
	movwf	USB_dev_req, BANKED	; clear device request
	banksel	BD0ADRH
	movf	BD0ADRH, W, BANKED	; put EP0 OUT buffer pointer...
	movwf	FSR0H, ACCESS
	movf	BD0ADRL, W, BANKED
	movwf	FSR0L, ACCESS		; ...into FSR0
	; get five bytes in the buffer and copy to LED_states
	banksel	LED_states
	movf	POSTINC0, W	
	movwf	LED_states, BANKED
	movf	POSTINC0, W	
	movwf	LED_states+1, BANKED
	movf	POSTINC0, W	
	movwf	LED_states+2, BANKED
	movf	POSTINC0, W	
	movwf	LED_states+3, BANKED
	movf	INDF0, W	
	movwf	LED_states+4, BANKED
	bsf	USB_received,0,BANKED
	return

sendDescriptorRequestAnswer
	movf	USB_buffer_data+(wLength+1),W,BANKED
	btfss	STATUS,Z,ACCESS		; skip if zero
	bra	SendDescriptorPacket
	movf	USB_bytes_left,W,BANKED
	subwf	USB_buffer_data+wLength,W,BANKED
	btfsc	STATUS,C,ACCESS	
	bra	SendDescriptorPacket	; USB_buffer_data+wLength >= USB_bytes_left
	movf	USB_buffer_data+wLength, W, BANKED
	movwf	USB_bytes_left, BANKED

SendDescriptorPacket
	banksel	USB_bytes_left
	movlw	0x08
	subwf	USB_bytes_left,W,BANKED
	btfsc	STATUS,C,ACCESS
	bra	longDescriptor		; bytes_left > 8

	movlw	NO_REQUEST
	movwf	USB_dev_req, BANKED	; sending a short packet, so clear device request
	movf	USB_bytes_left, W, BANKED
	bra	shortDescriptor

longDescriptor
	movlw	0x08

shortDescriptor
	; bytes to send now in W
	subwf	USB_bytes_left, F, BANKED
	movwf	USB_packet_length, BANKED
	banksel	BD1CNT
	movwf	BD1CNT, BANKED			; set EP0 IN byte count with packet size
	movf	BD1ADRH, W, BANKED		; put EP0 IN buffer pointer...
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED
	movwf	FSR0L, ACCESS			; ...into FSR0
	banksel	USB_loop_index

	movlw	1
	movwf	USB_loop_index,BANKED

sendNextDescriptorByte
	movf	USB_loop_index,W,BANKED
	subwf	USB_packet_length,W,BANKED
	btfss	STATUS,C,ACCESS
	bra	descriptorSent

	call	copyNextDescriptorByte	; get next byte of descriptor being sent
	incf	USB_loop_index,F,BANKED
	bra	sendNextDescriptorByte

descriptorSent
	banksel	BD1STAT
	movlw	0x40
	xorwf	BD1STAT, W, BANKED	; toggle the DATA01 bit
	andlw	0x40			; clear the PIDs bits
	iorlw	0x88			; set UOWN and DTS bits
	movwf	BD1STAT, BANKED
	return

WaitConfiguredUSB
	call	ServiceUSB		; service USB requests...
	banksel	USB_USWSTAT
	movf	USB_USWSTAT,W,BANKED
	sublw	CONFIG_STATE
	btfss	STATUS,Z,ACCESS
	bra	WaitConfiguredUSB	; ...until the host configures the peripheral

	banksel	LED_states
	clrf	LED_states, BANKED
	clrf	LED_states+1, BANKED
	clrf	LED_states+2, BANKED
	clrf	LED_states+3, BANKED
	clrf	LED_states+4, BANKED
	return

			END
