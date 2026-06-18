# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base Image
FROM ghcr.io/ublue-os/bazzite:stable
## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:44
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint

# --- AIC8800 Wi-Fi Driver Build Section ---
RUN dnf install -y git make gcc kernel-devel-matched && \
    git clone https://github.com/shenmintao/aic8800d80 /tmp/aic8800 && \
    # 1. ファームウェアの配置
    mkdir -p /usr/lib/firmware/aic8800D80 && \
    cp -r /tmp/aic8800/fw/aic8800D80/* /usr/lib/firmware/aic8800D80/ && \
    # 2. カーネルバージョンの取得
    export KVER=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | head -n 1) && \
    # 3. リポジトリ推奨の正しいフォルダで一括ビルドを実行
    cd /tmp/aic8800/drivers/aic8800 && \
    make -C /lib/modules/$KVER/build M=$(pwd) modules && \
    # 4. サブフォルダに生成された2つの必須ドライバーを直接指定してコピー
    mkdir -p /usr/lib/modules/$KVER/extra && \
    cp aic8800_fdrv/aic8800_fdrv.ko /usr/lib/modules/$KVER/extra/ && \
    cp aic_load_fw/aic_load_fw.ko /usr/lib/modules/$KVER/extra/ && \
    depmod -a $KVER && \
    # 不要なツールの削除とクリーンアップ
    dnf remove -y git make gcc kernel-devel-matched && \
    dnf clean all && \
    rm -rf /tmp/aic8800

RUN echo -e '#!/bin/bash\n/usr/sbin/usb_modeswitch -KQ -v a69c -p 5723\nsleep 3\nmodprobe aic_load_fw\nmodprobe aic8800_fdrv' > /usr/usr-local-bin-wifi-init.sh && \
    chmod +x /usr/usr-local-bin-wifi-init.sh

RUN echo -e '[Unit]\nDescription=Setup AIC8800 Wi-Fi\nAfter=network.target\n\n[Service]\nType=oneshot\nExecStart=/usr/usr-local-bin-wifi-init.sh\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target' > /etc/systemd/system/aic8800-wifi.service && \
    systemctl enable aic8800-wifi.service
