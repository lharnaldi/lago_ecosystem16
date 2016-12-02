# lago\_ecosystem

## What is LAGO Ecosystem?

Lago Ecosystem is a build system for quick prototyping and working with the Zynq SoCs.

## Quickstart with the [Red Pitaya](http://redpitaya.com)

### 1. Requirements for Ubuntu 16.04

#### 1.1. Download [`Vivado HLx 2016.3: All OS Installer Single-File Download`](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2016-3.html).

#### 1.2 Run

```bash
$ sudo apt-get install curl
$ cd ~/Downloads
$ curl https://raw.githubusercontent.com/lagoprojectrp/lago_ecosystem/master/scripts/install_vivado.sh | sudo /bin/bash /dev/stdin
$ sudo ln -s make /usr/bin/gmake # tells Vivado to use make instead of gmake
```

#### 1.3. Install requirements

```bash
$ sudo apt-get update

$ sudo apt-get --no-install-recommends install \
    build-essential git curl ca-certificates sudo \
    libxrender1 libxtst6 libxi6 lib32ncurses5 \
    crossbuild-essential-armhf \
    bc u-boot-tools device-tree-compiler libncurses5-dev \
    libssl-dev qemu-user-static binfmt-support \
    dosfstools parted debootstrap

$ git clone https://github.com/lagoprojectrp/lago_ecosystem
$ cd lago_ecosystem
$ sudo pip install -r requirements.txt
```

### 2. Install LAGO Linux for Red Pitaya ([Download SD card image](https://github.com/lagoprojectrp/lago_ecosystem/releases))

### 3. Build and run the minimal instrument

```bash
$ source settings.sh
$ make NAME=led_blinker
```

