# xray-deploy

现代的代理节点一键部署工具（Xray-core），是老式 `v2ray-on-Doprax` 脚本的升级替代品。
**一套配置兼容两种部署方式**：免费 PaaS 一键部署（自动换 IP）与 自有 VPS/Docker（域名 + TLS）。

- 底层：[Xray-core](https://github.com/XTLS/Xray-core)（v2ray 的现代继承者，性能更好、支持 Reality）
- 自动生成 UUID，无需手动计算
- 三种模式：`vless-reality`（免证书）／`vless-ws-tls`／`vmess-ws-tls`

---

## 模式一：Doprax / Render 免费 PaaS（推荐新手，免域名免证书）

原理：在免费容器平台跑一个 TCP 服务，Xray 监听平台分配的端口。
**每次重新部署容器 = 分配新出口 IP**，天然实现「自动换 IP」抗封锁。

1. Fork 本仓库（或克隆到本地后推到自己的仓库）
2. 在 Doprax / Render 新建 Web Service，关联本仓库
3. 构建/运行设置**保持默认即可**——所有环境变量都有合理默认值，**无需任何配置**
4. 直接 Deploy

部署后看运行日志，会直接打印一段 **`vless://...` 导入链接**，把里面的 `<地址>` 换成 Doprax 分配的域名/IP，复制到 v2rayN / NekoBox / Shadowrocket 即可联网。

> 想要新 IP：在平台点「Redeploy」即可。

---

## 模式二：自有 VPS / 服务器 + Docker（稳定长效，需域名）

适合已有 ECS、域名（如你的 `sscuu.cn` / `suyc.top`）的场景，走 WebSocket + TLS，流量像普通 HTTPS。

1.  clone 本仓库到服务器，复制配置：
   ```bash
   git clone <本仓库> && cd xray-deploy
   cp .env.example .env
   ```
2. 准备证书：把 `cert.pem` / `key.pem` 放到 `./certs/` 目录
   （可用 `acme.sh` / `certbot` 签发你的域名证书）
3. 编辑 `.env`：`MODE=vless-ws-tls`、`DOMAIN=你的域名`、`PORT=443`、`UUID` 留空或固定
4. 启动：`docker compose up -d`
5. 看日志取连接参数：`docker compose logs`

---

## 客户端配置示例

### VLESS + Reality（模式一）

把服务端日志里的 **公钥 / shortId / 端口** 填进去：

```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "<平台分配的IP或域名>",
        "port": 8080,
        "users": [{ "id": "<UUID>", "flow": "xtls-rprx-vision", "encryption": "none" }]
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "serverName": "www.apple.com",
        "publicKey": "<服务端打印的 publicKey>",
        "shortId": "<服务端打印的 shortId>",
        "spiderX": "/"
      }
    }
  }]
}
```

### VLESS + WS + TLS（模式二）

```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "<你的域名>",
        "port": 443,
        "users": [{ "id": "<UUID>", "encryption": "none" }]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": { "serverName": "<你的域名>" },
      "wsSettings": { "path": "/ray" }
    }
  }]
}
```

VMess 版只需把上面 `protocol` 改成 `vmess`、`flow` 去掉、`address/port` 不变即可。

---

## 环境变量速查

| 变量 | 说明 | 默认 |
|---|---|---|
| `MODE` | `vless-reality` / `vless-ws-tls` / `vmess-ws-tls` | `vless-reality` |
| `PORT` | 监听端口 | `8080` |
| `UUID` | 留空自动生成 | 空 |
| `REALITY_SNI` | Reality 伪装站点 | `www.apple.com` |
| `REALITY_DEST` | 伪装站点地址:端口 | `www.apple.com:443` |
| `SHORT_ID` | Reality shortId（留空自动生成） | 空 |
| `DOMAIN` | ws-tls 模式绑定的域名 | 空 |
| `WS_PATH` | WebSocket 路径 | `/ray` |
| `CERT_DIR` | TLS 证书目录（需含 cert.pem/key.pem） | `/certs` |

---

## 与原 `ssss` 的区别

| | 原 ssss (2023) | xray-deploy |
|---|---|---|
| 内核 | v2ray（已停更） | Xray-core（活跃维护） |
| 协议 | VMess / VLess | VLESS + **Reality**（免证书、更难探测） |
| 部署 | 仅 Doprax | Doprax / Render / 任意 Docker 主机 |
| IP 轮换 | 自动换 IP | 重新部署即换 IP（文档说明） |
| 配置 | 改源码 | 纯环境变量驱动 |
