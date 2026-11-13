#!/bin/bash
# Runs inside the new system: the directory layout, then gettext, bison, perl, python, texinfo, util-linux.
set -e
umask 022
SRC=/sources; BUILD=/build
mkdir -p $BUILD
unpack() {
    local f; f=$(ls $SRC/$1.tar.* 2>/dev/null | head -1)
    rm -rf $BUILD/$1; mkdir -p $BUILD/$1
    tar -xf "$f" -C $BUILD/$1 --strip-components=1
    cd $BUILD/$1
}
log() { printf '== %s\n' "$*"; }

log layout
mkdir -p /{boot,home,mnt,opt,srv} /etc/{opt,sysconfig} /lib/firmware /media/{floppy,cdrom}
mkdir -p /usr/{,local/}{include,src} /usr/lib/locale /usr/local/{bin,lib,sbin}
mkdir -p /usr/{,local/}share/{color,dict,doc,info,locale,man,misc,terminfo,zoneinfo}
mkdir -p /usr/{,local/}share/man/man{1..8}
mkdir -p /var/{cache,local,log,mail,opt,spool} /var/lib/{color,misc,locate}
ln -sfn /run /var/run; ln -sfn /run/lock /var/lock
install -d -m 0750 /root; install -d -m 1777 /tmp /var/tmp
ln -sf /proc/self/mounts /etc/mtab
cat > /etc/hosts <<H
127.0.0.1  localhost
::1        localhost
H
cat > /etc/passwd <<H
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
H
cat > /etc/group <<H
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:9:
tape:x:10:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:7:
dialout:x:18:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
H
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp utmp /var/log/lastlog; chmod 664 /var/log/lastlog; chmod 600 /var/log/btmp

log gettext
unpack gettext-0.26
./configure --disable-shared
make; cp gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

log bison
unpack bison-3.8.2
./configure --prefix=/usr
make; make install

log perl
unpack perl-5.42.0
sh Configure -des -D prefix=/usr -D vendorprefix=/usr -D useshrplib \
    -D privlib=/usr/lib/perl5/5.42/core_perl -D archlib=/usr/lib/perl5/5.42/core_perl \
    -D sitelib=/usr/lib/perl5/5.42/site_perl -D sitearch=/usr/lib/perl5/5.42/site_perl \
    -D vendorlib=/usr/lib/perl5/5.42/vendor_perl -D vendorarch=/usr/lib/perl5/5.42/vendor_perl
make; make install

log python
unpack Python-3.13.7
./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython
make; make install

log texinfo
unpack texinfo-7.2
./configure --prefix=/usr
make; make install

log util-linux
unpack util-linux-2.41.1
mkdir -p /var/lib/hwclock
./configure --libdir=/usr/lib --runstatedir=/run --disable-chfn-chsh --disable-login --disable-nologin --disable-su --disable-setpriv --disable-runuser --disable-pylibmount --disable-static --disable-liblastlog2 --without-python ADJTIME_PATH=/var/lib/hwclock/adjtime
make; make install

log cleanup
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name '*.la' -delete
rm -rf /tools
log stage 3 done
