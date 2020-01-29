# Snake Embedded
Classic Snake game written in AVR assembler for the ATmega128 8-bit Microcontroller.

On game over press the switch on the joystick to start a new game.

## Electronics
* Microcontroller: [Microchip ATmega128 8-bit AVR](https://www.microchip.com/wwwproducts/en/ATMEGA128)
* Development board: [ATMEGACONT128](https://futurlec.com/ATMEGA_Controller.shtml)
* Display: [DEVLCD (HD4470 compatible)](https://www.futurlec.com/DevBoardAccessories.shtml)
* Joystick module [similar to this](http://www.energiazero.org/arduino_sensori/joystick_module.pdf)

### Pins
Display: ET-CLCD (see board details) \
LED (blinks when display refreshes): GPIO A0 \
Joystick X-axis: GPIO F0 \
Joystick Y-axis: GPIO F1 \
Joystick switch: GPIO E0 
