#!/bin/bash

cd /root >/dev/null 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REGEX=("debian|astra" "ubuntu")
RELEASE=("Debian" "Ubuntu")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(lsb_release -sd 2>/dev/null)")
SYS="${CMD[0]}"
[[ -n $SYS ]] || exit 1

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        [[ -n $SYSTEM ]] && break
    fi
done

if [[ "$SYSTEM" != "Debian" && "$SYSTEM" != "Ubuntu" ]]; then
    echo -e "${RED}[ERR]${NC} 此脚本仅支持 Debian 和 Ubuntu 系统"
    exit 1
fi

if [[ "$SYSTEM" == "Debian" ]]; then
    OS_VERSION=$(cat /etc/debian_version | cut -d. -f1)
elif [[ "$SYSTEM" == "Ubuntu" ]]; then
    OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2 | cut -d. -f1)
fi

log() { echo -e "$1"; }
ok() { log "${GREEN}[OK]${NC} $1"; }
info() { log "${BLUE}[INFO]${NC} $1"; }
warn() { log "${YELLOW}[WARN]${NC} $1"; }
err() { log "${RED}[ERR]${NC} $1"; exit 1; }

reading() { read -rp "$(echo -e "${GREEN}$1${NC}")" "$2"; }

install_package() {
    package_name=$1
    if dpkg -l 2>/dev/null | grep -q "^ii.*$package_name"; then
        ok "$package_name 已安装"
    else
        apt-get install -y $package_name >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            apt-get install -y $package_name --fix-missing >/dev/null 2>&1
        fi
        if dpkg -l 2>/dev/null | grep -q "^ii.*$package_name"; then
            ok "$package_name 已安装"
        else
            warn "$package_name 安装失败"
        fi
    fi
}

get_available_space() {
    local available_space
    available_space=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
    echo "$available_space"
}

install_lxd() {
    apt-get update >/dev/null 2>&1
    info "安装 Incus 和 ZFS..."
    apt-get install -y incus zfsutils-linux
    command -v incus >/dev/null 2>&1 || err '未找到 incus 命令'
    
    ok "Incus 安装完成"
    
    if dpkg -l lxcfs 2>/dev/null | grep -q "^ii"; then
        warn "检测到 deb 版 lxcfs，正在移除..."
        systemctl stop lxcfs 2>/dev/null || true
        systemctl disable lxcfs 2>/dev/null || true
        apt-get remove -y lxcfs >/dev/null 2>&1
        ok "deb 版 lxcfs 已移除"
    fi
    
    incus_version=$(incus version 2>/dev/null)
    info "Incus 版本: $incus_version"
}

init_lxd_network() {
	info "初始化 Incus 网络..."
    reading "是否启用 IPv4？输入 y 或 n，默认 y：" enable_ipv4
    enable_ipv4=${enable_ipv4:-y}
    reading "是否启用 IPv6？输入 y 或 n，默认 y：" enable_ipv6
    enable_ipv6=${enable_ipv6:-y}
    ipv4_config="none"
    ipv6_config="none"
    ipv4_nat="false"
    ipv6_nat="false"
    if [[ "$enable_ipv4" =~ ^[yY]$ ]]; then
        ipv4_config="10.66.0.1/16"
        ipv4_nat="true"
    fi
    if [[ "$enable_ipv6" =~ ^[yY]$ ]]; then
        ipv6_config="fd66:6666::1/64"
        ipv6_nat="true"
    fi
    cat <<EOF | incus admin init --preseed
config:
  images.auto_update_interval: "0"
networks:
- config:
    ipv4.address: $ipv4_config
    ipv4.nat: "$ipv4_nat"
    ipv6.address: $ipv6_config
    ipv6.nat: "$ipv6_nat"
  description: ""
  name: incusbr0
  type: bridge
storage_pools: []
storage_volumes: []
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      network: incusbr0
      type: nic
  name: default
projects: []
cluster: null
EOF
	ok "Incus 网络初始化完成"
}

main() {
    echo
    echo "========================================"
	 echo "        Incus 安装脚本"
    echo "        by Github-xkatld"
    echo "========================================"
    echo
    
    echo "======== 步骤 1/3: 检测系统 ========"
    info "系统: $SYSTEM $OS_VERSION"
    ok "系统检测通过"
    echo
    
	 echo "======== 步骤 2/3: 安装 Incus ========"
	 reading "是否安装 Incus？输入 y 或 n，默认 y：" step2_confirm
    step2_confirm=${step2_confirm:-y}
    if [[ "$step2_confirm" =~ ^[yY]$ ]]; then
        install_lxd
		ok "Incus 安装完成"
    else
	info "已跳过 Incus 安装"
    fi
    echo
    
    echo "======== 步骤 3/3: 配置网络 ========"
	reading "是否配置 Incus 默认网络？输入 y 或 n，默认 y：" step3_confirm
    step3_confirm=${step3_confirm:-y}
    if [[ "$step3_confirm" =~ ^[yY]$ ]]; then
        init_lxd_network
    else
        info "已跳过网络配置"
    fi
    echo
    
    echo "======== 安装完成 ========"
    echo
    echo "========================================"
	 echo "        Incus 安装完成"
    echo "========================================"
    echo
	info "Incus 版本: $(incus version 2>/dev/null)"
    echo
    info "===== 网络配置 ====="
	incus network list 2>/dev/null || warn "无法获取网络列表"
}

main
