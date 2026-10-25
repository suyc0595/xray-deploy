#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"
MODE="${MODE:-vless-reality}"
UUID="${UUID:-$(xray uuid)}"
SHORT_ID="${SHORT_ID:-$(cat /dev/urandom | tr -dc '0-9a-f' | head -c 8)}"
REALITY_SNI="${REALITY_SNI:-www.apple.com}"
REALITY_DEST="${REALITY_DEST:-www.apple.com:443}"
WS_PATH="${WS_PATH:-/ray}"
DOMAIN="${DOMAIN:-}"
CERT_DIR="${CERT_DIR:-/certs}"

mkdir -p /etc/xray

gen_keypair() {
  local out
  out="$(xray x25519 2>/dev/null)"
  PRIV="$(printf '%s' "$out" | sed -n 's/.*Private key: //p')"
  PUB="$(printf '%s' "$out"  | sed -n 's/.*Public key: //p')"
}

case "$MODE" in
  vless-reality)
    gen_keypair
    jq -n --argjson port "$PORT" --arg uuid "$UUID" --arg priv "$PRIV" \
      --arg sni "$REALITY_SNI" --arg dest "$REALITY_DEST" --arg sid "$SHORT_ID" '
      {
        "log":{"loglevel":"warning"},
        "inbounds":[{
          "listen":"0.0.0.0","port":$port,"protocol":"vless",
          "settings":{"clients":[{"id":$uuid,"flow":"xtls-rprx-vision"}],"decryption":"none"},
          "streamSettings":{
            "network":"tcp","security":"reality",
            "realitySettings":{"dest":$dest,"serverNames":[$sni],"privateKey":$priv,"shortIds":[$sid]}
          }
        }],
        "outbounds":[{"protocol":"freedom","tag":"direct"}]
      }' > /etc/xray/config.json
    echo "==================== Xray VLESS + Reality ===================="
    echo " 地址(IP/域名):  <部署平台分配>"
    echo " 端口:           $PORT"
    echo " 用户 UUID:      $UUID"
    echo " 流控 flow:      xtls-rprx-vision"
    echo " SNI:            $REALITY_SNI"
    echo " 公钥 publicKey: $PUB"
    echo " shortId:        $SHORT_ID"
    echo "=============================================================="
    ;;

  vless-ws-tls|vmess-ws-tls)
    PROTO="$MODE"; PROTO="${PROTO%-ws-tls}"
    CERT="$CERT_DIR/cert.pem"; KEY="$CERT_DIR/key.pem"
    if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
      echo "ERROR: MODE=$MODE 需要 TLS 证书，请把 cert.pem / key.pem 挂到 $CERT_DIR"
      exit 1
    fi
    jq -n --argjson port "$PORT" --arg uuid "$UUID" --arg proto "$PROTO" \
      --arg cert "$CERT" --arg key "$KEY" --arg wspath "$WS_PATH" '
      {
        "log":{"loglevel":"warning"},
        "inbounds":[{
          "listen":"0.0.0.0","port":$port,"protocol":$proto,
          "settings":{"clients":[{"id":$uuid}],"decryption":"none"},
          "streamSettings":{
            "network":"ws","security":"tls",
            "tlsSettings":{"certificates":[{"certificateFile":$cert,"keyFile":$key}]},
            "wsSettings":{"path":$wspath}
          }
        }],
        "outbounds":[{"protocol":"freedom","tag":"direct"}]
      }' > /etc/xray/config.json
    echo "==================== Xray $PROTO + WS + TLS ===================="
    echo " 地址:  $DOMAIN"
    echo " 端口:  $PORT"
    echo " UUID:  $UUID"
    echo " WS路径: $WS_PATH"
    echo "==============================================================="
    ;;

  *)
    echo "ERROR: 未知 MODE=$MODE（支持 vless-reality / vless-ws-tls / vmess-ws-tls）"
    exit 1
    ;;
esac

exec xray run -c /etc/xray/config.json
