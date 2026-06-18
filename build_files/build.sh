#!/usr/bin/env bash

set -oeux pipefail

echo "=== BC-250 40CU Unlock Patch Tooling ==="

# 1. ビルドに必要なパッケージを一時的にシステムへ導入
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
rpm-ostree install gcc make git "kernel-devel-${KERNEL_VERSION}"

# 2. 40CU解放スクリプトのクローンとハードウェアチェックの無効化
cd /tmp
git clone https://github.com/duggasco/bc250-40cu-unlock.git
cd bc250-40cu-unlock

# ★【ここが修正のキモ】クラウド上に実機がないため、PCI IDのチェック（exit 1）を無効化（削除）します
sed -i 's/echo -e "\[!\] No BC-250.*exit 1//g' ./scripts/bc250-enable-40cu.sh

# スクリプト内のビルドコマンドを実行（実機がなくても強制コンパイルされます）
./scripts/bc250-enable-40cu.sh build

# 3. 生成されたドライバーをシステム側の正式な場所に配置
TARGET_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${TARGET_DIR}"
cp amdgpu.ko "${TARGET_DIR}/"

# 4. 一時的に入れたビルドツールを削除
rpm-ostree uninstall gcc make git "kernel-devel-${KERNEL_VERSION}"

echo "=== BC-250 Patch Integration Complete ==="
