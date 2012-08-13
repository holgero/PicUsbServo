; USB Firmware for PICs
; global definitions for USB descriptors
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
; definitions
NUM_INTERFACES		EQU	1

; descriptor types
DEVICE			EQU	1
CONFIGURATION		EQU	2
STRING			EQU	3
INTERFACE		EQU	4
ENDPOINT		EQU	5

; MS USB Extension Stuff
I_EXTENSION_STRING      EQU     0xEE
VENDOR_CODE		EQU	0x42
