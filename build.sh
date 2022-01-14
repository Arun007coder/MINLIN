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

export HOST=$(echo ${MACHTYPE} | sed "s/-[^-]*/-cross/")
export TARGET=x86_64-unknown-linux-gnu
export CPU=k8
export ARCH=x86_64

# END Warning

echo "Warning: This script can only build linux for the current machine's architecture"
echo "Press enter to continue or ctrl+c to exit"
read -r

case $1 in
    -s)
        echo "Welcome to the MINLINUX build system"
        echo "This script will build a minimal linux"
        echo "Please be patient, it may take a while"
        ;;
    *)
        echo "Welcome to the MINLINUX build system"
        echo "This script will build a minimal linux"
        echo "Please be patient, it may take a while"
        echo "Press enter to continue"
        read -r
        ;;
esac

mkdir -p "$SRC" "$INITRD" "$LOG" "$OUT" "$INS" "$ROOT" "$MNT" "$EPKG"
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
    make defconfig
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
    echo $PWD
    mkdir -pv glibc-build
    cd glibc-build || exit
    echo $PWD
    echo "libc_cv_forced_unwind=yes" > config.cache
    echo "libc_cv_c_cleanup=yes" >> config.cache
    echo "libc_cv_ssp=no" >> config.cache
    echo "libc_cv_ssp_strong=no" >> config.cache
    echo $LD_LIBRARY_PATH
    #sleep 10
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
    #sleep 10
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
    make defconfig
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
root::0:0:root:/root:/bin/sh
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

rootfs          /               auto    defaults        1      1
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

rm etc/hostname
echo TESTLinux > etc/hostname

mkdir etc/rc.d/
rm etc/rc.d/startup
cat > etc/rc.d/startup << "EOF"
#!/bin/sh
PATH=/sbin:/bin:/usr/sbin:/usr/bin #Initialize the environment variable PATH, the operating system executes the program by default to find the program in the directory specified by PATH

runlevel=S #Set the system to single user mode
prevlevel=N #Set the system to single user mode

umask 022 #Specify the default permissions of the current user when creating files 

export PATH runlevel prevlevel #Export environment variables

mount -a #mount The file system specified in the fstab file

#From/etc/sysconfig/Read the host name i

mount -o rw,remount / #Remount the file system specified in the fstab file

ldconfig # to start the dynamic linker

EOF

ln -svf ${INITRD}/proc/mounts ${INITRD}/etc/mtab

mkdir -pv var/{run,log}

touch var/run/utmp var/log/{btmp,lastlog,wtmp}
chmod -v 664 var/run/utmp var/log/lastlog

rm init
:<< "COM"
echo '#!/bin/sh' >> init
echo '' >> init
echo 'mount -t proc proc /proc' >> init
echo 'mount -t sysfs sysfs /sys' >> init
echo 'mount -t devtmpfs udev /dev' >> init
echo '' >> init
echo 'sysctl -w kernel.printk="2 4 1 7"' >> init
echo 'sysctl -w net.ipv4.ip_forward=1' >> init
echo '' >> init
echo 'wait 5' >> init
echo '' >> init
echo 'ldconfig' >> init
echo 'mknod -m 622 /dev/console c 5 1' >> init
echo 'mknod -m 666 /dev/null c 1 3' >> init
echo 'mknod -m 666 /dev/zero c 1 5' >> init
echo 'mknod -m 666 /dev/ptmx c 5 2' >> init
echo 'mknod -m 666 /dev/tty c 5 0' >> init
echo 'mknod -m 444 /dev/random c 1 8' >> init
echo 'mknod -m 444 /dev/urandom c 1 9' >> init
echo 'chown root:tty /dev/{console,ptmx,tty}' >> init
echo '' >> init
echo '/bin/sh' >> init
echo 'poweroff -f' >> init
COM

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

cat > etc/ld.so.conf.d/x86_64-linux-gnu.conf << "EOF"
# /etc/ld.so.conf.d/x86_64-linux-gnu.conf

/lib/x86_64-linux-gnu
/usr/lib/x86_64-linux-gnu
/usr/local/lib/x86_64-linux-gnu
EOF

rm etc/addusr
cat > etc/addusr << "EOF"
#!/bin/sh

username=$1

adduser adduser "$username" --shell /bin/bash --home /home/"$username"
passwd "$username"

echo new user "$username" added
sleep 10
EOF
sudo chmod +x etc/addusr

:<< "COM"
rm etc/fstab
cat > etc/fstab << "EOF"
# file system  mount-point  type   options          dump  fsck
#                                                         order

# rootfs          /               auto    defaults        1      1
proc            /proc           proc    defaults        0      0
sysfs           /sys            sysfs   defaults        0      0
devpts          /dev/pts        devpts  gid=4,mode=620  0      0
tmpfs           /dev/shm        tmpfs   defaults        0      0
EOF
COM

echo "Do you want to add new user? (y/n)"
read answer
if [ "$answer" == "y" ]; then
    echo "Enter username:"
    read username
    mkdir -p home/"$username"
    sudo chroot "$INITRD" /usr/bin/env \
    HOME=/root \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH="/bin:/usr/bin:/sbin:/usr/sbin" \
    LD_LIBRARY_PATH="/lib:/usr/lib:/lib64:/usr/lib64" \
    /bin/bash --login +h -c "/etc/addusr $username"
fi

FILES="$(ls ${INITRD}/usr/lib64/*.a)"
for file in $FILES; do
    rm -f $file
done

find ${INITRD}/{,usr/}{bin,lib,sbin} -type f -exec sudo strip --strip-debug '{}' ';' 2>&1
find ${INITRD}/{,usr/}lib64 -type f -exec sudo strip --strip-debug '{}' ';' 2>&1

sudo chmod -R 777 .
cp "$SRC"/linux-"$LINUX_VERSION"/arch/x86/boot/bzImage "$OUT"/bzImage-"$LINUX_VERSION"-generic

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
        cp "$OUT"/initrd.img "$ROOT"/boot/initrd.img
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
        "$GRUB_DIR"/grub-mkrescue -o "$OUT"/"$OS_NAME"-"$OS_VERSION".iso "$ROOT"

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