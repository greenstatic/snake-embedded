.include "m128def.inc"

#define DISPLAY_NO_CHARACTERS_PER_LINE 16
#define GAME_DISPLAY_RAM_SIZE 64 // 16 * 4 
#define DISPLAY_RAM_SIZE 32 // 16 * 2

.def TEMP = R18
.def TEMP2 = R19
.def TEMP3 = R20

.DSEG
GAME_DISPLAY_RAM:	.byte GAME_DISPLAY_RAM_SIZE
DISPLAY_RAM:		.byte DISPLAY_RAM_SIZE

.CSEG
START:
	; Initilize the stack pointer
	ldi TEMP, LOW(RAMEND)
	out SPL, TEMP
	ldi TEMP, HIGH(RAMEND)
	out SPH, TEMP

MAIN:
	rcall DISPLAY_INIT
	rcall SPRITE_INIT
	;rcall SPRITE_DEBUG_DISPLAY
	
	rcall DISPLAY_RAM_RESET

	rcall DISPLAY_SYNC_DEBUG

	rcall DISPLAY_SYNC

	WAIT: nop
	rjmp WAIT


; Resets the area of memory where the DISPLAY_RAM is with ' ' characters.
DISPLAY_RAM_RESET:
	ldi TEMP, ' '
	ldi XH, high(DISPLAY_RAM)
	ldi XL, low(DISPLAY_RAM)

	ldi TEMP2, DISPLAY_RAM_SIZE

	DISPLAY_RAM_RESET_LOOP:
	cpi TEMP2, 0
	breq DISPLAY_RAM_RESET_LOOP_END
	st X, TEMP
	inc XL
	dec TEMP2
	rjmp DISPLAY_RAM_RESET_LOOP
	DISPLAY_RAM_RESET_LOOP_END:

	ret

; TODO - delete me
DISPLAY_SYNC_DEBUG:
	ldi r24, '1'
	sts DISPLAY_RAM, r24

	ldi r24, '2'
	sts DISPLAY_RAM + 1, r24

	ldi r24, '3'
	sts DISPLAY_RAM + 2, r24

	ldi r24, '4'
	sts DISPLAY_RAM + 16, r24

	ret

; Writes the contents of DISPLAY_RAM to the display.
DISPLAY_SYNC:
	; Move cursor to beginning of the first line
	ldi r24, 0x80
	rcall DISPLAY_SEND_COMMAND

	ldi XH, high(DISPLAY_RAM)
	ldi XL, low(DISPLAY_RAM)
	
	ldi TEMP, DISPLAY_NO_CHARACTERS_PER_LINE

	DISPLAY_SYNC_LOOP_1:
	cpi TEMP, 0
	breq DISPLAY_SYNC_LOOP_1_END
	ld r24, X
	rcall DISPLAY_SEND_CHARACTER
	inc XL
	dec TEMP
	rjmp DISPLAY_SYNC_LOOP_1

	DISPLAY_SYNC_LOOP_1_END:

	; Move cursor to the beginning of the second line
	ldi r24, 0xC0
	rcall DISPLAY_SEND_COMMAND

	ldi TEMP, DISPLAY_NO_CHARACTERS_PER_LINE

	DISPLAY_SYNC_LOOP_2:
	cpi TEMP, 0
	breq DISPLAY_SYNC_LOOP_2_END
	ld r24, X
	rcall DISPLAY_SEND_CHARACTER
	inc XL
	dec TEMP
	rjmp DISPLAY_SYNC_LOOP_2

	DISPLAY_SYNC_LOOP_2_END:

	ret


; Initialize the game sprites in the HD4470 display. The display needs to be 
; first initialized (rcall DISPLAY_INIT).
SPRITE_INIT:

	; The game sprites, each byte represents one pixel row
	; 8 bytes make up a single 'character' which we will
	; display on the display by storing it into the CGRAM
	BODY_TOP_PIXEL_ROW:
	.db 0x0E, 0x1F, 0x1F, 0x0E, 0, 0, 0, 0

	BODY_BOTTOM_PIXEL_ROW:
	.db 0, 0, 0, 0, 0x0E, 0x1F, 0x1F, 0x0E

	BODY_BOTH_PIXEL_ROW:
	.db 0x0E, 0x1F, 0x1F, 0x0E, 0x0E, 0x1F, 0x1F, 0x0E

	HEAD_TOP_PIXEL_ROW:
	.db 0x0E, 0x11, 0x11, 0x0E, 0, 0, 0, 0

	HEAD_BOTTOM_PIXEL_ROW:
	.db 0, 0, 0, 0, 0x0E, 0x11, 0x11, 0x0E

	DROP_TOP_PIXEL_ROW:
	.db 0x0E, 0x15, 0x15, 0x0E, 0, 0, 0, 0

	DROP_BOTTOM_PIXEL_ROW:
	.db 0, 0, 0, 0, 0x0E, 0x15, 0x15, 0x0E

	; Create the sprites in the display's RAM
	ldi ZH, high(BODY_TOP_PIXEL_ROW * 2)
	ldi ZL, low(BODY_TOP_PIXEL_ROW * 2)
	ldi r24, 0
	rcall SPRITE_CREATE

	ldi ZH, high(BODY_BOTTOM_PIXEL_ROW * 2)
	ldi ZL, low(BODY_BOTTOM_PIXEL_ROW * 2)
	ldi r24, 1
	rcall SPRITE_CREATE
	
	ldi ZH, high(BODY_BOTH_PIXEL_ROW * 2)
	ldi ZL, low(BODY_BOTH_PIXEL_ROW * 2)
	ldi r24, 2
	rcall SPRITE_CREATE
	
	ldi ZH, high(HEAD_TOP_PIXEL_ROW * 2)
	ldi ZL, low(HEAD_TOP_PIXEL_ROW * 2)
	ldi r24, 3
	rcall SPRITE_CREATE

	ldi ZH, high(HEAD_BOTTOM_PIXEL_ROW * 2)
	ldi ZL, low(HEAD_BOTTOM_PIXEL_ROW * 2)
	ldi r24, 4
	rcall SPRITE_CREATE
	
	ldi ZH, high(DROP_TOP_PIXEL_ROW * 2)
	ldi ZL, low(DROP_TOP_PIXEL_ROW * 2)
	ldi r24, 5
	rcall SPRITE_CREATE

	ldi ZH, high(DROP_BOTTOM_PIXEL_ROW * 2)
	ldi ZL, low(DROP_BOTTOM_PIXEL_ROW * 2)
	ldi r24, 6
	rcall SPRITE_CREATE

	; Go to beginning of display (exit CGRAM mode)
	ldi r24, 0x80
	rcall DISPLAY_SEND_COMMAND
	
	ret

; Outputs to the display all the sprites we have created prefixed and suffixed with '|'.
SPRITE_DEBUG_DISPLAY:
	; Seperator
	ldi r24, '|'
	rcall DISPLAY_SEND_CHARACTER

	; Display custom char
	ldi r24, 0x00
	rcall DISPLAY_SEND_CHARACTER

	; Display custom char
	ldi r24, 0x01
	rcall DISPLAY_SEND_CHARACTER
	
	; Display custom char
	ldi r24, 0x02
	rcall DISPLAY_SEND_CHARACTER
	
	; Display custom char
	ldi r24, 0x03
	rcall DISPLAY_SEND_CHARACTER
	
	; Display custom char
	ldi r24, 0x04
	rcall DISPLAY_SEND_CHARACTER
	
	; Display custom char
	ldi r24, 0x05
	rcall DISPLAY_SEND_CHARACTER
	
	; Display custom char
	ldi r24, 0x06
	rcall DISPLAY_SEND_CHARACTER
	
	; Seperator
	ldi r24, '|' 
	rcall DISPLAY_SEND_CHARACTER

	ret

; Create a sprite in the display's RAM by creating a custom character pattern (CGRAM data)
; Z: Base pointer to 8 bytes of memory with the contents of the character pattern.
;	 Each byte represents a single pixel line
; r24: Character code (0-7)
SPRITE_CREATE:
	lsl r24
	lsl r24
	lsl r24
	ori r24, 0b0100_0000 ; CGRAM mode + CGRAM Address 
	rcall DISPLAY_SEND_COMMAND

	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	inc ZL
	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	inc ZL	
	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	inc ZL
	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	inc ZL
	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	inc ZL
	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	inc ZL
	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	inc ZL
	lpm r24, Z
	rcall DISPLAY_SEND_CHARACTER

	ret
	

; Sends "Hello World!" to the display. Do not forget to rcall DISPLAY_INIT first!
DISPLAY_HELLO_WORLD:
	; Send letter H
	ldi r24, 0x48
	rcall DISPLAY_SEND_CHARACTER

	; Send letter e
	ldi r24, 0x65
	rcall DISPLAY_SEND_CHARACTER

	; Send letter l
	ldi r24, 0x6C
	rcall DISPLAY_SEND_CHARACTER
	
	; Send letter l
	ldi r24, 0x6C
	rcall DISPLAY_SEND_CHARACTER

	; Send letter o
	ldi r24, 0x6F
	rcall DISPLAY_SEND_CHARACTER
	
	; Send 'space'
	ldi r24, 0x20
	rcall DISPLAY_SEND_CHARACTER

	; Send letter W
	ldi r24, 0x57
	rcall DISPLAY_SEND_CHARACTER

	; Send letter o
	ldi r24, 0x6F
	rcall DISPLAY_SEND_CHARACTER

	; Send letter r
	ldi r24, 0x72
	rcall DISPLAY_SEND_CHARACTER
	
	; Send letter l
	ldi r24, 0x6C
	rcall DISPLAY_SEND_CHARACTER

	; Send letter d
	ldi r24, 0x64
	rcall DISPLAY_SEND_CHARACTER

	; Send character '!'
	ldi r24, 0x21
	rcall DISPLAY_SEND_CHARACTER

	ret

; Initializes the Hitachi HD44780U display in 4-bit mode with the cursor and blinking turned on.
; Connect the following pins:
;	GPIO_PORT_G_0 -> DISPLAY_DATA_4
;	GPIO_PORT_G_1 -> DISPLAY_DATA_5
;	GPIO_PORT_G_2 -> DISPLAY_DATA_6
;	GPIO_PORT_G_3 -> DISPLAY_DATA_7
;	GPIO_PORT_G_4 -> DISPLAY_RS
;	GPIO_PORT_D_7 -> DISPLAY_EN
;
; Pin layout identical to ET-BASE AVR ATmega64/128 layout of PORT ET-CLCD.
; You can still use the remaining PORT_G and PORT_D pins not in use.
DISPLAY_INIT:
	push TEMP

	; GPIO D7: OUTPUT
	ldi TEMP, 0b1000_0000
	out DDRD, TEMP

	; GPIO G0-4: OUTPUT
	ldi TEMP, 0b0001_1111
	sts DDRG, TEMP

	; Delay 15 ms
	ldi r24, 15
	rcall DELAY_Nms


	; We send 8-bit mode command three times because that is the official way how initialize the
	; display according to the documentation (Hitachi HD44780U documentation pg. 26).
	; Function set instruction: 8-bit mode command #1
	ldi TEMP, 0b0000_0011
	sts PORTG, TEMP
	rcall DISPLAY_TOGGLE_EN

	; Function set instruction: 8-bit mode command #2
	ldi TEMP, 0b0000_0011
	sts PORTG, TEMP
	rcall DISPLAY_TOGGLE_EN

	; Function set instruction: 8-bit mode command #3
	ldi TEMP, 0b0000_0011
	sts PORTG, TEMP
	rcall DISPLAY_TOGGLE_EN

	; Function set instruction: 4-bit mode command #1 (we are still operating in 8-bit mode)
	ldi TEMP, 0b0000_0010
	sts PORTG, TEMP
	rcall DISPLAY_TOGGLE_EN

	; Function set instruction: 4-bit mode command #2 
	; (we are now operating in 4-bit mode, so send it using our DISPLAY_SEND_COMMAND routine)
	ldi r24, 0b0010_1100
	rcall DISPLAY_SEND_COMMAND

	; Display on/off control instruction - Turn display off
	ldi r24, 0b0001_0000
	rcall DISPLAY_SEND_COMMAND

	; Clear display instruction - Clear display
	ldi r24, 0b0000_0001
	rcall DISPLAY_SEND_COMMAND

	; Entry mode set instruction - Cursor move direction: increment and no display shift 
	ldi r24, 0b0000_0110
	rcall DISPLAY_SEND_COMMAND

	; Display on/off control instruction - Turn display, cursor and blinking to on 
	ldi r24, 0b0000_1101
	rcall DISPLAY_SEND_COMMAND

	pop TEMP
	ret

; Toggles the display enable (EN) pin. We use this when sending stuff to the display
; so that it reads the data pins.
DISPLAY_TOGGLE_EN:
	ldi TEMP, 0b1000_0000
	out PORTD, TEMP

	ldi r24, 1
	rcall DELAY_Nms

	ldi TEMP, 0b0000_0000
	out PORTD, TEMP

	ldi r24, 1
	rcall DELAY_Nms

	ret

; Send to display command. Set r24 with the command value.
DISPLAY_SEND_COMMAND:
	ldi r25, 0x0
	rcall DISPLAY_SEND
	ret

; Send to display character. Set r24 with the character value.
DISPLAY_SEND_CHARACTER:
	ldi r25, 0x1
	rcall DISPLAY_SEND
	ret

; Send to display command/data. Set r24 with the data and set r25 with 1 for data or 0 for command mode.
DISPLAY_SEND:
	push TEMP
	push TEMP2
	push TEMP3

	; r24 => | TEMP | TEMP2 |   we split the byte into two nibbles
	mov TEMP, r24
	mov TEMP2, r24

	lsr TEMP
	lsr TEMP
	lsr TEMP
	lsr TEMP

	andi TEMP2, 0x0F  ; clear first nibble since we have it stored in TEMP

	; Move value (which can be 0/1) to high nibble
	lsl r25
	lsl r25
	lsl r25
	lsl r25

	or TEMP, r25   ; set Port G pin 4 to RS value
	or TEMP2, r25  ; set Port G pin 4 to RS value

	lds TEMP3, PORTG
	andi TEMP3, 0xE0  ; get the previous non-display Port G pin values
	or TEMP, TEMP3    ; combine the upper nibble with the previous non-display Port G pin values
	or TEMP2, TEMP3   ; combine the lower nibble with the previous non-display Port G pin values

	; Send high nibble
	sts PORTG, TEMP
	rcall DISPLAY_TOGGLE_EN

	; Send low nibble
	sts PORTG, TEMP2
	rcall DISPLAY_TOGGLE_EN

	pop TEMP3
	pop TEMP2
	pop TEMP

	ret


; ====== Routines ======
; DELAY_Nms routine - Delay for n milliseconds
; Clock frequency must be 16 Mhz. 
; The parameter n must be:
; 1 <= n <= 255
;
; n is stored in r24. Load into r24 n before rcall-ing
; this routine.
;
; Formula to calculate cycles:
; IL = Inner loop constant = 15976
; Calculate by setting n=1 and using the debugger to count the cycles
; between DELAY_Nms_INNER and DELAY_Nms_INNER_END
;
; HEAD:    3 (RCALL) + 4 (2 * push) + 1 + 2 +
; FILLER   2 + (18+3)(n-1) +
;          1 (nop) + 1 (nop) 
; LOOP     n(IL + 3) - 1 +
; FOOTER   4 (2 * pop) + 4
;
DELAY_Nms:
	push r19
	push r20
	mov r19, r24
	rjmp DELAY_Nms_SKIP

	DELAY_Nms_FILLER:            ; | 18 OP
	ldi r20, 5                   ; |
	DELAY_Nms_FILLER_JMP:        ; |
	dec r20                      ; |
	brne DELAY_Nms_FILLER_JMP    ; |
	nop                          ; |
	nop                          ; |
	nop                          ; |

	DELAY_Nms_SKIP:
	dec r19
	brne DELAY_Nms_FILLER

	nop
	nop

	DELAY_Nms_OUTER:
	ldi  r19, 21
	ldi  r20, 191
	
	DELAY_Nms_INNER:
	dec  r20
	brne DELAY_Nms_INNER
	dec  r19
	brne DELAY_Nms_INNER

	dec r24
	brne DELAY_Nms_OUTER

	DELAY_Nms_INNER_END:
	pop r20
	pop r19

	ret
