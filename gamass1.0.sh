#!/bin/bash

# 预设密码
PRESET_PASSWORD="Aa19850409"

# 输入密码
echo -n "请输入密码以继续运行脚本："
read -s INPUT_PASSWORD
echo

# 验证密码
if [ "$INPUT_PASSWORD" != "$PRESET_PASSWORD" ]; then
    echo "密码错误，无法运行脚本。"
    exit 1
fi

echo "密码正确，开始执行脚本。"

# 配置文件目录
CONFIG_DIR="/etc/shadowsocks"
mkdir -p $CONFIG_DIR

# 配置参数
PASSWORD="zlidc.net"
METHOD="aes-256-gcm"
PORT_START=36009
PORT_COUNT=1

# 获取公网 IP
IP_LIST=($(ip -4 addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1))

if [ ${#IP_LIST[@]} -eq 0 ]; then
    echo "未检测到公网 IP，请检查网络配置。"
    exit 1
fi

echo "检测到以下公网 IP："
for IP in "${IP_LIST[@]}"; do
    echo "$IP"
done

# 自动安装 Shadowsocks-libev
install_shadowsocks() {
    echo "检测系统并安装 Shadowsocks-libev..."
    if [ -f /etc/debian_version ]; then
        sudo apt update
        sudo apt install -y shadowsocks-libev
    elif [ -f /etc/redhat-release ]; then
        if grep -qi "release 8" /etc/redhat-release; then
            sudo dnf install -y epel-release
            sudo dnf install -y shadowsocks-libev
        else
            sudo yum install -y epel-release
            sudo yum install -y shadowsocks-libev
        fi
    elif [ -f /etc/alpine-release ]; then
        sudo apk add shadowsocks-libev
    elif [ -f /etc/arch-release ]; then
        sudo pacman -S --noconfirm shadowsocks-libev
    else
        echo "无法检测到支持的系统，请手动安装 Shadowsocks-libev。"
        exit 1
    fi
}

if ! command -v ss-server &> /dev/null; then
    install_shadowsocks
fi

if ! command -v ss-server &> /dev/null; then
    echo "Shadowsocks-libev 安装失败，请检查。"
    exit 1
fi

echo "Shadowsocks-libev 已安装。"

# 用于输出 IP 和端口信息
OUTPUT_IPS=()

for IP in "${IP_LIST[@]}"; do
    for ((i=0; i<PORT_COUNT; i++)); do
        PORT=$((PORT_START + i))
        CONFIG_FILE="$CONFIG_DIR/ss-$IP-$PORT.json"
        cat > $CONFIG_FILE <<EOF
{
    "server": "$IP",
    "server_port": $PORT,
    "password": "$PASSWORD",
    "method": "$METHOD",
    "timeout": 300,
    "fast_open": true
}
EOF
        nohup ss-server -c $CONFIG_FILE &> /var/log/ss-$IP-$PORT.log &
        
        # 添加到输出列表
        OUTPUT_IPS+=("$IP|$PORT|$METHOD|$PASSWORD")
    done
done

# 输出配置的 IP 和端口信息
echo "Shadowsocks 服务已启动，以下是配置的 IP 和端口信息："
for line in "${OUTPUT_IPS[@]}"; do
    echo "$line"
done
