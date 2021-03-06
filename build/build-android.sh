#!/bin/bash
#set -x
set -o nounset
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

export API=24
#export ARCH=arm64
export ARCH=armv7a



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
    if [ ! -f ${CURRENT_PATH}/3rd_party/3rd-android.list ]; then
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
        export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig/
    else
        export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig/:${PKG_CONFIG_PATH}
    fi
    
    find=`env|grep PATH`
    if [ "find${find}" == "find" ]; then    
        export PATH=${PREFIX}/bin/
    else
        export PATH=${PREFIX}/bin/:${PATH}
    fi

    pkg-config --list-all
}

build_ffmpeg()
{    
    cd ${MK_ROOT}/ffmpeg*    
    cd ffbuild/
    chmod +x *.sh
    cd ..
    chmod +x configure

    set_extend_config
    
    export debug_tag=--disable-debug
    
    if [ "${WITH_DEBUG}" == "TRUE" ];then
        export debug_tag="--enable-debug --extra-cflags=-g --extra-ldflags=-g"
    fi

    if [ "$ARCH" = "arm64" ]; then
        #arm64-v8a
        HOST_ARCH=aarch64
        MARCH=armv8-a
    elif [ "$ARCH" = "armv7a" ]; then
        #armeabi-v7a
        HOST_ARCH=arm
        MARCH=armv7-a
    else
        echo "unsupport ARCH:$ARCH."
        return -1
    fi

    ./configure --prefix=$PREFIX \
                --toolchain=clang-usan \
                --pkg-config="pkg-config --static" \
                --enable-cross-compile \
                --target-os=android \
                --arch=${HOST_ARCH} \
                --cross-prefix=$CROSS_PREFIX \
                --cc=${CC} \
                --cxx=${CXX} \
                --ar=${AR} \
                --strip=${CROSS_PREFIX}strip \
                --extra-cflags="-I${PREFIX}/include -fPIE -pie -march=${MARCH} -mfloat-abi=softfp -mfpu=neon" \
                --extra-ldflags="-fPIE -pie -L/${PREFIX}/lib" \
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
                --enable-libx265 \
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
    
    mv ${PREFIX}/include/libavutil/time.h ${PREFIX}/include/libavutil/avtime.h
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
    
    mv ${PREFIX}/include/libavutil/time.h ${PREFIX}/include/libavutil/avtime.h
    return 0
}

ndk_configure()
{
    export PREBUILT=${ANDROID_NDK}/toolchains/llvm/prebuilt
    export SYSROOT=${PREBUILT}/linux-x86_64/sysroot
    export TOOLCHAIN=${PREBUILT}/linux-x86_64

    if [ "$ARCH" = "arm64" ]; then
        #arm64-v8a
        export PREFIX=${EXTEND_ROOT}/arm64-v8a
        export TARGET=aarch64-linux-android
        export CC=${TOOLCHAIN}/bin/${TARGET}${API}-clang
        export CXX=${TOOLCHAIN}/bin/${TARGET}${API}-clang++
        export CROSS_PREFIX=${TOOLCHAIN}/bin/aarch64-linux-android-
    elif [ "$ARCH" = "armv7a" ]; then
        #armeabi-v7a
        export PREFIX=${EXTEND_ROOT}/armeabi-v7a
        export TARGET=armv7a-linux-androideabi
        export CC=${TOOLCHAIN}/bin/${TARGET}${API}-clang
        export CXX=${TOOLCHAIN}/bin/${TARGET}${API}-clang++
        export CROSS_PREFIX=${TOOLCHAIN}/bin/arm-linux-androideabi-
    else
        echo "unsupport ARCH:$ARCH."
        return -1
    fi

    export NM=${CROSS_PREFIX}nm
    export AR=${CROSS_PREFIX}ar

    echo "********************************NDK ENV***************************************"

    echo "PREBUILT=${PREBUILT}"
    echo "SYSROOT=${SYSROOT}"
    echo "TOOLCHAIN=${TOOLCHAIN}"
    echo "CC=${CC}"
    echo "CXX=${CXX}"
    echo "NM=${NM}"
    echo "AR=${AR}"
    echo "CROSS_PREFIX=${CROSS_PREFIX}"

    echo "******************************************************************************"

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

    if [ "$ARCH" = "arm64" ]; then
        #arm64-v8a
        HOST=aarch64-linux-android
    elif [ "$ARCH" = "armv7a" ]; then
        #armeabi-v7a
        HOST=armv7a-linux-android
    else
        echo "unsupport ARCH:$ARCH."
        return -1
    fi
    
    ./configure --prefix=${PREFIX} \
                --host=${HOST} \
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
    mkdir ./${TARGET}
    cd ./${TARGET}
    C_CXX_FLAGS=""
    if [ "$ARCH" = "arm64" ]; then
        #arm64-v8a
        ARCH_ABI=arm64-v8a
        C_CXX_FLAGS="-I${PREFIX}/include -fPIE -fPIC -march=armv8-a -mfloat-abi=softfp -mfpu=neon"
    elif [ "$ARCH" = "armv7a" ]; then
        #armeabi-v7a
        ARCH_ABI=armeabi-v7a
        C_CXX_FLAGS="-I${PREFIX}/include -fPIE -fPIC  -march=armv7a -mfloat-abi=softfp -mfpu=neon"
    else
        echo "unsupport ARCH:$ARCH."
        return -1
    fi


    cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
          -DCMAKE_SYSTEM_NAME=Android \
          -DCMAKE_SYSTEM_VERSION=${API} \
          -DCMAKE_ANDROID_ARCH_ABI=${ARCH_ABI} \
          -DCMAKE_ANDROID_NDK=${ANDROID_NDK} \
          -DCMAKE_CXX_FLAGS="${C_CXX_FLAGS}" \
          -DCMAKE_C_FLAGS="${C_CXX_FLAGS}" \
          -DCMAKE_ANDROID_STL_TYPE=gnustl_static \
          -DNEON_ANDROID=1 \
          -G "Unix Makefiles" ../../source 

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

        TEXT[3]="build the ndk module"
        FUNC[3]="build_ndk"
        
        TEXT[4]="build the x264 module"
        FUNC[4]="build_x264"

        TEXT[5]="build the x265 module"
        FUNC[5]="build_x265"  
        
        TEXT[6]="build the ffmpeg module"
        FUNC[6]="build_ffmpeg"  
        
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

