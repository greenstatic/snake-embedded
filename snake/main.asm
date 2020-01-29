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
#define DISPLAY_CHAR_DROP					0x2A
#define DISPLAY_CHAR_UNKNOWN				0x21

#define SNAKE_POS_MAX_LENGTH 64
#define SNAKE_POS_INIT_X 7
#define SNAKE_POS_INIT_Y 1

#define DIRECTION_RIGHT 0
#define DIRECTION_DOWN	1
#define DIRECTION_LEFT	2
#define DIRECTION_UP	3
#define DIRECTION_PREVIOUS 4

#define JOYSTICK_THRESHOLD_DELTA 30 ; how sensative the controls are

; Parameters for Lehmer random number generator
#define RNG_SEED	1
#define RNG_M		31
#define RNG_A		3

#define COLLISION_NO	0
#define COLLISION_DROP	1
#define COLLISION_SELF	2

#define TRUE 1
#define FALSE 0


; We treat these register values as 'variables' with local scope, therefore
; we assume when we call a subroutine they will be pushed/popped by the subroutine
.def TEMP = R18
.def TEMP2 = R19
.def TEMP3 = R20

.DSEG
GAME_DISPLAY_RAM:	.byte GAME_DISPLAY_RAM_SIZE
DISPLAY_RAM:		.byte DISPLAY_RAM_SIZE
POINTS:				.byte 1
DIRECTION:			.byte 1
JOYSTICK_BUFFER:	.byte 1
DROP_COORDINATES:	.byte 2 * 2 ; two drops with x,y
SNAKE_POS_SIZE:		.byte 1
SNAKE_POS:			.byte (SNAKE_POS_MAX_LENGTH + 1) * 2; we store X,Y for one position
													  ; +1 to add a buffer when we add the new
													  ; head and remove the last element
TEMP_8_BYTE:	.byte 8
RNG_NUMBER:		.byte 1
TEMP_64_byte:	.byte 64 + 1 ; first byte should have written the size of the array


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
	
	rcall RNG_INIT

	;rcall SPRITE_DEBUG_DISPLAY

	rcall GAME_INIT
	rcall JOYSTICK_INIT

	; Pre-render the game as part of initialization
	rcall GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM
	rcall GAME_DISPLAY_RAM_MAP_DISPLAY_RAM
	rcall DROP_NEXT
	rcall DROP_RENDER
	; End pre-render

	; Main game loop
	MAIN_GAME_LOOP:
	rcall JOYSTICK_READ
	rcall MOVE_DIRECTION_VALID

	rcall GAME_TICK
	rcall GAME_SNAKE_POSITION_MAP_GAME_DISPLAY_RAM
	rcall DROP_RENDER
	rcall GAME_DISPLAY_RAM_MAP_DISPLAY_RAM
	rcall DISPLAY_SYNC
	rcall DISPLAY_SYNC_LED_BLINK
	
	
	; 200 ms delay
	ldi r24, 200
	rcall DELAY_Nms

	rjmp MAIN_GAME_LOOP

; Blocks until the button is pressed
BUTTON_PRESS_WAIT:
	; GPIO E0
	BUTTON_PRESS_WAIT__LOOP:
	in r24, PINE
	andi r24, 0x01

	cpi r24, 0
	breq BUTTON_PRESS_WAIT__LOOP_END

	rjmp BUTTON_PRESS_WAIT__LOOP

	BUTTON_PRESS_WAIT__LOOP_END:
	
	; Minor 200ms delay
	ldi r24, 200
	rcall DELAY_Nms

	ret

; Renders the game over screen, showing the number of points
; and waits for the user to press conitnue to restart the game.
; Only jump into this subroutine, DO NOT CALL IT (rcall). Even
; though we restart the game by jumping to START (therefore 
; initializing the stack from the beginning), it is more
; clear what is happening in the code.
GAME_OVER_SCREEN:
	rcall GAME_OVER_SCREEN_DISPLAY_PRINT
	rcall BUTTON_PRESS_WAIT

	rjmp START ; restart game


; Sends to the display the text for the game over screen.
GAME_OVER_SCREEN_DISPLAY_PRINT:
	rcall DISPLAY_CLEAR

	; First line
	ldi r24, 0x82
	rcall DISPLAY_SEND_COMMAND
	ldi r24, 'G'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'A'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'M'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'E'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, ' '
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'O'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'V'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'E'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'R'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, ' '
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, '='
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, '('
	rcall DISPLAY_SEND_CHARACTER

	; Second line
	ldi r24, 0xC2
	rcall DISPLAY_SEND_COMMAND

	ldi r24, 'P'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'O'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'I'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'N'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'T'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, 'S'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, ':'
	rcall DISPLAY_SEND_CHARACTER
	ldi r24, ' '
	rcall DISPLAY_SEND_CHARACTER

	lds r24, POINTS
	rcall DISPLAY_SEND_DECIMAL

	ret


; Call when the snake has collided with a drop. Increases the points and spawns
; a new drop.
; r24: Input Snake head X coordinate
; r25: Input Snake head Y coordinate
SNAKE_COLLIDED_WITH_DROP:
	push TEMP
	push TEMP2
	push TEMP3

	mov TEMP2, r24
	mov TEMP3, r25

	; Increment points by one
	lds r24, POINTS
	inc r24
	sts POINTS, r24


	; Add's the drops position to the snakes position stack
	; Get stack size
	lds TEMP, SNAKE_POS_SIZE
	
	; Set pointer to top most element
	ldi XH, high(SNAKE_POS)
	ldi XL, low(SNAKE_POS)
	
	; XH | XL  +  r24 | TEMP
	ldi r24, 0
	add XL, TEMP
	adc XH, r24

	; Create a new element on the top with the coordinates of
	; the drop
	st x+, TEMP2
	st x+, TEMP3

	; Increment stack size
	lds TEMP, SNAKE_POS_SIZE
	inc TEMP
	inc TEMP
	sts SNAKE_POS_SIZE, TEMP

	rcall DROP_NEXT
	
	pop TEMP3
	pop TEMP2
	pop TEMP
	ret


; Checks if the snake has collided with anything.
; r24: Input register with snake head X coordinate (game display coordinate)
; r25: Input register with snake head Y coordinate (game display coordinate)
;
; r25: Return register value with collision, if any (COLLISION_NO, COLLISION_DROP, COLLISION_SELF).
SNAKE_COLLISION_DETECTION:
	push TEMP
	push TEMP2

	mov TEMP, r24
	mov TEMP2, r25

	; Check if collision with self
	SNAKE_COLLISION__CHECK_SELF:
	mov r24, TEMP
	mov r25, TEMP2
	rcall SNAKE_POS_CONTAINS
	cpi r25, TRUE
	brne SNAKE_COLLISION__CHECK_DROP_1

	; Collision with self detected
	ldi r25, COLLISION_SELF
	rjmp SNAKE_COLLISION__END

	SNAKE_COLLISION__CHECK_DROP_1:
	; Check if drop collision (upper part)
	lds r24, DROP_COORDINATES
	lds r25, DROP_COORDINATES + 1

	cp TEMP, r24
	brne SNAKE_COLLISION__CHECK_DROP_2
	cp TEMP2, r25
	brne SNAKE_COLLISION__CHECK_DROP_2
	; Drop collision
	ldi r25, COLLISION_DROP
	rjmp SNAKE_COLLISION__END

	; Check if drop collision (bottom part)
	SNAKE_COLLISION__CHECK_DROP_2:
	lds r24, DROP_COORDINATES + 2
	lds r25, DROP_COORDINATES + 3
	
	cp TEMP, r24
	brne SNAKE_COLLISION__NO_COLLISION
	cp TEMP2, r25
	brne SNAKE_COLLISION__NO_COLLISION
	; Drop collision
	ldi r25, COLLISION_DROP
	rjmp SNAKE_COLLISION__END
	

	; No collision
	SNAKE_COLLISION__NO_COLLISION:
	ldi r25, COLLISION_NO

	SNAKE_COLLISION__END:

	pop TEMP2
	pop TEMP
	ret


; Renders drops to the game display RAM
DROP_RENDER:
	lds r24, DROP_COORDINATES
	lds r25, DROP_COORDINATES + 1
	ldi r23, SPRITE_DROP
	rcall GAME_DISPLAY_WRITE_XY

	lds r24, DROP_COORDINATES + 2
	lds r25, DROP_COORDINATES + 3
	ldi r23, SPRITE_DROP
	rcall GAME_DISPLAY_WRITE_XY

	ret


; Places the drop with respect to the game state (position of the snake)
DROP_NEXT:
	push TEMP

	ldi XH, high(TEMP_64_byte)
	ldi XL, low(TEMP_64_byte)
	rcall SNAKE_POS_FREE_COORDINATES
	
	ldi XH, high(TEMP_64_byte)
	ldi XL, low(TEMP_64_byte)
	
	ld TEMP, X+ ; Number of free characters (possible placements of drop)
	; X now points to the array

	rcall RNG_NEXT
	mov r24, r25
	mov r25, TEMP
	rcall MOD
	; r24 now contains the offset of the array which points to the display RAM offset
	; where the drop is going to be
	; XH | XL  +  r25 | r24
	ldi r25, 0
	add XL, r24
	adc XH, r25

	ld TEMP, X ; The offset of display RAM where the drop is going to be

	; Assume we have only two lines on our display
	cpi TEMP, DISPLAY_NO_CHARACTERS_PER_LINE
	brlo DROP_COORDINATES_UPDATE__TRANSFORM_DISPLAY_OFFSET_FIRST_LINE
	; Second character line
	subi TEMP, DISPLAY_NO_CHARACTERS_PER_LINE
	sts DROP_COORDINATES, TEMP
	ldi r24, 2
	sts DROP_COORDINATES + 1, r24

	sts DROP_COORDINATES + 2, TEMP
	ldi r24, 3
	sts DROP_COORDINATES + 3, r24

	rjmp DROP_COORDINATES_UPDATE__TRANSFORM_DISPLAY_OFFSET_END

	DROP_COORDINATES_UPDATE__TRANSFORM_DISPLAY_OFFSET_FIRST_LINE:
	; First character line
	sts DROP_COORDINATES, TEMP
	ldi r24, 0
	sts DROP_COORDINATES + 1, r24

	sts DROP_COORDINATES + 2, TEMP
	ldi r24, 1
	sts DROP_COORDINATES + 3, r24

	DROP_COORDINATES_UPDATE__TRANSFORM_DISPLAY_OFFSET_END:

	pop TEMP
	ret

; Saves into memory the offsets of the character display RAM which are free (empty) 
; in the game world.
; X: Base pointer to block of memory where we can write the empty character offsets
SNAKE_POS_FREE_COORDINATES:
	push TEMP
	push TEMP2

	push XH
	push XL
	adiw X, 1 ; first element is for the size which we will write in the end

	ldi YH, high(DISPLAY_RAM)
	ldi YL, low(DISPLAY_RAM)

	ldi TEMP2, 0 ; size counter of empty chars
	ldi TEMP, 0

	SNAKE_POS_FREE_COORDINATES__LOOP:
	cpi TEMP, DISPLAY_RAM_SIZE
	breq SNAKE_POS_FREE_COORDINATES__LOOP_END

	ld r24, Y+
	cpi r24, DISPLAY_CHAR_EMPTY
	brne SNAKE_POS_FREE_COORDINATES__LOOP_CONTINUE

	; write the offset into memory where the empty char is in display RAM
	st X+, TEMP

	inc TEMP2
	SNAKE_POS_FREE_COORDINATES__LOOP_CONTINUE:
	inc TEMP
	rjmp SNAKE_POS_FREE_COORDINATES__LOOP
	
	SNAKE_POS_FREE_COORDINATES__LOOP_END:
	; Write the size of the array
	pop XL
	pop XH

	st X, TEMP2

	pop TEMP2
	pop TEMP
	ret

; Clears a block of memory.
; r24: Value to replace the block of memory with
; r25: Length of memory to clear
; X: Base pointer to the block of memory
ARRAY_CLEAR:
	push TEMP

	ARRAY_CLEAR__LOOP:
	cpi r25, 0
	breq ARRAY_CLEAR__END

	ld r24, X+

	dec r25
	rjmp ARRAY_CLEAR__LOOP

	ARRAY_CLEAR__END:
	pop TEMP
	ret


; Initialize the pseudo random number generator.
RNG_INIT:
	ldi r24, RNG_SEED
	sts RNG_NUMBER, r24
	ret

; Returns the next random number from the pseudo random number generator.
; We use a very primitive Lehmer random number generator with a period of
; 30. We subtract from the original answer 1 in order to get numbers [0,29]
; r25: Return register for the random number
RNG_NEXT:
	push TEMP
	push TEMP2

	lds TEMP, RNG_NUMBER
	mov TEMP2, TEMP
	
	ldi r24, RNG_A
	mul r24, TEMP2

	; 3 * 30 = 90 can be the max product, the lower byte is all we need
	mov r24, r0 
	ldi r25, RNG_M
	rcall MOD

	sts RNG_NUMBER, r24

	; Return the "previous" value and subtract one
	mov r25, TEMP
	subi r25, 1

	pop TEMP2
	pop TEMP
	ret

; Take a 8-bit unsigned number and convert it into ASCII decimal, then
; send it to the display. Make sure the cursor is set where you wish the
; first digit to appear and that there is enough room to print the entire number
; (3 characters since 8-bits can be max 2^8 = 255 DEC, three digits).
;
; r24: Input register value to display as a deciaml number on the display
DISPLAY_SEND_DECIMAL:
	push TEMP

	ldi XH, high(TEMP_8_BYTE)
	ldi XL, low(TEMP_8_BYTE)
	rcall BIN_2_ASCII_DEC

	ldi XH, high(TEMP_8_BYTE)
	ldi XL, low(TEMP_8_BYTE)
	
	ldi TEMP, 8
	DISPLAY_SEND_DECIMAL__LOOP:
	cpi TEMP, 0
	breq DISPLAY_SEND_DECIMAL__LOOP_END

	ld r24, X+
	cpi r24, 0
	breq DISPLAY_SEND_DECIMAL__LOOP_SKIP

	rcall DISPLAY_SEND_CHARACTER

	DISPLAY_SEND_DECIMAL__LOOP_SKIP:
	dec TEMP
	rjmp DISPLAY_SEND_DECIMAL__LOOP

	DISPLAY_SEND_DECIMAL__LOOP_END:

	pop TEMP
	ret

; Convert a 8-bit register value into an ASCII decimal number stored in memory.
; r24: Input register unsigned number
; X: Base pointer to memory space where we will save the decimal number (1 byte = 1 DEC digit)
BIN_2_ASCII_DEC:
	push TEMP
	push TEMP2
	
	; Add 8 to base pointer since we will decrement it in the loop below
	; XH | XL  +  TEMP2 | TEMP
	ldi TEMP, 8
	ldi TEMP2, 0
	add XL, TEMP
	adc XH, TEMP2

	; Check if input is 0
	cpi r24, 0
	brne BIN_2_ASCII_DEC__LOOP_INIT

	ldi TEMP, 0x30
	add r24, TEMP
	st -X, r24
	rjmp BIN_2_ASCII_DEC__LOOP_END

	; Input is not equal to 0
	BIN_2_ASCII_DEC__LOOP_INIT:
	mov TEMP2, r24

	BIN_2_ASCII_DEC__LOOP:
	cpi TEMP, 0
	breq BIN_2_ASCII_DEC__LOOP_END

	cpi TEMP2, 0
	brne BIN_2_ASCII_DEC__LOOP_1

	ldi r24, 0
	st -X, r24
	rjmp BIN_2_ASCII_DEC__LOOP_2


	BIN_2_ASCII_DEC__LOOP_1:
	mov r24, TEMP2
	ldi r25, 10
	rcall MOD

	ldi r25, 0x30 ; ASCII digit section
	add r24, r25

	st -X, r24

	mov r24, TEMP2
	ldi r25, 10
	rcall DIV

	mov TEMP2, r24

	BIN_2_ASCII_DEC__LOOP_2:

	dec TEMP
	rjmp BIN_2_ASCII_DEC__LOOP
	BIN_2_ASCII_DEC__LOOP_END:


	pop TEMP2
	pop TEMP
	ret


; Take the modulo (remainder) of two 8-bit unsigned numbers
; r24: Input dividend register with unsigned number
; r25: Input divisor register with unsigned number
;
; r24: Return register with remainder
;
; If divisor is 0, undefined behaviour.
MOD:
	rcall DIV
	mov r24, r25
	ret


; Divide two 8-bit unsigned numbers
; r24: Input dividend register with unsigned number
; r25: Input divisor register with unsigned number
;
; r24: Return register with quotient
; r25: Return register with remainder
;
; If divisor is 0, undefined behaviour.
DIV:
	push TEMP

	ldi TEMP, 0 ; quotient

	; Cannot divide by 0, if we do, simply end the subroutine
	cpi r25, 0
	breq DIV__LOOP_END

	DIV__LOOP:
	cp r24, r25
	brlo DIV__LOOP_END ; r24 < r25

	sub r24, r25
	inc TEMP

	rjmp DIV__LOOP

	DIV__LOOP_END:
	mov r25, r24 ; remainder
	mov r24, TEMP
	
	pop TEMP
	ret



; Sends to the display a 8-bit register value as a 8 character binary number.
; Please make sure that the cursor is at a place where the full 8 character
; binary number will be visable.
; r24: Input register value to display
DISPLAY_SEND_REGISTER:
	push TEMP

	ldi XH, high(TEMP_8_BYTE)
	ldi XL, low(TEMP_8_BYTE)

	rcall REGISTER_2_MEMORY_BIN

	ldi XH, high(TEMP_8_BYTE)
	ldi XL, low(TEMP_8_BYTE)

	ldi TEMP, 8
	DISPLAY_SEND_REGISTER__LOOP:
	cpi TEMP, 0
	breq DISPLAY_SEND_REGISTER__LOOP_END

	ld r24, X+
	ldi r25, 0x30 ; ASCII 0x30 = 0, 0x31 = 1
	add r24, r25
	rcall DISPLAY_SEND_CHARACTER

	dec TEMP
	rjmp DISPLAY_SEND_REGISTER__LOOP

	DISPLAY_SEND_REGISTER__LOOP_END:

	pop TEMP
	ret


; Copies the register value into an array in the memory
; r24: Register value
; X: base pointer to a 8 byte memory location where we will copy each bit
;    of the register value
;
; e.g. r24 = 1101_1001
;      memory = | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 1 |
REGISTER_2_MEMORY_BIN:
	push TEMP
	push TEMP2

	; We will start from the "end" LSB to the "start" MSB
	; Add 8 to the base pointer, then we will decrement it
	; in each iteration of our loop below. Note: we use 8
	; because we use pre-decrement not post.
	; XH | XL  +  TEMP2 | TEMP
	ldi TEMP, 8
	ldi TEMP2, 0
	add XL, TEMP
	adc XH, TEMP2

	ldi TEMP, 8
	REGISTER_2_MEMORY_BIN__LOOP:
	cpi TEMP, 0
	breq REGISTER_2_MEMORY_BIN__LOOP_END
	
	mov TEMP2, r24
	andi TEMP2, 0x01
	st -X, TEMP2
	lsr r24

	dec TEMP
	rjmp REGISTER_2_MEMORY_BIN__LOOP
	REGISTER_2_MEMORY_BIN__LOOP_END:

	pop TEMP2
	pop TEMP
	ret


; Checks the players desired direction from the JOYSTICK_BUFFER
; and verifies it is a valid movement for the current state, if
; it is update the DIRECTION memory value.
MOVE_DIRECTION_VALID:
	push TEMP
	push TEMP2
	push TEMP3
	
	lds TEMP, JOYSTICK_BUFFER

	rcall SNAKE_HEAD_POS
	mov r23, TEMP
	rcall SNAKE_POS_TRANSFORM
	mov TEMP2, r24 ; new X coordinate if joystick buffer direction is applied
	mov TEMP3, r25 ; new Y coordinate if joystick buffer direction is applied

	; Check if the second element (after head) in the snake position stack contains 
	; the new X/Y coordinates, if it does ignore the joystick buffer direction
	lds r24, SNAKE_POS_SIZE
	cpi r24, 2 + 1
	brlo MOVE_DIRECTION_VALID__UPDATE_DIRECTION ; only head is in the stack, skip this check

	ldi XH, HIGH(SNAKE_POS)
	ldi XL, LOW(SNAKE_POS)
	subi r24, 2 + 2 ; since offset is at 0 not 1 (first 2), then to get the second last element 
					; in the array (second 2)
	ld r24, X+
	ld r25, X+

	cp r24, TEMP2
	brne MOVE_DIRECTION_VALID__UPDATE_DIRECTION
	cp r25, TEMP3
	brne MOVE_DIRECTION_VALID__UPDATE_DIRECTION

	; Second element in position stack is equal to the new head coordinates.
	; This is an invalid move, ignore joystick buffer direction.
	rjmp MOVE_DIRECTION_VALID__END 

	; Update the direction from the joystick buffer if buffer is not set
	; to DIRECTION_PREVIOUS
	MOVE_DIRECTION_VALID__UPDATE_DIRECTION:
	cpi TEMP, DIRECTION_PREVIOUS
	breq MOVE_DIRECTION_VALID__END
	sts DIRECTION, TEMP

	MOVE_DIRECTION_VALID__END:

	pop TEMP3
	pop TEMP2
	pop TEMP
	ret	


; Initialize the Joystick by turning on the ADC and configuring the switch.
; Joystick should be connected to PF0 (x), PF1 (y), PE0 (sw).
JOYSTICK_INIT:
	push TEMP

	; Set the port for the switch GPIO E0 as an input pin
	in TEMP, DDRE
	andi TEMP, 0xFE
	out DDRE, TEMP
	
	; Enable pull-up resistor for GPIO E0
	in TEMP, PORTE
	ori TEMP, 0x01
	out PORTE, TEMP

	; Setup the port for X/Y axis potenciometer
	ldi TEMP, 0x00
	sts DDRF, TEMP
	
	; Disable pull-up resistors for X/Y axis potenciometer
	ldi TEMP, 0x00
	sts PORTF, TEMP 

	; Enable ADC for X/Y axis potenciometer
	ldi TEMP, 0b1000_0111
	out ADCSRA, TEMP

	; Enable ADC Left Adjust Result
	ldi TEMP, 0b0010_0000
	out ADMUX, TEMP

	pop TEMP
	ret

; Read the values of the joystick and write the snake direction
; in the JOYSTICK_BUFFER.
JOYSTICK_READ:
	push TEMP
	push TEMP2
	push TEMP3

	rcall JOYSTICK_ADC_READ
	mov TEMP2, r24 ; X-axis
	mov TEMP3, r25 ; Y-axis

	; X-axis
	; 0 <= TEMP2 <= JOYSTICK_THRESHOLD_DELTA -> DIRECTION_LEFT
	; 255 - JOYSTICK_THRESHOLD_DELTA <= TEMP2 <= 255 -> DIRECTION_RIGHT
	JOYSTICK_READ__X_LEFT:
	cpi TEMP2, JOYSTICK_THRESHOLD_DELTA + 1
	brsh JOYSTICK_READ__X_RIGHT
	
	ldi TEMP, DIRECTION_LEFT
	sts JOYSTICK_BUFFER, TEMP
	rjmp JOYSTICK_READ__END

	JOYSTICK_READ__X_RIGHT:
	cpi TEMP2, 255 - JOYSTICK_THRESHOLD_DELTA
	brlo JOYSTICK_READ__Y_UP

	ldi TEMP, DIRECTION_RIGHT
	sts JOYSTICK_BUFFER, TEMP
	rjmp JOYSTICK_READ__END

	; Y-axis
	; 0 <= TEMP3 <= JOYSTICK_THRESHOLD_DELTA -> DIRECTION_UP
	; 255 - JOYSTICK_THRESHOLD_DELTA <= TEMP3 <= 255 -> DIRECTION_DOWN
	JOYSTICK_READ__Y_UP:
	cpi TEMP3, JOYSTICK_THRESHOLD_DELTA + 1
	brsh JOYSTICK_READ__Y_DOWN
	
	ldi TEMP, DIRECTION_UP
	sts JOYSTICK_BUFFER, TEMP
	rjmp JOYSTICK_READ__END

	JOYSTICK_READ__Y_DOWN:
	cpi TEMP3, 255 - JOYSTICK_THRESHOLD_DELTA
	brlo JOYSTICK_READ__KEEP_DIRECTION

	ldi TEMP, DIRECTION_DOWN
	sts JOYSTICK_BUFFER, TEMP
	rjmp JOYSTICK_READ__END


	; Keep the previous direction
	JOYSTICK_READ__KEEP_DIRECTION:
	ldi TEMP, DIRECTION_PREVIOUS
	sts JOYSTICK_BUFFER, TEMP

	JOYSTICK_READ__END:

	pop TEMP3
	pop TEMP2
	pop TEMP
	ret

; Reads the ADC values of the joystick with 8-bit precision.
; r24: Return value of joystick X-axis (0-255)
; r25: Return value of joystick Y-axis (0-255)
JOYSTICK_ADC_READ:
	push TEMP

	; Read value for X-axis
	
	; Select ADC00 (X-axis)
	; Enable ADLAR (Left adjusted), meaning we cut off the last
	; two bits of the ADCH | ADCL 10-bit value (which is the equivalent
	; of dividing by 2^2=4).
	in TEMP, ADMUX
	andi TEMP, 0xF8 ; remove the first 3 LSB (MUX) selector
	ori TEMP, 0x00
	out ADMUX, TEMP

	; Start conversion
	in TEMP, ADCSRA
	sbr TEMP, 0x40
	out ADCSRA, TEMP

	; Wait until the conversion is done
	JOYSTICK_ADC_READ__LOOP_X:
	in TEMP, ADCSRA
	sbrc TEMP, 6
	rjmp JOYSTICK_ADC_READ__LOOP_X

	in r24, ADCH

	; Read value for Y-axis
	
	; Select ADC01 (Y-axis) and enable ADLAR (see above why)
	in TEMP, ADMUX
	andi TEMP, 0xF8 ; remove the first 3 LSB (MUX) selector
	ori TEMP, 0x01
	out ADMUX, TEMP

	; Start conversion
	in TEMP, ADCSRA
	sbr TEMP, 0x40
	out ADCSRA, TEMP

	; Wait until the conversion is done
	JOYSTICK_ADC_READ__LOOP_Y:
	in TEMP, ADCSRA
	sbrc TEMP, 6
	rjmp JOYSTICK_ADC_READ__LOOP_Y

	in r25, ADCH

	pop TEMP
	ret


; Clears the display
DISPLAY_CLEAR:
	ldi r24, 0x1
	rcall DISPLAY_SEND_COMMAND
	ret


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

	; Initialize the joystick buffer
	ldi TEMP, DIRECTION_PREVIOUS
	sts JOYSTICK_BUFFER, TEMP

	ret

; Perform one game tick
GAME_TICK:
	push TEMP
	push TEMP2

	rcall SNAKE_HEAD_POS
	mov TEMP, r24 ; old x-coordinate
	mov TEMP2, r25 ; old y-coordinate

	push XH ; Pointer to next stack element (empty)
	push XL

	lds r23, DIRECTION
	rcall SNAKE_POS_TRANSFORM
	mov TEMP, r24 ; new x-coordinate
	mov TEMP2, r25 ; new y-coordinate

	; Check if snake hit obstacle
	rcall SNAKE_COLLISION_DETECTION
	cpi r25, COLLISION_DROP
	brne GAME_TICK__CHECK_COLLISION_SELF
	
	; Increment the X register by 2
	pop XL
	pop XH
	; XH | XL  +  r24 | r25
	ldi r24, 0
	ldi r25, 2
	add XL, r25
	adc XH, r24

	push XH
	push XL

	mov r24, TEMP ; restore the new x/y coordinates
	mov r25, TEMP2
	rcall SNAKE_COLLIDED_WITH_DROP
	rjmp GAME_TICK__COLLISION_DONE

	GAME_TICK__CHECK_COLLISION_SELF:
	cpi r25, COLLISION_SELF
	brne GAME_TICK__COLLISION_DONE
	; Collision with self
	rjmp GAME_OVER_SCREEN
	; Should not be reachable when jumping to GAME_OVER_SCREEN
	rjmp GAME_TICK__COLLISION_DONE

	GAME_TICK__COLLISION_DONE:

	pop XL
	pop XH

	; Push new head postion to snake position stack and increment the stack size counter
	st X+, TEMP
	st X+, TEMP2
	lds TEMP, SNAKE_POS_SIZE 
	inc TEMP
	inc TEMP
	sts SNAKE_POS_SIZE, TEMP

	; Remove the first element (the lowest element) in the snake position stack
	ldi XH, high(SNAKE_POS)
	ldi XL, low(SNAKE_POS)
	
	ldi YH, high(SNAKE_POS + 2) ; Y points to the next stack element (2 because we have x,y as 1 'element')
	ldi YL, low(SNAKE_POS + 2)
	
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

	; End of removal of first snake position stack element

	pop TEMP2
	pop TEMP
	ret

; Checks to see if the provided X/Y coordinate is a part
; of the snake position stack (if it is a member of the stack)
; r24: Input x coordinate
; r25: Input y coordinate
;
; r25: Return value TRUE if match otherwise FALSE
SNAKE_POS_CONTAINS:
	push TEMP
	push TEMP2
	push TEMP3

	mov TEMP2, r24 ; x coordinate
	mov TEMP3, r25 ; y coordinate

	ldi XH, HIGH(SNAKE_POS)
	ldi XL, LOW(SNAKE_POS)

	lds TEMP, SNAKE_POS_SIZE

	SNAKE_POS_CONTAINS__LOOP:
	cpi TEMP, 0
	breq SNAKE_POS_CONTAINS__LOOP_END

	ld r24, X+
	ld r25, X+

	cp r24, TEMP2
	brne SNAKE_POS_CONTAINS__LOOP_CONTINUE

	cp r25, TEMP3
	brne SNAKE_POS_CONTAINS__LOOP_CONTINUE

	; Found match
	ldi r25, TRUE
	rjmp SNAKE_POS_CONTAINS__END

	SNAKE_POS_CONTAINS__LOOP_CONTINUE:

	dec TEMP
	dec TEMP
	rjmp SNAKE_POS_CONTAINS__LOOP

	SNAKE_POS_CONTAINS__LOOP_END:
	; No match
	ldi r25, FALSE

	SNAKE_POS_CONTAINS__END:

	pop TEMP3
	pop TEMP2
	pop TEMP
	ret

; Gets the snakes head position in r24,r25 (x,y)
; r24: Return value X coordinate
; r25: Return value Y coordinate
SNAKE_HEAD_POS:
	push TEMP
	push TEMP2

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

	pop TEMP2
	pop TEMP
	ret


; Transforms the position of a block of snake
; in relation to the direction
; r24: X coordinate
; r25: Y coordinate
; r23: direction (DIRECTION_RIGHT, DIRECTION_DOWN, etc.)
;
; Return's the transofmred X,Y coordinates
; r24: Return value X coordinate
; r25: Return value Y coordinate
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
	; t = Drop or b = Drop => 'Drop'
	cpi r24, SPRITE_DROP
	breq GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_8_
	cpi r25, SPRITE_DROP
	breq GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_8_
	
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_UNKNOWN

	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_8_:
	ldi r25, DISPLAY_CHAR_DROP
	rjmp GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_RETURN


	GAME_DISPLAY_CHARACTER_MAP_DISPLAY_CHARACTER_UNKNOWN:
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


; Delay for n milliseconds
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
