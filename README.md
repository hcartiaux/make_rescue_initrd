# make_rescue_initrd

The aim of this script is to generate a *rescue linux system*, bootable via PXE, which allow the user to recover a machine without physical access (thanks to DHCP and SSH).

`make_rescue_initrd.sh` generates an [initrd file](https://www.kernel.org/doc/Documentation/filesystems/ramfs-rootfs-initramfs.txt), containing a full Debian system, and make use of busybox and debootstrap (which should be installed on your system).
The `init` script is strongly inspired by the one provided by [debirf](http://cmrg.fifthhorseman.net/wiki/debirf).
