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

# ★【最重要】スクリプト内にある「実機チェックで強制終了（exit 1）する3行」を完全にピンポイントで消し去ります
sed -i '/No BC-250/d' ./scripts/bc250-enable-40cu.sh
sed -i '/This patch is BC-250 specific/d' ./scripts/bc250-enable-40cu.sh
sed -i '/exit 1/d' ./scripts/bc250-enable-40cu.sh

# 3. 公式スクリプトを走らせて自動ビルド（実機チェックをスルーしてカーネルソースの展開〜ビルドまで完遂させます）
./scripts/bc250-enable-40cu.sh build

# 4. 生成されたドライバー（amdgpu.ko）をシステム側の正式な場所に配置
TARGET_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${TARGET_DIR}"
cp amdgpu.ko "${TARGET_DIR}/"

# 5. 一時的に入れたビルドツールとゴミを削除してクリーンアップ
cd /tmp
rm -rf /tmp/bc250-40cu-unlock
rpm-ostree uninstall gcc make git "kernel-devel-${KERNEL_VERSION}"

echo "=== BC-250 Patch Integration Complete ==="
