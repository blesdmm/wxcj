```bash
#!/bin/sh

export LANG=en_US.UTF-8
arch="$(uname -m)"

# 支持的架构检查
if [ "$arch" != "mips" ] && [ "$arch" != "mipsle" ]; then
    echo "当前架构为 $arch，暂不支持" && exit
fi

showports() {
    ports=$(ps aux | grep "$HOME/cfs5http/cfwp" | grep -v grep | awk '{print $12}' | sed 's/client_ip=://')
}

showmenu() {
    showports
    if [ -n "$ports" ]; then
        echo "已在运行的节点端口："
        for port in $ports; do
            echo " - $port"
        done
    else
        echo "未安装任何节点"
    fi
}

delsystem() {
    local port=$1
    /etc/init.d/cf_$port stop >/dev/null 2>&1
    rm -f /etc/init.d/cf_$port
    killall -9 cf_$port >/dev/null 2>&1
}

# 入口提示
echo "================================================================"
echo "Cloudflare Socks5/Http代理脚本"
showmenu

read -p "请选择操作（1增设节点 | 2查看节点 | 3删除节点 | 4卸载所有节点 | 5退出）:" menu

if [ "$menu" = "1" ]; then
    mkdir -p "$HOME/cfs5http"
    curl -L -o "$HOME/cfs5http/cfwp" -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/Cloudflare-vless-trojan/main/s5http_wkpgs/linux-${arch}
    chmod +x "$HOME/cfs5http/cfwp"

    read -p "1、CF workers/pages/自定义的域名设置（格式为：域名:端口）:" cf_domain
    read -p "2、密钥设置（回车默认：不设密钥）:" token
    read -p "3、客户端本地端口设置（回车默认：30000）:" port="${REPLY:-30000}"

    SCRIPT="$HOME/cfs5http/cf_$port.sh"
    cat > "$SCRIPT" << EOF
#!/bin/sh
CMD="$HOME/cfs5http/cfwp client_ip=:$port cf_domain=$cf_domain token=$token"
nohup \$CMD > "$HOME/cfs5http/$port.log" 2>&1 &
EOF

    chmod +x "$SCRIPT"

    cat > "/etc/init.d/cf_$port" << EOF
#!/bin/sh
START=99
STOP=10
USE_PROCD=1
SCRIPT="$HOME/cfs5http/cf_$port.sh"

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh -c "sleep 10 && /bin/bash \"\$SCRIPT\""
    procd_set_param respawn
    procd_close_instance
}
EOF

    chmod +x "/etc/init.d/cf_$port"
    /etc/init.d/cf_$port start
    /etc/init.d/cf_$port enable

    echo "安装完毕，Socks5/Http 节点已在运行中"

elif [ "$menu" = "2" ]; then
    showmenu

elif [ "$menu" = "3" ]; then
    read -p "选择要删除的端口（输入端口即可）:" port
    delsystem "$port"
    echo "端口 $port 的进程已被终止"

elif [ "$menu" = "4" ]; then
    read -p "确认卸载所有节点？(y/n)： " confirm
    if [ "$confirm" = "y" ]; then
        showports
        for port in $ports; do
            delsystem "$port"
        done
        rm -rf "$HOME/cfs5http"
        echo "所有节点已卸载完成"
    else
        echo "已取消操作"
    fi

else
    echo "退出程序"
    exit
fi
```