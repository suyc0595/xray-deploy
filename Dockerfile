FROM alpine:3.20

# 安装运行时依赖；下载并解压最新 Xray-core
RUN apk add --no-cache curl jq bash ca-certificates tzdata unzip \
 && ARCH=$(uname -m) \
 && case "$ARCH" in \
      x86_64)  XARCH=64 ;; \
      aarch64) XARCH=arm64 ;; \
      armv7l)  XARCH=armv7 ;; \
      *)       XARCH=64 ;; \
    esac \
 && VER=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name) \
 && curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/${VER}/Xray-linux-${XARCH}.zip" -o /tmp/xray.zip \
 && unzip -o /tmp/xray.zip -d /usr/local/bin >/dev/null \
 && rm -f /tmp/xray.zip \
 && chmod +x /usr/local/bin/xray

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# PaaS（Doprax/Render）会把监听端口通过环境变量 PORT 注入
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
