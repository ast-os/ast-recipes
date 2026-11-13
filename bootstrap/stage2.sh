#!/bin/bash
# Stage 2: cross-compile the temporary tools into $AST (LFS chapter 6). Resumable: a finished step is skipped.
set -e
. "$(dirname "$0")/env.sh"
HOST=(--host=$AST_TGT)
inst() { make DESTDIR=$AST install; }

b_m4() {
    unpack m4-1.4.20
    ./configure --prefix=/usr "${HOST[@]}" --build=$(build-aux/config.guess)
    make; inst
}

b_ncurses() {
    unpack ncurses-6.6
    mkdir build; (cd build; ../configure AWK=gawk; make -C include; make -C progs tic)
    ./configure --prefix=/usr "${HOST[@]}" --build=$(./config.guess) --mandir=/usr/share/man --with-manpage-format=normal --with-shared --without-normal --with-cxx-shared --without-debug --without-ada --disable-stripping AWK=gawk
    make; make DESTDIR=$AST TIC_PATH=$PWD/build/progs/tic install
    ln -sf libncursesw.so $AST/usr/lib/libncurses.so
    sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $AST/usr/include/curses.h
}

b_bash() {
    unpack bash-5.3
    ./configure --prefix=/usr --build=$(sh support/config.guess) "${HOST[@]}" --without-bash-malloc
    make; inst
    ln -sf bash $AST/bin/sh
}

b_coreutils() {
    unpack coreutils-9.7
    ./configure --prefix=/usr "${HOST[@]}" --build=$(build-aux/config.guess) --enable-install-program=hostname --enable-no-install-program=kill,uptime
    make; inst
    mv $AST/usr/bin/chroot $AST/usr/sbin
}

# the plain ones: configure, make, install
b_plain() {
    unpack "$1"
    extra=()
    [ "$1" = diffutils-3.12 ] && extra=(gl_cv_func_strcasecmp_works=y)
    [ "$1" = findutils-4.10.0 ] && extra=(--localstatedir=/var/lib/locate)
    [ "$1" = gawk-5.3.2 ] && sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr "${extra[@]}" "${HOST[@]}" --build=$(./build-aux/config.guess)
    make; inst
}

b_file() {
    unpack file-5.46
    mkdir build; (cd build; ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib; make)
    ./configure --prefix=/usr "${HOST[@]}" --build=$(./config.guess)
    make FILE_COMPILE=$PWD/build/src/file; inst
    rm -f $AST/usr/lib/libmagic.la
}

b_make() {
    unpack make-4.4.1
    ./configure --prefix=/usr --without-guile "${HOST[@]}" --build=$(build-aux/config.guess)
    make; inst
}

b_xz() {
    unpack xz-5.8.1
    ./configure --prefix=/usr "${HOST[@]}" --build=$(build-aux/config.guess) --disable-static --docdir=/usr/share/doc/xz-5.8.1
    make; inst
    rm -f $AST/usr/lib/liblzma.la
}

b_binutils2() {
    unpack binutils-2.45
    sed '6031s/$add_dir//' -i ltmain.sh
    mkdir build; cd build
    ../configure --prefix=/usr --build=$(../config.guess) "${HOST[@]}" --disable-nls --enable-shared --enable-gprofng=no --disable-werror --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu
    make; inst
    rm -f $AST/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
}

b_gcc2() {
    export CXX_FOR_BUILD="$HOST_CXX"
    unpack gcc-15.2.0
    for p in gmp-6.3.0:gmp mpfr-4.2.2:mpfr mpc-1.3.1:mpc; do
        mkdir ${p#*:}; tar -xf "$(ls $SRC/${p%:*}.tar.*)" -C ${p#*:} --strip-components=1
    done
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
    mkdir build; cd build
    ../configure --build=$(../config.guess) --host=$AST_TGT --target=$AST_TGT LDFLAGS_FOR_TARGET=-L$PWD/$AST_TGT/libgcc --prefix=/usr --with-build-sysroot=$AST --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libsanitizer --disable-libssp --disable-libvtv --enable-languages=c,c++
    make; inst
    ln -sf gcc $AST/usr/bin/cc
}

step m4 b_m4
step ncurses b_ncurses
step bash b_bash
step coreutils b_coreutils
for p in diffutils-3.12 findutils-4.10.0 gawk-5.3.2 grep-3.12 gzip-1.14 patch-2.8 sed-4.9 tar-1.35; do step "$p" b_plain "$p"; done
step file b_file
step make b_make
step xz b_xz
step binutils2 b_binutils2
step gcc2 b_gcc2
log stage 2 done
