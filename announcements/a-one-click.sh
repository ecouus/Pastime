#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 变量定义
INSTALL_DIR="/home/web/announcements"
NGINX_CONF="/etc/nginx/sites-available/announcements"
NGINX_ENABLED="/etc/nginx/sites-enabled/announcements"
HTPASSWD_FILE="/etc/nginx/.htpasswd_announcements"

# 版本和资源
PARSEDOWN_URL="https://raw.githubusercontent.com/erusev/parsedown/master/Parsedown.php"
INDEX_URL="https://raw.githubusercontent.com/ecouus/Pastime/refs/heads/main/announcements/index.php"
ADMIN_URL="https://raw.githubusercontent.com/ecouus/Pastime/refs/heads/main/announcements/admin.php"
JSON_URL="https://raw.githubusercontent.com/ecouus/Pastime/refs/heads/main/announcements/announcements.json"

# 检查是否是root用户
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}此脚本需要使用root权限运行${NC}" 1>&2
   exit 1
fi

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}        公告系统一键安装脚本               ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "${GREEN}1. 安装公告系统${NC}"
    echo -e "${GREEN}2. 卸载公告系统${NC}"
    echo -e "${GREEN}3. 退出${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    read -p "请输入选项 [1-3]: " option
    
    case $option in
        1) install_system ;;
        2) uninstall_system ;;
        3) echo -e "${GREEN}已退出脚本${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请重新选择${NC}"; sleep 2; show_welcome ;;
    esac
}

# 安装系统
install_system() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}           开始安装公告系统                ${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    # 检查是否已安装 Nginx
    if ! command -v nginx &> /dev/null; then
        echo -e "${YELLOW}Nginx未安装，正在安装...${NC}"
        apt update
        apt install -y nginx
    else
        echo -e "${GREEN}Nginx已安装，跳过安装步骤${NC}"
    fi
    
    # 检查是否已安装 PHP-FPM
    if ! dpkg -l | grep -q "php.*-fpm"; then
        echo -e "${YELLOW}PHP-FPM未安装，正在安装...${NC}"
        apt update
        apt install -y php-fpm
    else
        echo -e "${GREEN}PHP-FPM已安装，跳过安装步骤${NC}"
    fi
    
    # 检查是否已安装 apache2-utils (htpasswd工具)
    if ! command -v htpasswd &> /dev/null; then
        echo -e "${YELLOW}htpasswd工具未安装，正在安装...${NC}"
        apt update
        apt install -y apache2-utils
    else
        echo -e "${GREEN}htpasswd工具已安装，跳过安装步骤${NC}"
    fi
    
    # 检查是否已安装 wget
    if ! command -v wget &> /dev/null; then
        echo -e "${YELLOW}wget未安装，正在安装...${NC}"
        apt update
        apt install -y wget
    else
        echo -e "${GREEN}wget已安装，跳过安装步骤${NC}"
    fi
    
    # 获取当前服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 询问端口
    echo -e "${GREEN}是否使用自定义端口？${NC}"
    echo -e "${GREEN}1. 是${NC}"
    echo -e "${GREEN}2. 否（使用默认80端口）${NC}"
    read -p "请选择 [1-2]: " port_option
    
    if [ "$port_option" = "1" ]; then
        read -p "请输入您要使用的端口号（1-65535）: " PORT
        # 检查端口是否为数字且在有效范围内
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
            echo -e "${RED}端口号无效，将使用默认80端口${NC}"
            PORT=80
        fi
    else
        PORT=80
    fi
    
    # 询问管理页面用户名和密码
    echo -e "${GREEN}设置管理页面访问凭据${NC}"
    read -p "请输入管理员用户名: " ADMIN_USER
    read -s -p "请输入管理员密码: " ADMIN_PASS
    echo ""
    
    # 创建目录
    echo -e "${YELLOW}创建安装目录...${NC}"
    mkdir -p $INSTALL_DIR
    
    # 下载文件
    echo -e "${YELLOW}下载所需文件...${NC}"
    wget -q $PARSEDOWN_URL -O $INSTALL_DIR/Parsedown.php
    wget -q $INDEX_URL -O $INSTALL_DIR/index.php
    wget -q $ADMIN_URL -O $INSTALL_DIR/admin.php
    wget -q $JSON_URL -O $INSTALL_DIR/announcements.json
    
    # 设置权限
    echo -e "${YELLOW}设置文件权限...${NC}"
    chown -R www-data:www-data $INSTALL_DIR
    chmod 644 $INSTALL_DIR/*.php
    chmod 644 $INSTALL_DIR/Parsedown.php
    chmod 666 $INSTALL_DIR/announcements.json
    
    # 创建Nginx配置
    echo -e "${YELLOW}创建Nginx配置...${NC}"
    cat > $NGINX_CONF << EOF
server {
    listen $PORT;
    server_name _;
    
    root $INSTALL_DIR;
    index index.php index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ ^/admin\.php$ {
        auth_basic "Restricted Access";
        auth_basic_user_file $HTPASSWD_FILE;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    # 检查PHP-FPM版本并更新配置文件
    PHP_FPM_SOCK=$(ls /var/run/php/php*-fpm.sock 2>/dev/null | sort -V | tail -n 1)
    if [ -n "$PHP_FPM_SOCK" ]; then
        sed -i "s|fastcgi_pass unix:/var/run/php/php-fpm.sock;|fastcgi_pass unix:$PHP_FPM_SOCK;|g" $NGINX_CONF
    else
        echo -e "${RED}无法找到PHP-FPM socket文件，请手动编辑Nginx配置${NC}"
    fi
    
    # 创建管理员账户
    echo -e "${YELLOW}创建管理员账户...${NC}"
    htpasswd -bc $HTPASSWD_FILE $ADMIN_USER $ADMIN_PASS
    
    # 启用站点
    echo -e "${YELLOW}启用站点...${NC}"
    ln -sf $NGINX_CONF $NGINX_ENABLED
    
    # 测试Nginx配置
    nginx -t
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Nginx配置测试失败，请检查配置文件${NC}"
        exit 1
    fi
    
    # 重启服务
    echo -e "${YELLOW}重启服务...${NC}"
    systemctl restart nginx
    systemctl restart $(ls /etc/init.d/php*-fpm 2>/dev/null | xargs -n1 basename) 2>/dev/null || systemctl restart php-fpm

    # 显示安装完成信息
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${GREEN}            公告系统安装完成              ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "${YELLOW}访问信息:${NC}"
    echo -e "公告页面: ${GREEN}http://$SERVER_IP:$PORT/${NC}"
    echo -e "管理页面: ${GREEN}http://$SERVER_IP:$PORT/admin.php${NC}"
    echo -e "管理员用户名: ${GREEN}$ADMIN_USER${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "${YELLOW}如需修改管理员账户:${NC}"
    echo -e "${GREEN}sudo htpasswd -c $HTPASSWD_FILE 新用户名${NC}"
    echo -e "${YELLOW}要添加额外的管理员账户:${NC}"
    echo -e "${GREEN}sudo htpasswd $HTPASSWD_FILE 用户名${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    read -p "按Enter键返回主菜单"
    show_welcome
}

# 卸载系统
uninstall_system() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${RED}           准备卸载公告系统                ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "${YELLOW}此操作将彻底删除公告系统的所有文件和配置！${NC}"
    echo -e "${RED}警告: 所有公告数据将会丢失！${NC}"
    echo ""
    read -p "确定要继续卸载吗？(y/n): " confirm
    
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo -e "${YELLOW}开始卸载...${NC}"
        
        # 禁用站点
        if [ -f "$NGINX_ENABLED" ]; then
            rm -f $NGINX_ENABLED
        fi
        
        # 删除Nginx配置
        if [ -f "$NGINX_CONF" ]; then
            rm -f $NGINX_CONF
        fi
        
        # 删除htpasswd文件
        if [ -f "$HTPASSWD_FILE" ]; then
            rm -f $HTPASSWD_FILE
        fi
        
        # 删除安装目录
        if [ -d "$INSTALL_DIR" ]; then
            rm -rf $INSTALL_DIR
        fi
        
        # 重启Nginx
        systemctl restart nginx
        
        echo -e "${GREEN}公告系统已成功卸载！${NC}"
    else
        echo -e "${YELLOW}已取消卸载操作${NC}"
    fi
    
    echo ""
    read -p "按Enter键返回主菜单"
    show_welcome
}

# 开始脚本
show_welcome
