#!/bin/bash

############################################
# File Name : make_rescue_initrd.sh
# Purpose : create an initrd containing a 
# full Debian installation 
# Creation Date : 01-06-2011
# Last Modified : jeu. 03 juin 2011 14:22:30 CEST
# Created By : Hyacinthe Cartiaux
############################################

set -x

HOSTNAME=rescue
PASSWORD=******

# latest static busybox x86_64
 URL_BUSYBOX=http://www.busybox.net/downloads/binaries/1.18.4/busybox-x86_64
# MD5SUM of URL_BUSYBOX
 MD5SUM=338914af0cd008a6766d45293043e6f6

# latest static busybox i486
# URL_BUSYBOX=http://www.busybox.net/downloads/binaries/1.18.4/busybox-i486
# MD5SUM of URL_BUSYBOX
# MD5SUM=5f9bfcf7d7863515aba34ee72d699410

# Debootstrap
 ARCH=amd64
 PKG_ARCH=amd64

# ARCH=i386
# PKG_ARCH=486

SUITE=squeeze

# MIRROR=http://ftp.fr.debian.org/debian
# MIRROR=http://localhost:3142/debian
MIRROR=http://penny.local.easy-hebergement.net:3142/debian

WORK_DIR=/tmp/rescue_initrd_${ARCH} # /!\ Will be deleted
DEBOOTSTRAP_DIR=${WORK_DIR}/root_${SUITE}_${ARCH}
# DEBOOTSTRAP_DIR=/root/debootstrap_${SUITE}_${ARCH} # /!\ Deleted in case of failure
INSTALL_DIR=$(dirname `cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}"`)

PKG=linux-image-${PKG_ARCH},openssh-server,locales

############ WORKDIR

rm -r ${WORK_DIR}
mkdir -p ${WORK_DIR}/nest/bin

########### BUSYBOX DOWNLOAD

wget -c ${URL_BUSYBOX} -O ${WORK_DIR}/busybox -o /dev/null
if [ $MD5SUM != "`md5sum ${WORK_DIR}/busybox | awk '{print $1}'`" ]
then
  echo Busybox : corrupted file
  exit
fi

########### DEBOOTSTRAP / rootfs.cgz

debootstrap --include=${PKG} --arch=${ARCH} ${SUITE} ${DEBOOTSTRAP_DIR} ${MIRROR}

if [ $? -ne 0 ]
then
  rm -rf ${DEBOOTSTRAP_DIR}
  exit
fi

# Config

echo ${HOSTNAME} > ${DEBOOTSTRAP_DIR}/etc/hostname
chroot ${DEBOOTSTRAP_DIR} chpasswd << EOF
root:${PASSWORD}
EOF
echo proc /proc proc defaults 0 0 > "${DEBOOTSTRAP_DIR}/etc/fstab"

echo en_US.UTF-8 UTF-8 > ${DEBOOTSTRAP_DIR}/etc/locale.gen
chroot ${DEBOOTSTRAP_DIR} locale-gen

echo Europe/Paris > /${DEBOOTSTRAP_DIR}/etc/timezone
chroot ${DEBOOTSTRAP_DIR} dpkg-reconfigure -f noninteractive tzdata

# Network

echo auto lo eth0 eth1       > ${DEBOOTSTRAP_DIR}/etc/network/interfaces
echo allow-hotplug eth0     >> ${DEBOOTSTRAP_DIR}/etc/network/interfaces
echo allow-hotplug eth1     >> ${DEBOOTSTRAP_DIR}/etc/network/interfaces
echo iface lo inet loopback >> ${DEBOOTSTRAP_DIR}/etc/network/interfaces
echo iface eth0 inet dhcp   >> ${DEBOOTSTRAP_DIR}/etc/network/interfaces
echo iface eth1 inet dhcp   >> ${DEBOOTSTRAP_DIR}/etc/network/interfaces

# Clean

find ${DEBOOTSTRAP_DIR}/usr/share/locale -maxdepth 1 -mindepth 1 -type d ! -iname 'en*' -execdir rm -rf '{}' \+
rm ${DEBOOTSTRAP_DIR}/var/cache/apt/*.bin
rm -rf ${DEBOOTSTRAP_DIR}/var/lib/apt/lists/*
mkdir ${DEBOOTSTRAP_DIR}/var/lib/apt/lists/partial

# Rootfs

(cd "${DEBOOTSTRAP_DIR}"; find . | cpio -o -H newc | gzip) > "${WORK_DIR}/nest/rootfs.cgz"

########## NEST / EARLY BOOT

install -m 755 ${INSTALL_DIR}/init ${WORK_DIR}/nest/init

for cmd in `echo echo awk busybox cpio free grep gunzip ls mkdir mount rm sh switch_root umount` ; do
  ln ${WORK_DIR}/busybox ${WORK_DIR}/nest/bin/$cmd
  chmod -R +x ${WORK_DIR}/nest/bin
done

######### FINAL INITRD

(cd "${WORK_DIR}/nest"; find . | cpio -o -H newc | gzip) > "${WORK_DIR}/initrd.cgz"

echo "------ OK ------"
echo "initrd file : ${WORK_DIR}/initrd.cgz"

kernel=$(ls -la ${DEBOOTSTRAP_DIR}/boot/vmlinuz-* | grep -o -e '/.*$')
echo "kernel file : ${kernel}"

