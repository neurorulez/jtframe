#!/bin/bash

function zero_file {
    rm -f $1
    cnt=$2
    while [ $cnt != 0 ]; do
        echo -e "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0" >> $1
        cnt=$((cnt-16))
    done;
}

if [ ! -e zeros1k.bin ]; then
    dd if=/dev/zero of=zeros1k.bin count=2
fi

if [ ! -e zeros512.bin ]; then
    dd if=/dev/zero of=zeros512.bin count=1
fi

DUMP=
CHR_DUMP=NOCHR_DUMP
RAM_INFO=NORAM_INFO
FIRMWARE=gng_test.s
VGACONV=NOVGACONV
LOADROM=
FIRMONLY=NOFIRMONLY
MAXFRAME=
SIM_MS=1
SIMULATOR=iverilog
TOP=game_test
MIST=
MIST_PLL=fast_pll.f
MACROPREFIX=-D
EXTRA=
ARGNUMBER=1
MEM_CHECK_TIME=140_000_000

rm -f test2.bin

function add_dir {
    for i in $(cat $1/$2); do
        fn="$1/$i"
        if [ ! -e "$fn" ]; then
            (>&2 echo "Cannot find file $fn")
            exit 1
        fi
        echo $fn
    done
}

function get_named_arg {
    ARGNAME="$1"
    shift
    while [ $# -gt 0 ]; do
        if [ "$1" = "$ARGNAME" ]; then
            echo $2
            return
        fi
        shift
    done
}

# Which core is this for?
SYSNAME=$(get_named_arg -sysname $*)
MODULES=$(get_named_arg -modules $*)
PERCORE=

if [ "$MODULES" = "" ]; then
    echo "ERROR: Missing required argument -modules"
    exit 1
fi

# switch to NCVerilog if available
if which ncverilog; then
    SIMULATOR=ncverilog
    MACROPREFIX="+define+"
fi

case "$SYSNAME" in
    "")
        echo "ERROR: Needs system name. Use -sysname"
        exit 1;;
    gng)    PERCORE=$(add_dir $MODULES/jt12/hdl jt03.f);;
    1942)   PERCORE=$(add_dir $MODULES/jt12/jt49/hdl jt49.f);;
    popeye) PERCORE=$(add_dir $MODULES/jt49/hdl jt49.f)
            EXTRA="$EXTRA ${MACROPREFIX}NOGNGCEN"
            EXTRA="$EXTRA ${MACROPREFIX}GAME_ROM_PATH=\"../../rom/jtpopeye.rom\""
            ;;
    1943)   PERCORE=$(add_dir $MODULES/jt12/hdl jt03.f);
            MEM_CHECK_TIME=250_000_000;;
esac


while [ $# -gt 0 ]; do
case "$1" in
    "-sysname") shift;; # ignore here
    "-modules") shift;; # ignore here
    "-w" | "-deep")
        DUMP=${MACROPREFIX}DUMP
        echo Signal dump enabled
        if [ $1 = "-deep" ]; then DUMP="$DUMP ${MACROPREFIX}DEEPDUMP"; fi
        ;;
    "-d")
        shift
        EXTRA="$EXTRA ${MACROPREFIX}$1"
        ;;
    "-frame")
        shift
        if [ "$1" = "" ]; then
            echo "Must specify number of frames to simulate"
            exit 1
        fi
        MAXFRAME="${MACROPREFIX}MAXFRAME=$1"
        echo Simulate up to $1 frames
        ;;
    "-mist")
        TOP=mist_test
        if [ $SIMULATOR == iverilog ]; then
            MIST=$(add_dir $MODULES/jtframe/hdl/mist/mist mist_iverilog.f)
        else
            MIST="-F $MODULES/jtframe/hdl/mist/mist.f"
        fi
        MIST="$MODULES/jtframe/hdl/mist/mist_test.v ../../hdl/jt${SYSNAME}_mist.v $MIST mist_dump.v"
        # Add a local copy of mist_dump if it doesn't exist
        if [ ! -e mist_dump.v ]; then
            cp $MODULES/jtframe/hdl/ver/mist_dump.v .
            git add -v mist_dump.v
        fi
        ;;
    "-slowpll")
        echo "INFO: Simulation will use the slow PLL model"
        MIST_PLL=altera_pll.f
        ;;
    "-nosnd")
        EXTRA="$EXTRA ${MACROPREFIX}NOSOUND";;
    "-nocolmix")
        EXTRA="$EXTRA ${MACROPREFIX}NOCOLMIX";;
    "-noscr")
        EXTRA="$EXTRA ${MACROPREFIX}NOSCR";;
    "-nochar")
        EXTRA="$EXTRA ${MACROPREFIX}NOCHAR";;
    "-time")
        shift
        if [ "$1" = "" ]; then
            echo "Must specify number of milliseconds to simulate"
            exit 1
        fi
        SIM_MS="$1"
        echo Simulate $1 ms
        ;;
    "-firmonly")
        FIRMONLY=FIRMONLY
        echo Firmware dump only
        ;;
    "-t")
        # is there a file name?
        if [[ "${2:0:1}" != "-" && $# -gt 1  ]]; then
            shift
            FIRMWARE=$1
        else
            FIRMWARE=bank_check.s
        fi
        echo "Using test firmware $FIRMWARE"
        LOADROM="${MACROPREFIX}TESTROM ${MACROPREFIX}FIRMWARE_SIM"
        if ! z80asm $FIRMWARE -o test.bin -l; then
            exit 1
        fi
        ;;
    "-t2")
        # is there a file name?
        if [[ "${2:0:1}" != "-" && $# -gt 1  ]]; then
            shift
            FIRMWARE2=$1
        else
            FIRMWARE2=bank_check.s
        fi
        echo "Using test firmware $FIRMWARE2 for second CPU"
        LOADROM=${MACROPREFIX}TESTROM
        if ! z80asm $FIRMWARE2 -o test2.bin -l; then
            exit 1
        fi
        ;;
    "-info")
        RAM_INFO=RAM_INFO
        echo RAM information enabled
        ;;
    "-video")
        EXTRA="$EXTRA ${MACROPREFIX}DUMP_VIDEO"
        echo Video dump enabled
        rm -f video.bin
        rm -f *png
        VIDEO_DUMP=TRUE
        ;;
    "-load")
        LOADROM=${MACROPREFIX}LOADROM
        echo ROM load through SPI enabled
        if [ ! -e ../../../rom/JT1942.rom ]; then
            echo "Missing file JT1942.rom in rom folder"
            echo "Run 1942rom.py in rom folder to generate it."
            exit 1
        fi
        ;;
    "-lint")
        SIMULATOR=verilator;;
    "-nc")
        SIMULATOR=ncverilog
        MACROPREFIX="+define+"
        if [ $ARGNUMBER != 1 ]; then
            echo "ERROR: -nc must be the first argument so macros get defined correctly"
            exit 1
        fi
        ;;
    "-help")
        cat << EOF
JT_GNG simulation tool. (c) Jose Tejada 2019, @topapate
    -sysname  Specify the name of the core
    -modules  Location of the modules folder with respect to the simulation folder
    -mist     Use MiST setup for simulation, instead of using directly the
              game module. This is slower but more informative.
    -video    Enable video output
    -lint     Run verilator as lint tool
    -nc       Select NCVerilog as the simulator
    -load     Load the ROM file using the SPI communication. Slower.
    -t        Compile and load test file for main CPU. It can be used with the
              name of an assembly language file.
    -t2       Same as -t but for the sound CPU
    -nochar   Disable CHAR hardware. Faster simulation.
    -noscr    Disable SCROLL hardware. Faster simulation.
    -nosnd    Disable SOUND hardware. Speeds up simulation a lot!
    -w        Save a small set of signals for scope verification
    -deep     Save all signals for scope verification
    -frame    Number of frames to simulate
    -time     Number of milliseconds to simulate
    -slowpll  Simulate using Altera's model for PLLs
    -d        Add specific Verilog macros for the simulation. Common options
        VIDEO_START=X   video output will start on frame X
        TESTSCR1        disable scroll control by the CPU and scroll the
                        background automatically. It can be used together with
                        NOMAIN macro
        SDRAM_DELAY=X   ns delay for SDRAM_CLK (cannot use with -slowpll)
        BASE_CLK=X      Base period for game clock (cannot use with -slowpll)
EOF
        exit 0
        ;;
    *) echo "Unknown option $1. Use -help to see the list of options"; exit 1;;
esac
    shift
    ARGNUMBER=$((ARGNUMBER+1))
done

if [ $FIRMONLY = FIRMONLY ]; then exit 0; fi

# HEX files with initial contents for some of the RAMs
function clear_hex_file {
    cnt=0
    rm -f $1.hex
    while [ $cnt -lt $2 ]; do
        echo 0 >> $1.hex
        cnt=$((cnt+1))
    done
}

clear_hex_file obj_buf  128

if [ "$EXTRA" != "" ]; then
    echo Verilog macros: "$EXTRA"
fi

EXTRA="$EXTRA ${MACROPREFIX}MEM_CHECK_TIME=$MEM_CHECK_TIME ${MACROPREFIX}SYSTOP=jt${SYSNAME}_mist"

# Add the PLL
if [[ $SIMULATOR == iverilog && $TOP == mist_test ]]; then
    MIST="$MIST $(add_dir $MODULES/jtframe/hdl/mist/mist $MIST_PLL)"
else
    MIST="$MIST -F $MODULES/jtframe/hdl/mist/$MIST_PLL"
fi

case $SIMULATOR in
iverilog)
    iverilog -g2005-sv $MIST \
        -f game.f $PERCORE \
        $(add_dir $MODULES/jtframe/hdl/ver/sim.f ) \
        $MODULES/tv80/*.v  \
        -s $TOP -o sim -DSIM_MS=$SIM_MS -DSIMULATION \
        $DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM \
        $MAXFRAME -DIVERILOG $EXTRA \
    && sim -lxt;;
ncverilog)
    ncverilog +access+r +nc64bit +define+NCVERILOG \
        -f game.f $PERCORE \
        -F $MODULES/jtframe/hdl/ver/sim.f -disable_sem2009 $MIST \
        +define+SIM_MS=$SIM_MS +define+SIMULATION \
        $DUMP $LOADROM \
        $MAXFRAME \
        -ncvhdl_args,-V93 $MODULES/t80/T80{pa,_ALU,_Reg,_MCode,"",s}.vhd \
        $MODULES/tv80/*.v \
        $MIST $EXTRA;;
verilator)
    verilator -I../../hdl \
        -f game.f $PERCORE \
        $MODULES/tv80/*.v \
        $MODULES/ver/quick_sdram.v \
        --top-module jt${SYSNAME}_game -o sim \
        $DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM -DFASTSDRAM \
        -DVERILATOR_LINT \
        $MAXFRAME -DSIM_MS=$SIM_MS --lint-only $EXTRA;;
esac

if [ "$VIDEO_DUMP" = TRUE ]; then
    ../../../bin/bin2png.py
fi