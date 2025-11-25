// --- 请求头过滤器 ---
// 这个函数会在 Nginx 准备将请求头转发给上游时执行
function header_filter(r) {
    // 场景1: 强制添加 API 版本头
    if (!r.headersIn['X-API-Version']) {
        r.headersOut['X-API-Version'] = '2';
        r.log("Added missing X-API-Version header.");
    }

    // 场景3: 从验证过的 JWT (假设已存入变量) 转换认证头
    // 注意: 这通常与 js_access 阶段配合使用
    if (r.variables.jwt_user_id) {
        r.headersOut['X-User-ID'] = r.variables.jwt_user_id;
        // 我们可以删除原始的 Authorization 头，不让它传到后端
        delete r.headersOut['Authorization'];
    }
}

// --- 请求体过滤器 (更高级) ---
// 这个函数可以流式地修改 POST/PUT 请求的 body
function body_filter(r, data, flags) {
    // 场景: 将请求体中的 "legacy_field" 重命名为 "new_field"
    try {
        var body = JSON.parse(data);
        if (body.legacy_field) {
            body.new_field = body.legacy_field;
            delete body.legacy_field;
            // 将修改后的 JSON 字符串发回
            r.sendBuffer(JSON.stringify(body), flags);
        } else {
            // 如果没有需要修改的字段，直接发送原始数据
            r.sendBuffer(data, flags);
        }
    } catch (e) {
        // 如果 JSON 解析失败，发送原始数据
        r.sendBuffer(data, flags);
    }
}

export default { header_filter, body_filter };


// http {
//     js_import /etc/nginx/njs/request_rewriter.js;
//     # ...
// }

// server {
//     # ...
//     location /api/v2/ {
//         # 使用 js_header_filter 来修改请求头
//         js_header_filter request_rewriter.header_filter;
        
//         # 如果需要修改请求体，使用 js_body_filter
//         # js_body_filter request_rewriter.body_filter;

//         proxy_pass http://my_backend_service;
//     }
// }