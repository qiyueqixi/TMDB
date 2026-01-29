#!/bin/bash
# TMDB API 反向代理一键部署脚本 - 增强版

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="/etc/tmdb-proxy.conf"
NGINX_CONF="/etc/nginx/conf.d/tmdb-proxy.conf"

# 显示 Logo
show_header() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   TMDB API 反向代理 管理脚本${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# 检查 root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}请使用 root 用户运行此脚本${NC}"
        exit 1
    fi
}

# 主菜单
main_menu() {
    show_header

    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}状态：已安装${NC}"
        echo ""
        echo "1. 修改配置"
        echo "2. 查看当前配置"
        echo "3. 重启服务"
        echo "4. 卸载"
        echo "0. 退出"
    else
        echo -e "${YELLOW}状态：未安装${NC}"
        echo ""
        echo "1. 开始安装"
        echo "0. 退出"
    fi

    echo ""
    read -p "请选择操作: " choice

    case $choice in
        1)
            if [ -f "$CONFIG_FILE" ]; then
                modify_config
            else
                install_proxy
            fi
            ;;
        2)
            if [ -f "$CONFIG_FILE" ]; then
                view_config
            fi
            ;;
        3)
            if [ -f "$CONFIG_FILE" ]; then
                restart_service
            fi
            ;;
        4)
            if [ -f "$CONFIG_FILE" ]; then
                uninstall_proxy
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            sleep 2
            main_menu
            ;;
    esac
}

# 安装代理
install_proxy() {
    show_header
    echo -e "${BLUE}=== 开始安装配置 ===${NC}"
    echo ""

    # 域名配置
    read -p "请输入域名（如 tmdb.example.com）: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        sleep 2
        main_menu
        return
    fi

    # 代理目标选择
    echo ""
    echo "选择代理目标："
    echo "1. TMDB API (api.themoviedb.org)"
    echo "2. TMDB Images (image.tmdb.org)"
    echo "3. 自定义地址"
    read -p "请选择 [1-3]: " PROXY_TYPE

    case $PROXY_TYPE in
        1)
            PROXY_TARGET="https://api.themoviedb.org"
            PROXY_HOST="api.themoviedb.org"
            ;;
        2)
            PROXY_TARGET="https://image.tmdb.org"
            PROXY_HOST="image.tmdb.org"
            ;;
        3)
            read -p "请输入目标地址（如 https://example.com）: " PROXY_TARGET
            read -p "请输入 Host 头（如 example.com）: " PROXY_HOST
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            sleep 2
            install_proxy
            return
            ;;
    esac

    # API Key 配置（仅 API 代理需要）
    API_KEY=""
    if [ "$PROXY_TYPE" = "1" ]; then
        echo ""
        read -p "是否自动追加 TMDB API Key？(y/n): " ADD_KEY
        if [ "$ADD_KEY" = "y" ]; then
            read -p "请输入 API Key: " API_KEY
        fi
    fi

    # 缓存配置
    echo ""
    read -p "是否启用缓存？(y/n，推荐 y): " ENABLE_CACHE
    ENABLE_CACHE=${ENABLE_CACHE:-y}

    if [ "$ENABLE_CACHE" = "y" ]; then
        read -p "缓存有效期（天，默认 7）: " CACHE_DAYS
        CACHE_DAYS=${CACHE_DAYS:-7}
        read -p "缓存大小限制（GB，默认 10）: " CACHE_SIZE
        CACHE_SIZE=${CACHE_SIZE:-10}
    fi

    # IP 访问限制
    echo ""
    read -p "是否限制访问 IP？(y/n): " LIMIT_IP
    ALLOW_IPS=""
    if [ "$LIMIT_IP" = "y" ]; then
        echo "请输入允许的 IP 或网段（每行一个，输入空行结束）："
        while true; do
            read -p "> " ip
            if [ -z "$ip" ]; then
                break
            fi
            ALLOW_IPS="${ALLOW_IPS}${ip}|"
        done
        ALLOW_IPS=${ALLOW_IPS%|}
    fi

    # HTTPS 配置
    echo ""
    read -p "是否配置 HTTPS 证书？(y/n): " SETUP_SSL
    SETUP_SSL=${SETUP_SSL:-n}

    if [ "$SETUP_SSL" = "y" ]; then
        read -p "请输入邮箱（用于 Let's Encrypt）: " EMAIL
        if [ -z "$EMAIL" ]; then
            echo -e "${RED}邮箱不能为空${NC}"
            sleep 2
            install_proxy
            return
        fi
    fi

    # 确认信息
    echo ""
    echo -e "${YELLOW}========== 配置确认 ==========${NC}"
    echo -e "  域名：${GREEN}${DOMAIN}${NC}"
    echo -e "  代理目标：${GREEN}${PROXY_TARGET}${NC}"
    [ -n "$API_KEY" ] && echo -e "  API Key：${GREEN}已配置${NC}"
    [ "$ENABLE_CACHE" = "y" ] && echo -e "  缓存：${GREEN}启用（${CACHE_DAYS}天，${CACHE_SIZE}GB）${NC}"
    [ -n "$ALLOW_IPS" ] && echo -e "  IP 限制：${GREEN}已启用${NC}"
    [ "$SETUP_SSL" = "y" ] && echo -e "  HTTPS：${GREEN}是${NC}"
    echo -e "${YELLOW}============================${NC}"
    echo ""
    read -p "确认开始安装？(y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "已取消"
        sleep 2
        main_menu
        return
    fi

    # 保存配置
    save_config

    # 执行安装
    do_install
}

# 保存配置
save_config() {
    cat > "$CONFIG_FILE" << EOF
DOMAIN="${DOMAIN}"
PROXY_TYPE="${PROXY_TYPE}"
PROXY_TARGET="${PROXY_TARGET}"
PROXY_HOST="${PROXY_HOST}"
API_KEY="${API_KEY}"
ENABLE_CACHE="${ENABLE_CACHE}"
CACHE_DAYS="${CACHE_DAYS}"
CACHE_SIZE="${CACHE_SIZE}"
ALLOW_IPS="${ALLOW_IPS}"
SETUP_SSL="${SETUP_SSL}"
EMAIL="${EMAIL}"
EOF
}

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# 执行安装
do_install() {
    echo ""
    echo -e "${GREEN}[1/5] 安装 Nginx...${NC}"

    if command -v apt &> /dev/null; then
        apt update -y && apt install -y nginx curl
    elif command -v yum &> /dev/null; then
        yum install -y epel-release && yum install -y nginx curl
    elif command -v dnf &> /dev/null; then
        dnf install -y nginx curl
    else
        echo -e "${RED}不支持的系统${NC}"
        exit 1
    fi

    echo -e "${GREEN}[2/5] 生成 Nginx 配置...${NC}"
    generate_nginx_config

    echo -e "${GREEN}[3/5] 启动 Nginx...${NC}"
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null
    nginx -t
    systemctl restart nginx
    systemctl enable nginx

    if [ "$SETUP_SSL" = "y" ]; then
        echo -e "${GREEN}[4/5] 配置 HTTPS 证书...${NC}"
        if command -v apt &> /dev/null; then
            apt install -y certbot python3-certbot-nginx
        elif command -v yum &> /dev/null; then
            yum install -y certbot python3-certbot-nginx
        elif command -v dnf &> /dev/null; then
            dnf install -y certbot python3-certbot-nginx
        fi
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || {
            echo -e "${YELLOW}证书申请失败，请检查域名解析${NC}"
        }
    else
        echo -e "${YELLOW}[4/5] 跳过 HTTPS 配置${NC}"
    fi

    echo -e "${GREEN}[5/5] 完成！${NC}"

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    if [ "$SETUP_SSL" = "y" ]; then
        TEST_URL="https://${DOMAIN}"
    else
        TEST_URL="http://${DOMAIN}"
    fi

    if [ "$PROXY_TYPE" = "1" ]; then
        echo -e "测试命令："
        echo -e "  ${YELLOW}curl ${TEST_URL}/3/movie/popular${NC}"
        echo ""
        echo -e "MoviePilot 配置："
        echo -e "  TMDB API Host: ${GREEN}${DOMAIN}${NC}"
        [ -n "$API_KEY" ] && echo -e "  API Key: ${GREEN}已内置，可留空${NC}"
    else
        echo -e "代理地址："
        echo -e "  ${GREEN}${TEST_URL}${NC}"
    fi

    echo ""
    read -p "按回车键返回主菜单..."
    main_menu
}

# 生成 Nginx 配置
generate_nginx_config() {
    # 缓存配置
    CACHE_CONFIG=""
    if [ "$ENABLE_CACHE" = "y" ]; then
        CACHE_PATH="/var/cache/nginx/tmdb_cache"
        mkdir -p "$CACHE_PATH"
        CACHE_CONFIG="proxy_cache_path ${CACHE_PATH} levels=1:2 keys_zone=tmdb_cache:50m inactive=${CACHE_DAYS}d max_size=${CACHE_SIZE}g;"
    fi

    # IP 限制配置
    IP_LIMIT_CONFIG=""
    if [ -n "$ALLOW_IPS" ]; then
        IFS='|' read -ra IPS <<< "$ALLOW_IPS"
        for ip in "${IPS[@]}"; do
            IP_LIMIT_CONFIG="${IP_LIMIT_CONFIG}        allow ${ip};\n"
        done
        IP_LIMIT_CONFIG="${IP_LIMIT_CONFIG}        deny all;"
    fi

    # API Key 配置
    API_KEY_BLOCK=""
    PROXY_PASS_LINE=""
    if [ -n "$API_KEY" ]; then
        API_KEY_BLOCK=$(cat << 'APIEOF'
        set $new_args $args;
        if ($args = "") {
            set $new_args "api_key=API_KEY_PLACEHOLDER";
        }
        if ($args != "") {
            set $new_args "${args}&api_key=API_KEY_PLACEHOLDER";
        }
APIEOF
)
        API_KEY_BLOCK="${API_KEY_BLOCK//API_KEY_PLACEHOLDER/$API_KEY}"
        PROXY_PASS_LINE="        proxy_pass ${PROXY_TARGET}\$uri?\$new_args;"
    else
        PROXY_PASS_LINE="        proxy_pass ${PROXY_TARGET};"
    fi

    # 缓存指令
    CACHE_DIRECTIVES=""
    if [ "$ENABLE_CACHE" = "y" ]; then
        CACHE_DIRECTIVES=$(cat << 'CACHEEOF'
        proxy_cache tmdb_cache;
        proxy_cache_valid 200 CACHE_DAYS_PLACEHOLDERd;
        proxy_cache_valid 404 1h;
        proxy_cache_key $uri$is_args$args;
        add_header X-Cache-Status $upstream_cache_status;
CACHEEOF
)
        CACHE_DIRECTIVES="${CACHE_DIRECTIVES//CACHE_DAYS_PLACEHOLDER/$CACHE_DAYS}"
    fi

    # 生成完整配置
    cat > "$NGINX_CONF" << EOF
${CACHE_CONFIG}

server {
    listen 80;
    server_name ${DOMAIN};

    location / {
$([ -n "$IP_LIMIT_CONFIG" ] && echo -e "$IP_LIMIT_CONFIG")

${API_KEY_BLOCK}

${PROXY_PASS_LINE}
        proxy_set_header Host ${PROXY_HOST};
        proxy_ssl_server_name on;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
${CACHE_DIRECTIVES}
    }
}
EOF
}

# 修改配置
modify_config() {
    load_config

    show_header
    echo -e "${BLUE}=== 修改配置 ===${NC}"
    echo ""
    echo "1. 修改域名"
    echo "2. 修改代理目标"
    echo "3. 修改 API Key"
    echo "4. 修改缓存配置"
    echo "5. 修改 IP 限制"
    echo "6. 重新配置 HTTPS"
    echo "0. 返回主菜单"
    echo ""
    read -p "请选择: " choice

    case $choice in
        1)
            read -p "新域名: " DOMAIN
            save_config
            generate_nginx_config
            nginx -t && systemctl reload nginx
            echo -e "${GREEN}域名已更新，请记得修改 DNS 解析${NC}"
            ;;
        2)
            echo "1. TMDB API"
            echo "2. TMDB Images"
            echo "3. 自定义"
            read -p "选择: " PROXY_TYPE
            case $PROXY_TYPE in
                1) PROXY_TARGET="https://api.themoviedb.org"; PROXY_HOST="api.themoviedb.org" ;;
                2) PROXY_TARGET="https://image.tmdb.org"; PROXY_HOST="image.tmdb.org" ;;
                3)
                    read -p "目标地址: " PROXY_TARGET
                    read -p "Host 头: " PROXY_HOST
                    ;;
            esac
            save_config
            generate_nginx_config
            nginx -t && systemctl reload nginx
            echo -e "${GREEN}代理目标已更新${NC}"
            ;;
        3)
            read -p "新 API Key（留空则不追加）: " API_KEY
            save_config
            generate_nginx_config
            nginx -t && systemctl reload nginx
            echo -e "${GREEN}API Key 已更新${NC}"
            ;;
        4)
            read -p "启用缓存？(y/n): " ENABLE_CACHE
            if [ "$ENABLE_CACHE" = "y" ]; then
                read -p "缓存天数: " CACHE_DAYS
                read -p "缓存大小(GB): " CACHE_SIZE
            fi
            save_config
            generate_nginx_config
            nginx -t && systemctl reload nginx
            echo -e "${GREEN}缓存配置已更新${NC}"
            ;;
        5)
            read -p "启用 IP 限制？(y/n): " LIMIT_IP
            ALLOW_IPS=""
            if [ "$LIMIT_IP" = "y" ]; then
                echo "输入允许的 IP（空行结束）："
                while true; do
                    read -p "> " ip
                    [ -z "$ip" ] && break
                    ALLOW_IPS="${ALLOW_IPS}${ip}|"
                done
                ALLOW_IPS=${ALLOW_IPS%|}
            fi
            save_config
            generate_nginx_config
            nginx -t && systemctl reload nginx
            echo -e "${GREEN}IP 限制已更新${NC}"
            ;;
        6)
            read -p "邮箱: " EMAIL
            if command -v certbot &> /dev/null; then
                certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"
                SETUP_SSL="y"
                save_config
            else
                echo -e "${RED}请先安装 certbot${NC}"
            fi
            ;;
        0)
            main_menu
            return
            ;;
    esac

    read -p "按回车继续..."
    modify_config
}

# 查看当前配置
view_config() {
    load_config

    show_header
    echo -e "${BLUE}=== 当前配置 ===${NC}"
    echo ""
    echo -e "域名：${GREEN}${DOMAIN}${NC}"
    echo -e "代理目标：${GREEN}${PROXY_TARGET}${NC}"
    [ -n "$API_KEY" ] && echo -e "API Key：${GREEN}${API_KEY}${NC}"
    [ "$ENABLE_CACHE" = "y" ] && echo -e "缓存：${GREEN}启用（${CACHE_DAYS}天，${CACHE_SIZE}GB）${NC}"
    [ -n "$ALLOW_IPS" ] && echo -e "允许 IP：${GREEN}${ALLOW_IPS//|/, }${NC}"
    [ "$SETUP_SSL" = "y" ] && echo -e "HTTPS：${GREEN}已配置${NC}"
    echo ""
    echo -e "${BLUE}=== Nginx 状态 ===${NC}"
    systemctl status nginx --no-pager | grep -E "Active|Main PID"
    echo ""

    read -p "按回车返回主菜单..."
    main_menu
}

# 重启服务
restart_service() {
    show_header
    echo -e "${BLUE}正在重启 Nginx...${NC}"
    nginx -t && systemctl restart nginx
    echo -e "${GREEN}服务已重启${NC}"
    sleep 2
    main_menu
}

# 卸载
uninstall_proxy() {
    show_header
    echo -e "${RED}=== 卸载 TMDB 代理 ===${NC}"
    echo ""
    echo -e "${YELLOW}警告：此操作将删除所有配置和缓存${NC}"
    read -p "确认卸载？(yes/no): " CONFIRM

    if [ "$CONFIRM" = "yes" ]; then
        rm -f "$NGINX_CONF"
        rm -f "$CONFIG_FILE"
        rm -rf /var/cache/nginx/tmdb_cache
        nginx -t && systemctl reload nginx
        echo -e "${GREEN}已卸载${NC}"
        sleep 2
    fi

    main_menu
}

# 主程序
check_root
main_menu
