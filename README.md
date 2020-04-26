JTFRAME by Jose Tejada (@topapate)
==================================

JTFRAME is a framework for FPGA computing on the MiST and MiSTer platform. JTFRAME is also a collection of useful verilog modules, simulation models and utilities to develop retro hardware on FPGA.

This is a work in progress. The first version will be considered ready once the 1942, 1943, Ghosts'n Goblins and Popeye cores all use JTFRAME common files.

You can show your appreciation through
    * Patreon: https://patreon.com/topapate
    * Paypal: https://paypal.me/topapate

#CPUs

Some CPUs are included in JTFRAME. Some of them can be found in other repositories in Github but the versions in JTFRAME include clock enable inputs and other improvements.

#Simulation of 74-series based schematics

Many arcade games and 80's computers use 74-series devices to do discrete logic. There are some files in JTFRAME that help analyze these systems using the following flow:

1. Draw the schematics in KiCAD using the libraries in the kicad folder
2. Generate a netlist in standard KiCAD format
3. Use the pcb2ver utility in the cc folder to convert the output from KiCAD to a verilog file
4. Prepare a module wrapper for the new verilog file and include the verilog file in the wrapper via an include command
5. Simulate the file with a regular verilog simulator.

There is a verilog library of 74-series gates in the hdl folder: hdl/jt74.v. The ones that include // ref and // pin comments can be used for KiCAD sims. It is very easy to add support for more cells. Feel free to submit pull merges to Github.

It makes sense to simulate delays in 74-series gates as this is important in some designs. Even if some cells do not include delays, later versions of jt74.v may include delays for all cells. It is not recommended to set up your simulations with Verilator because Verilator does not support delays and other modelling constructs. The jt74 library is not meant for synthesis, only simulation.

#Cabinet inputs during simulation
You can use a hex file with inputs for simulation. Enable this with the macro
SIM_INPUTS. The file must be called sim_inputs.hex. Each line has a hexadecimal
number with inputs coded. Active high only:

bit         meaning
0           coin 1
1           coin 2
2           1P start
3           2P start
4           right   (may vary with each game)
5           left    (may vary with each game)
6           down    (may vary with each game)
7           up      (may vary with each game)
8           Button 1
9           Button 2

Each line will be applied on a new frame.

#OSD colours
The macro JTFRAME_OSDCOLOR should be defined with a 6-bit value encoding an RGB tone. This is used for
the OSD background. The meanins are:

Value | Meaning                 | Colour
------|-------------------------|---------
6'h3f | Mature core             | Gray
6'h1e | Almost done             | Green
6'h3c | Playable with problems  | Yellow
6'h35 | Very early core         | Red

#SDRAM Controller
**jtframe_sdram** is a generic SDRAM controller that runs upto 48MHz because it is designed for CL=2. It mainly serves for reading ROMs from the SDRAM but it has some support for writting (apart from the initial ROM download process).

This module may result in timing errors in MiSTer because sometimes the compiler does not assign the input flip flops from SDRAM_DQ at the pads. In order to avoid this, you can define the macro **JTFRAME_SDRAM_REPACK**. This will add one extra stage of data latching, which seems to allow the fitter to use the pad flip flops. This does delay data availability by one clock cycle. Some cores in MiSTer do synthesize with pad FF without the need of this option. Use it if you find setup timing violation about the SDRAM_DQ pins.

SDRAM is treated in top level modules as a read-only memory (except for the download process). If the game core needs to write to the SDRAM the **JTFRAME_WRITEBACK** macro must be defined.

By default only the first bank of the SDRAM is used, allowing for 8MB of data organized in 4 M x 16bits. In order to enable access to the other three banks the macro **JTFRAME_SDRAM_BANKS** is used. Once this macro is defined the game module is expected to provide the following signals

[1:0] prog_bank     bank used during SDRAM programming
[1:0] sdram_bank    bank used during regular SDRAM use

These signals should be used in combination with the rest of prog_ and sdram_ signals in order to control the SDRAM.

The data bus is held down all the time and only released when the SDRAM is expected to use it. This behaviour can be reverted using **JTFRAME_NOHOLDBUS**. When this macro is defined, the bus will only be held while writting data and released the rest of the time. For 48MHz operation, holding the bus works better. For 96MHz it doesn't seem to matter.

#Fast Load

##MiST
Starting from the Dec. 2020 firmware update, MiST can now delegate the ROM load to the FPGA. This makes the process 4x faster. This option is enabled by default. However, it can be a problem because the ROM transfer will be composed of full SD card sectors so there will be some garbage sent at the end of the ROM. If the core is not compatible with this and it relies on exact sizing of the ROM it needs to define the macro **JTFRAME_MIST_DIRECT** and set it to zero:

```
set_global_assignment -name VERILOG_MACRO "JTFRAME_MIST_DIRECT=0"
```

##MiSTer
In order to preserve the 8-bit ROM download interface with MiST, _jtframe_mister_ presents it too. However it can operate internally with 16-bit packets if the macro **JTFRAME_MR_FASTIO** is set to 1. This has only been tested with 96MHz clock. Indeed, if **JTFRAME_CLK96** is defined and **JTFRAME_MR_FASTIO** is not, then it will be defined to 1.

#DIP switches and OSD

To enable support of DIP switches in MRA files define the macro **JTFRAME_MRA_DIP**. The maximum length of DIP switches is 32 bits.

Macro                | Effect
---------------------|----------------------------
JTFRAME_OSD_NOLOAD   | Do not display _load file_ 
JTFRAME_OSD_NOCREDITS| Do not display _Credits_ 
JTFRAME_OSD_FLIP     | Display flip option (only for vertical games)
JTFRAME_OSD_NOSND    | Do not display sound options

## Values used in the status word by JTFRAME

Values above 8 are not available in MiST if **JTFRAME_MRA_DIP** is defined.

bit     |  meaning                | Enabled with macro
--------|-------------------------|-------------------------------------
0       | Reset in MiST           |
1       | Flip screen             | VERTICAL_SCREEN && JTFRAME_OSD_FLIP
2       | Rotate controls         | VERTICAL_SCREEN (MiST)
2       | Rotate screen           | VERTICAL_SCREEN (MiSTer)
3-5     | Scandoubler Fx          | MISTER_VIDEO_MIXER
6-7     | FX Volume               | JT12
8       | ADPCM                   | JTFRAME_ADPCM && !JT12 && !JTFRAME_OSD_NOSND
8       | PSG                     | JT12 && !JTFRAME_OSD_NOSND
9       | FM                      | (JT51 || JT12) && !JTFRAME_OSD_NOSND
10      | Test mode               | JTFRAME_OSD_TEST
11      | Aspect Ratio            | MiSTer only
12      | Credits/Pause           |

If **JTFRAME_FLIP_RESET** is defined a change in dip_flip will reset the game.

##DIP switch information extraction from MAME

First you need to get the xml with all the information:

```
mame -listxml > mame.xml
```

The file *mamefilter.cc* is an example of how to extract a subset of machine definitions from the file.

The files *mamegame.hpp* and *mamegame.cc* contain some classes and a function to process the MAME XML into easy-to-use C++ objects. An example of this in use can be seen in JTCPS1 core.

#Joysticks
By default the frame supports two joysticks only and will try to connect to game modules based on this assumption. For games that need four joysticks, define the macro **JTFRAME_4PLAYERS**.
Note that the registers containing the coin and start button inputs are always passed as 4 bits, but the game can just ignore the 2 MSB if it only supports two players.

Analog controllers are not connected to the game module by default. In order to get them connected, define the macro **JTFRAME_ANALOG** and then these input ports:

```
    input   [15:0]  joystick_analog_0,
    input   [15:0]  joystick_analog_1,
```

#SDRAM Simulation

A model for SDRAM mt48lc16m16a2 is included in JTFRAME. The model will load the contents of the file **sdram.hex** if available at the beginning of simulation.

The current contents of the SDRAM can be dumped at the beginning of each frame (falling edge of vertical blank) if **JTFRAME_SAVESDRAM** is defined. Because this is quite an overhead, it is possible to restrict it to dump only a certain **DUMP_START** frame count has been reached. All frames will be dumped after it. The macro **DUMP_START** is the same one used for setting the start of signal dump to the __VCD__ file.

To simulate the SDRAM load operation use **-load** on sim.sh. The normal download speed 1/270ns=3.7MHz. This is faster than the real systems but speeds up simulation. It is possible to slow it down by adding dead clock cycles to each transfer. The macro **JTFRAME_SIM_LOAD_EXTRA** can be defined with the required number of extra cycles. 

#Game clocks
Games are expected to operate on a 48MHz clock using clock enable signals. There is an optional 6MHz that can be enabled with the macro **JTFRAME_CLK6**. This clock goes in the game module through a _clk6_ port which is only connected to when that macro is defined. _jtbtiger_ is an example of game using this feature.

optional clock input | Macro Needed
---------------------|--------------
clk6                 | JTFRAME_CLK6
clk24                | JTFRAME_CLK24
clk48                | JTFRAME_CLK96

Note that although clk6 and clk24 are obtained without affecting the main clock input, if **JTFRAME_CLK96** is defined, the main clock input moves up from 48MHz to 96MHz. The 48MHz clock can the be obtained from clk48.

By default unless **JTFRAME_MR_FASTIO** is already defined, **JTFRAME_CLK96** will define it to 1. This enables fast ROM download in MiSTer using 16-bit mode in _hps_io_.

#Aspect Ratio
In MiSTer the aspect ratio through the scaler can be controlled via the core. By default it is possible to switch between 16:9 and 4:3. However, if the game AR is different, the following macros can be used to redefine it:

Macro       |  Default    |   Meaning        
------------|-------------|----------------------
JTFRAME_ARX |     4       | horizontal magnitude
JTFRAME_ARY |     3       | vertical   magnitude

Internally each value is converted to an eight bit signal.

#Debug Features

If JTFRAME_RELEASE is not defined, some extra features within JTFRAME will operate.

##GFX Enable Signals

In debug mode keys F7-F10 will switch the *gfx_en[3:0]* signal. This can be used internally by the core for debugging. The original intent was to get each bit enable/disable a given GFX layer, hence the name.

#Modules with simulation files added automatically
Define and export the following environgment variables to have these
modules added to your simulation when using sim.sh

YM2203
YM2149
YM2151
MSM5205
M6801
M6809
I8051

#Credits Screen
Credits can be displayed using the module *jtframe_credits*. This module needs the following files

File           | Tool      | Function
---------------|-----------|--------------
msg.hex        | msg2hex   | text shown
avatar.hex     | avatar.py | avatar images. 4bpp indexed
avatar_pal.hex | avatar.py | avatar paletters
lut.hex        | lut2hex   | avatar tiles location in 8-pixel multiples

avatar.py needs a .png image that complies with:

1. x-y sizes are multiples of 8
2. Maximum 16 colours in the image
3. Alpha channel present in the PNG

#Compilation

jtcore is the script used to compile the cores.

## JTAG Programming

jtcore can also program the FPGA (MiST or MiSTer) with the ```-p``` option. In order to use an USB Blaster cable in Ubuntu you need to setup two urules files. The script **jtblaster** does that for you.