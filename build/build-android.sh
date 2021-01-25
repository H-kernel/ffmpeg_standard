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

export SDK_VERSION=21
#ARCH=arm64
export ARCH=arm64



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



build_ffmpeg()
{    
    cd ${MK_ROOT}/ffmpeg*    
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
                --cc=${CC} \
                --cxx=${CXX} \
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

ndk_configure()
{
    if [ "$ARCH" = "arm64" ]; then
        export PLATFORM_PREFIX="aarch64-linux-android"
        export HOST="aarch64"
    elif [ "$ARCH" = "arm" ]; then
        export PLATFORM_PREFIX="arm-linux-androideabi"
        export HOST="arm"
    elif [ "$ARCH" = "armv7a" ]; then
        export PLATFORM_PREFIX="armv7a-linux-androideabi"
        export HOST="armv7a"
    elif [ "$ARCH" = "i686" ]; then
        export PLATFORM_PREFIX="i686-linux-android"
        export HOST="i686"
    elif [ "$ARCH" = "x86_64" ]; then
        export PLATFORM_PREFIX="x86_64-linux-android"
        export HOST="x86_64"
    else
        echo "unsupport ARCH:$ARCH."
        return -1
    fi

    export PREBUILT=${ANDROID_NDK}/toolchains/llvm/prebuilt/
    export SYSROOT=${PREBUILT}/linux-x86_64/sysroot
    export TOOLCHAIN=${PREBUILT}/linux-x86_64/bin

    export CC=${TOOLCHAIN}/${PLATFORM_PREFIX}${SDK_VERSION}-clang
    export CXX=${TOOLCHAIN}/${PLATFORM_PREFIX}${SDK_VERSION}-clang++

    export LLVM_AR=${TOOLCHAIN}/llvm-ar
    export LLVM_LINKER=${TOOLCHAIN}/llvm-ld
    export LLVM_NM=${TOOLCHAIN}/llvm-nm
    export LLVM_OBJDUMP=${TOOLCHAIN}/llvm-objdump
    export LLVM_RANLIB=${TOOLCHAIN}/llvm-ranlib

    export CROSS_PREFIX=${TOOLCHAIN}/${PLATFORM_PREFIX}-

    export ADDI_LDFLAGS="-fPIE -pie L/${EXTEND_ROOT}/lib"
    export ADDI_CFLAGS="-I${EXTEND_ROOT}/include -fPIE -pie -march=${HOST} -mfloat-abi=softfp -mfpu=neon"

}

build_ndk()
{
    module_pack=android-ndk-r21d-linux-x86_64.zip
    cd ${THIRD_ROOT}

    cd android-ndk*/                
    if [ 0 -eq ${?} ]; then
        NDK_PATH=`pwd`
        export ANDROID_NDK=${NDK_PATH}
        ndk_configure
        if [ 0 -ne ${?} ]; then
            echo "configure android-ndk fail!\n"
            return 1
        fi
        return 0
    fi

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
    NDK_PATH=`pwd`
    export ANDROID_NDK=${NDK_PATH}
    ndk_configure
    if [ 0 -ne ${?} ]; then
        echo "configure android-ndk fail!\n"
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
    cd x264*/
    
    ./configure --prefix=${EXTEND_ROOT} \
                --host=${PLATFORM_PREFIX} \
                --cross-prefix=${CROSS_PREFIX} \
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
    
    cd x265*/build/
    mkdir ./${PLATFORM_PREFIX}
    cd ./${PLATFORM_PREFIX}

    cmake ../../source \
          -DCMAKE_INSTALL_PREFIX=${EXTEND_ROOT} \
          -DCMAKE_SYSTEM_NAME=Android \
          -DCMAKE_ANDROID_ARCH_ABI=${HOST} \
          -DCMAKE_ANDROID_NDK=${ANDROID_NDK} \
          -DCMAKE_ANDROID_STL_TYPE=gnustl_static \
          -DCMAKE_C_COMPILER=${CC} \
          -DCMAKE_C_FLAGS=${ADDI_CFLAGS} \
          -DCMAKE_CXX_COMPILER=${CXX} \
          -DCMAKE_CXX_FLAGS=${ADDI_CFLAGS} \
          -DCMAKE_AR=${LLVM_AR} \
          -DCMAKE_LINKER=${LLVM_LINKER} \
          -DCMAKE_NM=${LLVM_NM} \
          -DCMAKE_OBJDUMP=${LLVM_OBJDUMP} \
          -DCMAKE_RANLIB=${LLVM_RANLIB} \
          -DENABLE_SHARED=0 \
          -DENABLE_TESTS=0 \
          -DNEON_ANDROID=1

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


build_extend_modules()
{
    build_ndk
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
    build_ffmpeg
    if [ 0 -ne ${?} ]; then
        return 1
    fi

    return 0
}

setup()
{
    
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

