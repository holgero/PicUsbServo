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
	global	enableUSBInterrupts
	global	sleepUsbSuspended

;**************************************************************
; exported variables
	global	LED_states
	global	USB_received
;**************************************************************
; imported subroutines
;	descriptor.asm
	extern	copyNextDescriptorByte
	extern	getIndexedString
	extern	getCompatibleIdFeature
	extern	getDeviceDescriptor
	extern	getConfigurationDescriptor

;**************************************************************
; local definitions
; usb states
POWERED_STATE		EQU	0x00
DEFAULT_STATE		EQU	0x01
ADDRESS_STATE		EQU	0x02
CONFIG_STATE		EQU	0x03
SUSPEND_STATE		EQU	0x04

; endpoint types
ENDPT_IN		EQU	0x12
ENDPT_OUT		EQU	0x14
ENDPT_CONTROL		EQU	0x16

; tokens
TOKEN_OUT		EQU	(0x01<<2)
TOKEN_IN		EQU	(0x09<<2)
TOKEN_SETUP		EQU	(0x0D<<2)

; usb addresses
USBMEMORY		EQU	0x0200
BD0STAT			EQU	( USBMEMORY + 0x00 )
BD0CNT			EQU	( USBMEMORY + 0x01 )
BD0ADRL			EQU	( USBMEMORY + 0x02 )
BD0ADRH			EQU	( USBMEMORY + 0x03 )
BD1STAT			EQU	( USBMEMORY + 0x04 )
BD1CNT			EQU	( USBMEMORY + 0x05 )
BD1ADRL			EQU	( USBMEMORY + 0x06 )
BD1ADRH			EQU	( USBMEMORY + 0x07 )
; Register location after last buffer descriptor register
USB_Buffer		EQU	( USBMEMORY + 0x0080 )

; BDSTAT bits
UOWN                   EQU     7
DTSEN                  EQU     3

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
usb_code		CODE	0x00082a

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
	goto	suspendUSB

	btfsc	UIR, ACTVIF, ACCESS
	goto	resumeUSB

	btfsc	UIR, STALLIF, ACCESS
	bcf	UIR, STALLIF, ACCESS

	btfsc	UIR, URSTIF, ACCESS
	goto	resetUSB

	btfsc	UIR, TRNIF, ACCESS
	; USB transaction complete, process it
	goto	processUSBTransaction

	return


resumeUSB
	bcf	UCON, SUSPND, ACCESS	; leave suspend
clearActivityBitLoop
	bcf	UIR, ACTVIF, ACCESS
	btfsc	UIR, ACTVIF, ACCESS
	goto	clearActivityBitLoop
	banksel	USB_USWSTAT
	movf	USB_USWSTAT,W,BANKED
	sublw	SUSPEND_STATE
	btfss	STATUS,Z,ACCESS		; skip if zero: we were suspended
	goto	activNotFromSuspendMode	; not suspended, leave USB_USWSTAT as is
	movlw	CONFIG_STATE		; restore CONFIG_STATE
	movwf	USB_USWSTAT,BANKED
activNotFromSuspendMode
	return

suspendUSB
	bcf	UIR, IDLEIF, ACCESS
	banksel	USB_USWSTAT
	movf	USB_USWSTAT,W,BANKED
	sublw	CONFIG_STATE
	btfss	STATUS,Z,ACCESS		; skip if zero: we are configured
	return				; not even configured: refuse to suspend
	movlw	SUSPEND_STATE
	movwf	USB_USWSTAT,BANKED
	bsf	UCON, SUSPND, ACCESS	; suspend USB
	return

sleepUsbSuspended
	banksel	USB_USWSTAT
	movf	USB_USWSTAT,W,BANKED
	sublw	SUSPEND_STATE
	btfss	STATUS,Z,ACCESS		; skip if zero: we are suspended
	return				; not suspended
	bcf	OSCCON,IDLEN,ACCESS	; sleep tight (dont idle)
	sleep
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
	; set up endpoint EP0
	movlw		0x08
	movwf		BD0CNT, BANKED
	movlw		low USB_Buffer		; EP0 OUT gets a buffer...
	movwf		BD0ADRL, BANKED
	movlw		high USB_Buffer
	movwf		BD0ADRH, BANKED		; ...set up its address
	clrf		BD0STAT, BANKED
	bsf		BD0STAT, UOWN, BANKED	; set UOWN: USB can write
	; set up endpoint EP1
	movlw		0x08
	movwf		BD1CNT, BANKED
	movlw		low (USB_Buffer+0x08)	; EP1 IN gets a buffer...
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
	goto	requestLabel
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
	movwf	BD1STAT, BANKED		; return the in buffer to us
					; (dequeue any pending requests)
	banksel	USB_buffer_data+bmRequestType
	movf	USB_buffer_data+bmRequestType,W,BANKED
	sublw	HID_SET_REPORT
	btfss	STATUS,Z,ACCESS		; skip if request type is HID_SET_REPORT
	goto	setupTokenOtherRequestTypes
	movlw	0xC8
	goto	setupTokenAllRequestTypes
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
	dispatchRequest	VENDOR, vendorRequests
	goto	standardRequestsError

standardRequests
	movf	USB_buffer_data+bRequest, W, BANKED
	dispatchRequest	GET_STATUS, getStatusRequest
	dispatchRequest	CLEAR_FEATURE, setFeatureRequest
	dispatchRequest	SET_FEATURE, setFeatureRequest
	dispatchRequest	SET_ADDRESS, setAddressRequest
	dispatchRequest	GET_DESCRIPTOR, getDescriptorRequest
	dispatchRequest	GET_CONFIGURATION, getConfigurationRequest
	dispatchRequest	SET_CONFIGURATION, setConfigurationRequest
	dispatchRequest	GET_INTERFACE, getInterfaceRequest
	dispatchRequest	SET_INTERFACE, setInterfaceRequest

vendorRequests
	movf	USB_buffer_data+bRequest, W, BANKED
	sublw	VENDOR_CODE		; our vendor code?
	btfss	STATUS,Z,ACCESS		; skip if yes
	goto	standardRequestsError	; something else
	movf	USB_buffer_data+wIndex, W, BANKED
	sublw	0x04			; special feature request index?
	btfss	STATUS,Z,ACCESS		; skip if yes
	goto	standardRequestsError	; something else
; we are to return a compatible id feature descriptor
	movlw	GET_DESCRIPTOR
	movwf	USB_dev_req, BANKED	; processing a GET_DESCRIPTOR request
	call	getCompatibleIdFeature	; returns length of descriptor
	movwf	USB_bytes_left, BANKED
	goto	sendDescriptorRequestAnswer

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

gotoRequestErrorIfNotConfigured	macro
	movf	USB_USWSTAT, W, BANKED
	sublw	CONFIG_STATE		; are we configured?
	btfss	STATUS,Z,ACCESS		; skip if yes
	goto	standardRequestsError	; not yet configured
	endm
	
setInterfaceRequest
	gotoRequestErrorIfNotConfigured

	movlw	NUM_INTERFACES
	subwf	USB_buffer_data+wIndex,W,BANKED
	btfsc	STATUS,C,ACCESS
	goto	standardRequestsError	; USB_buffer_data+wIndex < NUM_INTERFACES
	movf	USB_buffer_data+wValue, W, BANKED
	; bAlternateSetting needs to be 0
	btfss	STATUS,Z,ACCESS		; skip if zero
	goto	standardRequestsError	; not zero
	goto	sendAnswerOk	; ok

getInterfaceRequest
	gotoRequestErrorIfNotConfigured

	movlw	NUM_INTERFACES
	subwf	USB_buffer_data+wIndex,W,BANKED
	btfsc	STATUS,C,ACCESS
	goto	standardRequestsError	; USB_buffer_data+wIndex < NUM_INTERFACES
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED	; get buffer pointer
	movwf	FSR0L, ACCESS
	clrf	INDF0		; always send back 0 for bAlternateSetting
	movlw	0x01
	movwf	BD1CNT, BANKED	; set byte count to 1
	goto	sendAnswer

setConfigurationRequest
	movf	USB_buffer_data+wValue,W,BANKED
	addlw	0xff				; check is zero based: 0..NUM_CONFIG-1 are valid
	call	getConfigurationDescriptor	; see if requested configuration is valid
	btfsc	STATUS,Z,ACCESS
	goto	standardRequestsError	; nope, total length was Zero: invalid
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_curr_config, BANKED
	btfss	STATUS,Z,ACCESS		; skip if value is zero
	goto	setConfiguredState
	; set address state
	movlw	ADDRESS_STATE
	movwf	USB_USWSTAT, BANKED
	goto	sendAnswerOk
setConfiguredState
	; we always set up the same configuration
	movlw	CONFIG_STATE
	movwf	USB_USWSTAT, BANKED
	movlw	0x08
	banksel	BD1CNT+0x08
	movwf	BD1CNT+0x08, BANKED	; set EP1 IN byte count to 8 
	movlw	low (USB_Buffer+0x10)
	movwf	BD1ADRL+0x08, BANKED	; set EP1 IN buffer address
	movlw	high (USB_Buffer+0x10)
	movwf	BD1ADRH+0x08, BANKED
	movlw	0x48
	movwf	BD1STAT+0x08, BANKED	; clear UOWN bit (PIC can write EP1 IN buffer)
	movlw	ENDPT_IN
	banksel	UEP1
	movwf	UEP1, BANKED		; enable EP1 for interrupt in transfers
	banksel	BD1CNT+0x08
	goto	sendAnswerOk

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
	goto	sendAnswer

setAddressRequest
	btfsc	USB_buffer_data+wValue, 7, BANKED 
	goto	standardRequestsError	; new device address illegal
	movlw	SET_ADDRESS
	movwf	USB_dev_req, BANKED	; processing a SET_ADDRESS request
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_address_pending, BANKED	; save new address
	goto	sendAnswerOk

getStatusRequest
	movf	USB_buffer_data+bmRequestType, W, BANKED
	andlw	0x1F			; extract request recipient bits
	dispatchRequest	RECIPIENT_DEVICE, getDeviceStatusRequest
	dispatchRequest	RECIPIENT_INTERFACE, getInterfaceStatusRequest
	dispatchRequest RECIPIENT_ENDPOINT, getEndpointStatusRequest
	goto	standardRequestsError

getDeviceStatusRequest
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED	; get buffer pointer
	movwf	FSR0L, ACCESS
	banksel	USB_device_status
	; copy device status byte to EP0 buffer
	movf	USB_device_status, W, BANKED	
	movwf	POSTINC0
	clrf	INDF0
	banksel	BD1CNT
	movlw	0x02
	movwf	BD1CNT, BANKED		; set byte count to 2
	goto	sendAnswer

getInterfaceStatusRequest
	gotoRequestErrorIfNotConfigured
	movlw	NUM_INTERFACES
	subwf	USB_buffer_data+wIndex,W,BANKED
	btfsc	STATUS,C,ACCESS
	goto	standardRequestsError	; USB_buffer_data+wIndex < NUM_INTERFACES
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED	; get buffer pointer
	movwf	FSR0L, ACCESS
	clrf	POSTINC0
	clrf	INDF0
	movlw	0x02
	movwf	BD1CNT, BANKED		; set byte count to 2
	goto	sendAnswer

getEndpointStatusRequest
	movf	USB_USWSTAT, W, BANKED
	dispatchRequest	ADDRESS_STATE, getEndpointStatusInAddressStateRequest
	dispatchRequest	CONFIG_STATE, getEndpointStatusInConfiguredStateRequest
	goto	standardRequestsError

getEndpointStatusInAddressStateRequest
	movf	USB_buffer_data+wIndex, W, BANKED	; get EP
	andlw	0x0F			; strip off direction bit
	btfss	STATUS,Z,ACCESS		; is it EP0?
	goto	standardRequestsError	; not zero
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED	; put EP0 IN buffer ptr
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED
	movwf	FSR0L, ACCESS		; ...into FSR0
	banksel	UEP0
	movlw	0x00
	btfsc	UEP0, EPSTALL, BANKED
	movlw	0x01
	movwf	POSTINC0
	clrf	INDF0
	banksel	BD1CNT
	movlw	0x02
	movwf	BD1CNT, BANKED		; set byte count to 2
	goto	sendAnswer

getEndpointStatusInConfiguredStateRequest
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED	; put EP0 IN buffer pointer...
	movwf	FSR0H, ACCESS
	movf	BD1ADRL, W, BANKED
	movwf	FSR0L, ACCESS		; ...into FSR0
	movlw	high UEP0		; put UEP0 address...
	movwf	FSR1H, ACCESS
	movlw	low UEP0
	movwf	FSR1L, ACCESS		; ...into FSR1
	banksel	USB_buffer_data+wIndex
	movf	USB_buffer_data+wIndex, W, BANKED  ; get EP and...
	andlw	0x0F			; ...strip off direction bit
	btfsc	PLUSW1, EPOUTEN, ACCESS
	goto	okToReply
	btfss	PLUSW1, EPINEN, ACCESS
	goto	standardRequestsError	; neither EPOUTEN nor EPINEN are set
okToReply
	; send back the state of the EPSTALL bit + 0 byte
	movlw	0x01
	btfss	PLUSW1, EPSTALL, ACCESS
	clrw
	movwf	POSTINC0
	clrf	INDF0
	banksel	BD1CNT
	movlw	0x02
	movwf	BD1CNT, BANKED		; set byte count to 2
	goto	sendAnswer

setFeatureRequest
	movf	USB_buffer_data+bmRequestType, W, BANKED
	andlw	0x1F				; extract request recipient bits
	dispatchRequest	RECIPIENT_DEVICE, setDeviceFeatureRequest
	dispatchRequest	RECIPIENT_ENDPOINT, setEndpointFeatureRequest
	goto	standardRequestsError

setDeviceFeatureRequest
	movf	USB_buffer_data+wValue, W, BANKED
	sublw	WAKEUP_REQUEST
	btfss	STATUS, Z, ACCESS	; skip if request is wakeup
	goto	standardRequestsError	; dunno what to do with this request
	bcf	USB_device_status, 1, BANKED
	movf	USB_buffer_data+bRequest, W, BANKED
	sublw	CLEAR_FEATURE
	btfss	STATUS, Z		; skip if == CLEAR_FEATURE
	bsf	USB_device_status, 1, BANKED
	goto	sendAnswerOk

setEndpointFeatureRequest
	movf		USB_USWSTAT, W, BANKED
	dispatchRequest	ADDRESS_STATE, setEndpointFeatureInAddressStateRequest
	dispatchRequest	CONFIG_STATE, setEndpointFeatureInConfiguredStateRequest
	goto	standardRequestsError

setEndpointFeatureInAddressStateRequest
	movf	USB_buffer_data+wIndex, W, BANKED ; get EP
	andlw	0x0F			; strip off direction bit
	btfss	STATUS,Z,ACCESS		; is it EP0?
	goto	standardRequestsError	; not zero
	banksel	UEP0
	bcf	UEP0, EPSTALL, BANKED
	banksel	USB_buffer_data+bRequest
	movf	USB_buffer_data+bRequest, W, BANKED
	sublw	CLEAR_FEATURE
	banksel	UEP0
	btfss	STATUS, Z, ACCESS	; skip if == CLEAR_FEATURE
	bsf	UEP0, EPSTALL, BANKED
	banksel	USB_buffer_data
	goto	sendAnswerOk

setEndpointFeatureInConfiguredStateRequest
	movlw	high UEP0		; put UEP0 address...
	movwf	FSR0H, ACCESS
	movlw	low UEP0
	movwf	FSR0L, ACCESS		; ...into FSR0
	movf	USB_buffer_data+wIndex, W, BANKED	; get EP
	andlw	0x0F			; strip off direction bit
	addwf	FSR0L, F, ACCESS	; add EP number to FSR0
	btfsc	STATUS, C, ACCESS
	incf	FSR0H, F, ACCESS
	btfsc	INDF0, EPOUTEN, ACCESS
	goto	continueAnswerConfigState
	btfss	INDF0, EPINEN, ACCESS
	goto	standardRequestsError	; neither EPOUTEN nor EPINEN are set: error
continueAnswerConfigState
	bcf	INDF0, EPSTALL, ACCESS
	movf	USB_buffer_data+bRequest, W, BANKED
	sublw	CLEAR_FEATURE
	btfss	STATUS, Z, ACCESS	; skip if == CLEAR_FEATURE
	bsf	INDF0, EPSTALL, ACCESS
	goto	sendAnswerOk

getDescriptorRequest
	movlw	GET_DESCRIPTOR
	movwf	USB_dev_req, BANKED	; processing a GET_DESCRIPTOR request
	movf	USB_buffer_data+(wValue+1), W, BANKED
	dispatchRequest	DEVICE, getDeviceDescriptorRequest
	dispatchRequest	CONFIGURATION, getConfigurationDescriptorRequest
	dispatchRequest	STRING, getStringDescriptorRequest
	goto	standardRequestsError

getDeviceDescriptorRequest
	call	getDeviceDescriptor	; returns length of Device
	movwf	USB_bytes_left, BANKED
	goto	sendDescriptorRequestAnswer

getConfigurationDescriptorRequest
	movf	USB_buffer_data+wValue, W, BANKED
	call	getConfigurationDescriptor	; get total length
	btfsc	STATUS, Z, ACCESS	; is descriptor index valid?
	goto	standardRequestsError	; nope, Z is set
	banksel	USB_bytes_left
	movwf	USB_bytes_left, BANKED
	goto 	sendDescriptorRequestAnswer

getStringDescriptorRequest
	movf	USB_buffer_data+wValue, W, BANKED	; string no
	sublw	I_EXTENSION_STRING	; MS extension: ask for string with special idx
	btfsc	STATUS,Z,ACCESS		; skip if not Zero=it is a normal request
	goto	specialStringDescriptorRequest
	movf	USB_buffer_data+wValue, W, BANKED	; get string no again
	goto	normalStringDescriptorRequest
specialStringDescriptorRequest
	movlw	3			; the real index of the special string
	goto	sendBackStringWithIndex
normalStringDescriptorRequest
	sublw	2
	btfss	STATUS,C
	goto	standardRequestsError	; string index > 2
	; all right string index <= 2
	movf	USB_buffer_data+wValue, W, BANKED	; string no
sendBackStringWithIndex
	call	getIndexedString	; get length
	movwf	USB_bytes_left, BANKED
	goto	sendDescriptorRequestAnswer

classRequests
	movf	USB_buffer_data+bRequest, W, BANKED
	dispatchRequest	GET_REPORT, classGetReport
	dispatchRequest	SET_REPORT, classSetReport
	dispatchRequest	GET_PROTOCOL, classGetProtocol
	dispatchRequest	SET_PROTOCOL, classSetProtocol
	dispatchRequest	GET_IDLE, classGetIdle
	dispatchRequest	SET_IDLE, classSetIdle
	goto	standardRequestsError

classGetReport				; report current LED_state
	banksel	BD1ADRH
	movf	BD1ADRH, W, BANKED	; put EP0 IN buffer pointer...
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
	goto	sendAnswer

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
	goto	sendAnswer

classSetProtocol
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_protocol, BANKED	; update the new protocol value
	goto	sendAnswerOk

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
	goto	sendAnswer

classSetIdle
	movf	USB_buffer_data+wValue, W, BANKED
	movwf	USB_idle_rate, BANKED	; update the new idle rate
	goto	sendAnswerOk

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
	goto	SendDescriptorPacket
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
	goto	sendAnswerOk

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
	goto	SendDescriptorPacket
	movf	USB_bytes_left,W,BANKED
	subwf	USB_buffer_data+wLength,W,BANKED
	btfsc	STATUS,C,ACCESS	
	goto	SendDescriptorPacket	; USB_buffer_data+wLength >= USB_bytes_left
	movf	USB_buffer_data+wLength, W, BANKED
	movwf	USB_bytes_left, BANKED

SendDescriptorPacket
	banksel	USB_bytes_left
	
	movlw	0x08
	subwf	USB_bytes_left,W,BANKED
	btfsc	STATUS,C,ACCESS
	goto	longDescriptor		; bytes_left > 8

	movlw	NO_REQUEST
	movwf	USB_dev_req, BANKED	; sending a short packet, so clear device request
	movf	USB_bytes_left, W, BANKED
	goto	shortDescriptor

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
	goto	descriptorSent

	call	copyNextDescriptorByte	; get next byte of descriptor being sent
	incf	USB_loop_index,F,BANKED
	goto	sendNextDescriptorByte

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
	goto	WaitConfiguredUSB	; ...until the host configures the peripheral

	banksel	LED_states
	clrf	LED_states, BANKED
	clrf	LED_states+1, BANKED
	clrf	LED_states+2, BANKED
	clrf	LED_states+3, BANKED
	clrf	LED_states+4, BANKED
	return

enableUSBInterrupts
;	movlw	( 1 << URSTIE ) || ( 1 << TRNIE )
	movlw	0xFF		; switch all interrupts on
	movwf	UIE, ACCESS
	return

			END
