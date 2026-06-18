#!/usr/bin/env bash

set -oeux pipefail

echo "=== BC-250 40CU Unlock Patch Tooling ==="

# 1. ビルドに必要なパッケージを一時的にシステムへ導入 (コンパイル時のみ使用)
# ※現在のカーネルバージョンに完全一致する kernel-devel を自動取得します
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
rpm-ostree install gcc make git "kernel-devel-${KERNEL_VERSION}"

# 2. 40CU解放スクリプトのクローンとコンパイル
cd /tmp
git clone https://github.com
cd bc250-40cu-unlock

# スクリプト内のビルドコマンドを実行してカーネルモジュール (.ko) を生成
./scripts/bc250-enable-40cu.sh build

# 3. 生成されたドライバーをシステム側の正式な場所に配置
# (Bazzite本体の有効化スクリプトの挙動をイメージビルド用にエミュレート)
TARGET_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${TARGET_DIR}"
cp amdgpu.ko "${TARGET_DIR}/"

# 4. 一時的に入れたビルドツールを削除してイメージを軽量化
rpm-ostree uninstall gcc make git "kernel-devel-${KERNEL_VERSION}"

echo "=== BC-250 Patch Integration Complete ==="
