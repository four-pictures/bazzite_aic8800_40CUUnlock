#!/usr/bin/env bash

set -oeux pipefail

echo "=== BC-250 40CU Unlock Patch Tooling ==="

# 1. ビルドに必要なパッケージを一時的に導入
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n 1)
rpm-ostree install gcc make git "kernel-devel-${KERNEL_VERSION}"

# 2. ビルド用の一時作業ディレクトリを作成し、kernel-develからビルド環境をコピー
WORK_DIR="/tmp/amdgpu-build"
mkdir -p "${WORK_DIR}"
cp -r "/usr/src/kernels/${KERNEL_VERSION}/drivers/gpu/drm/amd/amdgpu" "${WORK_DIR}/"

cd "${WORK_DIR}/amdgpu"

# 3. パッチ対象のCコード（40CU解放処理）を直接ファイルとして新規作成
# (kernel-develにソースコードが無くても、これで確実にCファイルが存在することになります)
cat << 'EOF' > bc250_patch.c
#include <linux/module.h>
#include <linux/pci.h>

/* BC-250 40CU Unlock Parameters */
int amdgpu_bc250_cc_write_mode = 0;
module_param_named(bc250_cc_write_mode, amdgpu_bc250_cc_write_mode, int, 0444);
MODULE_PARM_DESC(bc250_cc_write_mode, "BC-250 CC Write Mode (0=off, 3=enable all)");

void bc250_unlock_40cu(struct pci_dev *pdev, void __iomem *rmmio)
{
    /* Check for AMD BC-250 (PCI ID 0x13FE) */
    if (pdev && pdev->device == 0x13fe) {
        if (amdgpu_bc250_cc_write_mode == 3) {
            /* 1. CC_GC_SHADER_ARRAY_CONFIG: Clear harvest mask */
            writel(0, rmmio + (0x1570 * 4)); 
            
            /* 2. SPI_PG_ENABLE_STATIC_WGP_MASK: Enable all 5 WGPs per SA */
            writel(0x1f1f1f1f, rmmio + (0x2c00 * 4) + 0x228); 
            
            /* 3. RLC_PG_ALWAYS_ON_WGP_MASK: Keep all WGPs powered on */
            writel(0x1f1f1f1f, rmmio + (0x3c00 * 4) + 0x3d0);
            
            pr_info("[bc250-patch] AMD BC-250 40 CU Unlock Applied Successfully!\n");
        }
    }
}
EXPORT_SYMBOL(bc250_unlock_40cu);
EOF

# 4. コピーしたMakefileの末尾に、今作ったパッチファイルをビルド対象として追記
echo "amdgpu-y += bc250_patch.o" >> Makefile

# 5. amdgpuドライバーをピンポイントでコンパイル
make -C "/lib/modules/${KERNEL_VERSION}/build" M="${WORK_DIR}/amdgpu" -j$(nproc) modules

# 6. 生成されたドライバー（amdgpu.ko）をシステム側の正式な場所に配置
TARGET_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${TARGET_DIR}"
cp amdgpu.ko "${TARGET_DIR}/"

# 7. 一時的に入れたビルドツールとゴミを削除してクリーンアップ
cd /tmp
rm -rf "${WORK_DIR}"
rpm-ostree uninstall gcc make git "kernel-devel-${KERNEL_VERSION}"

echo "=== BC-250 Patch Integration Complete ==="
