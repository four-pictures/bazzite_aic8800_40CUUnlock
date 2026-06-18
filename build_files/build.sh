#!/usr/bin/env bash

set -oeux pipefail

echo "=== BC-250 40CU Unlock Patch Tooling ==="

# 1. ビルドに必要なパッケージを一時的にシステムへ導入
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
rpm-ostree install gcc make git "kernel-devel-${KERNEL_VERSION}"

# 2. 40CU解放スクリプトのクローン
cd /tmp
git clone https://github.com/duggasco/bc250-40cu-unlock.git
cd bc250-40cu-unlock

# 3. パッチの適用と手動コンパイル（バグるスクリプトは一切使いません）
# カーネルのソースコードツリーのふりをして、直接 make を叩きます
cd patch
# 本来スクリプトが裏側で実行しているコンパイルコマンドを直接実行
make -C "/lib/modules/${KERNEL_VERSION}/build" M="$(pwd)" -j$(nproc) modules

# 4. 生成されたドライバー（amdgpu.ko）をシステム側の正式な場所に配置
TARGET_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${TARGET_DIR}"
cp amdgpu.ko "${TARGET_DIR}/"

# 5. 一時的に入れたビルドツールを削除してクリーンアップ
cd /tmp
rm -rf /tmp/bc250-40cu-unlock
rpm-ostree uninstall gcc make git "kernel-devel-${KERNEL_VERSION}"

echo "=== BC-250 Patch Integration Complete ==="
