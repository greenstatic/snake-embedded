.include "m128def.inc"

#define DISPLAY_NO_CHARACTERS_PER_LINE 16
#define DISPLAY_NO_LINES	2
#define GAME_DISPLAY_LINES	4
#define GAME_DISPLAY_RAM_SIZE	(DISPLAY_NO_CHARACTERS_PER_LINE * GAME_DISPLAY_LINES)
#define DISPLAY_RAM_SIZE		(DISPLAY_NO_CHARACTERS_PER_LINE * DISPLAY_NO_LINES)

#define SPRITE_EMPTY	0
#define SPRITE_BODY		1
#define SPRITE_HEAD		2
#define SPRITE_DROP		3

#define DISPLAY_CHAR_BODY_TOP		0x00
#define DISPLAY_CHAR_BODY_BOTTOM	0x01
#define DISPLAY_CHAR_BODY_BOTH		0x02
#define DISPLAY_CHAR_HEAD_TOP		0x03
#define DISPLAY_CHAR_HEAD_BOTTOM	0x04
#define DISPLAY_CHAR_HEAD_TOP_BODY_BOTTOM	0x05
#define DISPLAY_CHAR_BODY_TOP_HEAD_BOTTOM	0x06
#define DISPLAY_CHAR_EMPTY					0x20
#define DISPLAY_CHAR_UNKNOWN				0x21

#define SNAKE_POS_MAX_LENGTH 64
#define SNAKE_POS_INIT_X 7
#define SNAKE_POS_INIT_Y 1

#define DIRECTION_RIGHT 0
#define DIRECTION_DOWN	1
#define DIRECTION_LEFT	2
#define DIRECTION_UP	3


.def TEMP = R18
.def TEMP2 = R19
.def TEMP3 = R20

.DSEG
GAME_DISPLAY_RAM:	.byte GAME_DISPLAY_RAM_SIZE
DISPLAY_RAM:		.byte DISPLAY_RAM_SIZE
POINTS:				.byte 1
DIRECTION:			.byte 1
SNAKE_POS_SIZE:		.byte 1
SNAKE_POS:			.byte (SNAKE_POS_MAX_LENGTH + 1) * 2; we store X,Y for one position
													  ; +1 to add a buffer when we add the new
													  ; head and remove the last element

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
	rcall GAME_DISPLAY_RAM_RESET
	rcall DISPLAY_RAM_RESET
	rcall DISPLAY_SYNC_LED_INIT

	;rcall GAME_DISPLAY_RAM_DEBUG
	;rcall SPRITE_DEBUG_DISPLAY
	;rcall DISPLAY_SYNC_DEBUG

	rcall GAME_INIT
	
	;WAIT: nop
	;rjmp WAIT

	; Main game loop
	MAIN_GAME_LOOP:
	rcall GAME_TICK
	rcall GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM
	rcall GAME_DISPLAY_RAM_MAP_DISPLAY_RAM
	rcall DISPLAY_SYNC
	rcall DISPLAY_SYNC_LED_BLINK
	
	; 400 ms delay
	ldi r24, 250
	rcall DELAY_Nms
	ldi r24, 150
	rcall DELAY_Nms
	

	rjmp MAIN_GAME_LOOP

; Initialize the game
GAME_INIT:
	; Add to the snake position stack the initial
	; snake position
	ldi TEMP, SNAKE_POS_INIT_X
	sts SNAKE_POS, TEMP

	ldi TEMP, SNAKE_POS_INIT_Y
	sts SNAKE_POS + 1, TEMP

	; Initialize the snake position stack size
	ldi TEMP, 2
	sts SNAKE_POS_SIZE, TEMP

	; Initialize the number of points the user has
	ldi TEMP, 0
	sts POINTS, TEMP

	; Initialize the direction
	ldi TEMP, DIRECTION_RIGHT
	sts DIRECTION, TEMP

	; TODO - delete
	/*;ldi TEMP, SPRITE_HEAD
	;sts GAME_DISPLAY_LINE_2 + 1, TEMP
	ldi r23, SPRITE_HEAD
	ldi r24, SNAKE_POS_INIT_X
	ldi r25, SNAKE_POS_INIT_Y
	rcall GAME_DISPLAY_WRITE_XY*/

	ret

;
GAME_TICK:
	push TEMP

	; Get the head of the snake position stack
	ldi XH, high(SNAKE_POS)
	ldi XL, low(SNAKE_POS)

	lds TEMP, SNAKE_POS_SIZE
	subi TEMP, 2 ; SIZE - 2 (offset of the head of the stack)
	
	ldi XH, high(SNAKE_POS)
	ldi XL, low(SNAKE_POS)

	; XH | XL  +  TEMP2 | TEMP
	ldi TEMP2, 0
	add XL, TEMP
	adc XH, TEMP2

	ld r24, X+ ; X coordinate
	ld r25, X+ ; Y coordinate

	lds r23, DIRECTION
	rcall SNAKE_POS_TRANSFORM

	; TODO - check if snake hit obstacle


	; Push to snake position stack
	st X+, r24
	st X+, r25
	lds TEMP, SNAKE_POS_SIZE
	inc TEMP
	inc TEMP
	sts SNAKE_POS_SIZE, TEMP

	; TODO - remove the first element in stack
	ldi XH, high(SNAKE_POS)
	ldi XL, low(SNAKE_POS)
	
	ldi YH, high(SNAKE_POS + 2) ; Y points to the next stack element (2 because we have x,y as 1 'element')
	ldi YL, low(SNAKE_POS + 2)
	;lds TEMP, SNAKE_POS_SIZE
	
	GAME_TICK__LOOP:
	cpi TEMP, 0
	breq GAME_TICK__LOOP_END

	ld TEMP2, Y+ ; next X coordinate 
	ld TEMP3, Y+ ; next Y coordinate

	st X+, TEMP2
	st X+, TEMP3

	dec TEMP ; two dec because of x,y
	dec TEMP
	rjmp GAME_TICK__LOOP

	GAME_TICK__LOOP_END:

	; Decrement stack size by 2
	lds TEMP, SNAKE_POS_SIZE
	dec TEMP
	dec TEMP
	sts SNAKE_POS_SIZE, TEMP

	pop TEMP
	ret

; Transforms the position of a block of snake
; in relation to the direction
; r24: X coordinate
; r25: Y coordinate
; r23: direction (DIRECTION_RIGHT, DIRECTION_DOWN, etc.)
;
; Return's the transofmred X,Y coordinates in r24,r25
SNAKE_POS_TRANSFORM:
	push TEMP

	cpi r23, DIRECTION_RIGHT
	breq SNAKE_POS_TRANSFORM__DIRECTION_RIGHT

	cpi r23, DIRECTION_DOWN
	breq SNAKE_POS_TRANSFORM__DIRECTION_DOWN

	cpi r23, DIRECTION_LEFT
	breq SNAKE_POS_TRANSFORM__DIRECTION_LEFT

	cpi r23, DIRECTION_UP
	breq SNAKE_POS_TRANSFORM__DIRECTION_UP

	; Unknown direction
	rjmp SNAKE_POS_TRANSFORM__DONE


	; Transform direction: Right
	SNAKE_POS_TRANSFORM__DIRECTION_RIGHT:
	ldi TEMP, 1
	add r24, TEMP
	; r24 < DISPLAY_NO_CHARACTERS_PER_LINE ? r24 : 0
	cpi r24, DISPLAY_NO_CHARACTERS_PER_LINE
	brlo SNAKE_POS_TRANSFORM__DIRECTION_RIGHT_
	ldi r24, 0
	
	SNAKE_POS_TRANSFORM__DIRECTION_RIGHT_:
	rjmp SNAKE_POS_TRANSFORM__DONE


	; Transform direction: Down
	SNAKE_POS_TRANSFORM__DIRECTION_DOWN:
	ldi TEMP, 1
	add r25, TEMP
	; r25 < GAME_DISPLAY_LINES ? r25 : 0
	cpi r25, GAME_DISPLAY_LINES
	brlo SNAKE_POS_TRANSFORM__DIRECTION_DOWN_
	ldi r25, 0

	SNAKE_POS_TRANSFORM__DIRECTION_DOWN_:
	rjmp SNAKE_POS_TRANSFORM__DONE


	; Transform direction: Left
	SNAKE_POS_TRANSFORM__DIRECTION_LEFT:
	ldi TEMP, 1
	sub r24, TEMP
	; r24 >= 0 ? r24 : (DISPLAY_NO_CHARACTERS_PER_LINE - 1)
	cpi r24, 0
	brge SNAKE_POS_TRANSFORM__DIRECTION_LEFT_
	ldi r24, (DISPLAY_NO_CHARACTERS_PER_LINE - 1)

	SNAKE_POS_TRANSFORM__DIRECTION_LEFT_:
	rjmp SNAKE_POS_TRANSFORM__DONE


	; Transform direction: Up
	SNAKE_POS_TRANSFORM__DIRECTION_UP:
	ldi TEMP, 1
	sub r25, TEMP
	; r25 >= 0 ? r25 : (GAME_DISPLAY_LINES - 1)
	brge SNAKE_POS_TRANSFORM__DIRECTION_UP_
	ldi r25, GAME_DISPLAY_LINES - 1

	SNAKE_POS_TRANSFORM__DIRECTION_UP_:
	rjmp SNAKE_POS_TRANSFORM__DONE


	SNAKE_POS_TRANSFORM__DONE:

	pop TEMP
	ret



; Maps the Snakes position stack to the game's display RAM
GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM:
	rcall GAME_DISPLAY_RAM_RESET

	ldi XH, high(SNAKE_POS)
	ldi XL, low(SNAKE_POS)

	lds TEMP, SNAKE_POS_SIZE
	lsr TEMP ; divide by two since we pop two elements (x,y)
	GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM_LOOP:
	cpi TEMP, 0
	breq GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM_LOOP_END

	ld r24, X+ ; X coordinate
	ld r25, X+ ; Y coordinate
	
	; If we are on the head of stack, then select SPRITE_HEAD
	; otherwise SPRITE_BODY
	ldi r23, SPRITE_BODY
	cpi TEMP, 1
	brne GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM_LOOP_1
	ldi r23, SPRITE_HEAD

	GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM_LOOP_1:
	rcall GAME_DISPLAY_WRITE_XY

	dec TEMP
	rjmp GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM_LOOP

	GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM_LOOP_END:


	ret

; Write to the game display RAM using X,Y coordinates
;
; Point = X,Y
;
; |-------- ... -----|
; |0,0|1,0| ... |15,0|
; |0,1|   | ... |    |
; |0,2|   | ... |    |
; |0,3|   | ... |15,3|
; |-------- ... -----|
;
; r24: X
; r25: Y
; r23: DATA to write
GAME_DISPLAY_WRITE_XY:
	push TEMP
	push TEMP2
	push XH
	push XL

	; (GAME_DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE * Y + X)

	ldi XH, high(GAME_DISPLAY_RAM)
	ldi XL, low(GAME_DISPLAY_RAM)

	; TEMP = DISPLAY_NO_CHARACTERS_PER_LINE * Y
	ldi TEMP, DISPLAY_NO_CHARACTERS_PER_LINE
	mul TEMP, r25
	mov TEMP, r0

	; XH | XL  +  TEMP2 (0) | TEMP 
	ldi TEMP2, 0
	add XL, TEMP 
	adc XH, TEMP2

	; XH | XL  +  TEMP2 (0) | X
	ldi TEMP2, 0
	add XL, r24
	adc XH, TEMP2

	st X, r23

	pop XL
	pop XH
	pop TEMP2
	pop TEMP
	ret


; Maps the game display character into the display character font necessary
; to render the character to the display.
; r24: top game display character
; r25: bottom game display character
;
; r25: return value (display character)
;	|-------|
;	|  Top  |
;	|  Char |
;	|-------|
;	| Bottom|
;	|  Char |
;	|-------|
;
GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER:
	; t = Top character
	; b = Bottom character

	; t = Empty & b = Empty => 'Empty'
	cpi r24, SPRITE_EMPTY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_1
	cpi r25, SPRITE_EMPTY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_1

	ldi r25, DISPLAY_CHAR_EMPTY
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_1:
	; t = Empty & b = Body => 'Body bottom'
	cpi r24, SPRITE_EMPTY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_2
	cpi r25, SPRITE_BODY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_2
	
	ldi r25, DISPLAY_CHAR_BODY_BOTTOM
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_2:
	; t = Body & b = Empty => 'Body top'
	cpi r24, SPRITE_BODY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_3
	cpi r25, SPRITE_EMPTY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_3

	ldi r25, DISPLAY_CHAR_BODY_TOP
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_3:
	; t = Empty & b = Head => 'Head bottom'
	cpi r24, SPRITE_EMPTY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_4
	cpi r25, SPRITE_HEAD
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_4

	ldi r25, DISPLAY_CHAR_HEAD_BOTTOM
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_4:
	; t = Head & b = Empty => 'Head top'
	cpi r24, SPRITE_HEAD
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_5
	cpi r25, SPRITE_EMPTY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_5

	ldi r25, DISPLAY_CHAR_HEAD_TOP
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_5:
	; t = Body & b = Body => 'Body both'
	cpi r24, SPRITE_BODY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_6
	cpi r25, SPRITE_BODY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_6

	ldi r25, DISPLAY_CHAR_BODY_BOTH
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_6:
	; t = Body & b = Head => 'Body top, head bottom'
	cpi r24, SPRITE_BODY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_7
	cpi r25, SPRITE_HEAD
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_7

	ldi r25, DISPLAY_CHAR_BODY_TOP_HEAD_BOTTOM
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_7:
	; t = Head & b = Body => 'Head top, body bottom'
	cpi r24, SPRITE_HEAD
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_8
	cpi r25, SPRITE_BODY
	brne GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_8

	ldi r25, DISPLAY_CHAR_HEAD_TOP_BODY_BOTTOM
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_8:
	; SOMETHING ELSE??!?! Return the 'unknown' character
	ldi r25, DISPLAY_CHAR_UNKNOWN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN:

	ret


; Maps the game display ram to the display ram, accounting for the display's
; limitations (i.e. 1 display line is 2 game display lines). 
GAME_DISPLAY_RAM_MAP_DISPLAY_RAM:
	
	ldi XH, high(GAME_DISPLAY_RAM)
	ldi XL, low(GAME_DISPLAY_RAM)

	ldi YH, high(GAME_DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE)
	ldi YL, low(GAME_DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE)

	ldi ZH, high(DISPLAY_RAM)
	ldi ZL, low(DISPLAY_RAM)

	; LOOP
	ldi TEMP, DISPLAY_NO_CHARACTERS_PER_LINE
	ldi TEMP2, 0 ; line number 0 = 1st line, 1 = 2nd line

	GAME_DISPLAY_RAM_MAP_DISPLAY_RAM_LOOP:
	cpi TEMP, 0
	breq GAME_DISPLAY_RAM_MAP_DISPLAY_RAM_LOOP_END

	ld r24, X+
	ld r25, Y+
	rcall GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER
	st Z+, r25

	dec TEMP
	rjmp GAME_DISPLAY_RAM_MAP_DISPLAY_RAM_LOOP
	GAME_DISPLAY_RAM_MAP_DISPLAY_RAM_LOOP_END:


	cpi TEMP2, 1
	breq GAME_DISPLAY_RAM_MAP_DISPLAY_RAM_RETURN

	inc TEMP2
	ldi TEMP, DISPLAY_NO_CHARACTERS_PER_LINE

	ldi XH, high(GAME_DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE * 2)
	ldi XL, low(GAME_DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE * 2)

	ldi YH, high(GAME_DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE * 3)
	ldi YL, low(GAME_DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE * 3)

	ldi ZH, high(DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE)
	ldi ZL, low(DISPLAY_RAM + DISPLAY_NO_CHARACTERS_PER_LINE)

	rjmp GAME_DISPLAY_RAM_MAP_DISPLAY_RAM_LOOP

	GAME_DISPLAY_RAM_MAP_DISPLAY_RAM_RETURN:

	ret
	

; TODO - delete me
GAME_DISPLAY_RAM_DEBUG:
	ldi r24, SPRITE_BODY
	sts GAME_DISPLAY_RAM, r24

	ldi r24, SPRITE_BODY
	sts GAME_DISPLAY_RAM + 1, r24

	ldi r24, SPRITE_HEAD
	sts GAME_DISPLAY_RAM + 2, r24

	ldi r24, SPRITE_BODY
	sts GAME_DISPLAY_RAM + 16, r24

	ldi r24, SPRITE_BODY
	sts GAME_DISPLAY_RAM + 32, r24

	ldi r24, SPRITE_BODY
	sts GAME_DISPLAY_RAM + 48, r24

	ret

; Display sync status LED, Pin A1
DISPLAY_SYNC_LED_INIT:
	ldi TEMP, 0x01
	out DDRA, TEMP
	ret

DISPLAY_SYNC_LED_BLINK:
	ldi TEMP, 0x01
	out PORTA, TEMP

	ldi r24, 200
	rcall DELAY_Nms

	ldi TEMP, 0x00
	out PORTA, TEMP

	ldi r24, 200
	rcall DELAY_Nms

	ret

GAME_DISPLAY_RAM_RESET:
	ldi TEMP, SPRITE_EMPTY
	ldi XH, high(GAME_DISPLAY_RAM)
	ldi XL, low(GAME_DISPLAY_RAM)

	ldi TEMP2, GAME_DISPLAY_RAM_SIZE

	GAME_DISPLAY_RAM_RESET_LOOP:
	cpi TEMP2, 0
	breq GAME_DISPLAY_RAM_RESET_LOOP_END
	st X+, TEMP
	;inc XL
	dec TEMP2
	rjmp GAME_DISPLAY_RAM_RESET_LOOP
	GAME_DISPLAY_RAM_RESET_LOOP_END:

	ret


; Resets the area of memory where the DISPLAY_RAM is with ' ' characters.
DISPLAY_RAM_RESET:
	ldi TEMP, ' '
	ldi XH, high(DISPLAY_RAM)
	ldi XL, low(DISPLAY_RAM)

	ldi TEMP2, DISPLAY_RAM_SIZE

	DISPLAY_RAM_RESET_LOOP:
	cpi TEMP2, 0
	breq DISPLAY_RAM_RESET_LOOP_END
	st X+, TEMP
	;inc XL
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
	ld r24, X+
	rcall DISPLAY_SEND_CHARACTER
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
	ld r24, X+
	rcall DISPLAY_SEND_CHARACTER
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

	HEAD_TOP_BODY_BOTTOM_PIXEL_ROW:
	.db 0x0E, 0x11, 0x11, 0x0E, 0x0E, 0x1F, 0x1F, 0x0E

	HEAD_BOTTOM_BODY_TOP_PIXEL_ROW:
	.db 0x0E, 0x1F, 0x1F, 0x0E, 0x0E, 0x11, 0x11, 0x0E

	; Create the sprites in the display's RAM
	ldi ZH, high(BODY_TOP_PIXEL_ROW * 2)
	ldi ZL, low(BODY_TOP_PIXEL_ROW * 2)
	ldi r24, DISPLAY_CHAR_BODY_TOP
	rcall SPRITE_CREATE

	ldi ZH, high(BODY_BOTTOM_PIXEL_ROW * 2)
	ldi ZL, low(BODY_BOTTOM_PIXEL_ROW * 2)
	ldi r24, DISPLAY_CHAR_BODY_BOTTOM
	rcall SPRITE_CREATE
	
	ldi ZH, high(BODY_BOTH_PIXEL_ROW * 2)
	ldi ZL, low(BODY_BOTH_PIXEL_ROW * 2)
	ldi r24, DISPLAY_CHAR_BODY_BOTH
	rcall SPRITE_CREATE
	
	ldi ZH, high(HEAD_TOP_PIXEL_ROW * 2)
	ldi ZL, low(HEAD_TOP_PIXEL_ROW * 2)
	ldi r24, DISPLAY_CHAR_HEAD_TOP
	rcall SPRITE_CREATE

	ldi ZH, high(HEAD_BOTTOM_PIXEL_ROW * 2)
	ldi ZL, low(HEAD_BOTTOM_PIXEL_ROW * 2)
	ldi r24, DISPLAY_CHAR_HEAD_BOTTOM
	rcall SPRITE_CREATE
	
	ldi ZH, high(HEAD_TOP_BODY_BOTTOM_PIXEL_ROW * 2)
	ldi ZL, low(HEAD_TOP_BODY_BOTTOM_PIXEL_ROW * 2)
	ldi r24, DISPLAY_CHAR_HEAD_TOP_BODY_BOTTOM
	rcall SPRITE_CREATE

	ldi ZH, high(HEAD_BOTTOM_BODY_TOP_PIXEL_ROW * 2)
	ldi ZL, low(HEAD_BOTTOM_BODY_TOP_PIXEL_ROW * 2)
	ldi r24, DISPLAY_CHAR_BODY_TOP_HEAD_BOTTOM
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

	ldi r24, DISPLAY_CHAR_BODY_TOP
	rcall DISPLAY_SEND_CHARACTER

	ldi r24, DISPLAY_CHAR_BODY_BOTTOM
	rcall DISPLAY_SEND_CHARACTER
	
	ldi r24, DISPLAY_CHAR_BODY_BOTH
	rcall DISPLAY_SEND_CHARACTER
	
	ldi r24, DISPLAY_CHAR_HEAD_TOP
	rcall DISPLAY_SEND_CHARACTER
	
	ldi r24, DISPLAY_CHAR_HEAD_BOTTOM
	rcall DISPLAY_SEND_CHARACTER
	
	ldi r24, DISPLAY_CHAR_HEAD_TOP_BODY_BOTTOM
	rcall DISPLAY_SEND_CHARACTER
	
	ldi r24, DISPLAY_CHAR_BODY_TOP_HEAD_BOTTOM
	rcall DISPLAY_SEND_CHARACTER

	ldi r24, DISPLAY_CHAR_EMPTY
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

	lpm r24, Z+
	rcall DISPLAY_SEND_CHARACTER

	lpm r24, Z+
	rcall DISPLAY_SEND_CHARACTER

	lpm r24, Z+
	rcall DISPLAY_SEND_CHARACTER

	lpm r24, Z+
	rcall DISPLAY_SEND_CHARACTER

	lpm r24, Z+
	rcall DISPLAY_SEND_CHARACTER

	lpm r24, Z+
	rcall DISPLAY_SEND_CHARACTER

	lpm r24, Z+
	rcall DISPLAY_SEND_CHARACTER

	lpm r24, Z+ ; strickly speaking + not necessary here
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

	; Display on/off control instruction - Turn display on, cursor & blinking off
	ldi r24, 0b0000_1100
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
