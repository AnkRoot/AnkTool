### **本地开发环境架构蓝图 V2.0**

**核心哲学:**
1.  **环境同构 (Environment Parity):** 本地环境必须在网络层（域名、HTTPS）无限逼近生产环境，以根除只在部署后才出现的Bug。
2.  **声明式配置 (Declarative Configuration):** 所有的环境状态（域名、代理目标）都应在少数几个集中的“事实源”（Source of Truth）中声明，而非散落在各处。
3.  **零摩擦切换 (Frictionless Switching):** 在不同的开发场景（纯本地、混合开发）之间切换，必须是原子级的、可预测的、且成本极低的操作。

---

### **模块一：事实源 (The Sources of Truth)**

这是整个架构的控制中心。未来99%的日常操作，都只发生在这个模块内。

#### **1.1 DNS 劫持清单 (`/etc/hosts`)**

此文件是本地DNS解析的最高权威。它决定了哪些域名应该被“捕获”并指向你的本地机器。

```bash
sudo nano /etc/hosts
```

**配置清单:**
```hosts
# ======================================================================
# 本地开发环境 DNS 劫持清单 V2.0
# 每一行都声明了一个“事实”：将一个域名指向本地Nginx。
# ======================================================================

# --- 纯本地开发域 (场景A) ---
127.0.0.1   ank.local
127.0.0.1   api.ank.local

# --- 混合开发域 (场景B/C) ---
# 智慧: 取消注释此行，即可将对 'work.online-domain.com' 的所有请求
#       从互联网“劫持”到你本地的Nginx，从而开启混合开发模式。
# 127.0.0.1   work.online-domain.com
```

#### **1.2 SSL 信任域 (`mkcert` 命令)**

此命令定义了哪些域名将被你的操作系统和浏览器无条件信任。它是一次性的声明，生成一个包含所有可能性的“通配证书”。

**证书生成命令:**
```bash
# 切换到证书存放目录，避免路径混淆
cd /etc/nginx/ssl/local

# 声明所有受信任的域名和IP，并生成单一的证书对。
mkcert \
  -key-file key.pem \
  -cert-file cert.pem \
  "ank.local" \
  "*.ank.local" \
  "work.online-domain.com" \
  "localhost" \
  "127.0.0.1" \
  "::1"```

---

### **模块二：基础设施即代码 (Infrastructure as Code)**

此模块定义了环境的“物理”结构和自动化工具。它是一次性配置，后续很少改动。

#### **2.1 核心软件包清单**

```bash
# 使用 CachyOS (Arch) 的包管理器安装所有依赖
sudo pacman -Syu nginx mkcert nss
```

#### **2.2 证书基础设施**

```bash
# 1. 创建证书的永久存放位置
sudo mkdir -p /etc/nginx/ssl/local

# 2. 将目录所有权赋予你的普通用户，以实现无sudo的证书管理
sudo chown $USER:$USER /etc/nginx/ssl/local

# 3. 安装 mkcert 的本地证书颁发机构 (CA) - 全局只需一次
mkcert -install
```

---

### **模块三：路由引擎 (The Routing Engine)**

这是架构的核心执行逻辑。我们采用单一配置文件，通过 `map` 指令和 `include` 实现声明式路由和场景切换。

#### **3.1 主路由配置文件 (`/etc/nginx/conf.d/00-local-dev-engine.conf`)**

用以下内容**完整创建**此文件。文件名中的 `00-` 确保它在Nginx加载时处于最优先的位置。

```bash
sudo nano /etc/nginx/conf.d/00-local-dev-engine.conf
```

**最终配置:**
```nginx
# /etc/nginx/conf.d/00-local-dev-engine.conf
# ======================================================================
# 本地开发路由引擎 V2.0
# 这是一个统一的、由 map 驱动的配置。它读取场景文件来决定行为。
# ======================================================================

# --- 路由映射表 (The Brain) ---
# 默认将所有请求代理到 Vite/Webpack 开发服务器。
map $host $proxy_target {
    default             http://127.0.0.1:5173; # 前端开发服务器
    api.ank.local       http://127.0.0.1:3000; # 本地API服务器
}

# --- 单一服务入口 (The Engine) ---
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;# 将 HTTP/2 作为一个独立的指令启用

    # 捕获所有在 /etc/hosts 中声明的域名。
    # 使用一个永远不会匹配的 server_name 来捕获所有未明确匹配的请求。
    server_name _;

    # --- 统一的SSL证书 ---
    # 所有本地开发站点共享同一张由 mkcert 生成的通配证书。
    ssl_certificate /etc/nginx/ssl/local/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/local/key.pem;

    # --- 动态日志文件 ---
    access_log /var/log/nginx/$host.access.log;
    error_log /var/log/nginx/$host.error.log;

    # --- [NEW] 场景注入点 (The Scenario Switch) ---
    # 根据当前激活的场景文件，动态加载特殊的路由规则。
    include /etc/nginx/scenarios/active.conf;

    # --- 核心路由逻辑 ---
    location / {
        proxy_pass $proxy_target;
        
        # 包含通用的 WebSocket 和代理头配置。
        include snippets/proxy-common.conf;
        include snippets/proxy-ws.conf;
    }
}
```

#### **3.2 场景配置文件 (The Scenarios)**

这是实现“零摩擦切换”的关键。我们为每种开发场景创建一个独立的配置文件，通过一个符号链接来激活它。

1.  **创建场景目录:**
    ```bash
    sudo mkdir -p /etc/nginx/scenarios
    ```

2.  **创建场景B的配置文件 (`/etc/nginx/scenarios/B-hybrid-online-api.conf`):**
    ```nginx
    # 场景B: 混合开发 - 使用线上API
    # 目的: 在 'work.online-domain.com' 域名下运行本地前端，
    #       使其可以无CORS问题地调用真实的线上API。
    # 行为: 无特殊路由规则，所有请求都由默认的 location / 处理。
    #       此文件为空是正常的，它的存在本身就是一种声明。
    ```

3.  **创建场景C的配置文件 (`/etc/nginx/scenarios/C-hybrid-local-api.conf`):**
    ```nginx
    # 场景C: 混合开发 - 使用本地API
    # 目的: 调试线上前端问题时，将API流量劫持到本地。
    
    # 规则1: 将 /api/ 路径的请求，代理到本地的 API 服务。
    location /api/ {
        proxy_pass http://127.0.0.1:3000/;
        include snippets/proxy-common.conf;
        include snippets/proxy-ws.conf;
    }
    
    # 规则2: 所有其他请求，都代理回真正的线上服务器。
    location / {
        proxy_pass https://work.online-domain.com;
        proxy_set_header Host "work.online-domain.com";
        include snippets/proxy-common.conf;
        include snippets/proxy-ws.conf;
    }
    ```

---

### **模块四：工作流协议 (The Workflow Protocol)**

这是你日常使用的、标准化的操作流程。

#### **4.1 初始化 (只需一次)**

1.  执行**模块二**中的所有命令，安装软件并设置目录。
2.  执行**模块 1.2** 的 `mkcert` 命令，生成你的通配证书。
3.  创建**模块 3.1** 和 **3.2** 中的所有 Nginx 配置文件。
4.  启动 Nginx: `sudo systemctl start nginx && sudo systemctl enable nginx`。

#### **4.2 日常工作流**

**场景A: 纯本地开发 (`ank.local`)**
1.  **DNS:** 确保 `ank.local` 在 `/etc/hosts` 中被声明。
2.  **场景切换:** 不需要激活任何特殊场景。
    ```bash
    # 如果存在旧的激活链接，先删除它
    sudo rm /etc/nginx/scenarios/active.conf
    # 创建一个空的激活文件，表示无特殊场景
    sudo touch /etc/nginx/scenarios/active.conf
    ```
3.  **重载Nginx:** `sudo systemctl reload nginx`。

**切换到场景B: 混合开发 (本地前端，线上API)**
1.  **DNS:** 确保 `work.online-domain.com` 在 `/etc/hosts` 中**未被注释**。
2.  **场景切换:** 激活场景B的配置。
    ```bash
    sudo ln -sf /etc/nginx/scenarios/B-hybrid-online-api.conf /etc/nginx/scenarios/active.conf
    ```
3.  **重载Nginx:** `sudo systemctl reload nginx`。

**切换到场景C: 混合开发 (线上前端，本地API)**
1.  **DNS:** 确保 `work.online-domain.com` 在 `/etc/hosts` 中**未被注释**。
2.  **场景切换:** 激活场景C的配置。
    ```bash
    sudo ln -sf /etc/nginx/scenarios/C-hybrid-local-api.conf /etc/nginx/scenarios/active.conf
    ```
3.  **重载Nginx:** `sudo systemctl reload nginx`。

---

### **最终裁决**

你现在拥有的，不再是一份简单的操作步骤列表。你拥有的是一个**系统**。

*   **事实源 (`hosts`, `mkcert`)** 定义了你的意图。
*   **路由引擎 (`00-local-dev-engine.conf`)** 是一个不变的、稳定的执行核心。
*   **场景文件 (`scenarios/`)** 是可插拔的、原子化的行为模块。
*   **工作流协议** 是你与这个系统交互的唯一、标准化的方式。

这份蓝图，将根除你本地开发环境中的混乱和不确定性。它现在是一个可预测、可维护、可传承的工程系统。