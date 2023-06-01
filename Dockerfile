# ----------------------------------------------------------------------
# Debian baseOS docker container to use with ELM/CTSM builds
# ARM64 version
# ----------------------------------------------------------------------

# RF - start from slim distro
FROM debian:buster-slim

LABEL maintainer.name="Franklin J. Eaglebarger" \
      maintainer.email="fye@ornl.gov" \
      description="GCC-based image"

# Set a few variables that can be used to control the docker build
ARG OPENMPI_VERSION=3.1.6
ARG HDF5_VERSION=1.12.1
ARG NETCDF_VERSION=4.8.1
ARG NETCDF_FORTRAN_VERSION=4.5.4

# set path variables
ENV PATH=/usr/local/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH
ENV PATH=/usr/local/hdf5/bin:$PATH
ENV PATH=/usr/local/netcdf/bin:$PATH
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/hdf5/lib
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/netcdf/lib
ENV HDF5_DIR=/usr/local/hdf5

# Update the system and install initial dependencies
# RF - add gcc-8 and gfortran-8 to install precompiled 8.3.0
RUN apt-get update -y \
    && apt-get install -y \
    build-essential \
    cmake \
    git \
    gcc-8 \   
    gfortran-8 \
    subversion \
    bzip2 \
    libgmp3-dev \
    m4 \
    wget \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    libxml2 \
    libxml2-dev \
    csh \
    liblapack-dev \
    libblas-dev \
    liblapack-dev \
    libffi6 \
    libffi-dev \
    libxml-libxml-perl \
    libxml2-utils \
    vim \
    libudunits2-0 \
    libudunits2-dev \
    udunits-bin \
    python3 \
    python3-dev \
    python3-pip \
    apt-utils \
    ftp \
    apt-transport-https \
    libssl-dev \
    openssl \
    libncurses5-dev \
    libsqlite3-dev \
    gsl-bin \
    libgsl-dev \
    flex \
    nco \
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean all 

# RF - symlink gfortran for compiling hdf5/netcdf/e3sm 
RUN ln -sf /usr/bin/gfortran-8 /usr/bin/gfortran 

# Add symlink to python3 for running OLMT
RUN ln -sf /usr/bin/python3 /usr/bin/python

## Install program to configure locales
RUN dpkg-reconfigure locales && \
  locale-gen C.UTF-8 && \
    /usr/sbin/update-locale LANG=C.UTF-8
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && \
      locale-gen
## Set default locale for the environment
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

## check locales
RUN locale -a

## compile openMPI
RUN cd / \
    && wget https://download.open-mpi.org/release/open-mpi/v3.1/openmpi-${OPENMPI_VERSION}.tar.gz \
    && tar -zxvf openmpi-${OPENMPI_VERSION}.tar.gz \
    && cd openmpi-${OPENMPI_VERSION} \
    && export PATH=/usr/local/bin:$PATH \
    && export LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH \
    && ./configure --enable-static \
    && make \
    && make install \
    && cd / \
    && rm -r openmpi-${OPENMPI_VERSION} \
    && rm openmpi-${OPENMPI_VERSION}.tar.gz \
    && ldconfig

## Compile Expat XML parser
RUN cd / \
    && wget https://github.com/libexpat/libexpat/releases/download/R_2_4_7/expat-2.4.7.tar.bz2 \
    && tar -xvjf expat-2.4.7.tar.bz2 \
    && cd expat-2.4.7 \
    && ./configure \
    && make \
    && make install \
    && cd / \
    && rm -r expat-2.4.7 \
    && rm expat-2.4.7.tar.bz2

## HDF5 - use alternative source since main HDF5 source doesnt have useful download links
#https://support.hdfgroup.org/ftp/HDF5/releases/
RUN cd / \
    && mkdir -p /usr/local/hdf5 \
    && wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.1/src/hdf5-1.12.1.tar.gz \
    && tar -zxvf hdf5-1.12.1.tar.gz \
    && cd hdf5-1.12.1 \
    && CC=mpicc ./configure --enable-fortran --enable-parallel --prefix=/usr/local/hdf5 \
    && make \
    && make install \
    && export PATH=/usr/local/hdf5/bin:$PATH \
    && export LD_LIBRARY_PATH=/usr/local/hdf5/lib/libhdf5 \
    && cd / \
    && rm -r hdf5-1.12.1 \
    && rm hdf5-1.12.1.tar.gz

## netCDF & netCDF-Fortran
RUN cd / \
    && mkdir -p /usr/local/netcdf \
    && wget https://downloads.unidata.ucar.edu/netcdf-c/4.8.1/netcdf-c-4.8.1.tar.gz \
    && tar -zxvf netcdf-c-4.8.1.tar.gz \
    && cd netcdf-c-4.8.1 \
    && export H5DIR=/usr/local/hdf5 \
    && export NCDIR=/usr/local/netcdf \
    && CC=mpicc CPPFLAGS=-I${H5DIR}/include LDFLAGS=-L${H5DIR}/lib ./configure --enable-parallel-tests --prefix=${NCDIR} \
    && make \
    && make install \
    && export PATH=/usr/local/netcdf/bin:$PATH \
    && export LD_LIBRARY_PATH=/usr/local/netcdf/lib \
    && cd / \
    && rm -r netcdf-c-4.8.1 \
    && rm netcdf-c-4.8.1.tar.gz \
    && wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.5.4/netcdf-fortran-4.5.4.tar.gz \
    && tar -zxvf netcdf-fortran-4.5.4.tar.gz \
    && cd netcdf-fortran-4.5.4 \
    && export NCDIR=/usr/local/netcdf \
    && export NFDIR=/usr/local/netcdf \
    && FC=mpif90 CPPFLAGS=-I${NCDIR}/include LDFLAGS=-L${NCDIR}/lib ./configure --prefix=${NFDIR} --enable-parallel-tests \
    && make \
    && make install \
    && cd / \
    && rm -r netcdf-fortran-4.5.4 \
    && rm netcdf-fortran-4.5.4.tar.gz

## Install python libraries for OLMT
RUN pip3 install wheel
RUN pip3 install numpy scipy mpi4py netCDF4
RUN pip3 install h5py configparser cftime

## EOF
