#!/bin/sh
# worker.sh - Loop de uma conta individual
# Recebe TOYBOX e _TOYBOX_RUNNING via ambiente do play.sh

TOYBOX="${TOYBOX:-sh}"

TWM_SRV="$1"
TWM_USER="$2"
TWM_TAG="$3"
TWM_URL="$4"
TWM_ACC_DIR="$5"
TWM_STATUS_FILE="$6"
RUN="${7:--boot}"

if [ -z "$TWM_SRV" ] || [ -z "$TWM_URL" ] || [ -z "$TWM_ACC_DIR" ] || [ -z "$TWM_STATUS_FILE" ]; then
    printf "ERRO: worker.sh deve ser chamado pelo play.sh\n"
    exit 1
fi

export TWM_SRV TWM_USER TWM_TAG TWM_URL TWM_ACC_DIR TWM_STATUS_FILE TOYBOX

umask 077

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
unset _dir
export TWMDIR

PID_FILE="${TWM_STATUS_FILE%.status}.pid"

echo "$$" > "$PID_FILE"
echo "starting" > "$TWM_STATUS_FILE"

termux-wake-lock 2>/dev/null

printf "[%s] %s — worker PID=%s\n" "$TWM_TAG" "$TWM_USER" "$$"

mkdir -p "$TWM_ACC_DIR"
chmod 700 "$TWM_ACC_DIR" 2>/dev/null

if [ ! -s "$TWM_ACC_DIR/cript_file" ]; then
    printf "[%s] %s — ERRO: cript_file ausente. Rode ./setup.sh\n" "$TWM_TAG" "$TWM_USER"
    echo "dead" > "$TWM_STATUS_FILE"
    exit 1
fi
chmod 600 "$TWM_ACC_DIR/cript_file" 2>/dev/null

rotate_log() {
    _lg="$TWM_ACC_DIR/twm.log"
    [ -f "$_lg" ] || return 0
    _sz=$(wc -c < "$_lg" 2>/dev/null)
    case "$_sz" in ''|*[!0-9]*) return 0 ;; esac
    if [ "$_sz" -gt 5242880 ]; then
        rm -f "$_lg.1"
        mv "$_lg" "$_lg.1" 2>/dev/null
        : > "$_lg"
    fi
    unset _lg _sz
}

rotate_log
echo "running" > "$TWM_STATUS_FILE"

exec "$TOYBOX" "$TWMDIR/twm.sh" "$RUN" < /dev/null
