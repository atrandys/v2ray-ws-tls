#!/bin/bash
#判断系统
if [ ! -e '/etc/redhat-release' ]; then
echo "仅支持centos7"
exit
fi
if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
echo "仅支持centos7"
exit
fi

function blue(){
    echo -e "\033[34m\033[01m $1 \033[0m"
}
function green(){
    echo -e "\033[32m\033[01m $1 \033[0m"
}
function red(){
    echo -e "\033[31m\033[01m $1 \033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m $1 \033[0m"
}

#安装openssl1.1.1
install_openssl()
{
    yum install -y libtool perl-core zlib-devel gcc
    wget https://www.openssl.org/source/openssl-1.1.1a.tar.gz
    tar xzvf openssl-1.1.1a.tar.gz
    cd openssl-1.1.1a
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
    make && make install
    mv /usr/bin/openssl /usr/bin/openssl.bak
    mv /usr/include/openssl /usr/include/openssl.bak
    ln -s /usr/local/ssl/bin/openssl /usr/bin/openssl
    ln -s /usr/local/ssl/include/openssl /usr/include/openssl
    echo "/usr/local/ssl/lib" >> /etc/ld.so.conf
    ldconfig -v
}

#安装nginx
install_nginx(){

    yum install -y yum-utils
    
cat > /etc/yum.repos.d/nginx.repo<<-EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
EOF

    yum-config-manager --enable nginx-mainline
    yum install -y nginx
    systemctl enable nginx.service
    systemctl start nginx.service
    rm -f /etc/nginx/conf.d/default.conf
    rm -f /etc/nginx/nginx.conf
    mkdir /etc/nginx/ssl
    
cat > /etc/nginx/nginx.conf <<-EOF
user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
EOF

    curl https://get.acme.sh | sh
    green "======================"
    green " 输入解析到此VPS的域名"
    green "======================"
    read domain
    ~/.acme.sh/acme.sh  --issue  -d $domain  --webroot /usr/share/nginx/html/
    ~/.acme.sh/acme.sh  --installcert  -d  $domain   \
        --key-file   /etc/nginx/ssl/$domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer \
        --reloadcmd  "service nginx force-reload"
	
cat > /etc/nginx/conf.d/default.conf<<-EOF
server { 
    listen       80;
    server_name  $domain;
    rewrite ^(.*)$  https://\$host\$1 permanent; 
}
server {
    listen 443 ssl http2;
    server_name $domain;
    root /usr/share/nginx/html;
    index index.php index.html;
    ssl_certificate /etc/nginx/ssl/fullchain.cer; 
    ssl_certificate_key /etc/nginx/ssl/$domain.key;
    #TLS 版本控制
    ssl_protocols   TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_ciphers     'TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5';

    # 开启 1.3 0-RTT
    ssl_early_data  on;
    ssl_stapling on;
    ssl_stapling_verify on;
    #add_header Strict-Transport-Security "max-age=31536000";
    #access_log /var/log/nginx/access.log combined;
    location /mypath {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:11234; 
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location / {
       try_files \$uri \$uri/ /index.php?\$args;
    }
}
EOF
}
#安装v2ray
install_v2ray(){
    
    yum install -y wget
    bash <(curl -L -s https://install.direct/go.sh)  
    cd /etc/v2ray/
    rm -f config.json
    wget https://raw.githubusercontent.com/atrandys/v2ray-ws-tls/master/config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/aaaa/$v2uuid/;" config.json
    newpath=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
    sed -i "s/mypath/$newpath/;" config.json
    sed -i "s/mypath/$newpath/;" /etc/nginx/conf.d/default.conf
    systemctl restart nginx.service
    systemctl restart v2ray.service

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

clear
green
green "安装已经完成"
green 
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

install_openssl
install_nginx
install_v2ray



