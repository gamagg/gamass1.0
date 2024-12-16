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

# 默认配置
DEFAULT_PASSWORD="zlidc.net"
DEFAULT_PORT=36009
DEFAULT_METHODS=("aes-256-gcm" "aes-192-gcm" "chacha20-ietf-poly1305")

# 系统检查与依赖安装
check_system() {
    echo "检查系统类型..."
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_MANAGER="apt"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        PKG_MANAGER="yum"
    else
        echo "当前系统不受支持，请使用 Debian 8+/Ubuntu 16+/CentOS 7+。"
        exit 1
    fi

    echo "安装必要工具..."
    sudo $PKG_MANAGER update -y
    sudo $PKG_MANAGER install -y lsof wget curl
}

# 系统优化
system_optimization() {
    echo "优化系统设置..."
    sed -i '/^\*\s*soft\s*nofile/d' /etc/security/limits.conf
    sed -i '/^\*\s*hard\s*nofile/d' /etc/security/limits.conf
    echo '* soft nofile 65536' >> /etc/security/limits.conf
    echo '* hard nofile 65536' >> /etc/security/limits.conf
}

# 端口检查与处理
check_port() {
    local port=$1
    if lsof -i:"$port" &>/dev/null; then
        echo "检测到端口 $port 被占用，尝试释放..."
        lsof -i:"$port" | awk '{print $2}' | grep -v "PID" | xargs kill -9
        echo "端口 $port 已释放。"
    else
        echo "端口 $port 可用。"
    fi
}

# 获取所有公网 IP
get_public_ips() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -vE "^(127|10|192\.168|172\.(1[6-9]|2[0-9]|3[0-1]))\."
}

# 安装 Shadowsocks
install_shadowsocks() {
    echo "开始安装 Shadowsocks..."

    if ! command -v ss-server &>/dev/null; then
        echo "安装 Shadowsocks-libev..."
        if [ "$OS" == "debian" ]; then
            sudo $PKG_MANAGER install -y shadowsocks-libev
        elif [ "$OS" == "centos" ]; then
            sudo $PKG_MANAGER install -y epel-release
            sudo $PKG_MANAGER install -y shadowsocks-libev
        fi
    fi

    if ! command -v ss-server &>/dev/null; then
        echo "Shadowsocks 安装失败，请检查网络或软件源。"
        exit 1
    fi

    echo "Shadowsocks 已成功安装。"

    # 自定义配置
    read -rp "请输入 Shadowsocks 密码 (默认: $DEFAULT_PASSWORD): " PASSWORD
    PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}

    read -rp "请输入端口 (默认: $DEFAULT_PORT): " PORT
    PORT=${PORT:-$DEFAULT_PORT}

    echo "可用的加密协议："
    for i in "${!DEFAULT_METHODS[@]}"; do
        echo "$((i+1)). ${DEFAULT_METHODS[$i]}"
    done

    read -rp "请选择加密协议 (默认: 1): " METHOD_INDEX
    METHOD_INDEX=${METHOD_INDEX:-1}
    METHOD=${DEFAULT_METHODS[$((METHOD_INDEX-1))]}

    # 获取公网 IP
    PUBLIC_IPS=($(get_public_ips))

    if [ ${#PUBLIC_IPS[@]} -eq 0 ]; then
        echo "未检测到公网 IP，请检查网络配置。"
        exit 1
    fi

    echo "检测到以下公网 IP："
    for IP in "${PUBLIC_IPS[@]}"; do
        echo "$IP"
    done

    # 为每个 IP 配置 Shadowsocks
    OUTPUT_CONFIG=()
    for IP in "${PUBLIC_IPS[@]}"; do
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

        # 启动服务
        nohup ss-server -c $CONFIG_FILE &>/var/log/ss-$IP-$PORT.log &
        OUTPUT_CONFIG+=("$IP|$PORT|$METHOD|$PASSWORD")
    done

    echo "Shadowsocks 服务已配置如下："
    for line in "${OUTPUT_CONFIG[@]}"; do
        echo "$line"
    done

    echo "如果工具有疑问，请联系 zlidc.net"
}

# 删除 Shadowsocks
remove_shadowsocks() {
    echo "停止并删除 Shadowsocks..."
    pkill ss-server
    rm -rf $CONFIG_DIR
    echo "Shadowsocks 已删除。"
}

# 更新 Shadowsocks
update_shadowsocks() {
    echo "更新 Shadowsocks 配置..."
    remove_shadowsocks
    install_shadowsocks
}

# 菜单
menu() {
    echo "\n—————————————— 安装向导 ——————————————"
    echo "1. 安装 Shadowsocks"
    echo "2. 删除 Shadowsocks"
    echo "3. 更新 Shadowsocks"
    echo "99. 退出"
    echo "——————————————"

    read -rp "请输入操作编号: " CHOICE
    case $CHOICE in
        1)
            check_system
            system_optimization
            install_shadowsocks
            ;;
        2)
            remove_shadowsocks
            ;;
        3)
            update_shadowsocks
            ;;
        99)
            exit 0
            ;;
        *)
            echo "无效的输入，请重新选择。"
            menu
            ;;
    esac
}

menu
