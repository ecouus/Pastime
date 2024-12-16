#!/bin/bash

#########################
# 配置部分 - 按需修改这里 #
#########################

# 备份开关
BACKUP_FILES="yes"                         # 是否备份文件目录 (yes/no)
BACKUP_DB="yes"                           # 是否备份数据库 (yes/no)
MAX_BACKUPS=3                             # 保留的备份数量

# 备份目录配置
SOURCE_DIRS="/home /var/www"               # 要备份的目录，多个目录用空格分隔
BACKUP_SERVER="root@192.168.1.100"         # 修改为目标服务器地址
BACKUP_DIR="/home/backup"                  # 目标服务器存放备份文件的目录
REMOTE_PORT="22"                           # 目标服务器SSH端口

# 数据库配置
DB_USER="root"                            # 数据库用户名
DB_PASS="你的密码"                         # 数据库密码
DB_NAME="db1 db2"                         # 要备份的数据库，多个数据库用空格分隔

# SSH密钥配置
SSH_KEY="/root/.ssh/id_rsa"               # SSH私钥路径

#########################
# 脚本部分 - 无需修改下面的内容 #
#########################

# 设置日期和日志
DATE=$(date +%Y%m%d)
LOG_FILE="/var/log/backup.log"

# 记录日志的函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> ${LOG_FILE}
    echo "$1"
}

# 转换开关值为小写
BACKUP_FILES=$(echo "$BACKUP_FILES" | tr '[:upper:]' '[:lower:]')
BACKUP_DB=$(echo "$BACKUP_DB" | tr '[:upper:]' '[:lower:]')

log_message "开始备份任务..."
log_message "文件备份: $BACKUP_FILES"
log_message "数据库备份: $BACKUP_DB"

# 创建临时目录
TEMP_DIR="/tmp/backup_${DATE}"
mkdir -p ${TEMP_DIR}
log_message "创建临时目录: ${TEMP_DIR}"

# 备份数据库
if [ "$BACKUP_DB" = "yes" ] && [ ! -z "${DB_NAME}" ]; then
    log_message "开始备份数据库..."
    for db in ${DB_NAME}; do
        log_message "正在备份数据库: ${db}"
        mysqldump --single-transaction --quick --lock-tables=false -u"${DB_USER}" -p"${DB_PASS}" ${db} > "${TEMP_DIR}/${db}_${DATE}.sql"
        if [ $? -eq 0 ]; then
            # 压缩SQL文件
            gzip "${TEMP_DIR}/${db}_${DATE}.sql"
            log_message "数据库 ${db} 备份完成"
        else
            log_message "错误：数据库 ${db} 备份失败"
            exit 1
        fi
    done
fi

# 备份文件目录
if [ "$BACKUP_FILES" = "yes" ]; then
    for dir in ${SOURCE_DIRS}; do
        dir_name=$(echo ${dir} | sed 's/\//_/g' | sed 's/^_//')
        log_message "正在压缩目录: ${dir} -> ${dir_name}_${DATE}.tar.gz"
        tar czf "${TEMP_DIR}/${dir_name}_${DATE}.tar.gz" ${dir}
        if [ $? -eq 0 ]; then
            log_message "压缩完成: ${dir_name}_${DATE}.tar.gz"
        else
            log_message "错误：压缩失败: ${dir}"
            exit 1
        fi
    done
fi

# 检查是否有文件需要传输
if [ -z "$(ls -A ${TEMP_DIR})" ]; then
    log_message "没有需要备份的文件，退出脚本"
    rm -rf ${TEMP_DIR}
    exit 0
fi

# 创建远程备份目录
log_message "确保远程备份目录存在: ${BACKUP_DIR}"
ssh -p ${REMOTE_PORT} -i ${SSH_KEY} ${BACKUP_SERVER} "mkdir -p ${BACKUP_DIR}"

# 传输备份文件到远程服务器
log_message "开始传输备份文件到远程服务器..."
scp -P ${REMOTE_PORT} -i ${SSH_KEY} ${TEMP_DIR}/* ${BACKUP_SERVER}:${BACKUP_DIR}/
if [ $? -eq 0 ]; then
    log_message "文件传输成功"
else
    log_message "错误：文件传输失败"
    exit 1
fi

# 如果备份了文件，清理文件的旧备份
if [ "$BACKUP_FILES" = "yes" ]; then
    for dir in ${SOURCE_DIRS}; do
        dir_name=$(echo ${dir} | sed 's/\//_/g' | sed 's/^_//')
        log_message "清理 ${dir_name} 的旧备份，只保留最新的 ${MAX_BACKUPS} 份"
        ssh -p ${REMOTE_PORT} -i ${SSH_KEY} ${BACKUP_SERVER} "cd ${BACKUP_DIR} && \
            ls -t ${dir_name}*.tar.gz 2>/dev/null | \
            awk 'NR>${MAX_BACKUPS}' | \
            xargs -r rm"
    done
fi

# 如果备份了数据库，清理数据库的旧备份
if [ "$BACKUP_DB" = "yes" ] && [ ! -z "${DB_NAME}" ]; then
    for db in ${DB_NAME}; do
        log_message "清理数据库 ${db} 的旧备份，只保留最新的 ${MAX_BACKUPS} 份"
        ssh -p ${REMOTE_PORT} -i ${SSH_KEY} ${BACKUP_SERVER} "cd ${BACKUP_DIR} && \
            ls -t ${db}_*.sql.gz 2>/dev/null | \
            awk 'NR>${MAX_BACKUPS}' | \
            xargs -r rm"
    done
fi

# 清理本地临时文件
log_message "清理本地临时目录..."
rm -rf ${TEMP_DIR}

log_message "备份任务完成！"

# 列出备份文件确认
log_message "远程服务器上的备份文件列表："
ssh -p ${REMOTE_PORT} -i ${SSH_KEY} ${BACKUP_SERVER} "ls -lh ${BACKUP_DIR}"
