#!/bin/bash
#set -x
set -o nounset
MK_VERSION="ffmpeg 1.0.1"
CURRENT_PATH=`pwd`
cd ${CURRENT_PATH}/..
export MK_ROOT=$PWD
export EXTEND_ROOT=${MK_ROOT}/extend/
export THIRD_ROOT=${CURRENT_PATH}/3rd_party/
export PATCH_ROOT=${CURRENT_PATH}/patch/
export PREFIX_ROOT=${CURRENT_PATH}/libFFMPEG/
export WITH_3RDPARTY=TRUE
export WITH_DEBUG=FALSE
export BUILD_SILENT=FALSE
echo "------------------------------------------------------------------------------"
echo " MK_ROOT exported as ${MK_ROOT}"
echo "------------------------------------------------------------------------------"

#gcc_version=`gcc -dumpversion` 
gcc_version=`gcc -E -dM - </dev/null|grep __VERSION__|awk -F'"' '{print $2}'|awk '{print $1}'` 

host_type=`uname -p`

config_args=""

if [ "$host_type" = "aarch64" ];then
   config_args="--host=arm-linux --build=arm-linux"
fi

download_3rd()
{
    if [ ! -f ${CURRENT_PATH}/3rd_party/3rd.list ]; then
        echo "there is no 3rd package list\n"
        return 1
    fi
    cat ${CURRENT_PATH}/3rd_party/3rd.list|while read LINE
    do
        name=`echo "${LINE}"|awk -F '|' '{print $1}'`
        url=`echo "${LINE}"|awk -F '|' '{print $2}'`
        package=`echo "${LINE}"|awk -F '|' '{print $3}'`
        if [ ! -f ${THIRD_ROOT}/${package} ]; then
            echo "begin:download :${name}..................."
            wget --no-check-certificate ${url} -O ${THIRD_ROOT}/${package}
            echo "end:download :${name}....................."
        fi     
    done
    return 0
}

set_extend_config()
{
    find=`env|grep PKG_CONFIG_PATH`    
    if [ "find${find}" == "find" ]; then    
        export PKG_CONFIG_PATH=${EXTEND_ROOT}/lib/pkgconfig/
    else
        export PKG_CONFIG_PATH=${EXTEND_ROOT}/lib/pkgconfig/:${PKG_CONFIG_PATH}
    fi
    
    find=`env|grep PATH`
    if [ "find${find}" == "find" ]; then    
        export PATH=${EXTEND_ROOT}/bin/
    else
        export PATH=${EXTEND_ROOT}/bin/:${PATH}
    fi
}

build_ffmpeg()
{    
    cd ${MK_ROOT}/ffmpeg*
    ##set the env config
    set_extend_config
    
    cd ffbuild/
    chmod +x *.sh
    cd ..
    chmod +x configure
    
    export debug_tag=--disable-debug
    
    if [ "${WITH_DEBUG}" == "TRUE" ];then
        export debug_tag="--enable-debug --extra-cflags=-g --extra-ldflags=-g"
    fi

    ./configure --prefix=${EXTEND_ROOT}    \
                --enable-shared            \
                --disable-ffplay           \
                --disable-ffprobe          \
                --disable-indev=sndio      \
                --disable-outdev=sndio     \
                --enable-openssl           \
                --enable-x86asm            \
                --enable-pic               \
                --enable-gpl               \
                --enable-pthreads          \
                --enable-nonfree           \
                --enable-version3          \
                --enable-static            \
                --enable-frei0r            \
                --enable-gray              \
                --enable-libfreetype       \
                --enable-libmp3lame        \
                --enable-encoder=libmp3lame\
                --enable-libopencore-amrnb \
                --enable-libopencore-amrwb \
                --enable-libopenjpeg       \
                --enable-libspeex          \
                --enable-libvorbis         \
                --enable-libopus           \
                --enable-libtheora         \
                --enable-libvpx            \
                --enable-libwebp           \
                --enable-libx264           \
                --enable-libx265           \
                --enable-libxvid           \
                --enable-libfdk-aac        \
                --enable-libzmq            \
                --extra-cflags="-I${EXTEND_ROOT}/include -fPIC" \
                --extra-ldflags=-L/${EXTEND_ROOT}/lib  \
                ${debug_tag}                
                
    if [ 0 -ne ${?} ]; then
        echo "configure ffmpeg fail!"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build ffmpeg fail!"
        return 1
    fi
    
    #change the libavutil/time.h to libavutil/avtime.h
    
    mv ${EXTEND_ROOT}/include/libavutil/time.h ${EXTEND_ROOT}/include/libavutil/avtime.h
    return 0
}

build_ffmpeg_debug()
{
    export WITH_DEBUG=TRUE
    build_ffmpeg    
    if [ 0 -ne ${?} ]; then
        echo "build ffmpeg fail!"
        return 1
    fi
    return 0
}


rebuild_ffmpeg()
{    
    cd ${MK_ROOT}/ffmpeg*
    ##set the env config
    set_extend_config
    
    cd ffbuild/
    chmod +x *.sh
    cd ..
    chmod +x configure
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build ffmpeg fail!"
        return 1
    fi
    
    #change the libavutil/time.h to libavutil/avtime.h
    
    mv ${EXTEND_ROOT}/include/libavutil/time.h ${EXTEND_ROOT}/include/libavutil/avtime.h
    return 0
}

build_zlib()
{
    module_pack="zlib-1.2.8.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the zlib package from server\n"
        wget http://zlib.net/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd zlib*/
    export CFLAGS=-fPIC
    ./configure --prefix=${EXTEND_ROOT} 
                
    if [ 0 -ne ${?} ]; then
        echo "configure zlib fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build zlib fail!\n"
        return 1
    fi
    
    return 0
}
build_xzutils()
{
    module_pack="xz-5.2.2.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the xzutils package from server\n"
        wget http://tukaani.org/xz/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd xz*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
                
    if [ 0 -ne ${?} ]; then
        echo "configure xzutils fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build xzutils fail!\n"
        return 1
    fi
    
    return 0
}
build_libiconv()
{
    module_pack="libiconv-1.16.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the libiconv package from server\n"
        wget http://ftp.gnu.org/pub/gnu/libiconv/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libiconv*/
    patch -p0 <${PATCH_ROOT}/libiconv.patch
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --enable-static=yes --with-pic=yes
                
    if [ 0 -ne ${?} ]; then
        echo "configure libiconv fail!\n"
        return 1
    fi
    
    make clean  
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build libiconv fail!\n"
        return 1
    fi
    
    return 0
}
build_libxml2()
{
    module_pack="Python-2.7.tgz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}/${module_pack} ]; then
        echo "start get the Python package from server\n"
        wget https://www.python.org/ftp/python/2.7/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd Python*/
    PYTHON_ROOT=`pwd`

    module_pack="libxml2-2.9.7.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the libxml2 package from server\n"
        wget ftp://xmlsoft.org/libxml2/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libxml2*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes --enable-shared=no --with-sax1 --with-zlib=${EXTEND_ROOT} --with-iconv=${EXTEND_ROOT} --with-python=${PYTHON_ROOT}
                
    if [ 0 -ne ${?} ]; then
        echo "configure libxml2 fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build libxml2 fail!\n"
        return 1
    fi
    
    return 0
}

build_freetype()
{
    module_pack="freetype-2.6.1.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the freetype package from server\n"
        wget https://download.savannah.gnu.org/releases/freetype/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd freetype*/
    
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
                
    if [ 0 -ne ${?} ]; then
        echo "configure freetype fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build freetype fail!\n"
        return 1
    fi
    
    return 0
}
build_fontconfig()
{
    module_pack="fontconfig-2.12.91.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the fontconfig package from server\n"
        wget https://www.freedesktop.org/software/fontconfig/release/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd fontconfig*/
    
    export FREETYPE_CFLAGS=${EXTEND_ROOT}/include
    export FREETYPE_LIBS=${EXTEND_ROOT}/lib
    
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes --enable-iconv --enable-libxml2  --with-pkgconfigdir=${EXTEND_ROOT}/lib/
                
    if [ 0 -ne ${?} ]; then
        echo "configure fontconfig fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build fontconfig fail!\n"
        return 1
    fi
    
    return 0
}
build_frei0r_plugins()
{
    module_pack="frei0r-plugins-1.6.1.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the frei0r-plugins package from server\n"
        wget https://files.dyne.org/frei0r/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd frei0r-plugins*/
    
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
                
    if [ 0 -ne ${?} ]; then
        echo "configure frei0r-plugins fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build frei0r-plugins fail!\n"
        return 1
    fi
    
    return 0
}
build_fdkaac()
{
    module_pack="fdk-aac-v0.1.5.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the fdkaac package from server\n"
        wget https://github.com/mstorsjo/fdk-aac/archive/v0.1.5.tar.gz -O ${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd fdk-aac*/
    
    ./autogen.sh
    
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
                
    if [ 0 -ne ${?} ]; then
        echo "configure fdk-aac fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build fdk-aac fail!\n"
        return 1
    fi
    
    return 0
}
build_x264()
{
    module_pack="x264-snapshot-20190814-2245-stable.tar.bz2"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the x264 package from server\n"
        wget http://download.videolan.org/pub/videolan/x264/snapshots/${module_pack}
    fi
    tar -jxvf ${module_pack}
    ##set the env config
    set_extend_config
    cd x264*/
    
    ./configure --prefix=${EXTEND_ROOT} \
                --enable-static \
                --enable-pic \
                --disable-opencl  \
                --disable-avs \
                --disable-cli \
                --disable-ffms \
                --disable-gpac  \
                --disable-lavf  \
                --disable-swscale 
    if [ 0 -ne ${?} ]; then
        echo "configure x264 fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build x264 fail!\n"
        return 1
    fi
    
    return 0
}
build_x265()
{
    module_pack="x265_3.1.2.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the x265 package from server\n"
        wget http://download.videolan.org/pub/videolan/x265/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd x265*/build/linux
    ##set the env config
    set_extend_config
    cmake -DCMAKE_INSTALL_PREFIX=${EXTEND_ROOT} -DCMAKE_C_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-fPIC -G "Unix Makefiles" ../../source

    if [ 0 -ne ${?} ]; then
        echo "configure x265 fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build x265 fail!\n"
        return 1
    fi
    
    return 0
}

build_ffad()
{
    module_pack="faad2-2.8.8.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the faad2 package from server\n"
        wget http://downloads.sourceforge.net/faac/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd faad2*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes CFLAGS=-DWORDS_BIGENDIAN
    if [ 0 -ne ${?} ]; then
        echo "configure faad2 fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build faad2 fail!\n"
        return 1
    fi
    
    return 0
}

build_faac()
{
    module_pack="faac-1.29.9.2.tar.gz"
    if [ "$gcc_version" = "4.3.4" ];then
       module_pack="faac-1.28.tar.gz"
    fi
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the faac-1 package from server\n"
        wget http://downloads.sourceforge.net/faac/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd faac*/
    patch -p0 <${PATCH_ROOT}/faac.patch
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes CFLAGS=-DWORDS_BIGENDIAN
    if [ 0 -ne ${?} ]; then
        echo "configure faac fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build faac fail!\n"
        return 1
    fi
    
    return 0
}

build_lame()
{
    module_pack="lame-3.100.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the lame package from server\n"
        wget https://jaist.dl.sourceforge.net/project/lame/lame/3.100/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd lame*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure lame fail!\n"
        return 1
    fi
    
    make clean
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build lame fail!\n"
        return 1
    fi
    
    return 0
}


build_opencore_amr()
{
    module_pack="opencore-amr-0.1.5.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the opencore-amr package from server\n"
        wget https://nchc.dl.sourceforge.net/project/opencore-amr/opencore-amr/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd opencore-amr*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure opencore-amr fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build opencore-amr fail!\n"
        return 1
    fi
    
    return 0
}

build_openjpeg()
{
    module_pack="openjpeg-v2.3.0.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the openjpeg package from server\n"
        wget https://github.com/uclouvain/openjpeg/archive/v2.3.0.tar.gz -O ${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd openjpeg*/
    
    mkdir build
    
    cd build
    
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${EXTEND_ROOT} -DCMAKE_C_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-fPIC
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build openjpeg fail!\n"
        return 1
    fi
    
    return 0
}

build_rubberband()
{
    module_pack="rubberband-v1.8.1.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the rubberband package from server\n"
        wget https://bitbucket.org/breakfastquay/rubberband/get/v1.8.1.tar.gz -O ${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd *rubberband*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure rubberband fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build rubberband fail!\n"
        return 1
    fi
    
    return 0
}
build_openssl()
{
    module_pack="OpenSSL_1_0_2s.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the openssl package from server\n"
        wget https://www.openssl.org/source/old/0.9.x/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd openssl*/
                    
    if [ 0 -ne ${?} ]; then
        echo "get openssl fail!\n"
        return 1
    fi
    
    ./config shared --prefix=${EXTEND_ROOT}
    if [ 0 -ne ${?} ]; then
        echo "config openssl fail!\n"
        return 1
    fi
    
    make clean
    
    make
    if [ 0 -ne ${?} ]; then
        echo "make openssl fail!\n"
        return 1
    fi
    make test
    if [ 0 -ne ${?} ]; then
        echo "make test openssl fail!\n"
        return 1
    fi
    make install_sw
    if [ 0 -ne ${?} ]; then
        echo "make install openssl fail!\n"
        return 1
    fi
    
    return 0
}

build_rtmpdump()
{
    module_pack="rtmpdump-2.3.tgz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the rtmpdump package from server\n"
        wget http://rtmpdump.mplayerhq.hu/download/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd *rtmpdump*/
    #./configure ${config_args} --prefix=${EXTEND_ROOT} 
    EXTEND_ROOT_SED=$(echo ${EXTEND_ROOT} |sed -e 's/\//\\\//g')
    sed -i "s/prefix\=\/usr\/local/prefix\=${EXTEND_ROOT_SED}/" Makefile 
    if [ 0 -ne ${?} ]; then
        echo "configure rtmpdump fail!\n"
        return 1
    fi
    
    sed -i "s/LIB_OPENSSL\=-lssl -lcrypto/LIB_OPENSSL\=-L${EXTEND_ROOT_SED}\/lib\/ -lssl -lcrypto -ldl/" Makefile 
    if [ 0 -ne ${?} ]; then
        echo "configure rtmpdump open ssl fail!\n"
        return 1
    fi
    
    sed -i "s/prefix\=\/usr\/local/prefix\=${EXTEND_ROOT_SED}/" ./librtmp/Makefile 
    if [ 0 -ne ${?} ]; then
        echo "configure librtmp fail!\n"
        return 1
    fi
    
    C_INCLUDE_PATH=${EXTEND_ROOT}/include/:${C_INCLUDE_PATH:=/usr/local/include/}
    export C_INCLUDE_PATH 
    CPLUS_INCLUDE_PATH=${EXTEND_ROOT}/include/:${CPLUS_INCLUDE_PATH:=/usr/local/include/}
    export CPLUS_INCLUDE_PATH
    LIBRARY_PATH=${EXTEND_ROOT}/lib:${LIBRARY_PATH:=/usr/local/lib/}
    export LIBRARY_PATH 
                
    make SHARED=yes && make install SHARED=yes
    
    if [ 0 -ne ${?} ]; then
        echo "build rtmpdump fail!\n"
        return 1
    fi
    
    return 0
}

build_opus()
{
    module_pack="opus-1.2.1.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the opus package from server\n"
        wget https://archive.mozilla.org/pub/opus/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd opus*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure opus fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build opus fail!\n"
        return 1
    fi
    
    return 0
}
build_libunistring()
{
    module_pack="libunistring-0.9.10.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the libunistring package from server\n"
        wget http://mirrors.ustc.edu.cn/gnu/libunistring/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libunistring*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes --libdir=${EXTEND_ROOT}/lib/ --includedir=${EXTEND_ROOT}/include/ 
    if [ 0 -ne ${?} ]; then
        echo "configure libunistring fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build libunistring fail!\n"
        return 1
    fi
    
    return 0
}
build_gmp()
{
    module_pack="gmp-6.1.2.tar.bz2"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the gmp package from server\n"
        wget https://gmplib.org/download/gmp/${module_pack}
    fi
    tar -jxvf ${module_pack}
    
    cd gmp*/
    ./configure --prefix=${EXTEND_ROOT} --with-pic=yes --libdir=${EXTEND_ROOT}/lib/ --includedir=${EXTEND_ROOT}/include/ 
    if [ 0 -ne ${?} ]; then
        echo "configure gmp fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build gmp fail!\n"
        return 1
    fi
    
    return 0
}

build_soxr()
{
    module_pack="soxr-code.zip"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the soxr package from server\n"
        wget https://sourceforge.net/code-snapshots/git/s/so/soxr/code.git/soxr-code-e064aba6ac16fb8f1fa64bc692e54230cec1b3af.zip -O ${module_pack}
    fi
    unzip -o ${module_pack}
    
    cd soxr*/
    mkdir build
    cd build
    
    cmake -Wno-dev -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-fPIC -DBUILD_SHARED_LIBS:BOOL=ON -DCMAKE_INSTALL_PREFIX=${EXTEND_ROOT} ..
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build soxr fail!\n"
        return 1
    fi
    
    cmake -Wno-dev -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-fPIC -DBUILD_SHARED_LIBS:BOOL=OFF -DCMAKE_INSTALL_PREFIX=${EXTEND_ROOT} ..
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build soxr fail!\n"
        return 1
    fi
       
    return 0
}
build_speex()
{
    module_pack="speex-1.2.0.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the speex package from server\n"
        wget http://downloads.us.xiph.org/releases/speex/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd speex*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure speex fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build speex fail!\n"
        return 1
    fi
    
    return 0
}
build_ogg()
{
    module_pack="libogg-1.3.3.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the ogg package from server\n"
        wget http://downloads.xiph.org/releases/ogg/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libogg*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure ogg fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build ogg fail!\n"
        return 1
    fi
    
    return 0
}
build_vorbis()
{
    module_pack="libvorbis-1.3.5.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the vorbis package from server\n"
        wget http://downloads.xiph.org/releases/vorbis/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libvorbis*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure vorbis fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build vorbis fail!\n"
        return 1
    fi
    
    return 0
}
build_theora()
{
    module_pack="libtheora-1.1.1.tar.bz2"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the theora package from server\n"
        wget http://downloads.xiph.org/releases/theora/${module_pack}
    fi
    tar -jxvf ${module_pack}
    
    cd libtheora*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes --with-ogg=${EXTEND_ROOT} --with-vorbis=${EXTEND_ROOT} 
    if [ 0 -ne ${?} ]; then
        echo "configure theora fail!\n"
        return 1
    fi
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build theora fail!\n"
        return 1
    fi
    
    return 0
}
build_vidstab()
{
    module_pack="vidstab-v1.1.0.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the vidstab package from server\n"
        wget https://github.com/georgmartius/vid.stab/archive/v1.1.0.tar.gz -O ${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd vid.stab*/
    cmake -DCMAKE_INSTALL_PREFIX:PATH=${EXTEND_ROOT} -DBUILD_SHARED_LIBS=NO -DCMAKE_C_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-fPIC
    if [ 0 -ne ${?} ]; then
        echo "configure vidstab fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build vidstab fail!\n"
        return 1
    fi
    
    return 0
}

build_yasm()
{
    module_pack="yasm-1.3.0.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the yasm package from server\n"
        wget http://www.tortall.net/projects/yasm/releases/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd yasm*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure yasm fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build yasm fail!\n"
        return 1
    fi
    
    return 0
}
build_nasm()
{
    module_pack="nasm-2.13.03.tar.bz2"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the nasm package from server\n"
        wget https://www.nasm.us/pub/nasm/releasebuilds/2.13.03/${module_pack}
    fi
    tar -jxvf ${module_pack}
    
    cd nasm*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure nasm fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build nasm fail!\n"
        return 1
    fi
    
    return 0
}
build_libvpx()
{
    module_pack="libvpx-1.5.0.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the libvpx package from server\n"
        wget https://github.com/webmproject/libvpx/archive/v1.5.0.tar.gz -O ${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libvpx*/

    ./configure --prefix=${EXTEND_ROOT} --enable-pic --enable-shared
    if [ 0 -ne ${?} ]; then
        echo "configure libvpx fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build libvpx fail!\n"
        return 1
    fi
    
    return 0
}
build_libwebp()
{
    module_pack="libwebp-0.6.1.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the libwebp package from server\n"
        wget http://downloads.webmproject.org/releases/webp/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libwebp*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure libwebp fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build libwebp fail!\n"
        return 1
    fi
    
    return 0
}

build_xvidcore()
{
    module_pack="xvidcore-1.3.5.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the xvidcore package from server\n"
        wget https://downloads.xvid.com/downloads/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd xvidcore*/build/generic
    
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure xvidcore fail!\n"
        return 1
    fi

    make
    
    if [ 0 -ne ${?} ]; then
        echo "build xvidcore fail!\n"
        return 1
    fi
    
    make install
    
    return 0
}
build_zimg()
{
    module_pack="zimg-v3.1.0.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the zimg package from server\n"
        wget https://github.com/buaazp/zimg/archive/v3.1.0.tar.gz -O ${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd zimg*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure zimg fail!\n"
        return 1
    fi
    
    make clean
    make&&make install
    
    if [ 0 -ne ${?} ]; then
        echo "build zimg fail!\n"
        return 1
    fi
    
    return 0
}
build_libass()
{
    module_pack="libass-0.14.0.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the libass package from server\n"
        wget https://github.com/libass/libass/releases/download/0.14.0/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libass*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
    if [ 0 -ne ${?} ]; then
        echo "configure libass fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build libass fail!\n"
        return 1
    fi
    
    return 0
}

build_pcre()
{
    module_pack="pcre-8.39.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the pcre package from server\n"
        wget https://sourceforge.net/projects/pcre/files/pcre/8.39/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd pcre*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
                
    if [ 0 -ne ${?} ]; then
        echo "configure pcre fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build pcre fail!\n"
        return 1
    fi
    
    return 0
}


build_bzip2()
{
    module_pack="bzip2-1.0.6.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the bzip2 package from server\n"
        wget http://www.bzip.org/1.0.6/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd bzip2*/
    #./configure ${config_args} --prefix=${EXTEND_ROOT}
    EXTEND_ROOT_SED=$(echo ${EXTEND_ROOT} |sed -e 's/\//\\\//g')
    sed -i "s/PREFIX\=\/usr\/local/PREFIX\=${EXTEND_ROOT_SED}/" Makefile    
    sed -i "s/CFLAGS=-Wall -Winline -O2 -g/CFLAGS\=-Wall -Winline -O2 -fPIC -g/" Makefile
    if [ 0 -ne ${?} ]; then
        echo "sed bzip2 fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build bzip2 fail!\n"
        return 1
    fi
    
    return 0
}

build_zeromq()
{
    module_pack="zeromq-4.2.5.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the zeromq package from server\n"
        wget https://github.com/zeromq/libzmq/releases/download/v4.2.5/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd zeromq*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --with-pic=yes
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build zeromq fail!\n"
        return 1
    fi
    
    return 0
}


build_extend_modules()
{
    ##set the env config
    set_extend_config
    
    build_yasm
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_nasm
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_bzip2
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_zlib
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_xzutils
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_pcre
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_libiconv
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_libxml2
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_freetype
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    
    build_frei0r_plugins
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_fdkaac
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_x264
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_x265
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_ffad
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_faac
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_lame
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_opencore_amr
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_openjpeg
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_opus
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_libunistring
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_gmp
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_openssl
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_rtmpdump
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    #build_soxr
    #if [ 0 -ne ${?} ]; then
    #    return 1
    #fi
    build_speex
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_ogg
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_vorbis
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_theora
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    #build_vidstab
    #if [ 0 -ne ${?} ]; then
    #    return 1
    #fi
    build_libvpx
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_libwebp
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_xvidcore
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_zeromq
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_ffmpeg
    if [ 0 -ne ${?} ]; then
        return 1
    fi

    return 0
}

setup()
{
    ##set the env config
    set_extend_config
    
    if [ "${WITH_3RDPARTY}" == "TRUE" ];then
        download_3rd
        if [ 0 -ne ${?} ]; then
            return 1
        fi
        build_extend_modules
        if [ 0 -ne ${?} ]; then
            return 1
        fi 
    fi
    echo "make the all modules success!\n"
    cd ${MK_ROOT}
    return 0
}
package_all()
{
    # copy the ffmpeg include 
    cp -R ${EXTEND_ROOT}/include/libavutil     ${CURRENT_PATH}/libFFMPEG/include
    cp -R ${EXTEND_ROOT}/include/libswscale    ${CURRENT_PATH}/libFFMPEG/include
    cp -R ${EXTEND_ROOT}/include/libswresample ${CURRENT_PATH}/libFFMPEG/include
    cp -R ${EXTEND_ROOT}/include/libpostproc   ${CURRENT_PATH}/libFFMPEG/include
    cp -R ${EXTEND_ROOT}/include/libavcodec    ${CURRENT_PATH}/libFFMPEG/include
    cp -R ${EXTEND_ROOT}/include/libavformat   ${CURRENT_PATH}/libFFMPEG/include
    cp -R ${EXTEND_ROOT}/include/libavfilter   ${CURRENT_PATH}/libFFMPEG/include
    cp -R ${EXTEND_ROOT}/include/libavdevice   ${CURRENT_PATH}/libFFMPEG/include

    cd ${CURRENT_PATH} 
    
    tar -zcvf libFFMPEG-${host_type}-gcc${gcc_version}.tar.gz libFFMPEG/
    echo "package  success!\n"
}


all_modules_func()
{
        TITLE="Setup all the module"

        TEXT[1]="build the all module"
        FUNC[1]="setup"     

        TEXT[2]="package the all module"
        FUNC[2]="package_all"     
}


STEPS[1]="all_modules_func"

#
# Sets QUIT variable so script will finish.
#
quit()
{
    QUIT=$1
}

mkdir -p ${PREFIX_ROOT}
mkdir -p ${PREFIX_ROOT}/include
mkdir -p ${PREFIX_ROOT}/sbin
mkdir -p ${PREFIX_ROOT}/lib


QUIT=0
while [ "$QUIT" == "0" ]; do
    set_extend_config
    OPTION_NUM=1
    if [ ! -x "`which wget 2>/dev/null`" ]; then
        echo "Need to install wget."
        break 
    fi
    for s in $(seq ${#STEPS[@]}) ; do
        ${STEPS[s]}

        echo "----------------------------------------------------------"
        echo " Step $s: ${TITLE}"
        echo "----------------------------------------------------------"

        for i in $(seq ${#TEXT[@]}) ; do
            echo "[$OPTION_NUM] ${TEXT[i]}"
            OPTIONS[$OPTION_NUM]=${FUNC[i]}
            let "OPTION_NUM+=1"
        done

        # Clear TEXT and FUNC arrays before next step
        unset TEXT
        unset FUNC

        echo ""
    done

    echo "[$OPTION_NUM] Exit Script"
    OPTIONS[$OPTION_NUM]="quit"
    echo ""
    echo -n "Option: "
    read our_entry
    echo ""
    ${OPTIONS[our_entry]} ${our_entry}
    echo ""
done

exit 0

