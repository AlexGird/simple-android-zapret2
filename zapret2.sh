#!/system/bin/sh

BASE="/data/local/zapret2"
NFQWS="$BASE/bin/nfqws2"
PIDFILE="$BASE/nfqws2.pid"
LOGFILE="$BASE/log/nfqws2.log"
QNUM="300"

LUA_LIB="$BASE/lua/zapret-lib.lua"
LUA_ANTIDPI="$BASE/lua/zapret-antidpi.lua"
LUA_AUTO="$BASE/lua/zapret-auto.lua"

NFQWS_OPT="\
--qnum=$QNUM \
--lua-init=@$LUA_LIB \
--lua-init=@$LUA_ANTIDPI \
--lua-init=@$LUA_AUTO \
--filter-tcp=443 --filter-l7=tls --hostlist=/data/local/zapret2/list/youtube.txt --payload=tls_client_hello --lua-desync=hostfakesplit:tcp_md5:midhost=midsld
"

check_files() {
  [ -x "$NFQWS" ] || {
    echo "ERROR: nfqws2 not found or not executable: $NFQWS"
    exit 1
  }

  for f in "$LUA_LIB" "$LUA_ANTIDPI" "$LUA_AUTO"; do
    [ -f "$f" ] || {
      echo "ERROR: missing lua file: $f"
      exit 1
    }
  done

  mkdir -p "$BASE/log"
}

add_rules() {
  iptables -t mangle -A OUTPUT -p tcp -m multiport --dports 443 \
    -j NFQUEUE --queue-num "$QNUM" --queue-bypass

  iptables -t mangle -A OUTPUT -p udp -m multiport --dports 443 \
    -j NFQUEUE --queue-num "$QNUM" --queue-bypass
}

del_rules() {
  while iptables -t mangle -D OUTPUT -p tcp -m multiport --dports 443 \
    -j NFQUEUE --queue-num "$QNUM" --queue-bypass 2>/dev/null; do :; done

  while iptables -t mangle -D OUTPUT -p udp -m multiport --dports 443 \
    -j NFQUEUE --queue-num "$QNUM" --queue-bypass 2>/dev/null; do :; done
}

start() {
  check_files
  stop_silent

  add_rules

  "$NFQWS" $NFQWS_OPT > "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"

  sleep 1

  if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "zapret2 started"
  else
    echo "ERROR: nfqws2 failed to start"
    tail -40 "$LOGFILE"
    del_rules
    rm -f "$PIDFILE"
    exit 1
  fi
}

stop_silent() {
  del_rules

  if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
  fi

  killall nfqws2 2>/dev/null
}

stop() {
  stop_silent
  echo "zapret2 stopped"
}

status() {
  echo "iptables:"
  iptables -t mangle -L OUTPUT -n -v | grep NFQUEUE

  echo
  echo "process:"
  ps -A | grep nfqws2

  echo
  echo "queue:"
  cat /proc/net/netfilter/nfnetlink_queue 2>/dev/null

  echo
  echo "log:"
  tail -40 "$LOGFILE" 2>/dev/null
}

case "$1" in
  start) start ;;
  stop) stop ;;
  restart) stop_silent; start ;;
  status) status ;;
  *) echo "usage: $0 {start|stop|restart|status}" ;;
esac
