#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

logblue(){
    echo -e "\033[34m\033[01m$1\033[0m" | tee -ai /var/atrandys.log
}
loggreen(){
    echo -e "\033[32m\033[01m$1\033[0m" | tee -ai /var/atrandys.log
}
logred(){
    echo -e "\033[31m\033[01m$1\033[0m" | tee -ai /var/atrandys.log
}
logyellow(){
    echo -e "\033[33m\033[01m$1\033[0m" | tee -ai /var/atrandys.log
}

logcmd(){
    eval $1 | tee -ai /var/atrandys.log
}

source /etc/os-release
RELEASE=$ID
VERSION=$VERSION_ID
loggreen "== Script: atrandys/v2ray-ws-tls/vless_tcp_xtls.sh"
loggreen "== Time  : $(date +"%Y-%m-%d %H:%M:%S")"
loggreen "== OS    : $RELEASE $VERSION"
loggreen "== Kernel: $(uname -r)"
loggreen "== User  : $(whoami)"
sleep 2s
check_release(){
    loggreen "$(date +"%Y-%m-%d %H:%M:%S") ==== 检查系统版本"
    if [ "$RELEASE" == "centos" ]; then
        systemPackage="yum"
        logcmd "yum install -y wget"
        if  [ "$VERSION" == "6" ] ;then
            logred "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 6.\n== Install failed."
            exit
        fi
        if  [ "$VERSION" == "5" ] ;then
            logred "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 5.\n== Install failed."
            exit
        fi
        if [ -f "/etc/selinux/config" ]; then
            CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
            if [ "$CHECK" == "SELINUX=enforcing" ]; then
                loggreen "$(date +"%Y-%m-%d %H:%M:%S") - SELinux状态非disabled,关闭SELinux."
                setenforce 0
                sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
                #loggreen "SELinux is not disabled, add port 80/443 to SELinux rules."
                #loggreen "==== Install semanage"
                #logcmd "yum install -y policycoreutils-python"
                #semanage port -a -t http_port_t -p tcp 80
                #semanage port -a -t http_port_t -p tcp 443
                #semanage port -a -t http_port_t -p tcp 37212
                #semanage port -a -t http_port_t -p tcp 37213
            elif [ "$CHECK" == "SELINUX=permissive" ]; then
                loggreen "$(date +"%Y-%m-%d %H:%M:%S") - SELinux状态非disabled,关闭SELinux."
                setenforce 0
                sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            fi
        fi
        firewall_status=`firewall-cmd --state`
        if [ "$firewall_status" == "running" ]; then
            loggreen "$(date +"%Y-%m-%d %H:%M:%S") - FireWalld状态非disabled,添加80/443到FireWalld rules."
            firewall-cmd --zone=public --add-port=80/tcp --permanent
            firewall-cmd --zone=public --add-port=443/tcp --permanent
            firewall-cmd --reload
        fi
        while [ ! -f "nginx-release-centos-7-0.el7.ngx.noarch.rpm" ]
        do
            logcmd "wget http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm"
            if [ ! -f "nginx-release-centos-7-0.el7.ngx.noarch.rpm" ]; then
                logred "$(date +"%Y-%m-%d %H:%M:%S") - 下载nginx rpm包失败，继续重试..."
            fi
        done
        logcmd "rpm -ivh nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps"
        #logcmd "rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps"
        #loggreen "Prepare to install nginx."
        #yum install -y libtool perl-core zlib-devel gcc pcre* >/dev/null 2>&1
        logcmd "yum install -y epel-release"
    elif [ "$RELEASE" == "ubuntu" ]; then
        systemPackage="apt-get"
        if  [ "$VERSION" == "14" ] ;then
            logred "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 14.\n== Install failed."
            exit
        fi
        if  [ "$VERSION" == "12" ] ;then
            logred "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 12.\n== Install failed."
            exit
        fi
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update >/dev/null 2>&1
    elif [ "$RELEASE" == "debian" ]; then
        systemPackage="apt-get"
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update >/dev/null 2>&1
    else
        logred "$(date +"%Y-%m-%d %H:%M:%S") - 当前系统不被支持. \n== Install failed."
        exit
    fi
}

check_port(){
    loggreen "$(date +"%Y-%m-%d %H:%M:%S") ==== 检查端口"
    logcmd "$systemPackage -y install net-tools"
    Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
    Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
    if [ -n "$Port80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
        logred "$(date +"%Y-%m-%d %H:%M:%S") - 80端口被占用,占用进程:${process80}\n== Install failed."
        exit 1
    fi
    if [ -n "$Port443" ]; then
        process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
        logred "$(date +"%Y-%m-%d %H:%M:%S") - 443端口被占用,占用进程:${process443}.\n== Install failed."
        exit 1
    fi
}
install_nginx(){
    loggreen "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装nginx"
    logcmd "$systemPackage install -y nginx"
    if [ -f "/etc/nginx" ]; then
        logred "$(date +"%Y-%m-%d %H:%M:%S") - 看起来nginx没有安装成功，请先使用脚本中的删除v2ray功能，然后再重新安装.\n== Install failed."
        exit 1
    fi
    
cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
#error_log  /etc/nginx/error.log warn;
#pid    /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    #access_log  /etc/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
EOF

cat > /etc/nginx/conf.d/default.conf<<-EOF
 server {
    listen       127.0.0.1:37212;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
}
 server {
    listen       127.0.0.1:37213 http2;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
}
    
server { 
    listen       0.0.0.0:80;
    server_name  $your_domain;
    root /usr/share/nginx/html/;
    index index.php index.html;
    #rewrite ^(.*)$  https://\$host\$1 permanent; 
}
EOF
    loggreen "$(date +"%Y-%m-%d %H:%M:%S") ==== 检测nginx配置文件"
    logcmd "nginx -t"
    #CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    #if [ "$CHECK" != "SELINUX=disabled" ]; then
    #    loggreen "设置Selinux允许nginx"
    #    cat /var/log/audit/audit.log | grep nginx | grep denied | audit2allow -M mynginx  
    #    semodule -i mynginx.pp 
    #fi
    systemctl enable nginx.service
    systemctl restart nginx.service
    loggreen "$(date +"%Y-%m-%d %H:%M:%S") - 使用acme.sh申请https证书."
    curl https://get.acme.sh | sh
    logcmd "~/.acme.sh/acme.sh  --issue  -d $your_domain  --webroot /usr/share/nginx/html/"
    if test -s /root/.acme.sh/$your_domain/fullchain.cer; then
        loggreen "$(date +"%Y-%m-%d %H:%M:%S") - 申请https证书成功."
    else
        cert_failed="1"
        logred "$(date +"%Y-%m-%d %H:%M:%S") - 申请证书失败，请尝试手动申请证书."
    fi
    install_v2ray
}

install_v2ray(){ 
    loggreen "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装v2ray"
    mkdir /usr/local/etc/v2ray/
    mkdir /usr/local/etc/v2ray/cert
    logcmd "bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)"
    cd /usr/local/etc/v2ray/
    rm -f config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
cat > /usr/local/etc/v2ray/config.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    }, 
    "inbounds": [
        {
            "listen": "0.0.0.0", 
            "port": 443, 
            "protocol": "vless", 
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid", 
                        "level": 0, 
                        "email": "a@b.com",
                        "flow":"xtls-rprx-direct"
                    }
                ], 
                "decryption": "none", 
                "fallbacks": [
                    {
                        "dest": 37212
                    }, 
                    {
                        "alpn": "h2", 
                        "dest": 37213
                    }
                ]
            }, 
            "streamSettings": {
                "network": "tcp", 
                "security": "xtls", 
                "xtlsSettings": {
                    "serverName": "$your_domain", 
                    "alpn": [
                        "h2", 
                        "http/1.1"
                    ], 
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/v2ray/cert/fullchain.cer", 
                            "keyFile": "/usr/local/etc/v2ray/cert/private.key"
                        }
                    ]
                }
            }
        }
    ], 
    "outbounds": [
        {
            "protocol": "freedom", 
            "settings": { }
        }
    ]
}
EOF
cat > /usr/local/etc/v2ray/client.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 1080,
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "vless",
            "settings": {
                "vnext": [
                    {
                        "address": "$your_domain",
                        "port": 443,
                        "users": [
                            {
                                "id": "$v2uuid",
                                "flow": "xtls-rprx-direct",
                                "encryption": "none",
                                "level": 0
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "serverName": "$your_domain"
                }
            }
        }
    ]
}
EOF
    if [ -d "/usr/share/nginx/html/" ]; then
        cd /usr/share/nginx/html/ && rm -f ./*
        #wget https://github.com/atrandys/v2ray-ws-tls/raw/master/web.zip >/dev/null 2>&1
        logcmd "wget https://github.com/atrandys/trojan/raw/master/fakesite.zip"
        logcmd "unzip -o fakesite.zip"
        #unzip web.zip >/dev/null 2>&1
    fi
    #systemctl stop v2ray
    #cd /usr/local/bin/
    #rm -f v2*
    #wget https://github.com/rprx/v2ray-vless/releases/download/xtls/v2ray-linux-64.zip
    #wget https://github.com/rprx/v2ray-vless/releases/download/xtls3/v2ray-linux-64.zip
    #unzip v2ray-linux-64.zip
    #chmod +x v2ray v2ctl
    systemctl enable v2ray.service
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /usr/local/etc/v2ray/cert/private.key \
        --fullchain-file  /usr/local/etc/v2ray/cert/fullchain.cer \
        --reloadcmd  "chmod -R 777 /usr/local/etc/v2ray/cert && systemctl restart v2ray.service"

cat > /usr/local/etc/v2ray/myconfig.json<<-EOF
{
地址：${your_domain}
端口：443
id：${v2uuid}
加密：none
流控：xtls-rprx-direct
别名：自定义
传输协议：tcp
伪装类型：none
底层传输：xtls
跳过证书验证：false
}
EOF

    loggreen "== 安装完成."
    if [ "$cert_failed" == "1" ]; then
        loggreen "======nginx信息======"
        logred "申请证书失败，请尝试手动申请证书."
    fi    
    loggreen "=================v2ray配置文件=================="
    cat /usr/local/etc/v2ray/myconfig.json
    loggreen "本次安装检测信息如下："
    logcmd "ps -aux | grep -e nginx -e v2ray"
    
}

check_domain(){
    logcmd "$systemPackage install -y wget curl unzip"
    logblue "Eenter your domain:"
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        loggreen "域名解析地址与VPS IP地址匹配."
        install_nginx
    else
        logred "域名解析地址与VPS IP地址不匹配."
        read -p "强制安装?请输入 [Y/n] :" yn
        [ -z "${yn}" ] && yn="y"
        if [[ $yn == [Yy] ]]; then
            sleep 1s
            install_nginx
        else
            exit 1
        fi
    fi
}

remove_v2ray(){
    loggreen "$(date +"%Y-%m-%d %H:%M:%S") - 删除v2ray."
    systemctl stop v2ray.service
    systemctl disable v2ray.service
    systemctl stop nginx
    systemctl disable nginx
    if [ "$RELEASE" == "centos" ]; then
        yum remove -y nginx
    else
        apt-get -y autoremove nginx
        apt-get -y --purge remove nginx
        apt-get -y autoremove && apt-get -y autoclean
        find / | grep nginx | sudo xargs rm -rf
    fi
    rm -rf /usr/local/share/v2ray/ /usr/local/etc/v2ray/
    rm -f /usr/local/bin/v2ray /usr/local/bin/v2ctl 
    rm -rf /etc/systemd/system/v2ray*
    rm -rf /etc/nginx
    rm -rf /usr/share/nginx/html/*
    rm -rf /root/.acme.sh/
    loggreen "nginx & v2ray has been deleted."
    
}

function start_menu(){
    clear
    loggreen " ====================================================="
    loggreen " 描述：v2ray(vless) + tcp + xtls一键安装脚本"
    loggreen " 系统：支持centos7/debian9+/ubuntu16.04+     "
    loggreen " 作者：atrandys  www.atrandys.com"
    loggreen " ====================================================="
    echo
    loggreen " 1. 安装 vless + tcp + xtls"
    loggreen " 2. 更新 v2ray"
    logred " 3. 删除 v2ray"
    logyellow " 0. Exit"
    echo
    read -p "输入数字:" num
    case "$num" in
    1)
    check_release
    check_port
    check_domain
    ;;
    2)
    bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    systemctl restart v2ray
    ;;
    3)
    remove_v2ray 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    logred "Enter a correct number"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
