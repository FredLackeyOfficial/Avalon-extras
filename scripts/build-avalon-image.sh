#!/bin/bash

OPENWRT_PATH=../openwrt
OPENWRT_DL_PATH=${OPENWRT_PATH}/../dl
LUCI_PATH=../luci


## Init
if [ "$1" == "--clone" ]; then
    mkdir -p avalon
    cd avalon
    svn co svn://svn.openwrt.org/openwrt/trunk@36095 openwrt
    git clone git@github.com:BitSyncom/cgminer.git && (cd cgminer && git checkout -b avalon origin/avalon)
    git clone git@github.com:BitSyncom/luci.git && (cd luci && git checkout -b cgminer-webui origin/cgminer-webui)
    git clone git@github.com:BitSyncom/cgminer-openwrt-package.git
    cd openwrt
    mkdir -p ../dl
    ln -s ../dl
    wget https://raw.github.com/BitSyncom/cgminer-openwrt-packages/master/cgminer/data/feeds.conf
    wget https://raw.github.com/BitSyncom/cgminer-openwrt-packages/master/cgminer/data/config -O .config
    ./scripts/feeds update -a &&  ./scripts/feeds install -a
    ln -s feeds/cgminer/cgminer/root-files files
    cp feeds/cgminer/cgminer/data/config .config
    make -j4 V=s
    exit 0;
fi

## Rebuild cgminer
cd avalon/cgminer
git archive --format tar.gz --prefix=cgminer-20130108/ HEAD > \
      ${OPENWRT_DL_PATH}/cgminer-20130108-HEAD.tar.gz                                            && \
make -C ${OPENWRT_PATH} package/cgminer/{clean,compile} V=s

RET="$?"
if [ "${RET}" != "0" ] || [ "$1" == "--cgminer" ]; then
    if [ "${RET}" == "0" ]; then
	cp ${OPENWRT_PATH}/bin/ar71xx/packages/cgminer_20130108-1_ar71xx.ipk  ./
	cp ${OPENWRT_PATH}/build_dir/target-mips_r2_uClibc-0.9.33.2/cgminer-20130108/cgminer ./cgminer-mips
    fi
    exit "$?"
fi

## Build the Web UI & OpenWrt
## Get all repo commit for Avalon version file /etc/avalon_version
DATE=`date +%Y%m%d`
GIT_VERSION=`git rev-parse HEAD | cut -c 1-7`
if [ ! -z "`git status -s -uno`" ]; then
	GIT_STATUS="+"
fi

LUCI_GIT_VERSION=`cd ../luci && git rev-parse HEAD | cut -c 1-7`
if [ ! -z "`cd ../luci && git status -s -uno`" ]; then
	LUCI_GIT_STATUS="+"
fi

OW_GIT_VERSION=`cd ../cgminer-openwrt-package && git rev-parse HEAD | cut -c 1-7`
if [ ! -z "`cd ../cgminer-openwrt-package && git status -s -uno`" ]; then
	OW_GIT_STATUS="+"
fi

rm -rf ${LUCI_PATH}/applications/luci-cgminer/dist                                               && \
make -C ${LUCI_PATH}                                                                             && \
cp -a ${HOME}/workspace/bitcoin/avalon/luci/applications/luci-cgminer/dist/* \
        ${OPENWRT_PATH}/files/                                                                   && \
echo "$DATE"                                          > ${OPENWRT_PATH}/files/etc/avalon_version && \
echo "cgminer-$GIT_VERSION$GIT_STATUS"               >> ${OPENWRT_PATH}/files/etc/avalon_version && \
echo "luci-$LUCI_GIT_VERSION$LUCI_GIT_STATUS"        >> ${OPENWRT_PATH}/files/etc/avalon_version && \
echo "openwrt-package-$OW_GIT_VERSION$OW_GIT_STATUS" >> ${OPENWRT_PATH}/files/etc/avalon_version && \
make -C ${OPENWRT_PATH}                                      && \
mkdir -p ${OPENWRT_PATH}/bin/old/                            && \
cp ${HOME}/workspace/PanGu/openwrt/bin/ar71xx/openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-factory.bin \
     ${HOME}/workspace/PanGu/openwrt/bin/old/openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-factory-${DATE}.bin

