#!/bin/bash

# 客户端证书管理脚本
# 用于创建和删除客户端证书，支持设置网站访问限制

# 设置证书存储目录
CERT_DIR="/home/client-cert"
# 设置证书有效期（天）
VALIDITY=36500  # 100年

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请以root权限运行此脚本${NC}"
  exit 1
fi

# 确保证书目录存在
ensure_cert_dir() {
  if [ ! -d "$CERT_DIR" ]; then
    echo -e "${YELLOW}证书目录不存在，创建目录: ${CERT_DIR}${NC}"
    mkdir -p "$CERT_DIR"
  fi
}

# 检查CA是否已存在
check_ca() {
  if [ ! -f "${CERT_DIR}/ca.crt" ] || [ ! -f "${CERT_DIR}/ca.key" ]; then
    echo -e "${YELLOW}CA证书不存在，需要先创建CA${NC}"
    return 1
  fi
  return 0
}

# 创建CA证书
create_ca() {
  echo -e "${BLUE}正在创建CA证书...${NC}"
  
  # 提示用户输入CA名称
  read -p "请输入CA名称 (默认: YourCA): " ca_name
  ca_name=${ca_name:-YourCA}
  
  # 生成CA密钥和证书
  openssl genrsa -out "${CERT_DIR}/ca.key" 2048 &>/dev/null
  openssl req -x509 -new -nodes -key "${CERT_DIR}/ca.key" -subj "/CN=${ca_name}" -days $VALIDITY -out "${CERT_DIR}/ca.crt" &>/dev/null
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}CA证书创建成功!${NC}"
    echo -e "  证书: ${CERT_DIR}/ca.crt"
    echo -e "  私钥: ${CERT_DIR}/ca.key"
    return 0
  else
    echo -e "${RED}CA证书创建失败!${NC}"
    return 1
  fi
}

# 创建客户端证书
create_client_cert() {
  # 检查CA是否存在
  check_ca
  if [ $? -ne 0 ]; then
    create_ca
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi
  
  # 提示用户输入客户端证书名称
  read -p "请输入客户端证书名称 (例如: iPhone, iPad): " client_name
  
  if [ -z "$client_name" ]; then
    echo -e "${RED}错误: 证书名称不能为空${NC}"
    return 1
  fi
  
  # 提示用户输入该证书允许访问的网站
  read -p "请输入此证书可访问的网站名称 (例如: nav, dashboard): " website_name
  website_name=${website_name:-$client_name}
  
  # 为客户端证书创建独立文件夹
  CLIENT_CERT_DIR="${CERT_DIR}/${client_name}"
  if [ ! -d "$CLIENT_CERT_DIR" ]; then
    echo -e "${BLUE}为证书创建目录: ${CLIENT_CERT_DIR}${NC}"
    mkdir -p "$CLIENT_CERT_DIR"
  fi
  
  # 检查证书是否已存在
  if [ -f "${CLIENT_CERT_DIR}/${client_name}.crt" ]; then
    echo -e "${YELLOW}警告: 证书 ${client_name} 已存在${NC}"
    read -p "是否覆盖? (y/n): " overwrite
    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
      echo -e "${YELLOW}操作已取消${NC}"
      return 0
    fi
  fi
  
  echo -e "${BLUE}正在创建客户端证书: ${client_name} (访问限制: ${website_name})...${NC}"
  
  # 创建配置文件
  CONFIG_FILE="${CLIENT_CERT_DIR}/${client_name}.cnf"
  cat > "$CONFIG_FILE" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${client_name}
O = Client Certificate
OU = Access_${website_name}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${website_name}.example.com
EOF
  
  # 生成客户端私钥
  openssl genrsa -out "${CLIENT_CERT_DIR}/${client_name}.key" 2048 &>/dev/null
  
  # 使用配置文件生成证书请求
  openssl req -new -key "${CLIENT_CERT_DIR}/${client_name}.key" -config "$CONFIG_FILE" -out "${CLIENT_CERT_DIR}/${client_name}.csr" &>/dev/null
  
  # 使用CA签发客户端证书，包含扩展信息
  openssl x509 -req -in "${CLIENT_CERT_DIR}/${client_name}.csr" \
    -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" -CAcreateserial \
    -out "${CLIENT_CERT_DIR}/${client_name}.crt" -days $VALIDITY \
    -extfile "$CONFIG_FILE" -extensions v3_req &>/dev/null
  
  # 提示用户输入P12密码
  echo -e "${YELLOW}请为P12证书文件设置密码 (将用于导入设备)${NC}"
  openssl pkcs12 -export -inkey "${CLIENT_CERT_DIR}/${client_name}.key" -in "${CLIENT_CERT_DIR}/${client_name}.crt" -certfile "${CERT_DIR}/ca.crt" -out "${CLIENT_CERT_DIR}/${client_name}.p12"
  
  # 复制一份证书到主目录方便管理
  cp "${CLIENT_CERT_DIR}/${client_name}.crt" "${CERT_DIR}/${client_name}.crt"
  
  # 显示证书的详细信息
  echo
  echo -e "${BLUE}证书详细信息:${NC}"
  openssl x509 -text -noout -in "${CLIENT_CERT_DIR}/${client_name}.crt" | grep -E "Subject:|X509v3 Subject Alternative Name:" -A 1
  
  if [ $? -eq 0 ]; then
    echo
    echo -e "${GREEN}客户端证书创建成功!${NC}"
    echo -e "  证书目录: ${CLIENT_CERT_DIR}"
    echo -e "  P12证书 (用于导入设备): ${CLIENT_CERT_DIR}/${client_name}.p12"
    echo -e "  证书: ${CLIENT_CERT_DIR}/${client_name}.crt"
    echo -e "  私钥: ${CLIENT_CERT_DIR}/${client_name}.key"
    echo -e "  证书请求: ${CLIENT_CERT_DIR}/${client_name}.csr"
    echo
    echo -e "${YELLOW}在Nginx中使用以下配置来限制访问:${NC}"
    echo -e "  if (\$ssl_client_s_dn ~ \"OU=Access_${website_name}\") { set \$access_allowed 1; }"
    return 0
  else
    echo -e "${RED}客户端证书创建失败!${NC}"
    return 1
  fi
}

# 列出所有客户端证书
list_client_certs() {
  echo -e "${BLUE}证书列表:${NC}"
  
  # 查找独立目录中的证书，避免重复计数主目录的证书
  cert_dirs=$(find "$CERT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  
  if [ -z "$cert_dirs" ]; then
    echo -e "${YELLOW}没有找到客户端证书${NC}"
    return 0
  fi
  
  echo -e "${GREEN}已发现以下客户端证书:${NC}"
  for dir in $cert_dirs; do
    cert_name=$(basename "$dir")
    cert_file="${dir}/${cert_name}.crt"
    
    # 如果证书文件存在，显示其信息
    if [ -f "$cert_file" ]; then
      expiry=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
      subject=$(openssl x509 -subject -noout -in "$cert_file" | sed 's/subject=//g')
      
      # 提取访问权限信息
      access_info=$(openssl x509 -text -noout -in "$cert_file" | grep "OU=" | head -1 | sed 's/.*OU=Access_\([^,]*\).*/\1/')
      
      echo -e "  ${YELLOW}$cert_name${NC}"
      echo -e "    主题: $subject"
      
      if [ -n "$access_info" ]; then
        echo -e "    访问权限: $access_info"
      fi
      
      echo -e "    过期时间: $expiry"
      echo -e "    证书目录: $dir"
      echo ""
    fi
  done
}

# 删除客户端证书
delete_client_cert() {
  # 列出所有证书目录
  cert_dirs=$(find "$CERT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  
  if [ -z "$cert_dirs" ]; then
    echo -e "${YELLOW}没有找到客户端证书可删除${NC}"
    return 0
  fi
  
  # 创建证书名称数组
  declare -a cert_names
  i=1
  
  echo -e "${BLUE}可删除的证书:${NC}"
  for dir in $cert_dirs; do
    cert_name=$(basename "$dir")
    cert_names[$i]=$cert_name
    echo -e "  ${GREEN}$i)${NC} $cert_name"
    ((i++))
  done
  
  # 提示用户选择要删除的证书
  read -p "请输入要删除的证书编号 (输入0取消): " cert_num
  
  if [ -z "$cert_num" ] || [ "$cert_num" -eq 0 ]; then
    echo -e "${YELLOW}操作已取消${NC}"
    return 0
  fi
  
  if [ "$cert_num" -ge 1 ] && [ "$cert_num" -lt "$i" ]; then
    client_name=${cert_names[$cert_num]}
    echo -e "${YELLOW}您选择删除证书: $client_name${NC}"
    read -p "确认删除? (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      # 删除证书目录
      if [ -d "${CERT_DIR}/${client_name}" ]; then
        rm -rf "${CERT_DIR}/${client_name}"
        echo -e "${GREEN}证书目录 ${CERT_DIR}/${client_name} 已删除${NC}"
      fi
      
      # 删除主目录中的证书文件（如果存在）
      rm -f "${CERT_DIR}/${client_name}.key" "${CERT_DIR}/${client_name}.csr" "${CERT_DIR}/${client_name}.crt" "${CERT_DIR}/${client_name}.p12"
      
      echo -e "${GREEN}证书 $client_name 已成功删除${NC}"
    else
      echo -e "${YELLOW}操作已取消${NC}"
    fi
  else
    echo -e "${RED}无效的选择${NC}"
  fi
}

# 显示帮助菜单
show_help() {
  echo -e "${BLUE}客户端证书管理工具${NC}"
  echo -e "此脚本用于创建和管理用于Nginx客户端认证的SSL证书，支持设置网站访问限制"
  echo ""
  echo -e "${GREEN}用法:${NC}"
  echo -e "  $0 [选项]"
  echo ""
  echo -e "${GREEN}选项:${NC}"
  echo -e "  ${YELLOW}create-ca${NC}     创建新的CA证书"
  echo -e "  ${YELLOW}create${NC}        创建新的客户端证书"
  echo -e "  ${YELLOW}list-delete${NC}   列出所有客户端证书并可选择删除"
  echo -e "  ${YELLOW}help${NC}          显示此帮助信息"
  echo ""
  echo -e "${GREEN}交互式菜单选项:${NC}"
  echo -e "  ${YELLOW}1${NC} - 创建CA证书"
  echo -e "  ${YELLOW}2${NC} - 创建客户端证书"
  echo -e "  ${YELLOW}9${NC} - 列出所有证书并可选择删除"
  echo -e "  ${YELLOW}0${NC} - 退出"
  echo ""
  echo -e "${GREEN}示例:${NC}"
  echo -e "  $0 create        # 创建新的客户端证书"
  echo -e "  $0 nginx-config  # 生成Nginx配置示例"
}

# 主程序
main() {
  ensure_cert_dir
  cd "$CERT_DIR" || exit 1
  
  while true; do
    # 处理命令行参数
    if [ -n "$1" ]; then
      case "$1" in
        create-ca)
          create_ca
          exit 0
          ;;
        create)
          create_client_cert
          exit 0
          ;;
        list-delete)
          list_client_certs
          if [ -n "$(find "$CERT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
            echo -e "${YELLOW}要删除证书吗?${NC}"
            read -p "是否继续删除操作? (y/n): " delete_confirm
            if [ "$delete_confirm" = "y" ] || [ "$delete_confirm" = "Y" ]; then
              delete_client_cert
            fi
          fi
          exit 0
          ;;
        help|--help|-h)
          show_help
          exit 0
          ;;
        *)
          show_help
          exit 1
          ;;
      esac
    else
      # 显示交互式菜单
      clear
      echo -e "${BLUE}客户端证书管理${NC}"
      echo -e "${GREEN}请选择操作:${NC}"
      echo -e "  ${YELLOW}1)${NC} 创建CA证书"
      echo -e "  ${YELLOW}2)${NC} 创建客户端证书"
      echo -e "  ${YELLOW}3)${NC} 生成Nginx配置示例"
      echo -e "  ${YELLOW}9)${NC} 列出所有证书并删除"
      echo -e "  ${YELLOW}0)${NC} 退出"
      read -p "请输入选项 [0,1,2,3,9]: " choice
      
      case "$choice" in
        1) 
          create_ca
          echo
          read -p "按回车键返回主菜单" 
          ;;
        2) 
          create_client_cert
          echo
          read -p "按回车键返回主菜单" 
          ;;
        9) 
          list_client_certs
          if [ -n "$(find "$CERT_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
            echo -e "${YELLOW}要删除证书吗?${NC}"
            read -p "是否继续删除操作? (y/n): " delete_confirm
            if [ "$delete_confirm" = "y" ] || [ "$delete_confirm" = "Y" ]; then
              delete_client_cert
            fi
          fi
          echo
          read -p "按回车键返回主菜单" 
          ;;
        0) 
          echo -e "${GREEN}感谢使用，再见!${NC}"
          exit 0 
          ;;
        *) 
          echo -e "${RED}无效的选择${NC}"
          sleep 2
          ;;
      esac
    fi
  done
}

# 执行主程序
main "$@"
