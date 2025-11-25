### **终极部署协议 V5.0：零信任堡垒**

**核心哲学:**
*   **身份，而非位置:** 我们不再信任任何网络位置（IP地址）。信任的唯一依据是可验证的、加密的身份（证书）。
*   **默认拒绝:** 任何未经身份验证的连接，都将在协议层被直接丢弃，甚至没有机会触及我们的应用逻辑。
*   **配置即宪法:** 核心安全策略必须在代码中清晰、明确地定义，不可动摇。

---

### **阶段零：服务器初始设置 (进度: 0% -> 10%)**

这一阶段的目标是建立一个干净、安全、标准化的操作环境。

1.  **获取服务器信息:**
    *   你的服务器公网 IP 地址。**假设为 `192.0.2.100`**。
    *   你的域名。**假设为 `010314.xyz`**。

2.  **以 root 身份首次登录:**
    ```bash
    ssh root@192.0.2.100
    ```

3.  **创建管理员用户 (安全基石):**
    *   我们绝不长期使用 root。创建一个拥有 `sudo` 权限的日常管理用户。
    ```bash
    # 创建新用户，例如 'ank'
    adduser ank
    
    # 赋予该用户 sudo 权限
    usermod -aG sudo ank
    ```
    *   现在，退出并用新用户重新登录。未来的所有操作都将通过此用户完成。
    ```bash
    exit
    ssh ank@192.0.2.100
    ```

4.  **系统更新与核心软件包安装:**
    *   确保系统处于最新的安全状态，并安装我们架构所需的所有组件。
    ```bash
    # 更新软件包列表并升级所有已安装的包
    sudo apt update && sudo apt upgrade -y
    
    # 安装 Nginx (我们的核心引擎) 和 UFW (我们的基础防火墙)
    sudo apt install nginx ufw -y
    ```

5.  **配置基础防火墙 (第一道防线):**
    *   防火墙的职责不是识别Cloudflare，而是**只允许**可信的协议进入。
    ```bash
    # 允许 SSH 连接 (否则你将被锁定在外)
    sudo ufw allow OpenSSH
    
    # 允许 HTTP 和 HTTPS 流量
    sudo ufw allow 'Nginx Full'
    
    # 启用防火墙
    sudo ufw enable
    ```
    *   在提示时输入 `y` 确认。

---

### **阶段一：Cloudflare 配置 (进度: 10% -> 30%)**

这一阶段的目标是在云端建立我们零信任架构的“身份认证中心”。

1.  **登录 Cloudflare 并添加站点:**
    *   登录你的 Cloudflare 账户，添加 `010314.xyz` 站点，并按照指引将你的域名NS记录指向Cloudflare。**这是前提。**

2.  **配置 DNS 记录 (流量入口):**
    *   在 Cloudflare 的 DNS 页面，确保你有以下两条 **A 记录**，并且它们都处于**代理模式 (橙色云朵)**。
        *   **记录一 (根域名):**
            *   **Type:** `A`
            *   **Name:** `@` (或 `010314.xyz`)
            *   **IPv4 address:** `192.0.2.100`
            *   **Proxy status:** **Proxied**
        *   **记录二 (通配符):**
            *   **Type:** `A`
            *   **Name:** `*`
            *   **IPv4 address:** `192.0.2.100`
            *   **Proxy status:** **Proxied**

3.  **配置 SSL/TLS (加密通道):**
    *   左侧菜单进入 "SSL/TLS" -> "Overview"。
    *   加密模式选择 **Full (Strict)**。这是零信任架构的最低要求，确保从浏览器到Cloudflare，再从Cloudflare到你的服务器，全程加密。

4.  **生成源站证书 (服务器的“身份证”):**
    *   左侧菜单 "SSL/TLS" -> "Origin Server"。
    *   点击 "Create Certificate"。保持默认选项，点击 "Create"。
    *   **关键操作:** Cloudflare会提供“Origin Certificate”和“Private Key”。**立即复制它们**。我们将在下一阶段将它们部署到服务器上。

5.  **启用双向认证 (激活身份检查站):**
    *   在同一页面 ("Origin Server")，找到 "Authenticated Origin Pulls"，将其**开启 (Enable)**。
    *   **这就是零信任架构的开关。** 开启后，Cloudflare在连接你的服务器时，会主动出示一个客户端证书，证明自己的身份。

---

### **阶段二：服务器 Nginx 部署 (进度: 30% -> 90%)**

这是架构的核心。我们将从零开始，构建一个干净、模块化、零信任的Nginx配置。

1.  **清理默认配置:**
    *   清空/etc/nginx/*/下的子文件。

2.  **部署源站证书 (服务器身份证明):**
    *   将**阶段一**获取的证书和私钥部署到服务器。
    ```bash
    # 创建存放证书和私钥的安全目录
    sudo mkdir -p /etc/ssl/certs /etc/ssl/private
    
    # 创建并粘贴证书内容
    sudo nano /etc/ssl/certs/cloudflare_origin.pem
    
    # 创建并粘贴私钥内容
    sudo nano /etc/ssl/private/cloudflare_origin.key
    
    # 锁定私钥权限，只有root和Nginx主进程能读取
    sudo chmod 600 /etc/ssl/private/cloudflare_origin.key
    ```

3.  **部署 Cloudflare CA 证书 (验证Cloudflare的身份):**
    *   为了让Nginx能验证Cloudflare出示的客户端证书，我们需要Cloudflare的CA。
    ```bash
    # 创建存放第三方CA的目录
    sudo mkdir -p /etc/nginx/ssl
    
    # 下载Cloudflare Authenticated Origin Pulls的CA证书
    sudo wget https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem -O /etc/nginx/ssl/cloudflare_aop_ca.pem
    ```

4.  **编写主配置文件 `nginx.conf`:**
    *   这是Nginx的全局配置。我们将优化它，并确保它加载我们的站点配置。
    ```bash
    # 备份原始文件
    sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    
    # 创建新的主配置文件
    sudo nano /etc/nginx/nginx.conf
    ```
    *   **粘贴以下完整内容:**
    ```nginx
    # /etc/nginx/nginx.conf
    # 零信任架构 V5.0 - 全局配置
    
    # 定义Nginx工作进程的用户。建议使用一个非特权用户，例如 www-data 或 nginx。
    # 如果你的PHP-FPM或其他服务使用特定用户，保持一致性可能更好。
    user www-data; 
    # 根据CPU核心数自动优化工作进程数量。
    worker_processes auto;
    
    # Nginx主进程的PID文件路径。
    pid /run/nginx.pid;
    
    # 动态加载Nginx模块。
    include /etc/nginx/modules.d/*.conf;
    include /etc/nginx/modules-enabled/*.conf;
    
    events {
        # 每个工作进程允许的最大并发连接数。
        worker_connections 2048;
        # 优化网络连接处理，允许一次性接受所有新连接，在高并发下提升性能。
        multi_accept on;
    }
    
    http {
        # --- 基础网络与性能优化 ---
        sendfile on;                 # 开启高效文件传输模式，减少内核态到用户态的拷贝。
        tcp_nopush on;               # 在sendfile开启时，将多个小包组合成一个大包发送，提高网络效率。
        tcp_nodelay on;              # 禁用Nagle算法，降低小数据包的延迟，对API和WebSocket友好。
        keepalive_timeout 65s;       # HTTP长连接的超时时间，平衡资源占用和性能。
        types_hash_max_size 2048;
        server_tokens off;           # 安全基线：在错误页面和响应头中隐藏Nginx版本号。
    
        # 引入MIME类型定义。
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
    
        # --- 统一的、包含丰富调试信息的日志格式 ---
        log_format main_ext '$remote_addr - $remote_user [$time_local] "$request" '
                            '$status $body_bytes_sent "$http_referer" '
                            '"$http_user_agent" "$http_cf_ray" '
                            'rt=$request_time uct="$upstream_connect_time" uht="$upstream_header_time" urt="$upstream_response_time"';
    
        # 默认的访问和错误日志路径。站点配置中可以覆盖。
        access_log /var/log/nginx/access.log main_ext;
        error_log /var/log/nginx/error.log;
    
        # --- Gzip 压缩配置 ---
        gzip on;
        gzip_vary on;
        gzip_proxied any;
        gzip_comp_level 6;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
        # --- 全局SSL/TLS安全基线 ---
        ssl_protocols TLSv1.2 TLSv1.3; # 强制使用现代、安全的TLS协议。
        ssl_prefer_server_ciphers on;  # 由服务器端协商最优的加密套件，防止降级攻击。
        ssl_session_cache shared:SSL:10m; # 开启SSL会话缓存，加速后续TLS握手。
        ssl_session_timeout 10m;
        ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    
        # --- 全局 WebSocket Connection 头智能映射 ---
        # 这是实现优雅WebSocket代理的关键。
        map $http_upgrade $connection_upgrade {
            default upgrade;
            ''      close;
        }
    
        # --- 导入所有站点配置 ---
        # 这是我们架构的入口点。
        include /etc/nginx/conf.d/*.conf;
    }
    ```

5.  **创建模块化代码片段 (Snippets):**
    *   我们将所有可重用的配置块，都放入 `snippets` 目录，以实现“不要重复自己”(DRY)的原则。
    ```bash
    sudo mkdir -p /etc/nginx/snippets
    ```
    *   **`cloudflare-mtls-auth.conf` (零信任核心):**
        ```bash
        sudo nano /etc/nginx/snippets/cloudflare-mtls-auth.conf
        ```
        ```nginx
        # /etc/nginx/snippets/cloudflare-mtls-auth.conf
        # 零信任核心模块 V1.0
        # 强制所有进入的连接必须通过Cloudflare客户端证书的验证。
        
        # 1. 指定用于验证Cloudflare客户端证书的CA证书。
        ssl_client_certificate /etc/nginx/ssl/cloudflare_aop_ca.pem;
        
        # 2. 开启客户端证书验证。'on'表示强制验证，失败则连接被拒绝。
        ssl_verify_client on;
        
        # 3. 设置证书链的验证深度。
        ssl_verify_depth 1;
        ```
    *   **`security-headers.conf` (浏览器安全增强):**
        ```bash
        sudo nano /etc/nginx/snippets/security-headers.conf
        ```
        ```nginx
        # /etc/nginx/snippets/security-headers.conf
        # 添加一系列增强浏览器安全性的HTTP头。
        
        # 防止浏览器错误地解析文件类型 (MIME-sniffing)。
        add_header X-Content-Type-Options "nosniff" always;
        
        # 开启浏览器内置的XSS过滤器。
        add_header X-XSS-Protection "1; mode=block" always;
        
        # 防止你的网站被嵌入到iframe中 (点击劫持攻击)。
        add_header X-Frame-Options "SAMEORIGIN" always;
        
        # 控制Referer头的发送策略，增强隐私。
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        
        # 推荐开启HSTS，但在确保全站HTTPS完美运行后再取消注释。
        # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        ```

6.  **编写终极站点配置文件 `010314.xyz.conf`:**
    *   这是你所有站点逻辑的唯一入口和控制中心。
    ```bash
    sudo nano /etc/nginx/conf.d/010314.xyz.conf
    ```
    *   **粘贴以下完整内容:**
    ```nginx
    # /etc/nginx/conf.d/010314.xyz.conf
    # 站点: 010314.xyz (动态路由架构 V5.0 - 零信任)
    
    # ======================================================================
    # 第一部分: 路由映射表 (The Constitution)
    # 这是声明式配置的核心。日常维护99%的时间都在这里进行。
    # ======================================================================
    
    # --- 映射1: 主机名 -> 网站根目录 ---
    map $host $site_root {
        # 默认规则: 自动将子域名映射到同名目录。
        # 例如: blog.010314.xyz -> /var/www/010314.xyz/blog
        ~^(?<subdomain>.+)\.010314\.xyz$   /var/www/010314.xyz/$subdomain;
        
        # 精确匹配: 为根域名指定目录。
        010314.xyz                        /var/www/010314.xyz/main;
    }
    
    # --- 映射2: 主机名 -> 后端服务地址 (用于反向代理) ---
    map $host $backend_target {
        # 示例:
        # api.010314.xyz    127.0.0.1:8080;
        default             "";
    }
    
    # --- 映射3: 主机名 -> 是否为PHP站点 (激活PHP-FPM) ---
    map $host $is_php_site {
        # 示例:
        # blog.010314.xyz   1;
        default             0; # 默认禁用PHP
    }
    
    # --- 映射4: PHP开关 -> URL重写的回退路径 ---
    # 这是避免在location块中使用if语句的关键技巧，性能更优。
    map $is_php_site $fallback_file {
        1   /index.php?$query_string; # PHP站点的回退路径
        0   /index.html;              # 静态/SPA站点的回退路径
    }
    
    # ======================================================================
    # 第二部分: 单一服务入口 (The Engine)
    # ======================================================================
    
    server {
        # 监听443端口，并启用SSL和HTTP/2。
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
    
        # 使用前导点匹配根域名和所有子域名，作为统一入口。
        server_name .010314.xyz;
    
        # --- 身份与加密核心 ---
        # 1. 指定服务器身份 (由Cloudflare签发的源站证书)。
        ssl_certificate /etc/ssl/certs/cloudflare_origin.pem;
        ssl_certificate_key /etc/ssl/private/cloudflare_origin.key;
    
        # 2. 强制验证客户端身份 (必须是Cloudflare)。
        include snippets/cloudflare-mtls-auth.conf;
    
        # --- 安全的真实IP获取 ---
        # 由于mTLS确保了只有Cloudflare能连接，我们可以无条件信任这个头。
        real_ip_header CF-Connecting-IP;
        set_real_ip_from 0.0.0.0/0;
        set_real_ip_from ::/0;
    
        # --- 通用配置 ---
        include snippets/security-headers.conf;
        # 日志文件根据访问的主机名动态创建。
        access_log /var/log/nginx/$host.access.log main_ext;
        error_log /var/log/nginx/$host.error.log;
        # 根目录由上方的map指令动态决定。
        root $site_root;
        # 为特殊站点提供覆盖配置的扩展插槽。
        include /etc/nginx/sites-overrides/*.conf;
    
        # --- 核心路由逻辑 ---
        location / {
            # 预先定义所有反向代理所需的HTTP头。
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_http_version 1.1;
        
            # 仅当$backend_target非空时，才执行反向代理。
            if ($backend_target != "") {
                proxy_pass http://$backend_target;
                break; 
            }
        
            # 如果不是反向代理请求，则作为静态或PHP站点处理。
            index index.html index.htm index.php;
            try_files $uri $uri/ $fallback_file;
        }
    
        # --- PHP处理逻辑 ---
        location ~ \.php$ {
            # 如果站点未在map中标记为PHP站点，则拒绝访问.php文件。
            if ($is_php_site = 0) {
                return 404;
            }
            
            # 引入标准的fastcgi配置。
            include snippets/fastcgi-php.conf;
            # 确保你的PHP-FPM socket路径正确。
            fastcgi_pass unix:/run/php/php8.1-fpm.sock; 
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    
        # --- 通用静态资源缓存规则 ---
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff2)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
    
        # --- 通用安全规则 ---
        location ~ /\. {
            deny all; # 拒绝访问.htaccess, .git等隐藏文件。
        }
    }
    
    # --- HTTP到HTTPS的全局重定向规则 ---
    server {
        listen 80;
        listen [::]:80;
        server_name .010314.xyz;
        
        # 将所有其他HTTP请求永久重定向到HTTPS。
        location / {
            return 301 https://$host$request_uri;
        }
    }
    ```

7.  **创建必要的目录:**
    *   我们的配置引用了一些目录，现在创建它们。
    ```bash
    # 用于存放站点文件的根目录
    sudo mkdir -p /var/www/010314.xyz/main /var/www/010314.xyz/blog /var/www/010314.xyz/work
    
    # 用于Let's Encrypt验证的目录
    sudo mkdir -p /var/www/html
    
    # 用于存放特殊站点覆盖配置的目录
    sudo mkdir -p /etc/nginx/sites-overrides
    
    # 更改文件所有权，以便你的用户可以管理网站内容
    sudo chown -R ank:ank /var/www/010314.xyz
    ```

---

### **阶段三：启动、验证与工作流 (进度: 90% -> 100%)**

1.  **最终语法检查:**
    *   这是决定性的一步。
    ```bash
    sudo nginx -t
    ```
    *   如果一切正确，你将看到 `syntax is ok` 和 `test is successful`。

2.  **启动 Nginx 服务:**
    ```bash
    sudo systemctl start nginx
    sudo systemctl enable nginx
    ```

3.  **验证零信任架构:**
    *   **测试一 (直接访问):** 在浏览器中输入 `https://192.0.2.100`。你**必须**看到一个SSL错误（例如 `SSL_ERROR_BAD_CERT_ALERT`）。这证明了mTLS正在工作，你的服务器拒绝了没有Cloudflare客户端证书的连接。
    *   **测试二 (通过Cloudflare访问):** 在浏览器中访问 `https://010314.xyz`。网站应该可以正常访问。

4.  **终极工作流:**
    *   **上线新静态站 `blog.010314.xyz`:**
        1.  在服务器上创建目录 `/var/www/010314.xyz/blog` 并上传文件。
        2.  **完成。** `map` 规则会自动处理路由。
    *   **上线新反代服务 `api.010314.xyz` 到 `127.0.0.1:8080`:**
        1.  编辑 `/etc/nginx/conf.d/010314.xyz.conf`。
        2.  在 `$backend_target` map中添加一行: `api.010314.xyz 127.0.0.1:8080;`
        3.  执行 `sudo nginx -t && sudo systemctl reload nginx`。
    *   **为 `work.010314.xyz` 添加特殊路由:**
        1.  创建文件 `/etc/nginx/sites-overrides/work.010314.xyz.conf`。
        2.  将你的特殊 `location` 块（例如 `/terminal/api`）写入此文件。
        3.  执行 `sudo nginx -t && sudo systemctl reload nginx`。
