#!/bin/bash

# =============================================================================
# 脚本名称: update-firewall-for-cloudflare.sh
# 脚本描述: 自动更新 UFW 防火墙规则，确保只允许最新的 Cloudflare IP 范围
#           访问 Web 端口 (80, 443)。
# 核心哲学: 安全策略必须是动态的、自适应的，而不是静态的、僵化的。
# =============================================================================

# --- 严格模式 ---
set -e
set -u
set -o pipefail

# --- 配置 ---
LOG_FILE="/var/log/cloudflare-firewall-update.log"
CF_IPV4_URL="https://www.cloudflare.com/ips-v4"
CF_IPV6_URL="https://www.cloudflare.com/ips-v6"
TEMP_IP_LIST=$(mktemp)
trap 'rm -f "$TEMP_IP_LIST"' EXIT

# --- 日志函数 ---
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

# --- 主逻辑 ---
log_message "--- 启动 Cloudflare 防火墙规则更新任务 ---"

# 步骤 1: 获取最新的 Cloudflare IP 列表
log_message "正在从 Cloudflare 获取最新的 IP 列表..."
{
    curl -sS -L "$CF_IPV4_URL"
    curl -sS -L "$CF_IPV6_URL"
} > "$TEMP_IP_LIST"

if [ ! -s "$TEMP_IP_LIST" ]; then
    log_message "错误: 无法获取 Cloudflare IP 列表，文件为空。任务中止。"
    exit 1
fi
log_message "成功获取 $(wc -l < "$TEMP_IP_LIST") 个 IP 段。"

# 步骤 2: 检查并添加新规则
# 我们逐行读取新的 IP 列表，并检查每一条规则是否已经存在于 UFW 中。
# 只有当规则不存在时，我们才添加它。
NEW_RULES_ADDED=0
while read -r ip; do
    # 使用 ufw status | grep -q 来检查规则是否存在。-q 表示静默模式。
    # 我们检查 "ALLOW IN From $ip" 这个模式，这比精确匹配更可靠。
    if ! sudo ufw status | grep -q "ALLOW IN.*$ip"; then
        log_message "发现新的 IP 段: $ip。正在添加规则..."
        sudo ufw allow from "$ip" to any port 80,443 proto tcp comment 'Cloudflare IP (auto-updated)'
        NEW_RULES_ADDED=$((NEW_RULES_ADDED + 1))
    fi
done < "$TEMP_IP_LIST"

# 步骤 3: 报告结果
if [ "$NEW_RULES_ADDED" -gt 0 ]; then
    log_message "任务完成。成功添加了 $NEW_RULES_ADDED 条新的防火墙规则。"
    log_message "正在重载防火墙以应用新规则..."
    sudo ufw reload
    log_message "防火墙已重载。"
else
    log_message "检查完成。所有 Cloudflare IP 规则都已是最新，无需操作。"
fi

log_message "--- Cloudflare 防火墙规则更新任务结束 ---"
echo "" | sudo tee -a "$LOG_FILE" # 在日志中添加一个空行，方便阅读

exit 0



# **注意:** 这个脚本只负责**添加**新的规则。它不会自动删除那些 Cloudflare 可能已经弃用的旧 IP 段。这是一个安全上的权衡：错误地删除一条仍在使用的规则，其后果远比保留一条已不用的规则要严重。对于绝大多数情况，只增不删是更稳健的策略。

# 1. 清理UFW规则（保留OpenSSH:`sudo ufw allow OpenSSH`）
# sudo ufw status numbered  # 先查看确认
# for i in $(seq 20 -1 2); do sudo ufw delete $i; done  # 从高到低删除其他规则(20-2)

# 2. 设置Cloudflare脚本自动更新
# sudo chmod +x /usr/local/sbin/update-firewall-for-cloudflare.sh
# sudo crontab -e
# 每月1号凌晨 5:00 自动更新 UFW 防火墙的 Cloudflare IP 规则
# 0 5 1 * * /usr/local/sbin/update-firewall-for-cloudflare.sh
