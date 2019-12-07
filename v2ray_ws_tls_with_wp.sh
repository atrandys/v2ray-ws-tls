#!/bin/bash
 
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
function bred(){
    echo -e "\033[31m\033[01m\033[05m$1\033[0m"
}
function byellow(){
    echo -e "\033[33m\033[01m\033[05m$1\033[0m"
}

#判断系统
check_os(){
if [ ! -e '/etc/redhat-release' ]; then
	red "==============="
	red " 仅支持CentOS7"
	red "==============="
exit
fi
if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
	red "==============="
	red " 仅支持CentOS7"
	red "==============="
exit
fi
if  [ -n "$(grep ' 8\.' /etc/redhat-release)" ] ;then
	red "==============="
	red " 仅支持CentOS7"
	red "==============="
exit
fi
}

disable_selinux(){

    systemctl stop firewalld
    systemctl disable firewalld
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" == "SELINUX=enforcing" ]; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
    if [ "$CHECK" == "SELINUX=permissive" ]; then
         sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
         setenforce 0
    fi
}

check_domain(){
    green "======================="
    yellow "请输入绑定到本VPS的域名"
    green "======================="
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
    		green "=========================================="
		green "域名解析正常，开始安装wordpress+v2ray_ws_tls"
		green "你选择的这个方式，稍微复杂，安装时间比较长"
		green "请耐心等待……"
		green "=========================================="
	sleep 1s
		download_wp
		install_php7
    	install_mysql
    	install_nginx
		install_v2ray
		config_php
    	install_wp
		green
		green "v2ray安装已经完成"
		green 
		green "===========配置参数============"
		green "地址：${your_domain}"
		green "端口：443"
		green "uuid：${v2uuid}"
		green "额外id：64"
		green "加密方式：aes-128-gcm"
		green "传输协议：ws"
		green "别名：myws"
		green "路径：${newpath}"
		green "底层传输：tls"
		green 
    else
        red "================================"
		red "域名解析地址与本VPS IP地址不一致"
		red "本次安装失败，请确保域名解析正常"
		red "================================"
		red "脚本检测ping 域名获取解析IP， 并"
		red "与本机查询的外网IP比较，若不一致"
		red "将不允许进行安装。"
		red "================================"
    fi
}

install_php7(){

    green "==============="
    green " 1.安装必要软件"
    green "==============="
    sleep 1
    yum -y install epel-release
    sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
    yum -y install  wget unzip vim tcl expect curl libtool perl-core zlib-devel gcc pcre*
    echo
    echo
    green "=========="
    green "2.安装PHP7"
    green "=========="
    sleep 1
    rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
    yum -y install php70w php70w-mysql php70w-gd php70w-xml php70w-fpm
    service php-fpm start
    chkconfig php-fpm on
    if [ `yum list installed | grep php70 | wc -l` -ne 0 ]; then
        echo
    	green "【checked】 PHP7安装成功"
	echo
	echo
	sleep 2
	php_status=1
    fi
}

install_mysql(){

    green "==============="
    green "  3.安装MySQL"
    green "==============="
    sleep 1
    wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    rpm -ivh mysql-community-release-el7-5.noarch.rpm
    yum -y install mysql-server
    systemctl enable mysqld.service
    systemctl start  mysqld.service
    if [ `yum list installed | grep mysql-community | wc -l` -ne 0 ]; then
    	green "【checked】 MySQL安装成功"
		echo
		echo
		sleep 2
		mysql_status=1
    fi
    echo
    echo
    green "==============="
    green "  4.配置MySQL"
    green "==============="
    sleep 2
    mysqlpasswd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
    
/usr/bin/expect << EOF
spawn mysql_secure_installation
expect "password for root" {send "\r"}
expect "root password" {send "Y\r"}
expect "New password" {send "$mysqlpasswd\r"}
expect "Re-enter new password" {send "$mysqlpasswd\r"}
expect "Remove anonymous users" {send "Y\r"}
expect "Disallow root login remotely" {send "Y\r"}
expect "database and access" {send "Y\r"}
expect "Reload privilege tables" {send "Y\r"}
spawn mysql -u root -p
expect "Enter password" {send "$mysqlpasswd\r"}
expect "mysql" {send "create database wordpress_db;\r"}
expect "mysql" {send "exit\r"}
EOF


}

install_nginx(){
    echo
    echo
    green "==============="
    green "  5.安装nginx"
    green "==============="
    sleep 1
    wget https://www.openssl.org/source/openssl-1.1.1a.tar.gz
    tar xzvf openssl-1.1.1a.tar.gz
    
    mkdir /etc/nginx
    mkdir /etc/nginx/ssl
    mkdir /etc/nginx/conf.d
    wget https://nginx.org/download/nginx-1.15.8.tar.gz
    tar xf nginx-1.15.8.tar.gz && rm nginx-1.15.8.tar.gz
    cd nginx-1.15.8
    ./configure --prefix=/etc/nginx --with-openssl=../openssl-1.1.1a --with-openssl-opt='enable-tls1_3' --with-http_v2_module --with-http_ssl_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_sub_module --with-stream --with-stream_ssl_module
    make && make install
	
    rm -f /etc/nginx/conf.d/default.conf
    rm -f /etc/nginx/conf/nginx.conf
    
cat > /etc/nginx/conf.d/default.conf<<-EOF
server {
    listen       80;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF

cat > /etc/nginx/conf/nginx.conf <<-EOF
user  root;
worker_processes  1;
#error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/conf/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    #access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
EOF
	
	/etc/nginx/sbin/nginx 

    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh  --issue  -d $your_domain  --webroot /usr/share/nginx/html/
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /etc/nginx/ssl/$your_domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer \
        --reloadcmd  "service nginx force-reload"
	
cat > /etc/nginx/conf.d/default.conf<<-EOF
server { 
    listen       80;
    server_name  $your_domain;
    rewrite ^(.*)$  https://\$host\$1 permanent; 
}
server {
    listen 443 ssl http2;
    server_name $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html;
    ssl_certificate /etc/nginx/ssl/fullchain.cer; 
    ssl_certificate_key /etc/nginx/ssl/$your_domain.key;
    #TLS 版本控制
    ssl_protocols   TLSv1.3;
    ssl_ciphers     TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256;
    ssl_prefer_server_ciphers   on;
    # 开启 1.3 0-RTT
    ssl_early_data  on;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security "max-age=31536000";
    #access_log /var/log/nginx/hostscube.log combined;
    location ~ \.php$ {
    	fastcgi_pass 127.0.0.1:9000;
    	fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    	include fastcgi_params;
    }
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

    newpath=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
    sed -i "s/mypath/$newpath/;" /etc/nginx/conf.d/default.conf
    /etc/nginx/sbin/nginx -s stop
    /etc/nginx/sbin/nginx 

}

install_v2ray(){
    
    bash <(curl -L -s https://install.direct/go.sh)  
    cd /etc/v2ray/
    rm -f config.json
    wget https://raw.githubusercontent.com/atrandys/v2ray-ws-tls/master/config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/aaaa/$v2uuid/;" config.json
    sed -i "s/mypath/$newpath/;" config.json
    systemctl restart v2ray.service
    systemctl enable v2ray.service
    
    #增加自启动脚本
cat > /etc/rc.d/init.d/autov2ray<<-EOF
#!/bin/sh
#chkconfig: 2345 80 90
#description:autov2ray
/etc/nginx/sbin/nginx
EOF

    #设置脚本权限
    chmod +x /etc/rc.d/init.d/autov2ray
    chkconfig --add autov2ray
    chkconfig autov2ray on

cat > /etc/v2ray/myconfig.json<<-EOF
{
===========配置参数=============
地址：${your_domain}
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


}

config_php(){

    echo
    green "===================="
    green " 6.配置php和php-fpm"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/;" /etc/php.ini
    sed -i "s/pm.start_servers = 5/pm.start_servers = 3/;s/pm.min_spare_servers = 5/pm.min_spare_servers = 3/;s/pm.max_spare_servers = 35/pm.max_spare_servers = 8/;" /etc/php-fpm.d/www.conf
    systemctl restart php-fpm.service
    systemctl restart nginx.service

}


download_wp(){

    mkdir /usr/share/wordpresstemp
    cd /usr/share/wordpresstemp/
    wget https://cn.wordpress.org/latest-zh_CN.zip
    if [ ! -f "/usr/share/wordpresstemp/latest-zh_CN.zip" ]; then
    	red "从cn官网下载wordpress失败，尝试从github下载……"
		wget https://github.com/atrandys/wordpress/raw/master/latest-zh_CN.zip    
    fi
    if [ ! -f "/usr/share/wordpresstemp/latest-zh_CN.zip" ]; then
		red "我它喵的从github下载wordpress也失败了，请尝试用下面的方式手动安装……"
		grenn "从wordpress官网下载包然后命名为latest-zh_CN.zip，新建目录/usr/share/wordpresstemp/，上传到此目录下，重新执行安装脚本即可"
		exit 1
    fi
}

install_wp(){

    green "===================="
    green "  7.安装wordpress"
    green "===================="
    echo
    echo
    sleep 1
    cd /usr/share/nginx/html
    mv /usr/share/wordpresstemp/latest-zh_CN.zip ./
    unzip latest-zh_CN.zip
    mv wordpress/* ./
    cp wp-config-sample.php wp-config.php
    green "===================="
    green "  8.配置wordpress"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/database_name_here/wordpress_db/;s/username_here/root/;s/password_here/$mysqlpasswd/;" /usr/share/nginx/html/wp-config.php
    echo "define('FS_METHOD', "direct");" >> /usr/share/nginx/html/wp-config.php
    chmod -R 777 /usr/share/nginx/html/wp-content
    green "==========================================================="
    green " WordPress服务端配置已完成，请打开浏览器访问您的域名进行前台配置"
    green " 数据库密码等信息参考文件：/usr/share/nginx/html/wp-config.php"
    green "==========================================================="
}

uninstall_wp(){
    red "============================================="
    red "你的wordpress和v2ray数据将全部丢失！！你确定要卸载吗？"
    read -s -n1 -p "按回车键开始卸载，按ctrl+c取消"
    yum remove -y php70w php70w-mysql php70w-gd php70w-xml php70w-fpm mysql
    rm -rf /usr/share/nginx/html/*
    rm -rf /var/lib/mysql
    rm -rf /usr/share/mysql
	/etc/nginx/sbin/nginx -s stop
    systemctl stop v2ray.service
    systemctl disable v2ray.service
    rm -rf /usr/bin/v2ray
    rm -rf /etc/v2ray
    rm -rf /etc/nginx
	rm -rf /etc/rc.d/init.d/autov2ray
    green "=========="
    green " 卸载完成，如需重新安装建议重启后进行"
    green "=========="
}

start_menu(){
    clear
    green "=================================================="
    green " 介绍：适用CentOS7，一键安装wordpress+v2ray_ws_tls"
    green " 作者：atrandys"
    green " 网站：www.atrandys.com"
    green " Youtube：Randy's 堡垒"
    green "=================================================="
    green "1. 安装wordpress+v2ray_ws_tls"
    red "2. 卸载wordpress+v2ray_ws_tls"
    yellow "0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
		check_os
		disable_selinux
        check_domain
		;;
		2)
		uninstall_wp
		;;
		0)
		exit 1
		;;
		*)
	clear
	echo "请输入正确数字"
	sleep 2s
	start_menu
	;;
    esac
}

start_menu
