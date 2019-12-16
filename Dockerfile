# Referenced from http://itianda.com/2018/08/09/Build-Extreme-performance-Quantum-ESPRESSO-on-Docker-for-Windows/

FROM ubuntu:17.04

ARG PS=parallel_studio_xe_2018_update3_cluster_edition

RUN \
    tar -xzf psxe/$PS.tgz && \
    cd $PS && \
    mkdir /opt/intel && \
    cp ../psxe/psxe.lic /opt/intel/licenses && \
    ./install.sh --silent=../psxe/silent.cfg

ARG TOPROOT=/opt/intel
ARG INTELROOT=$TOPROOT/compilers_and_libraries/linux
ENV MKLROOT=$INTELROOT/mkl
ENV TBBROOT=$INTELROOT/tbb
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib/x86_64-linux-gnu/:/lib
ENV LD_LIBRARY_PATH=$INTELROOT/lib/intel64:$MKLROOT/lib/intel64:$TBBROOT/lib/intel64:$LD_LIBRARY_PATH
ENV PATH=$TOPROOT/bin:$PATH
ENV COMPILERVARS_ARCHITECTURE="intel64"
ENV COMPILERVARS_PLATFORM="linux"
ARG TARGET="SKYLAKE"
ARG CCFLAGS="-O3 -no-prec-div -fp-model fast=2 -x${TARGET}"
ARG FCFLAGS="-O3 -no-prec-div -fp-model fast=2 -x${TARGET} -align array64byte -threads -heap-arrays 4096"

RUN \
    apt-get update -y  && \
    apt-get upgrade -y && \
    apt-get install -y cpio wget make gcc g++ python ssh autotools-dev autoconf automake texinfo libtool patch flex

RUN \
    cd $OMPI_DIR && \
    . compilervars.sh && \
    ./autogen.pl && \
    ./configure \
    --with-cma="no" \
    CC="icc" \
    CXX="icpc" \
    FC="ifort" \
    CFLAGS="${CCFLAGS}" \
    CXXFLAGS="${CCFLAGS}" \
    FCFLAGS="${FCFLAGS}" \
    && \
    make -j && \
    make install

RUN \
    cd $ELPA_DIR && \
    . compilervars.sh && \
    autoconf && \
    ./configure \
    --enable-option-checking=fatal \
    --prefix=$ELPAROOT \
    AR="xiar" \
    FC="mpifort" \
    CC="mpicc" \
    CXX="mpicpc" \
    CFLAGS="${CCFLAGS}" \
    CXXFLAGS="${CCFLAGS}" \
    FCFLAGS="${FCFLAGS}" \
    ACLOCAL="aclocal" \
    AUTOCONF='autoconf' \
    AUTOHEADER='autoheader' \
    AUTOMAKE='automake' \
    MAKEINFO="makeinfo" \
    SCALAPACK_LDFLAGS="-L${MKLROOT}/lib/intel64 -lmkl_scalapack_lp64 -lmkl_intel_lp64 -lmkl_sequential -lmkl_core -lmkl_blacs_openmpi_lp64 -Wl,-rpath,${MKLROOT}/lib/intel64" \
    SCALAPACK_FCFLAGS="-L${MKLROOT}/lib/intel64 -lmkl_scalapack_lp64 -lmkl_intel_lp64 -lmkl_sequential -lmkl_core -lmkl_blacs_openmpi_lp64 -I${MKLROOT}/include/intel64/lp64" \
    && \
    make -j && \
    make install

RUN \
    ln -s q-e-$QE_DIR $QE_DIR && \
    cd $QE_DIR && \
    . compilervars.sh && \
    ./configure \
    AR="xiar" \
    MPIF90="mpifort" \
    CC="mpicc" \
    CFLAGS="${CCFLAGS}" \
    FFLAGS="${FCFLAGS} -I${MKLROOT}/include -I${MKLROOT}/include/fftw" \
    LDFLAGS="-Wl,--start-group \
    ${MKLROOT}/lib/intel64/libmkl_intel_lp64.a \
    ${MKLROOT}/lib/intel64/libmkl_core.a \
    ${MKLROOT}/lib/intel64/libmkl_sequential.a \
    ${MKLROOT}/lib/intel64/libmkl_blacs_openmpi_lp64.a \
    ${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a \
    -Wl,--end-group" \
    --with-elpa-include="${ELPAROOT}/include/${ELPA_DIR}/modules" \
    --with-elpa-lib="${ELPAROOT}/lib/libelpa.a" \
    --with-elpa-version=2016 && \
    make all
