# Referenced from http://itianda.com/2018/08/09/Build-Extreme-performance-Quantum-ESPRESSO-on-Docker-for-Windows/

FROM ubuntu:18.04

WORKDIR /root/

COPY psxe .

# 安装相关依赖包
RUN \
    apt-get update -y  && \
    apt-get upgrade -y && \
    apt-get install -y cpio wget make gcc g++ python ssh autotools-dev autoconf automake texinfo libtool patch flex && \
    apt-get -qq autoclean && apt-get -qq autoremove

# 选择基础镜像，安装 PS XE
ARG PS=parallel_studio_xe_2020_cluster_edition

RUN \
    tar -xzf $PS.tgz && \
    cd $PS && \
    mkdir /opt/intel && \
    cp ../psxe.lic /opt/intel/licenses && \
    ./install.sh --silent=../silent.cfg && \
    rm ../$PS.tgz

ARG TOPROOT=/opt/intel
ARG INTELROOT=$TOPROOT/compilers_and_libraries/linux
ENV MKLROOT=$INTELROOT/mkl
ENV TBBROOT=$INTELROOT/tbb
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib/x86_64-linux-gnu/:/lib
ENV LD_LIBRARY_PATH=$INTELROOT/lib/intel64:$MKLROOT/lib/intel64:$TBBROOT/lib/intel64:$LD_LIBRARY_PATH
ENV PATH=$TOPROOT/bin:$PATH

# 设置环境变量
ENV COMPILERVARS_ARCHITECTURE="intel64"
ENV COMPILERVARS_PLATFORM="linux"

# 指定编译器选项
ARG TARGET="SKYLAKE"
ARG CCFLAGS="-O3 -no-prec-div -fp-model fast=2 -x${TARGET}"
ARG FCFLAGS="-O3 -no-prec-div -fp-model fast=2 -x${TARGET} -align array64byte -threads -heap-arrays 4096"

# 编译 Open MPI
ARG OMPI_DIR=openmpi

RUN \
    wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.2.tar.gz && \
    tar -xzf openmpi-4.0.2.tar.gz && \
    rm openmpi-4.0.2.tar.gz && \
    mv openmpi-4.0.2 openmpi

RUN \
    cd $OMPI_DIR && \
    . compilervars.sh && \
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

# 编译 ELPA
ARG ELPAROOT=elpa
ARG ELPA_DIR=elpa-2019.11.001

RUN \
    wget -P $ELPAROOT https://elpa.mpcdf.mpg.de/html/Releases/2019.11.001/elpa-2019.11.001.tar.gz && \
    tar -xzf $ELPAROOT/*.tar.gz && \
    rm $ELPAROOT/*.tar.gz

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

# 编译 QE
ARG QE_DIR=qe

RUN \
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
