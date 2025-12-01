## 本地 Nginx 开发手册（Ank）

> 单一事实来源：所有配置以仓库 `nginx/local/**` 中的文件为准。本文只记录最精简、可复现的执行步骤。

### 1. 前置条件
- **系统/包**：CachyOS (Arch)。一次性装好依赖：
  ```bash
  sudo pacman -Syu nginx mkcert nss
  ```
- **DNS 劫持**：在 `/etc/hosts` 中映射所需域名到本机，至少包含：
  ```hosts
  127.0.0.1 ank.local
  127.0.0.1 api.ank.local
  # 需要混合调试时再解注释
  # 127.0.0.1 work.online-domain.com
  ```
- **本地 CA**：执行 `mkcert -install`，让系统信任自签根证书。

### 2. 同步仓库配置 → /etc/nginx
```bash
sudo install -Dm644 nginx/local/nginx.conf /etc/nginx/nginx.conf
sudo install -Dm644 -t /etc/nginx/conf.d nginx/local/conf.d/*.conf
sudo install -Dm644 -t /etc/nginx/modules.d nginx/local/modules.d/*.conf
sudo install -Dm644 -t /etc/nginx/snippets nginx/local/snippets/*.conf
sudo rsync -a nginx/local/njs/ /etc/nginx/njs/ 2>/dev/null || true
sudo rsync -a nginx/local/ssl/ /etc/nginx/ssl/
```
- `local-dev.conf` 是主要站点规则；`gateway.conf` / `proxy.conf` 为调试工具（见第 5 节）。
- 若只想启用部分配置，可将 `.conf` 改名为 `.conf.disabled`（Nginx 仅加载 `.conf`）。不过 `local-dev.conf` 的混合场景通过注释块启用/禁用，详见后文。

### 3. 证书与信任
`nginx/local/ssl/local/` 已包含一对 mkcert 证书。若需要重新生成：
```bash
cd /etc/nginx/ssl/local
mkcert -key-file key.pem -cert-file cert.pem \
  "ank.local" "*.ank.local" \
  "work.online-domain.com" \
  "localhost" 127.0.0.1 ::1
```
浏览器需信任 mkcert 根证书（`mkcert -install` 已处理）。若新增域名，请重新生成并同步仓库。

### 4. `local-dev.conf` 场景说明
- **变量声明**（顶部 `map`）：包含端口、域名三组：
  - `$project_ank_frontend_port` / `$project_ank_backend_port`：默认 5173 / 3000。
  - `$project_ank_frontend_domain` / `$project_ank_backend_domain`：默认 `ank.local` / `api.ank.local`，一处修改即可同步 server_name、Host 规则。
  - `$project_ank_online_domain`：默认 `work.online-domain.com`。
- **场景 A（本地前后端）**：
  - `ank.local` → `http://127.0.0.1:$project_ank_frontend_port`
  - `api.ank.local` → `http://127.0.0.1:$project_ank_backend_port`
  两个 server block 都启用 TLS（使用本地证书）并包含 HMR 所需的 websocket 代理。
- **场景 B（线上域名 → 本地前端）**：
  - `local-dev.conf` 中保留完整 server 块，但默认以 `#` 注释。需要此模式时，去掉注释并重载 Nginx，同时确认场景 C 仍保持注释，避免重复监听。
- **场景 C（线上域名 + 本地 API）**：
  - 启用方法相同：取消注释后 `/api/` 会代理到本地后端，其余路径回线上域名并强制 `Host` 头。
  - 场景 B、C 只能二选一，切换时务必恢复另一段的注释。

### 5. 调试工具
- **`gateway.conf`（端口 8080）**：简化版跨域代理，白名单 `127.0.0.1` 与 `192.168.31.0/24`。路径格式 `/proxy/{http|https}/{host}/{path}`，会附带统一的 CORS 头，用于快速测试第三方 API。
- **`proxy.conf`（端口 8080）**：全功能反向代理，除了动态 `proxy_pass` 外，还会伪造 `Referer/Origin`、重写 `Location` / `Set-Cookie` / HTML 资源路径，适合需要完整镜像外部站点时使用。性能开销较大，只在必要时启用。
- 两个文件默认都是 `.conf`，即始终可用；如需禁用请自定义白名单或重命名。

### 6. 启动与日常操作
```bash
sudo systemctl enable --now nginx
sudo nginx -t && sudo systemctl reload nginx   # 每次修改后执行
```
- 访问 `https://ank.local` / `https://api.ank.local` 验证证书是否被信任；混合场景下使用 `https://work.online-domain.com`。
- `journalctl -u nginx -f` 实时查看日志；具体站点请求可以在 `/var/log/nginx/access.log` 中看到（`log_format main_ext` 已写入 `$host` 字段）。
- 若端口 443 已被占用，记得停止系统自带 Nginx 或其他代理后再启动。

### 7. 维护要点
- 所有更改（端口、域名、证书）一律提交到仓库，确保团队同步。
- 本地 `.env` 中的端口需与 `map` default 保持一致，否则代理会指向错误服务。
- 任何一次性脚本/调试配置都放入 `gateway.conf` 或 `proxy.conf`，使用白名单控制访问，不要直接在主 server block 内做实验。
