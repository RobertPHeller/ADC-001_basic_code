#
# Run:
#  $ make
# to build all the example programs.
#

#----------------------------------------------------
# ARM code
CC := gcc
CXX := g++
XENOCFLAGS = `/usr/xenomai/bin/xeno-config --cobalt --cflags`
CFLAGS := $(XENOCFLAGS) -O3 -mfpu=vfpv3 -mfloat-abi=hard -march=armv7 -I./include
CXXFLAGS := $(XENOCFLAGS) -O3 -mfpu=vfpv3 -mfloat-abi=hard -march=armv7 -I./include
# LDFLAGS := -lprussdrv
#LDFLAGS := -lrt -lpthread
LDFLAGS := `/usr/xenomai/bin/xeno-config --cobalt --ldflags`

SRCS := main.c prussdrv.c adcdriver_host.c spidriver_host.c ADC_Stream.cc
OBJS := main.o prussdrv.o adcdriver_host.o spidriver_host.o
OBJS1 = mainstream1.o prussdrv.o adcdriver_host.o spidriver_host.o ADC_Stream.o
OBJS2 = mainstream2.o prussdrv.o adcdriver_host.o spidriver_host.o ADC_Stream.o
EXES := main mainstream1 mainstream2
INCLUDEDIR := ./include
INCLUDES := $(addprefix $(INCLUDEDIR)/, prussdrv.h pru_types.h __prussdrv.h pruss_intc_mapping.h spidriver_host.h adcdriver_host.h ADC_Stream.h)

#----------------------------------------------------
# PRU code
DEVICE=am335x
PRU_CC := clpru
PRU_CC_FLAGS := --silicon_version=3 -I./include -I/usr/share/ti/cgt-pru/include/ -D$(DEVICE) -i/usr/share/ti/cgt-pru/lib
PRU_LINKER_SCRIPT := AM335x_PRU.cmd
PRU_INCLUDES := resource_table_empty.h pru_ctrl.h pru_intc.h pru_cfg.h pru_spi.h

# PRU0 is the SPI stuff.
PRU0_SRCS := pru0.c pru_spi.c
PRU0_OBJS := pru0.obj pru_spi.obj
PRU0_MAP := pru0.map
PRU0_EXES := data0.bin text0.bin

# PRU1 is the oscillator
PRU1_SRCS := pru1.c
PRU1_OBJS := pru1.obj
PRU1_MAP := pru1.map
PRU1_EXES := data1.bin text1.bin

PRU_HEXPRU_SCRIPT := bin.cmd

#=================================================
all: $(EXES) pru0.bin pru1.bin ADC_001-00A0.dtbo

bins: $(EXES) pru0.bin

#--------------------------------
# Compile ARM sources for host.
main.o: main.c include/spidriver_host.h include/adcdriver_host.h
	echo "--> Building main.o"
	$(CC) $(CFLAGS) -E -MM  -c $< -MF $<.d
	$(CC) $(CFLAGS) -c $< -o $@

mainstream1.o: mainstream1.cc include/ADC_Stream.h \
	include/spidriver_host.h include/adcdriver_host.h
	echo "--> Building mainstream1.o"
	$(CXX) $(CXXFLAGS) -E -MM  -c $< -MF $<.d
	$(CXX) $(CXXFLAGS) -c $< -o $@
	
mainstream2.o: mainstream2.cc include/ADC_Stream.h \
	include/spidriver_host.h include/adcdriver_host.h
	echo "--> Building mainstream2.o"
	$(CXX) $(CXXFLAGS) -E -MM  -c $< -MF $<.d
	$(CXX) $(CXXFLAGS) -c $< -o $@
	

adcdriver_host.o: adcdriver_host.c ./include/adcdriver_host.h
	echo "--> Building adcdriver_host.o"
	$(CC) $(CFLAGS) -E -MM  -c $< -MF $<.d
	$(CC) $(CFLAGS) -c $< -o $@

spidriver_host.o: spidriver_host.c ./include/spidriver_host.h
	echo "--> Building spidriver_host.o"
	$(CC) $(CFLAGS) -E -MM  -c $< -MF $<.d
	$(CC) $(CFLAGS) -c $< -o $@

prussdrv.o: prussdrv.c # $(DEPS)
	echo "--> Building prussdrv.o"
	$(CC) $(CFLAGS) -E -MM  -c $< -MF $<.d
	$(CC) $(CFLAGS) -c $< -o $@

ADC_Stream.o: ADC_Stream.cc ./include/ADC_Stream.h \
		./include/adcdriver_host.h ./include/spidriver_host.h 
	echo "--> Building ADC_Stream.o"
	$(CXX) $(CXXFLAGS) -E -MM  -c $< -MF $<.d
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Link the ARM objects
main: $(OBJS) 
	echo "--> Linking main ...."
	$(CC) $(CFLAGS) $^ $(LIBLOCS) $(LDFLAGS) -o $@ 

$(OBJS): $(INCLUDES)

mainstream1: $(OBJS1)
	echo "--> Linking mainstream1 ...."
	$(CXX) $(CXXFLAGS) $^ $(LIBLOCS) $(LDFLAGS) -o $@

mainstream2: $(OBJS2)
	echo "--> Linking mainstream2 ...."
	$(CXX) $(CXXFLAGS) $^ $(LIBLOCS) $(LDFLAGS) -o $@

#--------------------------------
# Compile and link the PRU sources to create ELF executable
pru0.out: pru0.c pru_spi.c
	echo "--> Building and linking PRU0 stuff..."
	$(PRU_CC) $^ $(PRU_CC_FLAGS) -z $(PRU_LINKER_SCRIPT) -o $@ -m $(PRU0_MAP)

# Build PRU .bin file from ELF
pru0.bin: pru0.out $(PRU_HEXPRU_SCRIPT)
	echo "--> Running hexpru for PRU0..."
	hexpru $(PRU_HEXPRU_SCRIPT) $<
	-mv text.bin text0.bin
	-mv data.bin data0.bin

pru1.out: pru1.c
	echo "--> Building and linking PRU1 stuff..."
	$(PRU_CC) $^ $(PRU_CC_FLAGS) -z $(PRU_LINKER_SCRIPT) -o $@ -m $(PRU1_MAP)
        
# Build PRU .bin file from ELF
pru1.bin: pru1.out $(PRU_HEXPRU_SCRIPT)
	echo "--> Running hexpru for PRU1..."
	hexpru $(PRU_HEXPRU_SCRIPT) $<
	-mv text.bin text1.bin
	-mv data.bin data1.bin

#--------------------------------
# Build and install device tree overlay
ADC_001-00A0.dtbo: ADC_001.dts
	dtc -O dtb -o ADC_001-00A0.dtbo -b 0 -@ ADC_001.dts
	sudo cp ADC_001-00A0.dtbo /lib/firmware

#-------------------------------
# Clean up directory -- remove executables and intermediate files.
clean:
	-rm -f *.o *.obj *.out *.map $(EXES) $(OBJS) \
	 $(PRU0_OBJS) $(PRU0_EXES) $(PRU1_OBJS) $(PRU1_EXES) *~ *.dtbo



