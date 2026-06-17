#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/roshan/Developer/gsstack-container"
GHCLOUD="/home/roshan/Developer/ghcloud"
FRONTEND="/home/roshan/Developer/ghbf-gstack"
ENV_FILE="$ROOT/.env.local"
NGINX_CONF="$ROOT/tmp/nginx/ghcloud-gateway.conf"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

MYSQL_CONTAINER="ghscheduler-mysql"
MYSQL_IMAGE="mysql:8.0"
NGINX_CONTAINER="ghcloud-local-nginx"
NGINX_IMAGE="nginx:1.27-alpine"
PORTPROXY_LISTEN_ADDRESS="${GSSTACK_PORTPROXY_LISTEN_ADDRESS:-0.0.0.0}"
PORTPROXY_PORTS="${GSSTACK_PORTPROXY_PORTS:-8000 8080 8091 8100 3100 18080 9000 19090}"

GO_SESSION="gsstack-go-19090"
JAVA_SESSION="gsstack-java-9000"
FRONTEND_SESSION="gsstack-frontend-8000"

log() {
  printf '[gsstack-local-dev] %s\n' "$*"
}

die() {
  printf '[gsstack-local-dev] ERROR: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

load_env() {
  [ -f "$ENV_FILE" ] || die "missing env file: $ENV_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  : "${MYSQL_HOST:=127.0.0.1}"
  : "${MYSQL_PORT:=3306}"
  : "${MYSQL_USER:=root}"
  : "${MYSQL_DB:=ghks}"
  : "${MYSQL_ROOT_PWD:?MYSQL_ROOT_PWD must be set in $ENV_FILE}"
  : "${KUBECONFIG:=$ROOT/tmp/kubeconfig-192.168.11.114.local}"
}

wsl_ip() {
  hostname -I | awk '{print $1}'
}

port_listening() {
  ss -ltn "( sport = :$1 )" | awk 'NR > 1 {found=1} END {exit found ? 0 : 1}'
}

powershell_available() {
  command -v powershell.exe >/dev/null 2>&1
}

tmux_has() {
  tmux has-session -t "$1" >/dev/null 2>&1
}

ensure_tools() {
  need awk
  need curl
  need docker
  need hostname
  need ss
  need tmux
}

ensure_mysql() {
  load_env
  need docker

  local owner
  owner="$(docker ps --format '{{.Names}}\t{{.Ports}}' | awk '$0 ~ /0\\.0\\.0\\.0:3306->3306|\\[::\\]:3306->3306/ {print $1; exit}')"
  if [ -n "$owner" ] && [ "$owner" != "$MYSQL_CONTAINER" ]; then
    die "host port 3306 is owned by running container $owner; expected $MYSQL_CONTAINER"
  fi

  if docker container inspect "$MYSQL_CONTAINER" >/dev/null 2>&1; then
    local published running
    published="$(docker inspect "$MYSQL_CONTAINER" --format '{{json .NetworkSettings.Ports}}' | grep -c '"HostPort":"3306"' || true)"
    running="$(docker inspect "$MYSQL_CONTAINER" --format '{{.State.Running}}')"
    if [ "$published" -gt 0 ]; then
      if [ "$running" != "true" ]; then
        docker start "$MYSQL_CONTAINER" >/dev/null
      fi
      log "mysql: $MYSQL_CONTAINER publishes 3306"
      return
    fi

    local old volume
    old="${MYSQL_CONTAINER}-unpublished-$(date +%Y%m%d%H%M%S)"
    if [ "$running" = "true" ]; then
      docker stop "$MYSQL_CONTAINER" >/dev/null
    fi
    docker rename "$MYSQL_CONTAINER" "$old"
    volume="$(docker inspect "$old" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}')"
    [ -n "$volume" ] || die "could not find /var/lib/mysql volume on $old"
    docker run -d \
      --name "$MYSQL_CONTAINER" \
      -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PWD" \
      -e MYSQL_DATABASE=ghscheduler \
      -p 3306:3306 \
      -v "$volume:/var/lib/mysql" \
      "$MYSQL_IMAGE" >/dev/null
    log "mysql: republished $MYSQL_CONTAINER on 3306 using volume $volume"
    return
  fi

  die "missing $MYSQL_CONTAINER; restore the existing MySQL container/volume before starting the stack"
}

write_nginx_conf() {
  local ip
  ip="$(wsl_ip)"
  mkdir -p "$(dirname "$NGINX_CONF")"
  cat >"$NGINX_CONF" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

upstream ghcloud_java {
    server ${ip}:9000;
    keepalive 32;
}

upstream ghedge_go {
    server ${ip}:19090;
    keepalive 32;
}

upstream ghbf_frontend {
    server ${ip}:8000;
    keepalive 16;
}

server {
    listen 80;
    listen [::]:80;
    server_name _;

    client_max_body_size 200m;
    proxy_connect_timeout 30s;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;

    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header app-code \$http_app_code;
    proxy_set_header app_code \$http_app_code;

    location ^~ /kapis/kapis/ {
        rewrite ^/kapis/kapis/(.*)\$ /kapis/\$1 break;
        proxy_pass http://ghedge_go;
    }

    location ^~ /kapis/ {
        proxy_pass http://ghedge_go;
    }

    location ^~ /api/websocket {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_pass http://ghcloud_java;
    }

    location ^~ /api {
        proxy_pass http://ghcloud_java;
    }

    location ^~ /uuc {
        proxy_pass http://ghcloud_java/api/uuc;
    }

    location ^~ /oauth {
        proxy_pass http://ghcloud_java/api/oauth;
    }

    location ^~ /apis {
        proxy_pass http://ghcloud_java/api/apis;
    }

    location ^~ /mq {
        proxy_pass http://ghcloud_java/api;
    }

    location / {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_pass http://ghbf_frontend;
    }
}
EOF
  log "nginx: upstream WSL IP is $ip"
}

ensure_nginx() {
  need docker
  write_nginx_conf
  if docker container inspect "$NGINX_CONTAINER" >/dev/null 2>&1; then
    if [ "$(docker inspect "$NGINX_CONTAINER" --format '{{.State.Running}}')" != "true" ]; then
      docker start "$NGINX_CONTAINER" >/dev/null
    fi
    docker exec "$NGINX_CONTAINER" nginx -s reload >/dev/null 2>&1 || docker restart "$NGINX_CONTAINER" >/dev/null
    log "nginx: $NGINX_CONTAINER publishes 18080"
    return
  fi

  docker run -d \
    --name "$NGINX_CONTAINER" \
    -p 18080:80 \
    -v "$NGINX_CONF:/etc/nginx/conf.d/default.conf:ro" \
    "$NGINX_IMAGE" >/dev/null
  log "nginx: created $NGINX_CONTAINER on 18080"
}

go_run() {
  cd "$ROOT"
  load_env
  local dsn
  dsn="${MYSQL_USER}:${MYSQL_ROOT_PWD}@tcp(${MYSQL_HOST}:${MYSQL_PORT})/${MYSQL_DB}?charset=utf8mb4&collation=utf8mb4_general_ci&parseTime=True&loc=Local&timeout=1s&readTimeout=3s&writeTimeout=3s"
  exec ./ghedge/bin/cmd/ks-apiserver \
    --insecure-port 19090 \
    --kubeconfig "$KUBECONFIG" \
    --ghedge-db-dsn "$dsn" \
    --ghedge-run-modes container,virtual \
    --ghedge-virtual-host "${GHEDGE_VIRTUAL_HOST:-}" \
    --ghedge-virtual-zstore "${GHEDGE_VIRTUAL_ZSTORE:-}" \
    --ghedge-virtual-watch "${GHEDGE_VIRTUAL_WATCH:-}" \
    --ghedge-acess-key "${GHEDGE_ACESS_KEY:-}" \
    --ghedge-acesskey-secret "${GHEDGE_ACESSKEY_SECRET:-}" \
    --ghedge-uuc-base-url http://127.0.0.1:18080
}

java_run() {
  cd "$GHCLOUD"
  load_env
  local jar jdbc
  jar="$GHCLOUD/platform/target/platform.jar"
  [ -f "$jar" ] || die "missing Java jar: $jar"
  jdbc="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}?characterEncoding=utf-8&useSSL=false&serverTimezone=Asia/Shanghai"
  exec java -Xms512m -Xmx2g -jar "$jar" \
    --server.port=9000 \
    --spring.datasource.primary.jdbc-url="$jdbc" \
    --spring.datasource.primary.username="$MYSQL_USER" \
    --spring.datasource.primary.password="$MYSQL_ROOT_PWD" \
    --spring.datasource.uucdata.jdbc-url="$jdbc" \
    --spring.datasource.uucdata.username="$MYSQL_USER" \
    --spring.datasource.uucdata.password="$MYSQL_ROOT_PWD" \
    --spring.datasource.url="$jdbc" \
    --spring.datasource.username="$MYSQL_USER" \
    --spring.datasource.password="$MYSQL_ROOT_PWD" \
    --spring.redis.host=192.168.11.141 \
    --spring.redis.port=6379 \
    --ghcloud.ghv1.ghv1ApiUrl=http://127.0.0.1:19090 \
    --scheduled.status=false \
    --logging.file.path="$GHCLOUD/ghcloud-logs"
}

frontend_run() {
  cd "$FRONTEND"
  [ -d node_modules ] || die "missing node_modules in $FRONTEND"
  export HOST=0.0.0.0
  export PORT=8000
  export BROWSER=none
  export GHCLOUD_GATEWAY_TARGET=http://127.0.0.1:18080/
  exec npm run dev
}

start_session() {
  local session="$1"
  local workdir="$2"
  local subcommand="$3"
  if tmux_has "$session"; then
    log "tmux: $session already exists"
    return
  fi
  tmux new-session -d -s "$session" -c "$workdir" "$SCRIPT_PATH $subcommand"
  log "tmux: started $session"
}

stop_session() {
  local session="$1"
  if tmux_has "$session"; then
    tmux kill-session -t "$session"
    log "tmux: stopped $session"
  fi
}

start_stack() {
  ensure_tools
  load_env
  ensure_mysql
  ensure_nginx
  start_session "$GO_SESSION" "$ROOT" go-run
  start_session "$JAVA_SESSION" "$GHCLOUD" java-run
  start_session "$FRONTEND_SESSION" "$FRONTEND" frontend-run
  wait_for_stack
  status
}

restart_stack() {
  ensure_tools
  stop_session "$FRONTEND_SESSION"
  stop_session "$JAVA_SESSION"
  stop_session "$GO_SESSION"
  start_stack
}

stop_stack() {
  ensure_tools
  stop_session "$FRONTEND_SESSION"
  stop_session "$JAVA_SESSION"
  stop_session "$GO_SESSION"
  if docker container inspect "$NGINX_CONTAINER" >/dev/null 2>&1; then
    docker stop "$NGINX_CONTAINER" >/dev/null || true
    log "nginx: stopped $NGINX_CONTAINER"
  fi
  log "mysql: leaving $MYSQL_CONTAINER running to preserve local DB availability"
}

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$1" 2>/dev/null || printf '000'
}

wait_http() {
  local name="$1"
  local url="$2"
  local acceptable="$3"
  local timeout="${4:-45}"
  local code elapsed
  elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    code="$(http_code "$url")"
    case " $acceptable " in
      *" $code "*)
        log "$name: ready ($code)"
        return 0
        ;;
    esac
    sleep 1
    elapsed=$((elapsed + 1))
  done
  log "$name: not ready after ${timeout}s (last HTTP $code)"
  return 1
}

wait_for_stack() {
  wait_http "go" http://127.0.0.1:19090/version "200" 30 || true
  wait_http "java/uuc" http://127.0.0.1:9000/api/uuc/system/userLogin/getCaptcha "200" 60 || true
  wait_http "frontend" http://127.0.0.1:8000/ "200" 60 || true
  wait_http "nginx root" http://127.0.0.1:18080/ "200" 30 || true
  wait_http "nginx uuc" http://127.0.0.1:18080/api/uuc/system/userLogin/getCaptcha "200" 30 || true
  wait_http "nginx kapis" http://127.0.0.1:18080/kapis/ "200 401 403 404" 30 || true
}

wsl_portproxy() {
  local ip ports ps_ports
  ip="$(wsl_ip)"
  ports="$PORTPROXY_PORTS"
  ps_ports="$(printf '%s\n' $ports | awk 'NF {printf "%s%s", sep, $1; sep=","}')"
  [ -n "$ps_ports" ] || die "GSSTACK_PORTPROXY_PORTS is empty"
  powershell_available || die "powershell.exe is required to configure Windows portproxy"

  log "windows portproxy: forwarding $PORTPROXY_LISTEN_ADDRESS ports [$ports] to WSL $ip"
  powershell.exe -NoProfile -Command "
\$ports = @($ps_ports)
foreach (\$p in \$ports) {
  netsh interface portproxy delete v4tov4 listenaddress=$PORTPROXY_LISTEN_ADDRESS listenport=\$p | Out-Null
  netsh interface portproxy add v4tov4 listenaddress=$PORTPROXY_LISTEN_ADDRESS listenport=\$p connectaddress=$ip connectport=\$p | Out-Null
}
netsh interface portproxy show all
"
  log "windows portproxy: use the Windows LAN IP, for example http://<windows-lan-ip>:18080, from pods or cloud hosts"
  log "windows portproxy: do not use 127.0.0.1, the WSL IP, or the Hyper-V gateway address from cluster pods"
}

portproxy_status() {
  if powershell_available; then
    printf '\nWindows portproxy:\n'
    powershell.exe -NoProfile -Command 'netsh interface portproxy show all' || true
  fi
}

status() {
  ensure_tools
  load_env

  printf '\nDocker context: '
  docker context show || true

  printf '\nContainers:\n'
  docker ps --format '  {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}' | grep -E "($MYSQL_CONTAINER|$NGINX_CONTAINER)" || true

  printf '\nListeners:\n'
  ss -ltnp | grep -E ':(3306|8000|8080|8091|8100|3100|9000|18080|19090)\b' || true

  printf '\nTmux:\n'
  tmux ls 2>/dev/null | grep -E "($GO_SESSION|$JAVA_SESSION|$FRONTEND_SESSION)" || true

  printf '\nHTTP:\n'
  printf '  go direct      %s  http://127.0.0.1:19090/version\n' "$(http_code http://127.0.0.1:19090/version)"
  printf '  java direct    %s  http://127.0.0.1:9000/api/uuc/system/userLogin/getCaptcha\n' "$(http_code http://127.0.0.1:9000/api/uuc/system/userLogin/getCaptcha)"
  printf '  frontend       %s  http://127.0.0.1:8000/\n' "$(http_code http://127.0.0.1:8000/)"
  printf '  nginx root     %s  http://127.0.0.1:18080/\n' "$(http_code http://127.0.0.1:18080/)"
  printf '  nginx uuc      %s  http://127.0.0.1:18080/api/uuc/system/userLogin/getCaptcha\n' "$(http_code http://127.0.0.1:18080/api/uuc/system/userLogin/getCaptcha)"
  printf '  nginx kapis    %s  http://127.0.0.1:18080/kapis/\n' "$(http_code http://127.0.0.1:18080/kapis/)"
  printf '\n'
  portproxy_status
}

case "${1:-status}" in
  start)
    start_stack
    ;;
  restart)
    restart_stack
    ;;
  stop)
    stop_stack
    ;;
  status)
    status
    ;;
  wsl-portproxy)
    wsl_portproxy
    ;;
  go-run)
    go_run
    ;;
  java-run)
    java_run
    ;;
  frontend-run)
    frontend_run
    ;;
  *)
    die "usage: $0 {status|start|restart|stop|wsl-portproxy}"
    ;;
esac
