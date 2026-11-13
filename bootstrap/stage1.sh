#!/bin/bash
# Stage 1: a cross toolchain in $AST/tools that targets the new system (LFS chapter 5).
set -e
. "$(dirname "$0")/env.sh"
mkdir -p "$AST"/{etc,var,usr/{bin,lib,sbin},tools} "$AST/lib64"
for i in bin lib sbin; do ln -sfn usr/$i "$AST/$i"; done


binutils1() {
    unpack binutils-2.45; mkdir build; cd build
    ../configure --prefix=$AST/tools --with-sysroot=$AST --target=$AST_TGT --disable-nls --enable-gprofng=no --disable-werror --enable-new-dtags --enable-default-hash-style=gnu
    make; make install
}

gcc1() {
    export CXX="$HOST_CXX" CXX_FOR_BUILD="$HOST_CXX"
    unpack gcc-15.2.0
    for p in gmp-6.3.0:gmp mpfr-4.2.2:mpfr mpc-1.3.1:mpc; do
        mkdir ${p#*:}; tar -xf "$(ls $SRC/${p%:*}.tar.*)" -C ${p#*:} --strip-components=1
    done
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    mkdir build; cd build
    ../configure --target=$AST_TGT --prefix=$AST/tools --with-glibc-version=2.42 --with-sysroot=$AST --with-newlib --without-headers --enable-default-pie --enable-default-ssp --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
    make; make install
    cd ..; cat gcc/limitx.h gcc/glimits.h gcc/limity.h > "$(dirname "$($AST_TGT-gcc -print-libgcc-file-name)")/include/limits.h"
}

headers() {
    unpack linux-6.16.1
    make mrproper; make headers
    find usr/include -type f ! -name '*.h' -delete
    cp -r usr/include "$AST/usr"
}

glibc() {
    ln -sfn ../lib/ld-linux-x86-64.so.2 "$AST/lib64/ld-linux-x86-64.so.2"
    ln -sfn ../lib/ld-linux-x86-64.so.2 "$AST/lib64/ld-lsb-x86-64.so.3"
    unpack glibc-2.42; mkdir build; cd build
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure --prefix=/usr --host=$AST_TGT --build=$(../scripts/config.guess) --disable-nscd libc_cv_slibdir=/usr/lib --enable-kernel=5.4
    make; make DESTDIR=$AST install
    sed '/RTLDLIST=/s@/usr@@g' -i $AST/usr/bin/ldd
    echo 'int main(){}' | $AST_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
    readelf -l a.out | grep -q ld-linux-x86-64 || { echo "toolchain sanity check failed"; exit 1; }
}

libstdcxx() {
    unpack gcc-15.2.0; mkdir build; cd build
    ../libstdc++-v3/configure --host=$AST_TGT --build=$(../config.guess) --prefix=/usr --disable-multilib --disable-nls --disable-libstdcxx-pch --with-gxx-include-dir=/tools/$AST_TGT/include/c++/15.2.0
    make; make DESTDIR=$AST install
    rm -f $AST/usr/lib/lib{stdc++{,exp,fs},supc++}.la
}

step binutils1 binutils1
step gcc1 gcc1
step headers headers
step glibc glibc
step libstdcxx libstdcxx
log stage 1 done
