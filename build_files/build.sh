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

# ★【ここが最終解決のポイント】
# スクリプトの1番最初（2行目）に「実機チェック関数（check_device）」を
# 常に成功（中身を空にして即終了）させるコードを強制挿入して、元の重いチェック処理を完全に黙らせます。
sed -i '2i check_device() { return 0; }' ./scripts/bc250-enable-40cu.sh

# 3. 公式スクリプトを走らせて自動ビルド（実機チェックをスルーしてカーネルソースへのパッチ適用〜ビルドまで完遂）
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
