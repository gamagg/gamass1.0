#!/usr/bin/env bash


#====================================================
#   System Request:Centos 7
#   Author: zlidc.net 
#   Dscription: Socks5 Installation
#   Version: 1.0
#   email: zlidc@gmail.com 
#   TG: @IX_zhilian 
#====================================================

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
    cd "$(dirname "$0")" || exit
    pwd
)" || exit
echo > /root/socks.txt
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
source '/etc/os-release'
#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
error="${Red}[错误]${Font}"
check_system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
        INS="yum"
    yum remove firewalld -y ; yum install -y iptables-services ; iptables -F ; iptables -t filter -F ; systemctl enable iptables.service ; service iptables save ; systemctl start iptables.service

    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font}"
        INS="apt"
        $INS update
        ## 添加 apt源
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
        INS="apt"
        $INS update
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font}"
        exit 1
    fi
    $INS -y install lsof wget curl

}


is_root() {
    if [ 0 == $UID ]; then
        echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
        sleep 3
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到使用 'sudo -i' 切换到root用户后重新执行脚本 ${Font}"
        exit 1
    fi
}

judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}

sic_optimization() {
    # 最大文件打开数
    sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    echo '* soft nofile 65536' >>/etc/security/limits.conf
    echo '* hard nofile 65536' >>/etc/security/limits.conf

    # 关闭 Selinux
    if [[ "${ID}" == "centos" ]]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
    fi

}

port_set() {
        read -rp "请设置连接端口（默认:36009）:" ss_port
        [[ -z ${ss_port} ]] && ss_port="36009"
}

port_exist_check() {
    if [[ 0 -eq $(lsof -i:"${ss_port}" | grep -i -c "listen") ]]; then
        echo -e "${OK} ${GreenBG} $1 端口未被占用 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 检测到 ${ss_port} 端口被占用，以下为 ${ss_port} 端口占用信息 ${Font}"
        lsof -i:"${ss_port}"
        echo -e "${OK} ${GreenBG} 5s 后将尝试自动 kill 占用进程 ${Font}"
        sleep 5
        lsof -i:"${ss_port}" | awk '{print $2}' | grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill 完成 ${Font}"
        sleep 1
    fi
}

user_set() {
    read -rp  "请设置ss5账户。默认:zlidc.net）:" ss_user
    [[ -z ${ss_user} ]] && ss_user="zlidc.net"
    read -rp "请设置ss5连接密码。默认:zlidc.net）:" ss_pass
    [[ -z ${ss_pass} ]] && ss_pass="zlidc.net"
}



ip_list() {
ips=($(ip addr show |grep -v inet6 | awk '/global/{print $2}' | grep -Eo "^[0-9]{1,3}(.[0-9]{1,3}){3}"))
ip addr show | grep -v inet6 | awk '/global/{print $2}' | grep -Eo "^[0-9]{1,3}(.[0-9]{1,3}){3}"
echo "可用IP个数"
ip addr show | grep -v inet6 | awk '/global/{print $2}' | grep -Eo "^[0-9]{1,3}(.[0-9]{1,3}){3}" | wc -l

}
ss_install() {

# Socks5 Installation
if [ -f /usr/local/sbin/socks ]; then
    echo "Xray Installd"
else
    wget -O /usr/local/sbin/socks --no-check-certificate https://my.oofeye.com/socks
    chmod +x /usr/local/sbin/socks
fi


cat <<EOF > /etc/systemd/system/sockd.service
[Unit]
Description=Socks5 Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/sbin/socks run -config /etc/socks/config.toml
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sockd.service &> /dev/null
}


config_install() {
#Socks5 Configuration
mkdir -p /etc/socks
echo  "[routing]" > /etc/socks/config.toml
for ((i = 0;i < ${#ips[@]}; i++)); do
cat <<EOF >> /etc/socks/config.toml
[[routing.rules]]
type = "field"
inboundTag = "$((i+1))"
outboundTag = "$((i+1))"

EOF
done
for ((i = 0;i < ${#ips[@]}; i++)); do
echo "${ips[i]} $ss_port $ss_user $ss_pass" >> /root/socks.txt
cat <<EOF >> /etc/socks/config.toml
[[inbounds]]
listen = "${ips[i]}"
port = "$ss_port"
protocol = "socks"
tag = "$((i+1))"


[inbounds.settings]
auth = "password"
udp = true

[[inbounds.settings.accounts]]
user = "$ss_user"
pass = "$ss_pass"

[inbounds.streamSettings]
network = "tcp"


[[outbounds]]
sendThrough = "${ips[i]}"
protocol = "freedom"
tag = "$((i+1))"

EOF
done

systemctl restart sockd.service
}

is_root
check_system


install() {
    ip_list
    sic_optimization
    port_set
    port_exist_check
    user_set
    ss_install
    config_install
    judge "安装"
}

bbr_install() {
    [ -f "tcp.sh" ] && rm -rf ./tcp.sh
    wget -N -O /root/tcp.sh --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x /root/tcp.sh && bash /root/tcp.sh

}
del_ss5() {

    systemctl stop sockd.service
    rm -rf /usr/local/bin/socks
    rm -rf /etc/systemd/system/sockd.service
    systemctl daemon-reload
    rm -rf /etc/socks/config.toml
    judge "删除 ss5 "
}
update_ss5() {
    ip_list
    port_set
        port_exist_check
        user_set
    rm -rf /etc/socks/config.toml
    config_install
    systemctl restart sockd.service
    judge "跟改成功 "
}

menu() {
    echo -e "\t ss5 安装管理脚本 "
    echo -e "\tSystem Request:Debian 9+/Ubuntu 20.04+/Centos 7+"
    echo -e "\t无法使用请联系zldic.net\n"

    echo -e "—————————————— 安装向导 ——————————————"
    echo -e "${Green} 接受定制,特殊要求 等可以联系zlidc.net${Font}"
    echo -e "${Green}1.${Font}  安装ss5"
    echo -e "${Green}2.${Font}  停止ss5"
    echo -e "${Green}3.${Font}  删除ss5"
    echo -e "${Green}4.${Font}  更改端口账户密码"
    echo -e "${Green}99.${Font}  退出 \n"


    read -rp "请输入数字：" menu_num
    case $menu_num in
    1)
        install
        ;;
    2)
        systemctl stop sockd.service
        judge "停止"
        ;;
    3)
        del_ss5
        ;;
    4)
        update_ss5
        ;;
    99)
        exit 0
        ;;
    *)
    echo -e "${RedBG}请输入正确的数字${Font}"
        ;;
    esac

}


menu


cat /root/socks.txt
