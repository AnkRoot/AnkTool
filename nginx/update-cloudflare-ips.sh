#!/bin/bash

# =============================================================================
# 脚本名称: update-cloudflare-ips.sh
# 脚本描述: 自动更新 Nginx 配置文件，使其包含最新的 Cloudflare IP 地址范围，
#           用于正确获取访客真实 IP。
# 核心哲学: 自动化，但保持偏执。信任，但要去验证。
# =============================================================================

# --- 严格模式 ---
# set -e: 任何命令执行失败，脚本将立即退出。
set -e
# set -u: 任何未定义的变量被使用时，脚本将立即退出。
set -u
# set -o pipefail: 管道命令中任何一个失败，整个管道都视为失败。
set -o pipefail

# --- 配置变量 ---
# Nginx 配置文件的最终存放位置
NGINX_CONFIG_FILE="/etc/nginx/snippets/cloudflare.conf"

# Cloudflare 官方 IP 列表的 URL
IP_V4_URL="https://www.cloudflare.com/ips-v4"
IP_V6_URL="https://www.cloudflare.com/ips-v6"

# 创建一个安全的临时文件。脚本退出时（无论成功或失败），此文件都会被自动删除。
TEMP_CONFIG_FILE=$(mktemp)
trap 'rm -f "$TEMP_CONFIG_FILE"' EXIT

# --- 日志函数 ---
# 统一日志输出格式，方便追踪。
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# --- 主逻辑 ---
log_message "正在启动 Cloudflare IP 更新流程..."

# 步骤 1: 在临时文件中生成新的配置文件内容
# =================================================
# 我们先在一个安全隔离的临时文件中完成所有工作，避免污染现有配置。

# 为临时文件添加带中文注释的头部，警告不要手动编辑。
{
    echo "# =====================================================================";
    echo "# 此文件由 update-cloudflare-ips.sh 脚本自动生成";
    echo "# 请勿手动编辑，所有修改将在下次运行时被覆盖。";
    echo "# 最后更新于: $(date)";
    echo "# =====================================================================";
    echo "";
    echo "# --- 从Cloudflare获取真实访客IP ---";
    echo "# Cloudflare IP段列表，用于set_real_ip_from指令。";
    echo "# 来源: https://www.cloudflare.com/ips/ (应定期检查更新)";
    echo "";
    echo "# IPv4 地址段";
} >> "$TEMP_CONFIG_FILE"

# 使用 curl 获取 IPv4 地址列表，并通过管道逐行处理，格式化后追加到临时文件。
# -sS: 静默模式，但显示错误。 -L: 跟随重定向。
if ! curl -sS -L "$IP_V4_URL" | while read -r ip; do echo "set_real_ip_from $ip;" >> "$TEMP_CONFIG_FILE"; done; then
    log_message "错误: 从 Cloudflare 获取或处理 IPv4 列表失败。"
    exit 1
fi

{
    echo "";
    echo "# IPv6 地址段";
} >> "$TEMP_CONFIG_FILE"

# 获取并格式化 IPv6 地址列表。
if ! curl -sS -L "$IP_V6_URL" | while read -r ip; do echo "set_real_ip_from $ip;" >> "$TEMP_CONFIG_FILE"; done; then
    log_message "错误: 从 Cloudflare 获取或处理 IPv6 列表失败。"
    exit 1
fi

{
    echo "";
    echo "# 告知Nginx从哪个HTTP头获取真实IP。Cloudflare使用CF-Connecting-IP。";
    echo "real_ip_header CF-Connecting-IP;";
} >> "$TEMP_CONFIG_FILE"

log_message "已成功在临时文件中生成新的 Cloudflare IP 配置。"

# 步骤 2: 比较、验证和部署
# =================================================
# 只有在确认安全且必要时，才对线上服务进行操作。

# 使用 cmp 命令逐字节比较新旧文件。如果文件内容相同，则无需任何操作。
# -s: 静默模式，只通过退出码表示结果。
if cmp -s "$TEMP_CONFIG_FILE" "$NGINX_CONFIG_FILE" 2>/dev/null; then
    log_message "Cloudflare IP 列表无变化，无需更新。"
    exit 0
fi

log_message "检测到 Cloudflare IP 列表已更新，正在准备部署..."

# 在替换之前，先用新文件对整个 Nginx 配置进行一次语法测试。
# 这是最关键的安全步骤，确保新文件不会导致整个 Nginx 服务崩溃。
# 我们通过先备份旧文件，再用新文件覆盖的方式进行测试。
log_message "正在进行 Nginx 配置语法预检查..."
cp "$NGINX_CONFIG_FILE" "$NGINX_CONFIG_FILE.bak"
cp "$TEMP_CONFIG_FILE" "$NGINX_CONFIG_FILE"

if ! nginx -t; then
    log_message "错误: 使用新的 IP 列表进行 Nginx 配置测试失败！"
    # 如果测试失败，立刻恢复备份，保持服务稳定。
    mv "$NGINX_CONFIG_FILE.bak" "$NGINX_CONFIG_FILE"
    log_message "已恢复旧的配置文件。请检查 Nginx 错误日志以排查问题。"
    exit 1
fi

# 如果测试通过，说明新配置是安全的，可以删除备份文件。
rm "$NGINX_CONFIG_FILE.bak"

log_message "Nginx 配置语法测试成功。"

# 步骤 3: 平滑重载 Nginx
# =================================================
# 使用 'reload' 命令，Nginx 会在不中断现有连接的情况下应用新配置。

log_message "正在平滑重载 Nginx 服务以应用新配置..."
if systemctl reload nginx; then
    log_message "Nginx 服务已成功重载，新的 Cloudflare IP 已生效。"
else
    log_message "错误: Nginx 服务重载失败。"
    exit 1
fi

log_message "脚本执行成功。"
exit 0




# **用途:** 自动从 Cloudflare 获取最新的 IP 地址范围，生成 Nginx 配置文件，并在验证无误后平滑地重载 Nginx 服务。
#     ```bash
#     sudo chmod +x /usr/local/sbin/update-cloudflare-ips.sh
#     sudo /usr/local/sbin/update-cloudflare-ips.sh
#     sudo crontab -e
#     # 每周一凌晨 4:30 自动更新 Nginx 的 Cloudflare IP 列表
#     30 4 * * 1 /usr/local/sbin/update-cloudflare-ips.sh >> /var/log/cloudflare-ip-update.log 2>&1
#     ```