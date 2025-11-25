// --- 响应头过滤器 ---
function header_filter(r) {
    // 场景: 为所有 JSON 响应添加一个自定义头
    if (r.headersOut['Content-Type'] && r.headersOut['Content-Type'].includes('application/json')) {
        r.headersOut['X-Content-Source'] = 'Nginx-Gateway';
    }
    // 删除后端可能暴露的服务器信息头
    delete r.headersOut['X-Powered-By'];
    delete r.headersOut['Server'];
}

// --- 响应体过滤器 ---
function body_filter(r, data, flags) {
    // 场景: 过滤掉用户对象中的敏感字段
    // 我们只对 200 OK 的 JSON 响应进行操作
    if (r.status === 200 && r.headersOut['Content-Type'] && r.headersOut['Content-Type'].includes('application/json')) {
        try {
            var body = JSON.parse(data);
            // 假设 body 是一个用户对象或用户对象数组
            if (Array.isArray(body)) {
                body.forEach(user => {
                    delete user.internal_user_role;
                    delete user.last_login_ip;
                });
            } else if (typeof body === 'object' && body !== null) {
                delete body.internal_user_role;
                delete body.last_login_ip;
            }
            r.sendBuffer(JSON.stringify(body), flags);
            return; // 必须 return，防止执行下面的默认发送
        } catch (e) {
            // JSON 解析失败，可能不是我们期望的格式，直接发送原始数据
        }
    }
    // 对于其他所有情况，发送原始数据
    r.sendBuffer(data, flags);
}

export default { header_filter, body_filter };


// http {
//     js_import /etc/nginx/njs/response_rewriter.js;
//     # ...
// }

// server {
//     # ...
//     location /api/users/ {
//         # 响应头和响应体过滤器可以同时使用
//         js_header_filter response_rewriter.header_filter;
//         js_body_filter response_rewriter.body_filter;

//         proxy_pass http://user_service;
//     }
// }