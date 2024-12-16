# Linux自动备份脚本使用指南

## 功能概述
这是一个自动备份脚本，可以实现以下功能：
- 备份指定目录（默认 `/home` 和 `/var/www`）
- 备份MySQL数据库
- 将备份传输到远程服务器
- 自动清理旧备份文件
- 支持通过配置开关控制备份内容
- 自动记录备份日志

## 安装步骤

### 1. 创建脚本文件
```bash
# 创建脚本
nano /root/backup.sh

# 复制脚本内容到文件中
将脚本内容粘贴进去]（https://github.com）

# 设置权限，因包含敏感信息，故仅为文件所有者设置读写执行权限
chmod 700 /root/backup.sh
```

### 2. 配置脚本
修改脚本开头的配置部分：
```bash
# 备份开关
BACKUP_FILES="yes"                         # 是否备份文件目录 (yes/no)
BACKUP_DB="yes"                           # 是否备份数据库 (yes/no)

# 备份目录配置
SOURCE_DIRS="/home /var/www"               # 要备份的目录
BACKUP_SERVER="root@192.168.1.100"         # 目标服务器地址
BACKUP_DIR="/home/backup"                  # 备份存放目录
REMOTE_PORT="123"                          # SSH端口
MAX_BACKUPS=3                             # 保留的备份数量

# 数据库配置
DB_USER="root"                            # 数据库用户名
DB_PASS="你的密码"                         # 数据库密码
DB_NAME="typecho"                         # 数据库名称
```

### 3. 配置SSH免密登录
```bash
# 生成SSH密钥
ssh-keygen -t rsa

# 如果目标服务器允许密码登录，使用以下命令
ssh-copy-id -p 123 user@目标服务器IP

# 如果目标服务器使用密钥登录，手动复制公钥
# 1. 查看公钥
cat ~/.ssh/id_rsa.pub
# 2. 将内容粘贴到目标服务器的 ~/.ssh/authorized_keys 文件中
nano /root/.ssh/authorized_keys
```

### 4. 设置定时任务
```bash
# 编辑定时任务
crontab -e

# 添加以下内容（每天凌晨4:30执行）
30 4 * * * /root/backup.sh
```

## 使用说明

### 备份控制
通过修改脚本开头的配置来控制备份内容：

1. 备份所有内容：
```bash
BACKUP_FILES="yes"
BACKUP_DB="yes"
```

2. 只备份文件：
```bash
BACKUP_FILES="yes"
BACKUP_DB="no"
```

3. 只备份数据库：
```bash
BACKUP_FILES="no"
BACKUP_DB="yes"
```

### 日志查看
```bash
# 查看备份日志
tail -f /var/log/backup.log
```

### 手动执行
```bash
# 直接运行脚本
/root/backup.sh
```

## 备份文件说明

### 文件目录备份
- 格式：`目录名_日期.tar.gz`
- 示例：`home_20241216.tar.gz`, `var_www_20241216.tar.gz`

### 数据库备份
- 格式：`数据库名_日期.sql.gz`
- 示例：`typecho_20241216.sql.gz`

## 常见问题解决

### 1. 备份失败
检查以下几点：
- SSH免密登录是否配置正确
- 数据库密码是否正确
- 目标服务器空间是否足够
- 查看日志文件 `/var/log/backup.log`

### 2. 定时任务未执行
检查以下几点：
- 确认crontab服务是否运行：`systemctl status cron`
- 检查crontab配置：`crontab -l`
- 检查系统日志：`tail -f /var/log/syslog`

### 3. 远程传输失败
检查以下几点：
- SSH端口是否正确
- 网络连接是否正常
- 目标服务器是否在线
- SSH密钥权限是否正确（600）

## 维护建议

1. 定期检查：
- 查看备份日志
- 确认备份文件完整性
- 检查备份所占用的空间

2. 安全建议：
- 定期更换数据库密码
- 保护好SSH私钥
- 限制备份文件的访问权限

3. 建议配置：
- 根据数据重要性调整备份频率
- 根据磁盘空间调整保留的备份数量
- 根据网络状况调整备份时间

## 技术支持
如遇到问题，请：
1. 查看 `/var/log/backup.log` 日志文件
2. 检查服务器系统日志
3. 手动执行脚本测试
