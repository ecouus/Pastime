# 一键脚本
```
wget -O install.sh https://raw.githubusercontent.com/ecouus/Pastime/refs/heads/main/announcements/a-one-click.sh  && chmod +x a-one-click.sh && sudo ./a-one-click.sh
```
# 手动部署
### 1. 安装必要的软件包
首先，通过 SSH 连接到您的 VPS，然后运行以下命令安装 Nginx 和 PHP-FPM：
```bash
sudo apt update
sudo apt install nginx php-fpm
```
### 2. 创建网站目录
创建指定的目录来存放公告系统：
```bash
sudo mkdir -p /home/web/announcements
```
### 3. 上传或创建文件


```bash
cd /home/web/announcements
sudo wget https://raw.githubusercontent.com/erusev/parsedown/master/Parsedown.php
sudo wget https://raw.githubusercontent.com/ecouus/Pastime/refs/heads/main/announcements/admin.php
sudo wget https://raw.githubusercontent.com/ecouus/Pastime/refs/heads/main/announcements/announcements.json
sudo wget https://raw.githubusercontent.com/ecouus/Pastime/refs/heads/main/announcements/index.php
```

### 4. 设置文件权限
确保 Nginx 可以读取所有文件，并且可以写入 JSON 文件：
```bash
sudo chown -R www-data:www-data /home/web/announcements
sudo chmod 644 /home/web/announcements/*.php
sudo chmod 666 /home/web/announcements/announcements.json
```
### 5. 配置 Nginx
创建一个 Nginx 配置文件：
```bash
sudo nano /etc/nginx/sites-available/announcements
```
添加以下内容：
```nginx
server {
    listen 80;
    server_name your_domain_or_ip;  # 替换为您的域名或IP地址

    root /home/web/announcements;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;  # 根据您的PHP版本可能需要调整
    }

    location ~ /\.ht {
        deny all;
    }
}
```

注意：您需要将 `your_domain_or_ip` 替换为您自己的域名或 VPS 的 IP 地址。 您可能还需要根据系统上的 PHP 版本调整 `fastcgi_pass` 行。您可以运行 `ls /var/run/php/` 查看可用的 PHP-FPM socket 文件。

### 6. 启用站点并重启 Nginx

```bash
sudo ln -s /etc/nginx/sites-available/announcements /etc/nginx/sites-enabled/
sudo nginx -t  # 测试配置是否有误
sudo systemctl restart nginx
sudo systemctl restart php*-fpm  # 重启PHP-FPM
```

### 7. 访问您的公告系统

现在您应该可以通过浏览器访问您的公告系统了：

- 公告页面：`http://your_domain_or_ip/`
- 管理页面：`http://your_domain_or_ip/admin.php`

### 额外的安全措施（推荐）
1. **保护管理页面**：
```nginx
# 在server块中添加
location ~ ^/admin\.php$ {
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd_announcements;
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php-fpm.sock;
}
```

然后创建密码文件：
```bash
sudo apt install apache2-utils  # 安装htpasswd工具
sudo htpasswd -c /etc/nginx/.htpasswd_announcements 您的用户名
```

2. **如果您想将此系统作为现有网站的子目录**：

如果您已经有一个网站正在运行，只想将公告系统作为子目录，可以修改现有的 Nginx 配置文件，添加以下内容：

```nginx
location /announcements {
    alias /home/web/announcements;
    try_files $uri $uri/ =404;
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_param SCRIPT_FILENAME $request_filename;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
```

记得根据需要调整访问权限和文件所有权。
