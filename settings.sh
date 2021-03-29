export LC_CTYPE="en_US.UTF-8" 
export LC_NUMERIC="en_US.UTF-8"

export LC_TIME="en_US.UTF-8" 
export LC_COLLATE="en_US.UTF-8" 
export LC_MONETARY="en_US.UTF-8" 
export LC_MESSAGES="en_US.UTF-8" 
export LC_PAPER="en_US.UTF-8" 
export LC_NAME="en_US.UTF-8" 
export LC_ADDRESS="en_US.UTF-8" 
export LC_TELEPHONE="en_US.UTF-8" 
export LC_MEASUREMENT="en_US.UTF-8" 
export LC_IDENTIFICATION="en_US.UTF-8" 
export LC_ALL="en_US.UTF-8"
################################################################################
# setup Xilinx Vivado FPGA tools
################################################################################

. /tools/Xilinx/SDK/2018.3/settings64.sh
#. /tools/Xilinx/Vivado/2018.3/settings64.sh
#. /tools/Xilinx/Vivado/2019.2/settings64.sh

################################################################################
# setup cross compiler toolchain
################################################################################

export CROSS_COMPILE=arm-linux-gnueabihf-

################################################################################
# setup download cache directory, to avoid downloads
################################################################################

#export DL=dl

################################################################################
# common make procedure, should not be run by this script
################################################################################

#GIT_COMMIT_SHORT=`git rev-parse --short HEAD`
#make REVISION=$GIT_COMMIT_SHORT
