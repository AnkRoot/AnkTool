// =============================================================================
// 生产级 JWT 验证函数 for NJS (高兼容性版)
//
// 变更:
// - 移除了所有 ES6+ 语法 (如 const, let, 数组解构)。
// - 使用 NJS 同步的 crypto API，取代 async/await 和 crypto.subtle。
// - 手动处理 base64url 到 base64 的转换，以兼容旧版 NJS。
// =============================================================================

// --- 配置 ---
var JWT_SECRET = 'your-super-secret-and-long-key-that-no-one-knows';

function verify_jwt(r) {
    try {
        // 1. 提取 Token
        var token = extractToken(r);
        if (!token) {
            r.return(401, "Authorization header missing or invalid format");
            return;
        }

        // 2. 分割并解码 Token
        var parts = token.split('.');
        if (parts.length !== 3) {
            r.return(401, "Invalid JWT structure");
            return;
        }
        
        // 使用经典数组索引赋值，取代 ES6 解构
        var headerB64 = parts[0];
        var payloadB64 = parts[1];
        var signatureB64 = parts[2];

        var header = JSON.parse(fromBase64Url(headerB64));
        var payload = JSON.parse(fromBase64Url(payloadB64));

        // 3. 验证签名
        if (header.alg !== 'HS256') {
            r.return(401, "Unsupported JWT algorithm. Only HS256 is supported.");
            return;
        }
        var dataToSign = headerB64 + '.' + payloadB64;
        var expectedSignature = hmacSha256(dataToSign, JWT_SECRET);

        if (expectedSignature !== signatureB64) {
            r.return(403, "Forbidden: Invalid JWT signature");
            return;
        }

        // 4. 验证 Claims (过期时间等)
        var nowInSeconds = Math.floor(Date.now() / 1000);
        if (payload.exp && payload.exp < nowInSeconds) {
            r.return(401, "Unauthorized: Token has expired");
            return;
        }
        if (payload.nbf && payload.nbf > nowInSeconds) {
            r.return(401, "Unauthorized: Token not yet valid");
            return;
        }

        // 5. (可选) 将用户信息注入到下游请求头
        if (payload.sub) {
            r.headersOut['X-User-ID'] = payload.sub;
        }
        if (payload.email) {
            r.headersOut['X-User-Email'] = payload.email;
        }

        r.log("JWT validation successful for user: " + (payload.sub || 'unknown'));
        
        // 验证通过，允许请求继续
        r.internalRedirect('@app');

    } catch (e) {
        r.error("JWT validation error: " + e);
        r.return(500, "Internal Server Error during token validation");
    }
}

function extractToken(r) {
    var authHeader = r.headersIn['Authorization'];
    if (!authHeader) return null;
    var parts = authHeader.split(' ');
    if (parts.length === 2 && parts[0] === 'Bearer') {
        return parts[1];
    }
    return null;
}

// --- 加密与编码辅助函数 (高兼容性) ---

function hmacSha256(data, secret) {
    var hmac = require('crypto').createHmac('sha256', secret);
    hmac.update(data);
    return hmac.digest('base64url');
}

function fromBase64Url(base64url) {
    // 将 base64url 转换为标准的 base64
    base64url = base64url.replace(/-/g, '+').replace(/_/g, '/');
    // 根据 RFC 4648，补全等号
    var pad = base64url.length % 4;
    if (pad) {
        if (pad === 1) {
            throw new Error('InvalidLengthError: Input base64url string is the wrong length to determine padding');
        }
        base64url += new Array(5 - pad).join('=');
    }
    return Buffer.from(base64url, 'base64').toString();
}

export default { verify_jwt };