#!/bin/bash

MAINPATH=$GITHUB_WORKSPACE
GCC32=$MAINPATH/gcc-arm/bin/
GCC64=$MAINPATH/gcc-arm64/bin/
ANYKERNEL3_DIR=$MAINPATH/AnyKernel3/
TANGGAL=$(TZ=Asia/Jakarta date "+%Y%m%d-%H%M")
COMMIT=$(git rev-parse --short HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
KERNEL_DEFCONFIG=vendor/alioth_user_defconfig
FINAL_KERNEL_ZIP=Hyrax-Alioth-$TANGGAL.zip

export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="archlinux"
export KBUILD_BUILD_USER="darknight"
export GCC_VER=$("$GCC64"aarch64-elf-gcc --version | head -n 1)
export LLD_VER=$("$GCC64"aarch64-elf-ld.lld --version | head -n 1)
export PATH=$GCC64:$GCC32:/usr/bin:$PATH
export IMGPATH="$ANYKERNEL3_DIR/Image"
export DTBPATH="$ANYKERNEL3_DIR/dtb"
export DTBOPATH="$ANYKERNEL3_DIR/dtbo.img"

# Check kernel version
KERVER=$(make kernelversion)

# Post to Telegram channel
curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="start building the kernel
Branch : $(git rev-parse --abbrev-ref HEAD)
Version : "$KERVER"-perf-$COMMIT
Compiler Used : $GCC_VER $LLD_VER" -d chat_id=${chat_id} -d parse_mode=HTML

args="	ARCH=arm64 \
	AR=llvm-ar \
	NM=llvm-nm \
 	CC=aarch64-elf-gcc \
  	LD=aarch64-elf-ld.lld \
	CC_COMPAT=arm-eabi-gcc \
	OBJCOPY=llvm-objcopy \
	OBJDUMP=llvm-objdump \
	OBJCOPY=llvm-objcopy \
	OBJSIZE=llvm-size \
	STRIP=llvm-strip \
	CROSS_COMPILE=aarch64-elf- \
	CROSS_COMPILE_COMPAT=arm-eabi-"

BUILD_START=$(date +"%s")
mkdir out
make -j$(nproc --all) O=out $args $KERNEL_DEFCONFIG
cd out || exit
make -j$(nproc --all) O=out $args olddefconfig
cd ../ || exit
make -j$(nproc --all) O=out $args V=$VERBOSE 2>&1 | tee error.log

END=$(date +"%s")
DIFF=$((END - BUILD_START))

if [ -f $(pwd)/out/arch/arm64/boot/Image ]
        then
                curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="Build compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds" -d chat_id=${chat_id} -d parse_mode=HTML
                find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
                find $DTS -name 'Image' -exec cat {} + > $IMGPATH
                find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH
                cd $ANYKERNEL3_DIR/
                zip -r9 $FINAL_KERNEL_ZIP * -x README $FINAL_KERNEL_ZIP
                curl -F chat_id="${chat_id}"  \
		-F document=@"$FINAL_KERNEL_ZIP" \
		-F caption="" https://api.telegram.org/bot${token}/sendDocument
        else
                curl -s -X POST https://api.telegram.org/bot${token}/sendMessage -d text="Build failed !" -d chat_id=${chat_id} -d parse_mode=HTML
                curl -F chat_id="${chat_id}"  \
                     -F document=@"error.log" \
                     https://api.telegram.org/bot${token}/sendDocument
fi

echo "FINISH.."
