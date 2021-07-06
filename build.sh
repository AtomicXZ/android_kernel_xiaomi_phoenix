#!/usr/bin/env bash

# Download clang and kernel source
git clone --depth=1 https://github.com/AtomicXZ/android_kernel_xiaomi_phoenix.git -b LA.UM.9.1-x kernel
cd kernel
git clone --depth=1 https://github.com/kdrag0n/proton-clang clang
git clone https://github.com/AtomicXZ/AnyKernel3 AnyKernel

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
DTB=$(pwd)/out/arch/arm64/boot/dts/qcom/sdmmagpie.dtb
TANGGAL=$(date +"%d-%m_%H-%M")
START=$(date +"%s")
CLANG_VERSION=$(clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
BRANCH=$(git rev-parse --abbrev-ref HEAD)

export ARCH=arm64
export KBUILD_BUILD_HOST="NightBlade"
export KBUILD_BUILD_USER="YuanziX"
export PATH=$PWD/clang/bin:$PATH

# Info
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id=$chat_id \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>• NightBlade Kernel •</b>%0A<b>branch:-</b> <code>$BRANCH</code>%0A<b>Under commit</b> <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0A<b>Using compiler:- </b> <code>$CLANG_VERSION</code>%0A<b>Started on:- </b> <code>$(date)</code>"
}

# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id=$chat_id \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | <b>$CLANG_VERSION</b>"
}

# Send Error log
function finerr() {
    LOG=$(echo *.log)
    curl -F document=@$LOG "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id=$chat_id \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build threw an error(s)"
    exit 1
}

# Compile build
function compile() {
   make O=out ARCH=arm64 phoenix_defconfig
       make -j$(nproc --all) O=out \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      NM=llvm-nm \
                      OBJCOPY=llvm-objcopy \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip 2>&1 | tee build.log

if [[ -f ${IMAGE} && ${DTBO} ]]
then
   mv -f $IMAGE ${DTBO} ${DTB} AnyKernel
else
   finerr
fi
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 NightBlade-phoenix-${BRANCH}-${TANGGAL}.zip *
    cd ..
}
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
