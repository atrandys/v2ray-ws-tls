#!/bin/bash
if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
fi

if [ "$release" == "centos" ]; then
    if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    systemctl stop firewalld
    systemctl disable firewalld
    rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
elif [ "$release" == "ubuntu" ]; then
    if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    systemctl stop ufw
    systemctl disable ufw
    apt-get update
elif [ "$release" == "debian" ]; then
    apt-get update
fi

if [ -f "/etc/selinux/config" ]; then
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" != "SELINUX=disabled" ]; then
        semanage port -a -t http_port_t -p tcp 80
        semanage port -a -t http_port_t -p tcp 443
    fi
fi


function blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}


#安装caddy
function install_caddy(){
    green "======================="
    blue "请输入绑定到本VPS的域名"
    green "======================="
    read your_domain
    real_addr=`ping -4 ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        green "=========================================="
	green "       域名解析正常，开始安装trojan"
	green "=========================================="
	curl https://getcaddy.com | bash -s personal
	useradd -M -s /usr/sbin/nologin www-data
	mkdir /etc/caddy
	touch /etc/caddy/Caddyfile
	chown -R root:www-data /etc/caddy
	mkdir /etc/ssl/caddy
	chown -R www-data:root /etc/ssl/caddy
	chmod 0770 /etc/ssl/caddy
	mkdir /var/www
	chown www-data:www-data /var/www
	cd /etc/systemd/system
	curl -O https://raw.githubusercontent.com/mholt/caddy/master/dist/init/linux-systemd/caddy.service
	systemctl daemon-reload
	systemctl enable caddy.service
	newpath=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
	cat > /etc/nginx/nginx.conf <<-EOF
$your_domain
{
  root /var/www/
  proxy /$newpath localhost:11234 {
    websocket
    header_upstream -Origin
  }
}
EOF
    systemctl start caddy.service
    fi
}
#安装v2ray
function install_v2ray(){
    
    $systemPackage install -y wget curl unzip
    bash <(curl -L -s https://install.direct/go.sh)  
    cd /etc/v2ray/
    rm -f config.json
    wget https://raw.githubusercontent.com/atrandys/v2ray-ws-tls/master/config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/aaaa/$v2uuid/;" config.json
    sed -i "s/mypath/$newpath/;" config.json
    cd /var/www/
    wget https://github.com/atrandys/v2ray-ws-tls/raw/master/web.zip
    unzip web.zip
    systemctl restart v2ray.service
    systemctl restart caddy.service
    
cat > /etc/v2ray/myconfig.json<<-EOF
{
===========配置参数=============
地址：${domain}
端口：443
uuid：${v2uuid}
额外id：64
加密方式：aes-128-gcm
传输协议：ws
别名：myws
路径：${newpath}
底层传输：tls
}
EOF

green "=============================="
green "         安装已经完成"
green "===========配置参数============"
green "地址：${domain}"
green "端口：443"
green "uuid：${v2uuid}"
green "额外id：64"
green "加密方式：aes-128-gcm"
green "传输协议：ws"
green "别名：myws"
green "路径：${newpath}"
green "底层传输：tls"
green 
}

function remove_v2ray(){

    /etc/nginx/sbin/nginx -s stop
    systemctl stop v2ray.service
    systemctl disable v2ray.service
    
    rm -rf /usr/bin/v2ray /etc/v2ray
    rm -rf /etc/v2ray
    rm -rf /etc/nginx
    
    green "nginx、v2ray已删除"
    
}

function start_menu(){
    clear
    green " ===================================="
    green " 介绍：一键安装v2ray+ws+tls1.3        "
    green " 系统：centos7                       "
    green " 作者：atrandys                      "
    green " 网站：www.atrandys.com              "
    green " Youtube：atrandys                   "
    green " ===================================="
    echo
    green " 1. 安装v2ray+ws+tls1.3"
    green " 2. 升级v2ray"
    red " 3. 卸载v2ray"
    yellow " 0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    install_nginx
    install_v2ray
    ;;
    2)
    bash <(curl -L -s https://install.direct/go.sh)  
    ;;
    3)
    remove_v2ray 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
