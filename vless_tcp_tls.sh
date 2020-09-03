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

source /etc/os-release
RELEASE=$ID
VERSION=$VERSION_ID

check_release(){
    if [ "$RELEASE" == "centos" ]; then
        systemPackage="yum"
        if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
            red "CentOS 6 is not supported."
            exit
        fi
        if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
            red "CentOS 5 is not supported."
            exit
        fi
        if [ -f "/etc/selinux/config" ]; then
            CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
            if [ "$CHECK" != "SELINUX=disabled" ]; then
                green "SELinux is not disabled, add port 80/443 to SELinux rules."
                yum install -y policycoreutils-python >/dev/null 2>&1
                semanage port -a -t http_port_t -p tcp 80
                semanage port -a -t http_port_t -p tcp 443
                semanage port -a -t http_port_t -p tcp 37212
                semanage port -a -t http_port_t -p tcp 37213
            fi
        fi
        firewall_status=`firewall-cmd --state`
        if [ "$firewall_status" == "running" ]; then
            green "FireWalld is not disabled, add port 80/443 to FireWalld rules."
            firewall-cmd --zone=public --add-port=80/tcp --permanent
            firewall-cmd --zone=public --add-port=443/tcp --permanent
            firewall-cmd --reload
        fi
        rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm >/dev/null 2>&1
        #green "Prepare to install nginx."
        #yum install -y libtool perl-core zlib-devel gcc pcre* >/dev/null 2>&1
        yum install -y epel-release
    elif [ "$RELEASE" == "ubuntu" ]; then
        systemPackage="apt-get"
        if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
            red "Ubuntu 14 is not supported."
            exit
        fi
        if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
            red "Ubuntu 12 is not supported."
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
    fi
}

check_port(){
    green "Check ports..."
    sleep 1s
    $systemPackage -y install net-tools >/dev/null 2>&1
    Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
    Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
    if [ -n "$Port80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
        red "Port 80 is occupied, Process name : ${process80}, exit."
        exit 1
    fi
    if [ -n "$Port443" ]; then
        process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
        red "Port 443 is occupied, Process name : ${process443}, exit."
        exit 1
    fi
}
install_nginx(){
    green "Install nginx..."
    sleep 1s
    $systemPackage install -y nginx >/dev/null 2>&1
    if [ -f "/etc/nginx" ]; then
        red "It seems that nginx installation is not successful. Please use the uninstall function in the script first."
        exit 1
    fi
    
cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
#error_log  /etc/nginx/error.log warn;
pid    /var/run/nginx.pid;
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
    systemctl enable nginx.service
    systemctl restart nginx.service
    green "Use acme.sh apply https certificate."
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh  --issue  -d $your_domain  --webroot /usr/share/nginx/html/
    if test -s /root/.acme.sh/$your_domain/fullchain.cer; then
        green "Apply https certificate successful."
    else
        cert_failed="1"
        red "Apply https certificate failed, please apply for certificate manually."
    fi
    install_v2ray
}

install_v2ray(){ 
    mkdir /usr/local/etc/v2ray/
    mkdir /usr/local/etc/v2ray/cert
    bash <(curl -L -s https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
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
                        "email": "a@b.com"
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
                "security": "tls", 
                "tlsSettings": {
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
    if [ -d "/usr/share/nginx/html/" ]; then
        cd /usr/share/nginx/html/
        rm -f ./*
        #wget https://github.com/atrandys/v2ray-ws-tls/raw/master/web.zip >/dev/null 2>&1
        wget https://github.com/atrandys/trojan/raw/master/fakesite.zip >/dev/null 2>&1
        unzip fakesite.zip >/dev/null 2>&1
        #unzip web.zip >/dev/null 2>&1
    fi
    systemctl enable v2ray.service
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /usr/local/etc/v2ray/cert/private.key \
        --fullchain-file  /usr/local/etc/v2ray/cert/fullchain.cer \
        --reloadcmd  "chmod -R 777 /usr/local/etc/v2ray/cert && systemctl restart v2ray.service"

cat > /usr/local/etc/v2ray/myconfig.json<<-EOF
{
===========配置参数=============
地址：${your_domain}
端口：443
id：${v2uuid}
加密：none
别名：自定义
传输协议：tcp
伪装类型：none
底层传输：tls
跳过证书验证：false
}
EOF

    green "Installation is complete."
    if [ "$cert_failed" == "1" ]; then
        green "======nginx info======"
        red "Apply https certificate failed, please apply for certificate manually."
    fi    
    green "======v2ray config======"
    green "Address      :${your_domain}"
    green "Port         :443"
    green "ID           :${v2uuid}"
    green "Encryption   :none"
    green "Protocol     :tcp"
    green "Type         :none"
    green "TLSSetting   :tls"
    green "AllowInsecure:False"
    green 
}

check_domain(){
    $systemPackage install -y wget curl unzip >/dev/null 2>&1
    blue "Eenter your domain:"
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        green "DNS records are correct."
        install_nginx
    else
        red "DNS records are not correct."
        read -p "Still process ? Please enter [Y/n] :" yn
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
    rm -rf /etc/systemd/system/v2ray*
    rm -rf /etc/nginx
    rm -rf /usr/share/nginx/html/*
    rm -rf /root/.acme.sh/
    green "nginx & v2ray has been deleted."
    
}

function start_menu(){
    clear
    green " ====================================================="
    green "    Onekey script install v2ray(vless) + tcp + tls"
    green "    centos7/debian9+/ubuntu16.04+ supported     "
    green "                   by atrandys"
    green " ====================================================="
    echo
    green " 1. Install vless + tcp + tls"
    green " 2. Update v2ray"
    red " 3. Remove v2ray"
    yellow " 0. Exit"
    echo
    read -p "Enter a number:" num
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
    red "Enter a correct number"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
