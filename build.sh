#!/bin/bash

# A script to build a minimal linux

# START Changable variables

export SRC="$PWD"/src
export INITRD=$PWD/initrd
export LOG="$PWD"/log
export INS="$PWD"/INSTALL
export OUT="$PWD"/out
export ROOT="$PWD"/root
export MNT="$PWD"/mnt
export EPKG="$PWD"/extra-packages
export EXTRA="$PWD"/ext
export AUTO

export PKGL="$PWD"/packages.txt

if [ -z "${GRUB_DIR}" ]; then
    GRUB_DIR=$(dirname $(which grub-mkrescue))
    export GRUB_DIR
fi

export OS_NAME=LINUXOS
export OS_VERSION=1.0.2

LINUX_VERSION=5.15.9
LINUX_MAJOR_VERSION=5.x

BUSYBOX_VERSION=1.34.1

BASH_VERSION=5.1.8

GLIBC_VERSION=2.34

# END Changeable variables

# Warning: changing this will break the build system

HOST=$(echo ${MACHTYPE} | sed "s/-[^-]*/-cross/")
TARGET=x86_64-unknown-linux-gnu
CPU=k8
ARCH=x86_64

export HOST TARGET CPU ARCH

# END Warning

echo "Warning: This script can only build linux for the current machine's architecture"
if [ $AUTO -eq 1 ]; then
    echo ""
    sleep 10
else
    echo "Press enter to continue or ctrl+c to exit"
    echo ""
    read -r
fi

if [ $AUTO -eq 1 ]; then
    echo "Welcome to the MINLINUX build system"
    echo "This script will build a minimal linux"
    echo "Please be patient, it may take a while"
    sleep 10
else
    echo "Welcome to the MINLINUX build system"
    echo "This script will build a minimal linux"
    echo "Please be patient, it may take a while"
    echo "press enter to continue or ctrl+c to exit"
    read -r
fi

mkdir -p "$SRC" "$INITRD" "$LOG" "$OUT" "$INS" "$ROOT" "$MNT" "$EPKG" "$INS"/patch
mkdir -p "$INITRD"/{bin,dev,etc,lib,lib64,mnt,home,proc,root,run,sbin,sys,tmp,usr,var,srv,opt}
mkdir -p "$INITRD"/usr/{bin,include,lib,lib64,sbin,src,share,src,opt}

cd "$SRC" || exit

# LINUX HEADERS

if ls "$SRC"/linux-"$LINUX_VERSION".tar.xz 1> /dev/null 2>&1; then
    echo "Linux source already downloaded"
else
    echo "Downloading Linux source"
    wget https://mirrors.edge.kernel.org/pub/linux/kernel/v"$LINUX_MAJOR_VERSION"/linux-"$LINUX_VERSION".tar.xz
fi

if ls "$SRC"/linux-"$LINUX_VERSION" 1> /dev/null 2>&1; then
    echo "Linux source already extracted"
else
    echo "Extracting Linux source"
    tar -xJf linux-"$LINUX_VERSION".tar.xz
fi

if ls "$INS"/LINUX_HEADERS 1> /dev/null 2>&1; then
    echo "Linux headers already installed"
else
    echo "Installing Linux headers"
    cd "$SRC"/linux-"$LINUX_VERSION" || exit
    make ARCH=${ARCH} headers_check && \
    make ARCH=${ARCH} INSTALL_HDR_PATH=dest headers_install || exit  | tee /"$LOG"/linux_header.log
    touch "$INS"/LINUX_HEADERS
    cp -rv dest/include/* ${INITRD}/usr/include
    cd ..
fi

# Linux Kernel

if ls "$INS"/LINUX_KERNEL 1> /dev/null 2>&1; then
    echo "Linux source already installed"
else
    echo "Installing Linux source"
    cd "$SRC"/linux-"$LINUX_VERSION" || exit
    if [ $AUTO -eq 1 ]; then
    make defconfig
    else
    echo "Do you want to use the default configuration? (y/n)"
    read -r
    if [ "$REPLY" = "y" ]; then
        make defconfig
    else
        make menuconfig
    fi
    fi
    make -j8 || echo "error building linux kernel" && exit 1 | tee /"$LOG"/linux.log
    touch "$INS"/LINUX_KERNEL
    cp -rv "$INITRD"/usr/include/* "$INITRD"/usr/include/linux
    rm -rf "$INITRD"/usr/include
    cd ../
fi

#GLIBC

if ls "$SRC"/glibc-"$GLIBC_VERSION".tar.xz 1> /dev/null 2>&1; then
    echo "GLIBC source already downloaded"
else
    echo "Downloading GLIBC source"
    wget https://ftp.gnu.org/gnu/glibc/glibc-"$GLIBC_VERSION".tar.xz
fi

if ls "$SRC"/glibc-"$GLIBC_VERSION" 1> /dev/null 2>&1; then
    echo "GLIBC source already extracted"
else
    echo "Extracting GLIBC source"
    tar -xJf glibc-"$GLIBC_VERSION".tar.xz
fi


if ls "$INS"/GLIBC 1> /dev/null 2>&1; then
    echo "GLIBC already compiled"
else
    cd glibc-"$GLIBC_VERSION" || exit
    mkdir -pv glibc-build
    cd glibc-build || exit
    echo "libc_cv_forced_unwind=yes" > config.cache
    echo "libc_cv_c_cleanup=yes" >> config.cache
    echo "libc_cv_ssp=no" >> config.cache
    echo "libc_cv_ssp_strong=no" >> config.cache
    ../configure \
    --host=${TARGET} --build=${HOST} \
    --disable-profile --enable-add-ons --with-tls \
    --enable-kernel=2.6.32 --with-__thread \
    --without-selinux \
    --with-headers=${INITRD}/usr/include \
    --cache-file=config.cache
    make V=1 && \ | tee ${LOG}/GLIBC.log || exit 2
    make V=1 install_root=${INITRD}/ install | tee ${LOG}/GLIBC.log || exit 2
    touch "$INS"/GLIBC
    echo "GLIBC installed"
    cd ../..
fi

#Busybox

if ls "$SRC"/busybox-"$BUSYBOX_VERSION".tar.bz2 1> /dev/null 2>&1; then
    echo "Busybox source already downloaded"
else
    echo "Downloading Busybox source"
    wget https://busybox.net/downloads/busybox-"$BUSYBOX_VERSION".tar.bz2 
fi

if ls "$SRC"/busybox-"$BUSYBOX_VERSION" 1> /dev/null 2>&1; then
    echo "Busybox source already extracted"
else
    echo "Extracting Busybox source"
    tar -xjf busybox-"$BUSYBOX_VERSION".tar.bz2
fi

cd busybox-"$BUSYBOX_VERSION" || exit

if ls "$INS"/BUSYBOX 1> /dev/null 2>&1; then
    echo "Busybox source already compiled"
else
    echo "Compiling Busybox"
    if [ $AUTO -eq 1 ]; then
    make defconfig
    else
    echo "Do you want to use the default configuration? (y/n)"
    read -r
    if [ "$REPLY" = "y" ]; then
        make defconfig
    else
        make menuconfig
    fi
    fi
    #sed 's/^.*CONFIG_STATIC[^_].*$/CONFIG_STATIC=y/' -i .config
    make -j8 && \
    make CONFIG_PREFIX="$INITRD" install > /"$LOG"/busybox.log
    touch "$INS"/BUSYBOX
fi

cd ..

# Extra Packages

for PSCRIPT in $(cat ../packages.txt); do
    source $EPKG/$PSCRIPT.pscripts
done

cd ..

cd "$INITRD" || exit

rm etc/passwd
cat > etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
EOF

rm etc/group
cat > etc/group << "EOF"
root:x:0:
bin:x:1:
sys:x:2:
kmem:x:3:
tty:x:4:
daemon:x:6:
disk:x:8:
dialout:x:10:
video:x:12:
utmp:x:13:
usb:x:14:
EOF

rm etc/fstab
cat > etc/fstab << "EOF"
# file system  mount-point  type   options          dump  fsck
#                                                         order

rootfs          /               $AUTO    defaults        1      1
proc            /proc           proc    defaults        0      0
sysfs           /sys            sysfs   defaults        0      0
devpts          /dev/pts        devpts  gid=4,mode=620  0      0
tmpfs           /dev/shm        tmpfs   defaults        0      0
EOF

rm etc/inittab
cat > etc/inittab<< "EOF"
::sysinit:/etc/rc.d/startup

tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

::shutdown:/etc/rc.d/shutdown
::ctrlaltdel:/sbin/reboot
EOF

rm etc/profile
cat > etc/profile << "EOF"
export PATH=/bin:/usr/bin

if [ `id -u` -eq 0 ] ; then
    PATH=/bin:/sbin:/usr/bin:/usr/sbin
    unset HISTFILE
fi


# Set up some environment variables.
export USER=`id -un`
export PS1="\u@\h[\w]{\$?)\\$\[$(tput sgr0)\]"
export LOGNAME=$USER
export HOSTNAME=`/bin/hostname`
export HISTSIZE=1000
export HISTFILESIZE=1000
export PAGER='/bin/more '
export EDITOR='/bin/vi'
EOF

rm etc/issue
echo "$OS_NAME $OS_VERSION" > etc/issue

rm etc/HOSTNAME
echo TESTLinux > etc/HOSTNAME

mkdir -p etc/rc.d/

ln -svf ${INITRD}/proc/mounts ${INITRD}/etc/mtab

mkdir -pv var/{run,log}

touch var/run/utmp var/log/{btmp,lastlog,wtmp}
chmod -v 664 var/run/utmp var/log/lastlog

mkdir -p etc/selinux/

rm etc/selinux/config
cat > etc/selinux/config << "EOF"
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - SELinux is fully disabled.
SELINUX=disabled
EOF

rm -rf etc/ld.so.conf.d
mkdir -p etc/ld.so.conf.d/
rm etc/ld.so.conf
cat > etc/ld.so.conf << "EOF"
# /etc/ld.so.conf

include /etc/ld.so.conf.d/*.conf
EOF

cat > etc/ld.so.conf.d/local.conf << "EOF"
# /etc/ld.so.conf.d/local.conf

/usr/local/lib
/usr/local/lib64
EOF

cat > etc/ld.so.conf.d/default.conf << "EOF"
# /etc/ld.so.conf.d/default.conf

/lib
/lib64
/usr/lib
/usr/lib64
EOF

rm etc/mdev.conf
cat > etc/mdev.conf<< "EOF"
# Devices:
# Syntax: %s %d:%d %s
# devices user:group mode

# null does already exist; therefore ownership has to
# be changed with command
null    root:root 0666  @chmod 666 $MDEV
zero    root:root 0666
grsec   root:root 0660
full    root:root 0666

random  root:root 0666
urandom root:root 0444
hwrandom root:root 0660

# console does already exist; therefore ownership has to
# be changed with command
console root:tty 0600 @mkdir -pm 755 fd && cd fd && for x in 0 1 2 3 ; do ln -sf /proc/self/fd/$x $x; done

kmem    root:root 0640
mem     root:root 0640
port    root:root 0640
ptmx    root:tty 0666

# ram.*
ram([0-9]*)     root:disk 0660 >rd/%1
loop([0-9]+)    root:disk 0660 >loop/%1
sd[a-z].*       root:disk 0660
hd[a-z][0-9]*   root:disk 0660

tty             root:tty 0666
tty[0-9]        root:root 0600
tty[0-9][0-9]   root:tty 0660
ttyO[0-9]*      root:tty 0660
pty.*           root:tty 0660
vcs[0-9]*       root:tty 0660
vcsa[0-9]*      root:tty 0660

ttyLTM[0-9]     root:dialout 0660 @ln -sf $MDEV modem
ttySHSF[0-9]    root:dialout 0660 @ln -sf $MDEV modem
slamr           root:dialout 0660 @ln -sf $MDEV slamr0
slusb           root:dialout 0660 @ln -sf $MDEV slusb0
fuse            root:root  0666

# misc stuff
agpgart         root:root 0660  >misc/
psaux           root:root 0660  >misc/
rtc             root:root 0664  >misc/

# input stuff
event[0-9]+     root:root 0640 =input/
ts[0-9]         root:root 0600 =input/

# v4l stuff
vbi[0-9]        root:video 0660 >v4l/
video[0-9]      root:video 0660 >v4l/

# load drivers for usb devices
usbdev[0-9].[0-9]       root:root 0660 */lib/mdev/usbdev
usbdev[0-9].[0-9]_.*    root:root 0660
EOF

cat > etc/ld.so.conf.d/x86_64-linux-gnu.conf << "EOF"
# /etc/ld.so.conf.d/x86_64-linux-gnu.conf

/lib/x86_64-linux-gnu
/usr/lib/x86_64-linux-gnu
/usr/local/lib/x86_64-linux-gnu
EOF

# Networking

rm etc/network/interfaces
cat > etc/network/interfaces << "EOF"
auto eth0
iface eth0 inet dhcp
EOF

rm etc/network.conf
cat > etc/network.conf << "EOF"
# /etc/network.conf
# Global Networking Configuration
# interface configuration is in /etc/network.d/

INTERFACE="eth0"

# set to yes to enable networking
NETWORKING=yes

# set to yes to set default route to gateway
USE_GATEWAY=no

# set to gateway IP address
GATEWAY=10.0.2.2
EOF

mkdir -pv etc/network/if-{post-{up,down},pre-{up,down},up,down}.d
mkdir -pv usr/share/udhcpc

rm usr/share/udhcpc/default.script
cat > usr/share/udhcpc/default.script << "EOF"
#!/bin/sh
# udhcpc Interface Configuration
# Based on http://lists.debian.org/debian-boot/2002/11/msg00500.html
# udhcpc script edited by Tim Riker <Tim@Rikers.org>

[ -z "$1" ] && echo "Error: should be called from udhcpc" && exit 1

RESOLV_CONF="/etc/resolv.conf"
[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

case "$1" in
    deconfig)
            /sbin/ifconfig $interface 0.0.0.0
            ;;

    renew|bound)
            /sbin/ifconfig $interface $ip $BROADCAST $NETMASK

            if [ -n "$router" ] ; then
                    while route del default gw 0.0.0.0 dev $interface ; do
                            true
                    done

                    for i in $router ; do
                            route add default gw $i dev $interface
                    done
            fi

            echo -n > $RESOLV_CONF
            [ -n "$domain" ] && echo search $domain >> $RESOLV_CONF
            for i in $dns ; do
                    echo nameserver $i >> $RESOLV_CONF
            done
            ;;
esac

exit 0
EOF

chmod +x usr/share/udhcpc/default.script

sudo chroot $INITRD /bin/sh -c "ldconfig"
if [ $AUTO -eq 1 ]; then
    echo
    sudo chroot $INITRD passwd << "EOF"
root
root

EOF
else
    echo "Do you want to make a new root password?"
    echo -n "(y/n) "
    read -r ANSWER

    if [ "$ANSWER" = "y" ]; then
        sudo chroot $INITRD passwd
    else
        sudo chroot $INITRD passwd << "EOF"
root
root

EOF
    fi
fi

FILES="$(ls ${INITRD}/usr/lib64/*.a)"
for file in $FILES; do
    rm -f $file
done

find ${INITRD}/{,usr/}{bin,lib,sbin} -type f -exec sudo strip --strip-debug '{}' ';' > /dev/null 2>&1
find ${INITRD}/{,usr/}lib64 -type f -exec sudo strip --strip-debug '{}' ';' > /dev/null 2>&1

sudo chmod -R 777 .
cp "$SRC"/linux-"$LINUX_VERSION"/arch/x86/boot/bzImage "$OUT"/bzImage-"$LINUX_VERSION"-generic

if [ $AUTO -eq 1 ]; then
    mkdir -p "$ROOT"/boot/grub
    rm "$ROOT"/boot/grub/grub.cfg
    cat > "$ROOT"/boot/grub/grub.cfg << "EOF"
set default=0
set timeout=5
EOF
    printf "menuentry '%s_CDROM' {\n" $OS_NAME >> "$ROOT"/boot/grub/grub.cfg
    printf "set root=(cd)\n" >> "$ROOT"/boot/grub/grub.cfg
    printf "linux /boot/bzImage-%s-generic root=/dev/sr0 ro" $LINUX_VERSION >> "$ROOT"/boot/grub/grub.cfg
    printf "\n}\n\n" >> "$ROOT"/boot/grub/grub.cfg
    printf "menuentry '%s_HD' {\n" $OS_NAME >> "$ROOT"/boot/grub/grub.cfg
    printf "set root=(hd0,msdos1)\n" >> "$ROOT"/boot/grub/grub.cfg
    printf "linux /boot/bzImage-%s-generic root=/dev/sda1 ro" $LINUX_VERSION >> "$ROOT"/boot/grub/grub.cfg
    printf "\n}" >> "$ROOT"/boot/grub/grub.cfg
    cp "$OUT"/bzImage-"$LINUX_VERSION"-generic "$ROOT"/boot/bzImage-"$LINUX_VERSION"-generic
    cp -r -u "$INITRD"/* "$ROOT"/
    "$GRUB_DIR"/grub-mkrescue --compress=xz -o "$OUT"/"$OS_NAME"-"$OS_VERSION".iso "$ROOT"
    rm -rf "$ROOT"
    exit
fi

while true; do

echo "Building completed. You can find initrd.img and bzImage in $OUT"
echo "Enter a aption number to execute:"
echo "1. Run Linux in qemu with initrd"
echo "2. Run the os using chroot to change additional settings"
echo "3. Install the OS the the specified device"
echo "4. Build an iso image"
echo "5. Build initrd image"
echo "6. Exit"

read -r option

case $option in
    1)
        qemu-system-x86_64 -m 1024 -kernel "$OUT"/bzImage-"$LINUX_VERSION"-generic -initrd "$OUT"/initrd.img -append "console=ttyS0"
        ;;
    2)
        sudo chroot "$INITRD" /bin/bash
        ;;
    3)
        rm -rf "$ROOT"
        echo "Enter the device name (e.g. /dev/sda):"
        read device
        mkdir -p "$ROOT"/boot/grub
        rm "$ROOT"/boot/grub/grub.cfg
        cat > "$ROOT"/boot/grub/grub.cfg << "EOF"
set default=0
set timeout=5
set root=(hd0,msdos1)
EOF
        printf "menuentry 'LINUX' {\n" >> "$ROOT"/boot/grub/grub.cfg
        printf "linux /boot/bzImage-$LINUX_VERSION-generic root=/dev/sda1 ro" >> "$ROOT"/boot/grub/grub.cfg
        printf "\n}" >> "$ROOT"/boot/grub/grub.cfg
        cp "$OUT"/bzImage-"$LINUX_VERSION"-generic "$ROOT"/boot/bzImage-"$LINUX_VERSION"-generic
        cp -r -u "$INITRD"/* "$ROOT"/
        if ls "$device"1 > /dev/null 2>&1; then
        sudo wipefs -a "$device"1
        sudo fdisk "$device" << "EOF"
d
w
EOF
        fi
        sudo fdisk "$device" << EOF
o
n
p
1


a
w
EOF
        sudo mkfs.ext3 "$device"1
        mkdir -p "$MNT"/dev1
        sudo mount "$device"1 "$MNT"/dev1
        sudo cp -r -v "$ROOT"/* "$MNT"/dev1/
        sudo grub-install --target=i386-pc --boot-directory="$MNT"/dev1/boot/ "$device"
        sudo umount "$MNT"/dev1
        ;;
    4)
        mkdir -p "$ROOT"/boot/grub
        rm "$ROOT"/boot/grub/grub.cfg
        cat > "$ROOT"/boot/grub/grub.cfg << "EOF"
set default=0
set timeout=5
EOF
        printf "menuentry '%s_CDROM' {\n" $OS_NAME >> "$ROOT"/boot/grub/grub.cfg
        printf "set root=(cd)\n" >> "$ROOT"/boot/grub/grub.cfg
        printf "linux /boot/bzImage-%s-generic root=/dev/sr0 ro" $LINUX_VERSION >> "$ROOT"/boot/grub/grub.cfg
        printf "\n}\n\n" >> "$ROOT"/boot/grub/grub.cfg
        printf "menuentry '%s_HD' {\n" $OS_NAME >> "$ROOT"/boot/grub/grub.cfg
        printf "set root=(hd0,msdos1)\n" >> "$ROOT"/boot/grub/grub.cfg
        printf "linux /boot/bzImage-%s-generic root=/dev/sda1 ro" $LINUX_VERSION >> "$ROOT"/boot/grub/grub.cfg
        printf "\n}" >> "$ROOT"/boot/grub/grub.cfg
        cp "$OUT"/initrd.img "$ROOT"/boot/initrd.img
        cp "$OUT"/bzImage-"$LINUX_VERSION"-generic "$ROOT"/boot/bzImage-"$LINUX_VERSION"-generic
        cp -r -u "$INITRD"/* "$ROOT"/
        "$GRUB_DIR"/grub-mkrescue --compress=xz -o "$OUT"/"$OS_NAME"-"$OS_VERSION".iso "$ROOT"

        rm -rf "$ROOT"
        ;;
    5)
        find . | cpio -o -H newc | gzip -9 > "$OUT"/initrd.img
        ;;
    6)
        exit
        ;;
    *)
        echo "Invalid option"
        ;;

esac

done

cd ..