#!/bin/sh
# ============================================================
#  terabox-link - connect your TeraBox to this VPS as its disk
#
#  Install (run as root on a Linux VPS):
#    curl -fsSL https://raw.githubusercontent.com/ItzJoker2YT-city/terabox-link/main/install.sh | bash
#
#  Non-interactive (optional):
#    curl -fsSL .../install.sh | bash -s -- --cookie "ndus=...; ..."
#
#  What you get:
#    /root/disk   -> drop files here, they auto-upload to your
#                    TeraBox (folder "disk") and the local copy
#                    is cleared so the VPS disk never fills up
#    tb / tbsync / tbpull helper commands
# ============================================================
set -e

OPENLIST_VER="v4.2.9"
MOUNT="/terabox"
BIN=/root/bin
DATA=/root/openlist
DISK=/root/disk
PULLED=/root/pulled
COOKIE_FILE=/root/.terabox-cookie
ADMIN_PASS_FILE=/root/.tb-admin-pass
WEBDAV_PASS_FILE=/root/.tb-webdav-pass
MARKER="# --- TeraBox disk (default VPS disk) ---"
BRIDGE=http://127.0.0.1:5244

say() { printf '%s\n' "$*"; }
step() { printf '\n== %s ==\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }
genpass() { head -c 64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 20; }

usage() {
  cat <<'EOS'
terabox-link - connect your TeraBox cloud to this VPS as its disk

  curl -fsSL https://raw.githubusercontent.com/ItzJoker2YT-city/mini-core/main/terabox-link/install.sh | bash

Options:
  --cookie "COOKIE"   skip the paste prompt and use this TeraBox login key
  --help              show this help
EOS
}

# ---------- arguments ----------
COOKIE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cookie) [ -n "${2:-}" ] || die "--cookie needs a value"; COOKIE_ARG="$2"; shift 2 ;;
    --cookie=*) COOKIE_ARG="${1#--cookie=}"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

# ---------- pre-flight ----------
[ "$(id -u)" = "0" ] || die "please run as root (try: sudo -i first)"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) OL_ARCH="amd64"; RC_ARCH="amd64" ;;
  aarch64|arm64) OL_ARCH="arm64"; RC_ARCH="arm64" ;;
  *) die "unsupported architecture: $ARCH (supported: x86_64, arm64)" ;;
esac
export RCLONE_CONFIG=/root/.config/rclone/rclone.conf
mkdir -p /root/.config/rclone "$BIN" "$DATA" "$DISK" "$PULLED"

step "installing helper tools"
PKGS=""
command -v curl >/dev/null || PKGS="$PKGS curl"
command -v jq >/dev/null || PKGS="$PKGS jq"
command -v unzip >/dev/null || PKGS="$PKGS unzip"
command -v tar >/dev/null || PKGS="$PKGS tar"
if [ -n "$PKGS" ]; then
  if command -v apt-get >/dev/null; then
    apt-get update -qq >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $PKGS >/dev/null 2>&1 || true
  elif command -v dnf >/dev/null; then dnf install -y -q $PKGS >/dev/null 2>&1 || true
  elif command -v yum >/dev/null; then yum install -y -q $PKGS >/dev/null 2>&1 || true
  elif command -v apk >/dev/null; then apk add -q $PKGS >/dev/null 2>&1 || true
  elif command -v pacman >/dev/null; then pacman -Sy --noconfirm --quiet $PKGS >/dev/null 2>&1 || true
  fi
fi
command -v curl >/dev/null || die "curl is required but could not be installed"
command -v jq >/dev/null || die "jq is required but could not be installed"
command -v unzip >/dev/null || die "unzip is required but could not be installed"
command -v tar >/dev/null || die "tar is required but could not be installed"
say "  ok"

step "downloading rclone + OpenList (skips what is already installed)"
if [ ! -x "$BIN/rclone" ]; then
  curl -fsSL --retry 3 "https://downloads.rclone.org/rclone-current-linux-$RC_ARCH.zip" -o /tmp/rclone.zip
  rm -rf /tmp/rclone-un && mkdir -p /tmp/rclone-un
  unzip -q /tmp/rclone.zip -d /tmp/rclone-un
  RC=$(find /tmp/rclone-un -name rclone -type f 2>/dev/null | head -1)
  [ -n "$RC" ] || die "rclone download failed"
  mv "$RC" "$BIN/rclone" && chmod +x "$BIN/rclone"
  say "  rclone installed"
else
  say "  rclone already installed"
fi
if [ ! -x "$BIN/openlist" ]; then
  curl -fsSL --retry 3 "https://github.com/OpenListTeam/OpenList/releases/download/$OPENLIST_VER/openlist-linux-$OL_ARCH.tar.gz" -o /tmp/openlist.tar.gz
  rm -rf /tmp/ol-un && mkdir -p /tmp/ol-un
  tar -xzf /tmp/openlist.tar.gz -C /tmp/ol-un
  OL=$(find /tmp/ol-un -name openlist -type f 2>/dev/null | head -1)
  [ -n "$OL" ] || die "OpenList download failed"
  mv "$OL" "$BIN/openlist" && chmod +x "$BIN/openlist"
  say "  OpenList installed"
else
  say "  OpenList already installed"
fi
rm -rf /tmp/rclone.zip /tmp/openlist.tar.gz /tmp/rclone-un /tmp/ol-un

start_bridge() {
  (cd "$DATA" && nohup "$BIN/openlist" server >>"$DATA/server.log" 2>&1 &)
}

step "starting the TeraBox bridge (OpenList)"
if ! pgrep -f "openlist server" >/dev/null 2>&1; then
  start_bridge
  sleep 4
fi
# safety: make the bridge listen on localhost only (public VPS)
if [ -f "$DATA/data/config.json" ] && grep -q '"address": "0.0.0.0"' "$DATA/data/config.json" 2>/dev/null; then
  sed -i 's/"address": "0.0.0.0"/"address": "127.0.0.1"/' "$DATA/data/config.json"
  pkill -f "openlist server" 2>/dev/null || true
  sleep 1
  start_bridge
  sleep 4
fi
CODE=""
I=0
while [ $I -lt 15 ]; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BRIDGE/api/public/init_status" 2>/dev/null || true)
  [ "$CODE" = "200" ] && break
  I=$((I + 1)); sleep 1
done
[ "$CODE" = "200" ] || die "bridge did not start - see $DATA/server.log"
say "  bridge running (localhost only)"

step "preparing the bridge admin account"
ADMIN_PASS=""
[ -f "$ADMIN_PASS_FILE" ] && ADMIN_PASS=$(cat "$ADMIN_PASS_FILE")
INIT=$(curl -s "$BRIDGE/api/public/init_status")
if printf '%s' "$INIT" | grep -q '"initialized":false'; then
  ADMIN_PASS=$(genpass)
  curl -s -X POST "$BRIDGE/api/public/init/setup" -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg p "$ADMIN_PASS" '{username:"admin",password:$p,site_title:"TeraBox Disk"}')" >/dev/null
  printf '%s' "$ADMIN_PASS" > "$ADMIN_PASS_FILE" && chmod 600 "$ADMIN_PASS_FILE"
  say "  admin account created"
else
  if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS=$(genpass)
    pkill -f "openlist server" 2>/dev/null || true
    sleep 1
    (cd "$DATA" && "$BIN/openlist" admin set "$ADMIN_PASS" >/dev/null 2>&1) || true
    start_bridge
    sleep 5
    printf '%s' "$ADMIN_PASS" > "$ADMIN_PASS_FILE" && chmod 600 "$ADMIN_PASS_FILE"
    say "  admin password was lost - reset it"
  else
    say "  admin account ready"
  fi
fi

get_token() {
  curl -s -X POST "$BRIDGE/api/auth/login" -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg p "$1" '{username:"admin",password:$p}')" \
    | jq -r '.data.token // empty' 2>/dev/null || true
}
TOKEN=$(get_token "$ADMIN_PASS")
[ -n "$TOKEN" ] || die "could not log in to the bridge admin. Fix: rm $ADMIN_PASS_FILE && rerun this installer"
AUTH="Authorization: $TOKEN"

step "login to your TeraBox"
COOKIE=""
[ -n "$COOKIE_ARG" ] && COOKIE="$COOKIE_ARG"
if [ -z "$COOKIE" ]; then
  cat <<'EOS'

------------------------------------------------------------
  STEP 1 - get your TeraBox login key (takes 2 minutes)
------------------------------------------------------------
  1. Open  https://www.terabox.com  on a computer and log in.
  2. Press F12  ->  click the "Network" tab  ->  refresh (F5).
  3. Click the very first request in the list (the top row).
  4. In "Request Headers" find the line starting with  Cookie:
  5. Copy the WHOLE long value that comes after "Cookie:".

  Your key is stored only on this VPS (root-only file).
------------------------------------------------------------
  STEP 2 - paste it below and press Enter:
EOS
  printf '  > '
  read -r COOKIE < /dev/tty || die "could not read your paste - run from a real terminal, or use: bash -s -- --cookie \"...\""
fi
[ -n "$COOKIE" ] || die "empty login key"
COOKIE=$(printf '%s' "$COOKIE" | tr -d '\r\n')
case "$COOKIE" in
  '"'*'"') COOKIE=${COOKIE#\"}; COOKIE=${COOKIE%\"} ;;
esac
case "$COOKIE" in
  *ndus=*) : ;;
  *) say "  (note: key does not contain 'ndus=' - it may not be accepted)" ;;
esac
printf '%s' "$COOKIE" > "$COOKIE_FILE" && chmod 600 "$COOKIE_FILE"
say "  login key saved"

step "checking your login key with TeraBox"
TB_CHECK=$(curl -s --max-time 30 --retry 2 \
  "https://www.terabox.com/api/list?app_id=250528&web=1&channel=dubox&clienttype=0&dir=/&page=1&num=10" \
  -H "Cookie: $(cat "$COOKIE_FILE")" || true)
TB_ERRNO=$(printf '%s' "$TB_CHECK" | jq -r '.errno // 99' 2>/dev/null || echo 99)
[ "$TB_ERRNO" = "0" ] || die "TeraBox rejected your login key (error $TB_ERRNO).
  Get a fresh key (Step 1 above) and run this installer again."
say "  key accepted by TeraBox"

step "linking TeraBox storage to the bridge"
TOKEN=$(get_token "$ADMIN_PASS")
AUTH="Authorization: $TOKEN"
SID=$(curl -s -H "$AUTH" "$BRIDGE/api/admin/storage/list" 2>/dev/null \
  | jq -r --arg m "$MOUNT" '(.data.content // .data)[]? | select(.mount_path==$m) | .id' 2>/dev/null | head -1 || true)
if [ -n "$SID" ]; then
  curl -s -X POST "$BRIDGE/api/admin/storage/delete?id=$SID" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"id\":$SID}" >/dev/null 2>&1 || true
  sleep 1
  say "  old link removed (refreshing)"
fi
CREATE=""
for TRY in 1 2; do
  CREATE=$(curl -s -X POST "$BRIDGE/api/admin/storage/create" -H "$AUTH" -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg c "$(cat "$COOKIE_FILE")" '{mount_path:"'$MOUNT'",driver:"Terabox",addition:({root_folder_path:"/",cookie:$c,download_api:"",order_by:"",order_direction:""}|tojson),order:0,remark:"",cache_expiration:30,status:"work"}')")
  printf '%s' "$CREATE" | jq -e '.code==200' >/dev/null 2>&1 && break
  if [ "$TRY" = "1" ]; then
    SID=$(curl -s -H "$AUTH" "$BRIDGE/api/admin/storage/list" 2>/dev/null \
      | jq -r --arg m "$MOUNT" '(.data.content // .data)[]? | select(.mount_path==$m) | .id' 2>/dev/null | head -1 || true)
    if [ -n "$SID" ]; then
      curl -s -X POST "$BRIDGE/api/admin/storage/delete?id=$SID" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"id\":$SID}" >/dev/null 2>&1 || true
      sleep 2
    fi
  fi
done
printf '%s' "$CREATE" | jq -e '.code==200' >/dev/null 2>&1 \
  || die "the bridge refused to create the link.
  Bridge said: $(printf '%s' "$CREATE" | head -c 180)"
sleep 3
LIST=$(curl -s -X POST "$BRIDGE/api/fs/list" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"path\":\"$MOUNT\",\"page\":1,\"per_page\":5,\"refresh\":true}")
if printf '%s' "$LIST" | jq -e '.code==200' >/dev/null 2>&1; then
  say "  TeraBox connected and verified"
else
  say "  warning: bridge list check returned: $(printf '%s' "$LIST" | head -c 140)"
fi

step "creating the VPS disk user"
WDPASS=""
[ -f "$WEBDAV_PASS_FILE" ] && WDPASS=$(cat "$WEBDAV_PASS_FILE")
EXIST=$(curl -s -H "$AUTH" "$BRIDGE/api/admin/user/list" | jq -r --arg u tbdisk '(.data // [])[]? | select(.username==$u) | .id' 2>/dev/null | head -1 || true)
if [ -n "$EXIST" ]; then
  curl -s -X POST "$BRIDGE/api/admin/user/delete?id=$EXIST" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"id\":$EXIST}" >/dev/null 2>&1 || true
fi
[ -n "$WDPASS" ] || WDPASS=$(genpass)
UCREATE=$(curl -s -X POST "$BRIDGE/api/admin/user/create" -H "$AUTH" -H 'Content-Type: application/json' \
  -d "$(jq -cn --arg p "$WDPASS" '{username:"tbdisk",password:$p,base_path:"/",role:0,permission:65535,disabled:false,sso_id:""}')")
printf '%s' "$UCREATE" | jq -e '.code==200' >/dev/null 2>&1 \
  || die "could not create the disk user. Bridge said: $(printf '%s' "$UCREATE" | head -c 180)"
# force full permissions (WebDAV write needs bit 9)
UID2=$(curl -s -H "$AUTH" "$BRIDGE/api/admin/user/list" | jq -r --arg u tbdisk '(.data // [])[]? | select(.username==$u) | .id' 2>/dev/null | head -1 || true)
if [ -n "$UID2" ]; then
  U=$(curl -s -H "$AUTH" "$BRIDGE/api/admin/user/get?id=$UID2")
  UPD=$(printf '%s' "$U" | jq -c '.data | .permission=65535')
  curl -s -X POST "$BRIDGE/api/admin/user/update" -H "$AUTH" -H 'Content-Type: application/json' -d "$UPD" >/dev/null || true
  TOKEN=$(get_token "$ADMIN_PASS")
  AUTH="Authorization: $TOKEN"
fi
printf '%s' "$WDPASS" > "$WEBDAV_PASS_FILE" && chmod 600 "$WEBDAV_PASS_FILE"
say "  user 'tbdisk' ready"

step "wiring the disk commands (rclone)"
OBSCURED=$("$BIN/rclone" obscure "$WDPASS")
if "$BIN/rclone" listremotes 2>/dev/null | grep -q '^terabox:$'; then
  "$BIN/rclone" config update terabox url="$BRIDGE/dav$MOUNT" vendor=other user=tbdisk pass="$OBSCURED" >/dev/null
else
  "$BIN/rclone" config create terabox webdav url="$BRIDGE/dav$MOUNT" vendor=other user=tbdisk pass="$OBSCURED" >/dev/null
fi
"$BIN/rclone" lsd terabox: >/dev/null 2>&1 || die "rclone cannot see TeraBox through the bridge"
say "  rclone remote 'terabox:' ready"

step "installing the auto-disk + helper commands"
cat > "$BIN/tb-sync.sh" <<'TBEOF'
#!/bin/sh
# TeraBox auto-disk: everything in /root/disk uploads to terabox:disk, then local copy is cleared
while true; do
  sleep 20
  pgrep -f "openlist server" >/dev/null 2>&1 || { cd /root/openlist && nohup /root/bin/openlist server >>/root/openlist/server.log 2>&1 & sleep 6; }
  /root/bin/rclone move /root/disk terabox:disk --min-age 10s --delete-empty-src-dirs >>/root/.tb-sync.log 2>&1
done
TBEOF
chmod +x "$BIN/tb-sync.sh"

touch /root/.bashrc
if ! grep -qF "$MARKER" /root/.bashrc; then
  [ -f /root/.bashrc.tb-backup ] || cp /root/.bashrc /root/.bashrc.tb-backup
  cat > /tmp/.tb-prepend <<TBPRE
$MARKER
mkdir -p /root/disk /root/pulled 2>/dev/null
pgrep -f "tb-sync.sh" >/dev/null 2>&1 || { nohup /root/bin/tb-sync.sh >/dev/null 2>&1 & }
tb() { /root/bin/rclone ls terabox: "\$@"; }
tbsync() { /root/bin/rclone move /root/disk terabox:disk --min-age 1s && echo "disk synced to TeraBox"; }
tbpull() {
  p="\${1%/}"
  name="\$(basename "\$p")"
  if /root/bin/rclone lsf --files-only "terabox:\$(dirname "\$p")" 2>/dev/null | grep -Fxq "\$name"; then
    /root/bin/rclone copyto "terabox:\$p" "/root/pulled/\$name" && echo "saved to /root/pulled/\$name"
  else
    /root/bin/rclone copy "terabox:\$p" "/root/pulled/\$name" && echo "saved to /root/pulled/\$name/"
  fi
}
echo "TeraBox disk ready: put files in /root/disk - they upload to your TeraBox (folder 'disk') automatically, then the local copy is cleared to save VPS space"
echo "  list TeraBox: tb   |   sync now: tbsync   |   pull a file back: tbpull <name> (saved to /root/pulled)"
TBPRE
  cat /tmp/.tb-prepend /root/.bashrc > /root/.bashrc.new && mv /root/.bashrc.new /root/.bashrc
  rm -f /tmp/.tb-prepend
  say "  helpers added to /root/.bashrc"
else
  say "  helpers already installed"
fi
pkill -f "tb-sync.sh" >/dev/null 2>&1 || true
sleep 1
nohup "$BIN/tb-sync.sh" >/dev/null 2>&1 &
say "  auto-uploader running"

step "self-test (upload -> read back -> clean up)"
printf 'terabox-link self-test\n' > "$DISK/.tb-link-test.txt"
OK=""
I=0
while [ $I -lt 12 ]; do
  sleep 5
  if "$BIN/rclone" lsf --files-only terabox:disk 2>/dev/null | grep -q '^\.tb-link-test\.txt$'; then OK=1; break; fi
  I=$((I + 1))
done
if [ -n "$OK" ]; then
  say "  upload test:    PASSED"
  say "  read-back test: $("$BIN/rclone" cat terabox:disk/.tb-link-test.txt 2>/dev/null | head -c 30 | tr -d '\n')"
  "$BIN/rclone" delete terabox:disk/.tb-link-test.txt >/dev/null 2>&1 || true
  "$BIN/rclone" rmdir terabox:disk >/dev/null 2>&1 || true
  say "  cleanup:        done"
else
  say "  upload test:    could not confirm in 60s (TeraBox can be slow) - check with: tb"
fi

cat <<EOS

  ============================================================
    DONE - TeraBox is now the disk of this VPS
  ============================================================
    Drop files in : $DISK   (auto-uploads to TeraBox in ~30s,
                              then the local copy is cleared)
    Your files    : terabox.com or the TeraBox app -> folder "disk"
    New commands  : tb           list your TeraBox
                    tbsync       force upload now
                    tbpull NAME  download back (to /root/pulled)
                    rclone copy /root/file.txt terabox:   direct upload
  ------------------------------------------------------------
    Start using it right now:  type   source ~/.bashrc
    If it ever stops working (login expired weeks later),
    just run this installer again.
  ============================================================
EOS
