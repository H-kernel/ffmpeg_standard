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


CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli"

ARCHS="arm64 x86_64 i386 armv7 armv7s"

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
    if [ ! -f ${CURRENT_PATH}/3rd_party/3rd-ios.list ]; then
        echo "there is no 3rd package list\n"
        return 1
    fi
    cat ${CURRENT_PATH}/3rd_party/3rd-ios.list|while read LINE
    do
        name=`echo "${LINE}"|awk -F '|' '{print $1}'`
        url=`echo "${LINE}"|awk -F '|' '{print $2}'`
        package=`echo "${LINE}"|awk -F '|' '{print $3}'`
        if [ ! -f ${THIRD_ROOT}/${package} ]; then
            echo "begin:download :${name}..................."
            curl ${url} -o ${THIRD_ROOT}/${package}
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

    CFLAGS="-arch $ARCH"
    ASFLAGS=

	if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
	then
	    PLATFORM="iPhoneSimulator"
	    CPU=
	    if [ "$ARCH" = "x86_64" ]
	    then
	    	CFLAGS="$CFLAGS -mios-simulator-version-min=8.0"
	    	HOST=
	    else
	    	CFLAGS="$CFLAGS -mios-simulator-version-min=8.0"
			HOST="--host=i386-apple-darwin"
	    fi
	else
	    PLATFORM="iPhoneOS"
	    if [ $ARCH = "arm64" ]
	    then
	        HOST="--host=aarch64-apple-darwin"
			XARCH="-arch aarch64"
	    else
	        HOST="--host=arm-apple-darwin"
			XARCH="-arch arm"
	    fi
        CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=10"
        ASFLAGS="$CFLAGS"
	fi

	XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
	CC="xcrun -sdk $XCRUN_SDK clang"
    CXX="xcrun -sdk $XCRUN_SDK clang++"
	if [ $PLATFORM = "iPhoneOS" ]
	then
	    export AS="${CURRENT_PATH}/script/gas-preprocessor/gas-preprocessor.pl $XARCH -- $CC"
	else
	    export -n AS
	fi
	CXXFLAGS="$CFLAGS"
	LDFLAGS="$CFLAGS"


	CC=$CC ./configure --prefix=$EXTEND_ROOT/$ARCH \
                --disable-programs \
                --pkg-config="pkg-config --static" \
                --enable-cross-compile \
                --arch=${ARCH} \
                --cc="${CC}" \
                --as="$AS" \
                --extra-cflags="-I$EXTEND_ROOT/$ARCH/include -fPIE -pie ${CXXFLAGS}" \
                --extra-ldflags="-fPIE -pie -L/$EXTEND_ROOT/$ARCH/lib ${LDFLAGS}" \
                --disable-encoders \
                --disable-decoders \
                --disable-avdevice \
                --disable-shared \
                --disable-doc \
                --disable-ffplay \
                --disable-network \
                --disable-doc \
                --disable-symver \
                --disable-ffprobe \
                --enable-static \
                --enable-libx264 \
                --enable-gpl \
                --enable-pic \
                --enable-pthreads \
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
                --enable-decoder=pcm_s16le \
                --enable-decoder=flac \
                --enable-decoder=flv \
                --enable-decoder=gif \
                --enable-decoder=png \
                --enable-decoder=srt \
                --enable-decoder=xsub \
                --enable-decoder=yuv4 \
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
    
    mv $EXTEND_ROOT/$ARCH/include/libavutil/time.h $EXTEND_ROOT/$ARCH/include/libavutil/avtime.h
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


build_x264()
{
    module_pack="x264-snapshot-20190814-2245-stable.tar.bz2"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the x264 package from server\n"
        curl -O http://download.videolan.org/pub/videolan/x264/snapshots/${module_pack}
    fi
    tar -jxvf ${module_pack}
    cd x264*/

    echo "building $ARCH..."
	CFLAGS="-arch $ARCH"
    ASFLAGS=

	if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
	then
	    PLATFORM="iPhoneSimulator"
	    CPU=
	    if [ "$ARCH" = "x86_64" ]
	    then
	    	CFLAGS="$CFLAGS -mios-simulator-version-min=8.0"
	    	HOST=
	    else
	    	CFLAGS="$CFLAGS -mios-simulator-version-min=8.0"
			HOST="--host=i386-apple-darwin"
	    fi
	else
	    PLATFORM="iPhoneOS"
	    if [ $ARCH = "arm64" ]
	    then
	        HOST="--host=aarch64-apple-darwin"
			XARCH="-arch aarch64"
	    else
	        HOST="--host=arm-apple-darwin"
			XARCH="-arch arm"
	    fi
        CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=10"
        ASFLAGS="$CFLAGS"
	fi

	XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
	CC="xcrun -sdk $XCRUN_SDK clang"
    CXX="xcrun -sdk $XCRUN_SDK clang++"
	if [ $PLATFORM = "iPhoneOS" ]
	then
	    export AS="${CURRENT_PATH}/script/gas-preprocessor/gas-preprocessor.pl $XARCH -- $CC"
	else
	    export -n AS
	fi
	CXXFLAGS="$CFLAGS"
	LDFLAGS="$CFLAGS"


	CC=$CC ./configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    --extra-cflags="$CFLAGS" \
		    --extra-asflags="$ASFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$EXTEND_ROOT/$ARCH"

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
        curl -O http://download.videolan.org/pub/videolan/x265/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd x265*/build/
    mkdir ./${ARCH}
    cd ./${ARCH}
    C_CXX_FLAGS=""
    if [ "$ARCH" = "arm64" ]; then
        #arm64-v8a
        ARCH_ABI=arm64
        C_CXX_FLAGS="-I$EXTEND_ROOT/$ARCH/include -fPIE -fPIC"
    elif [ "$ARCH" = "armv7a" ]; then
        #armeabi-v7a
        ARCH_ABI=arm
        C_CXX_FLAGS="-I$EXTEND_ROOT/$ARCH/include -fPIE -fPIC"
    else
        echo "unsupport ARCH:$ARCH."
        return -1
    fi


    cmake -DCMAKE_INSTALL_PREFIX=$EXTEND_ROOT/$ARCH \
          -DCMAKE_SYSTEM_NAME=iOS \
          -DCROSS_COMPILE_ARM=1 \
          -DCMAKE_SYSTEM_PROCESSOR=${ARCH_ABI} \
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
        
        TEXT[3]="build the x264 module"
        FUNC[3]="build_x264"

        TEXT[4]="build the x265 module"
        FUNC[4]="build_x265"  
        
        TEXT[5]="build the ffmpeg module"
        FUNC[5]="build_ffmpeg"  
        
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
    if [ ! -x "`which curl 2>/dev/null`" ]; then
        echo "Need to install curl."
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

