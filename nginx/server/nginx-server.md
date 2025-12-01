## 零信任部署手册（010314.xyz）

> 单一事实来源：所有配置以仓库内 `nginx/server/**` 实际文件为准。本文仅提供最精简的执行指南。

### 0. 前置基础
- 操作系统：Arch/Debian 系列均可，示例命令假设 Debian。
- 账号：使用个人 `ank` 用户，禁止长期以 root 运维。
- 依赖：
  ```bash
  sudo apt update && sudo apt upgrade -y
  sudo apt install nginx ufw rsync -y
  sudo ufw allow OpenSSH
  sudo ufw allow 'Nginx Full'
  sudo ufw enable
  ```

### 1. Cloudflare 准备
1. DNS：`@` 与 `*` 指向服务器 IP，均保持橙色云朵（代理模式）。
2. SSL/TLS：模式设为 **Full (Strict)**。
3. Origin Cert：在「SSL/TLS → Origin Server」生成证书与私钥，保存为：
   ```
   /etc/ssl/certs/cloudflare_origin.pem
   /etc/ssl/private/cloudflare_origin.key   (chmod 600)
   ```
4. Authenticated Origin Pulls：保持开启，并下载官方 CA 到 `/etc/nginx/ssl/cloudflare_aop_ca.pem`。

### 2. 同步配置（仓库 → 服务器）
```bash
sudo install -Dm644 nginx/server/nginx.conf /etc/nginx/nginx.conf
sudo mkdir -p /etc/nginx/snippets
sudo install -Dm644 nginx/server/snippets/*.conf /etc/nginx/snippets/
sudo install -Dm644 nginx/server/conf.d/010314.xyz.conf /etc/nginx/conf.d/010314.xyz.conf
sudo rsync -a nginx/server/sites-overrides/ /etc/nginx/sites-overrides/
```
- `010314.xyz.conf` 仅 `include` 明确授权的 override（默认仅 `work.010314.xyz.conf`）。新增 override 时：先在 `/etc/nginx/sites-overrides/` 创建文件，再到 `010314.xyz.conf` 显式添加 `include` 行，禁止使用 `*.conf` 通配。
- Cloudflare 边缘网段列表已经写入 `010314.xyz.conf`。若 Cloudflare 公布新网段，请同步更新 `set_real_ip_from`。

### 3. 站点文件与目录
```bash
sudo mkdir -p /var/www/010314.xyz/{main,blog,work}
sudo mkdir -p /var/www/html
sudo chown -R ank:ank /var/www/010314.xyz
```
- 静态站点：将构建产物放入 `对应子目录`。`map $host $site_root` 会自动匹配 `subdomain -> /var/www/010314.xyz/subdomain`，根域名落在 `main`。
- PHP 站点：在 `map $host $is_php_site` 中把目标域名设为 `1`，并部署 PHP 文件；其余保持 `0`。

### 4. 反代与 override 工作流
- **反代 API**：在 `map $host $backend_target` 添加 `api.010314.xyz 127.0.0.1:8080;`，Nginx 会在命中该域名时走统一入口并 `proxy_pass`。
- **特殊 location（如 Terminal）**：位于 `/etc/nginx/sites-overrides/work.010314.xyz.conf`。守卫逻辑通过 `map $host $work_override_guard` 集中定义，`location` 内只需判断 `$work_override_guard`：
  ```nginx
  if ($work_override_guard = 0) { return 444; }
  ```
- 禁止在 override 中写 `listen` 或 `server`，只允许追加 `location` 规则。

### 5. 启动与巡检
```bash
sudo nginx -t && sudo systemctl reload nginx
sudo systemctl enable --now nginx
```
- 直连服务器 IP 时必须触发 mTLS 错误；经 Cloudflare 访问应正常。
- 日志集中在 `/var/log/nginx/010314.xyz.access.log`，格式包含 `$host` 便于区分站点。
- 本地调试：若需更新配置，先 `sudo nginx -t` 再 `sudo systemctl reload nginx`。

### 6. 维护 Checklist
- 证书：Cloudflare Origin Cert 自动续期，仍需关注磁盘权限与空间，防止写入失败。
- IP 白名单：定期检查 `https://www.cloudflare.com/ips/` 并更新配置。
- override 扩展：新增文件时需在 `map $host ...` 中添加守卫变量（参考 `$work_override_guard`），在 `location` 内统一判断该变量，并在主配置显式 include。
- 变更流程：任何配置改动都先在版本库提交，再同步至服务器，禁止直接在线编辑 `/etc/nginx`。
