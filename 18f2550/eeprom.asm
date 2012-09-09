; USB bootloader for PICs
; access to the EEPROM
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
#include <p18f2550.inc>

;**************************************************************
; exported subroutines

	global	readEEbyte
; in W: address in EEPROM
; out W: value from EEPROM
; changes W

	global	writeEEbyte
; call with interrupts disabled
; in EEADDR: address to write to
; in EEDATA: value to write

;**************************************************************
; Code section
eeprom_code	CODE

writeEEbyte
	bcf	EECON1, EEPGD, ACCESS	; access EEPROM data (not PGM)
	bcf	EECON1, CFGS, ACCESS	; access EEPROM data (not CFG)
	bsf	EECON1, WREN, ACCESS	; write enable
; required sequence
	movlw	0x55
	movwf	EECON2, ACCESS		; write 55
	movlw	0xaa
	movwf	EECON2, ACCESS		; write aa
	bsf	EECON1, WR, ACCESS	; set WR bit, starts write
; end required sequence
	return

readEEbyte
	movwf	EEADR, ACCESS		; store address
	bcf	EECON1, EEPGD, ACCESS	; access EEPROM data (not PGM)
	bcf	EECON1, CFGS, ACCESS	; access EEPROM data (not CFG)
	bsf	EECON1, RD, ACCESS	; start read
	movf	EEDATA, W, ACCESS	; retrieve byte
	return

	END
