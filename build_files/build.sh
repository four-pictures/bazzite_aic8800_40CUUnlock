#!/usr/bin/env bash

set -oeux pipefail

echo "=== BC-250 40CU Unlock Patch Tooling ==="

# 1. ビルドに必要なパッケージを一時的に導入
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
rpm-ostree install gcc make git patch "kernel-devel-${KERNEL_VERSION}"

# 2. 40CU解放リポジトリのクローン
cd /tmp
git clone https://github.com/duggasco/bc250-40cu-unlock.git

# 3. ビルド用の一時作業ディレクトリを作成
WORK_DIR="/tmp/amdgpu-build"
mkdir -p "${WORK_DIR}"

# 4. kernel-develに内蔵されているamdgpuのビルドソース一式を独自の作業ディレクトリに丸ごとコピー
# (これで Makefile やパッチ対象のソースコードがすべて揃います)
cp -r "/usr/src/kernels/${KERNEL_VERSION}/drivers/gpu/drm/amd/amdgpu" "${WORK_DIR}/"

# 5. 作業ディレクトリに移動して、パッチを適用
cd "${WORK_DIR}/amdgpu"
# パッチファイルの対象パスを合わせるため、-p5 オプションで適用します
patch -p5 < /tmp/bc250-40cu-unlock/patch/bc250-40cu-amdgpu.patch

# 6. パッチが当たったamdgpuドライバーのみをピンポイントでコンパイル
make -C "/lib/modules/${KERNEL_VERSION}/build" M="${WORK_DIR}/amdgpu" -j$(nproc) modules

# 7. 生成されたドライバー（amdgpu.ko）をシステム側の正式な場所に配置
TARGET_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${TARGET_DIR}"
cp amdgpu.ko "${TARGET_DIR}/"

# 8. 一時的に入れたビルドツールとゴミを削除してクリーンアップ
cd /tmp
rm -rf /tmp/bc250-40cu-unlock "${WORK_DIR}"
rpm-ostree uninstall gcc make git patch "kernel-devel-${KERNEL_VERSION}"

echo "=== BC-250 Patch Integration Complete ==="
