fpga-lunarLanderGame
====================

# the atari lunar lander game made with hardware!

A lunar lander game hardware design in synthesis-able VHDL. Designed to be implemented on a Spartan3
FPGA, and done using Xilinx ISE webpack 14.3.
The vhdl code is intended to be as understandable as possible (e.g., process are written to be as close as the rt diagram, instead of wrapping various components in one process).

notice: most of the code is in Spanish. Make an issue if you want it translated.
the design has attached pdfs with handmade rt diagrams.

## DESIGN  

#### Random positions of bases and world 
A Linear feedback shift register is used for implementing a pseudo-random number generator, as seen in this [paper](http://www.xilinx.com/support/documentation/application_notes/xapp052.pdf). The pseudo random generator is used for generating the world and bases.

#### Ship movement with inertia and gravity
The movement of the ship is rendered in two steps: 
  1. Velocities. The ship has vertical (up-down) and horizontal (left-right) velocities, which allow to have acceleration and correctly simulate the behaviour of the ship. This is implemented with two counters (the vertical counter is descending at a steady pace for simulating the gravity).
  2. Position in the screen. 2 counters, one for vertical, and the other for horizontal pixels, render the ship in the screen. The counters always change in +-1 pixel, but the values of the velocity counters determine the rate, and thus, the ship moves faster or slower in the screen.

#### World generation
The world is stored in a RAM, column by column. The first pixel of current column is randomly generated by summing/subtracting a fixed amount of pixels to the first pixel of the last painted column.
For this, a FSM iterates each column, reading the first pixel of the last column from a register, which stores it. 

#### PS2 module for interfacing with a keyboard
A little FSM with flag registers is used for taking into acount the key presses.

#### VGA sync and screen painting 
2 counters are used for creating the vertical and horizontal sync, and are also used for adressing the ram for painting the screen.

## Video
[see it here!](http://www.youtube.com/watch?v=YO3Od2-9k7o)


## License 
All the source code present here is under the GPLv3 license. Please see the GPv3License.md attached to this repo for more information.

