#使用SSH工具连接VPS，执行下列命令，选择安装v2ray+ws+tls

curl -O https://raw.githubusercontent.com/DuoBaoX/v2ray-ws-tls/master/v2ray_ws_tls1.3.sh && chmod +x v2ray_ws_tls1.3.sh && ./v2ray_ws_tls1.3.sh

##使用SSH工具连接VPS，执行下列命令，vless+tcp+tls一键脚本
bash <(curl -L -s https://raw.githubusercontent.com/DuoBaoX/v2ray-ws-tls/master/vless_tcp_tls.sh)

#BBR加速器：执行下列命令，选择安装，建议安装原版BBR

cd /usr/src && wget -N --no-check-certificate "https://raw.githubusercontent.com/DuoBaoX/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh


