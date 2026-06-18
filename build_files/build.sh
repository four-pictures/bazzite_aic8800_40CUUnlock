#!/usr/bin/env bash

set -oeux pipefail

echo "=== BC-250 40CU Unlock Patch Tooling ==="

# 1. ビルドに必要なパッケージを一時的にシステムへ導入
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
rpm-ostree install gcc make git patch "kernel-devel-${KERNEL_VERSION}"

# 2. 40CU解放リポジトリのクローン
cd /tmp
git clone https://github.com/duggasco/bc250-40cu-unlock.git

# 3. カーネル開発ソースのディレクトリに移動
# (rpm-ostreeで入れたkernel-develのソースツリーを直接利用します)
cd "/usr/src/kernels/${KERNEL_VERSION}"

# 4. 公式スクリプトが行っている「amdgpuへのパッチ適用」を直接手動で実行
# (実機チェックが入ったスクリプトは1行も実行しません)
patch -p1 < /tmp/bc250-40cu-unlock/patch/bc250-40cu-amdgpu.patch

# 5. パッチが当たったamdgpuドライバーだけをピンポイントでコンパイル
make -C "/lib/modules/${KERNEL_VERSION}/build" M="drivers/gpu/drm/amd/amdgpu" -j$(nproc) modules

# 6. 生成されたドライバー（amdgpu.ko）をシステム側の正式な場所に配置
TARGET_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${TARGET_DIR}"
cp drivers/gpu/drm/amd/amdgpu/amdgpu.ko "${TARGET_DIR}/"

# 7. 一時的に入れたビルドツールとゴミを削除してクリーンアップ
cd /tmp
rm -rf /tmp/bc250-40cu-unlock
rpm-ostree uninstall gcc make git patch "kernel-devel-${KERNEL_VERSION}"

echo "=== BC-250 Patch Integration Complete ==="
