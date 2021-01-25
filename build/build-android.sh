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

ANDROID_NDK=${THIRD_ROOT}android-ndk-r19c
SDK_VERSION=21
HOST_CPU=armv7-a
#ARCH=arm64
ARCH=arm
HOST=arm-linux

ADDI_LDFLAGS="-fPIE -pie L/${EXTEND_ROOT}/lib"
ADDI_CFLAGS="-I${EXTEND_ROOT}/include -fPIE -pie -march=${HOST_CPU} -mfloat-abi=softfp -mfpu=neon"

SYSROOT=${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot
TOOLCHAIN=${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin

PREFIX=$(pwd)/android/${HOST_CPU}
x264=$(pwd)/x264/android/${HOST_CPU}
export PATH=$x264/bin:$PATH
export PATH=$x264/include:$PATH
export PATH=$x264/lib:$PATH
#export PKG_CONFIG_PATH=$x264/lib/pkgconfig:$PKG_CONFIG_PATH

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
    cat ${CURRENT_PATH}/3rd_party/3rd-android.list|while read LINE
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

    ./configure --prefix=$EXTEND_ROOT \
                --toolchain=clang-usan \
                --enable-cross-compile \
                --target-os=android \
                --arch=$ARCH \
                --sysroot=$SYSROOT \
                --cc=$TOOLCHAIN/armv7a-linux-androideabi21-clang \
                --cxx=$TOOLCHAIN/armv7a-linux-androideabi21-clang++ \
                --strip=$TOOLCHAIN/arm-linux-androideabi-strip \
                --extra-cflags="$ADDI_CFLAGS" \
                --extra-ldflags="$ADDI_LDFLAGS" \
                --disable-encoders \
                --disable-decoders \
                --disable-avdevice \
                --disable-static \
                --disable-doc \
                --disable-ffplay \
                --disable-network \
                --disable-doc \
                --disable-symver \
                --disable-ffprobe \
                --enable-neon \
                --enable-shared \
                --enable-libx264 \
                --enable-gpl \
                --enable-pic \
                --enable-jni \
                --enable-pthreads \
                --enable-mediacodec \
                --enable-encoder=aac \
                --enable-encoder=gif \
                --enable-encoder=libopenjpeg \
                --enable-encoder=libmp3lame \
                --enable-encoder=libwavpack \
                --enable-encoder=libx264 \
                --enable-encoder=mpeg4 \
                --enable-encoder=pcm_s16le \
                --enable-encoder=png \
                --enable-encoder=mjpeg \
                --enable-encoder=srt \
                --enable-encoder=subrip \
                --enable-encoder=yuv4 \
                --enable-encoder=text \
                --enable-decoder=aac \
                --enable-decoder=aac_latm \
                --enable-decoder=libopenjpeg \
                --enable-decoder=mp3 \
                --enable-decoder=mpeg4_mediacodec \
                --enable-decoder=pcm_s16le \
                --enable-decoder=flac \
                --enable-decoder=flv \
                --enable-decoder=gif \
                --enable-decoder=png \
                --enable-decoder=srt \
                --enable-decoder=xsub \
                --enable-decoder=yuv4 \
                --enable-decoder=vp8_mediacodec \
                --enable-decoder=h264_mediacodec \
                --enable-decoder=hevc_mediacodec \
                --enable-bsf=aac_adtstoasc \
                --enable-bsf=h264_mp4toannexb \
                --enable-bsf=hevc_mp4toannexb \
                --enable-bsf=mpeg4_unpack_bframes\
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

build_ndk()
{
    module_pack="android-ndk-r19c-linux-x86_64.zip"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the android-ndk package from server\n"
        wget http://139.9.183.199:10608/download/${module_pack}
    fi
    unzip -o ${module_pack}
    
    cd android-ndk*/                
    if [ 0 -ne ${?} ]; then
        echo "configure android-ndk fail!\n"
        return 1
    fi
    export ANDROID_NDK=${THIRD_ROOT}android-ndk-r19c
    
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
                --cross-prefix=$CROSS_PREFIX \
                --sysroot=${SYSROOT} \
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

    build_libvpx
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_xvidcore
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

    cp -Rd ${EXTEND_ROOT}/lib/*   ${CURRENT_PATH}/libFFMPEG/lib/

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

