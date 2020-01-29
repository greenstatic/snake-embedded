# Snake Embedded
Classic Snake game written in AVR assembler for the ATmega128 8-bit Microcontroller.

On game over press the switch on the joystick to start a new game.

## Electronics
* Microcontroller: [Microchip ATmega128 8-bit AVR](https://www.microchip.com/wwwproducts/en/ATMEGA128)
* Development board: [ATMEGACONT128](https://futurlec.com/ATMEGA_Controller.shtml)
* Display: [DEVLCD (HD4470 compatible)](https://www.futurlec.com/DevBoardAccessories.shtml)

### Pins
Display is connected to: ET-CLCD \
LED (blinks when display refreshes): GPIO A0 \
Joystick X-axis: GPIO F0
Joystick Y-axis: GPIO F1
Joystick switch: GPIO E0
