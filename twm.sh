#!/bin/sh
# shellcheck disable=SC1091
# twm.sh - Worker de conta individual (nao interativo)
# Executado pelo worker.sh com o shell correto via $TOYBOX

TOYBOX="${TOYBOX:-sh}"

umask 077

if [ -z "$TWMDIR" ]; then
    _d=$(dirname "$0")
    TWMDIR=$(cd "$_d" && pwd)
    unset _d
    export TWMDIR
fi

if [ -z "$TWM_SRV" ] || [ -z "$TWM_URL" ] || [ -z "$TWM_ACC_DIR" ]; then
    printf "ERRO: twm.sh deve ser chamado pelo worker.sh\n"
    exit 1
fi

URL="$TWM_URL"
UR="$TWM_SRV"
TMP="$TWM_ACC_DIR"
TMP_COOKIE="$TMP/cookie.txt"
export URL UR TMP TMP_COOKIE

# Servidor unico (BR): fuso fixo.
export TZ="America/Bahia"

mkdir -p "$TMP"
chmod 700 "$TMP" 2>/dev/null

[ -n "$TWM_STATUS_FILE" ] && echo "loading" > "$TWM_STATUS_FILE"

. "$TWMDIR/info.sh"
. "$TWMDIR/session_check.sh"
colors

# Modo de execucao.
if [ -s "$TMP/runmode_file" ]; then
    read -r RUN < "$TMP/runmode_file" 2>/dev/null
elif [ -n "$1" ]; then
    RUN="$1"
fi
[ -z "$RUN" ] && RUN='-boot'
export RUN

if [ -d /data/data/com.termux/files/usr/share/doc ]; then
    termux-wake-lock 2>/dev/null
fi

cd "$TWMDIR" || exit 1
for _lib in \
    state.sh resource_guard.sh \
    requeriments.sh loginlogoff.sh \
    flagfight.sh clanid.sh crono.sh arena.sh coliseum.sh \
    campaign.sh run.sh altars.sh clandmg.sh clanfight.sh \
    clancoliseum.sh king.sh undying.sh trade.sh career.sh \
    cave.sh allies.sh svproxy.sh check.sh league.sh clanquest.sh \
    specialevent.sh function.sh update_check.sh \
    blessing.sh
do
    [ -f "$TWMDIR/$_lib" ] && . "$TWMDIR/$_lib"
done
unset _lib

load_config

if [ ! -f "$TMP/userAgent.txt" ] && [ -f "$TWMDIR/userAgent.txt" ]; then
    cp "$TWMDIR/userAgent.txt" "$TMP/userAgent.txt"
fi
random_ua 2>/dev/null
[ -z "$vUserAgent" ] && vUserAgent="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"
export vUserAgent

[ ! -f "$TMP/allies.txt" ]  && : > "$TMP/allies.txt"
[ ! -f "$TMP/callies.txt" ] && : > "$TMP/callies.txt"

printf "[%s] %s — iniciando (modo %s)\n" "$TWM_TAG" "$TWM_USER" "$RUN"

LOCKDIR="$HOME/.twm/.login.lock"

login_lock() {
    _n=0
    while [ "$_n" -lt 180 ]; do
        if mkdir "$LOCKDIR" 2>/dev/null; then
            echo $$ > "$LOCKDIR/pid" 2>/dev/null
            return 0
        fi
        read -r _dono < "$LOCKDIR/pid" 2>/dev/null
        case "$_dono" in
            ''|*[!0-9]*) : ;;
            *) kill -0 "$_dono" 2>/dev/null || rm -rf "$LOCKDIR" 2>/dev/null ;;
        esac
        sleep 1
        _n=$((_n + 1))
    done
    return 0
}

login_unlock() { rm -rf "$LOCKDIR" 2>/dev/null; }

do_login() {
    if [ -s "$TMP_COOKIE" ]; then
        PAGE=$(run_curl "${URL}/user" 2>/dev/null)
        _rc=$?
        if [ "$_rc" -ne 0 ] || [ -z "$PAGE" ]; then
            LOGIN_ERRO=rede
            unset PAGE
            return 1
        fi
        LOGIN_ERRO=credencial
        if is_logged_in "$PAGE"; then
            ACC=$(extract_username "$PAGE")
            [ -z "$ACC" ] && ACC="$TWM_USER"
            export ACC
            fetch_max_hp 2>/dev/null
            parse_status "$PAGE"
            messages_info
            printf "[%s] %s — sessao reaproveitada (sem novo login)\n" "$TWM_TAG" "$ACC"
            unset PAGE
            return 0
        fi
        unset PAGE
    fi

    cript_file="$TMP/cript_file"
    if [ ! -s "$cript_file" ]; then
        printf "[%s] %s — ERRO: sem credenciais\n" "$TWM_TAG" "$TWM_USER"
        return 1
    fi

    creds=$(base64 -d "$cript_file" 2>/dev/null)
    if [ -z "$creds" ]; then
        printf "[%s] %s — ERRO: cript_file ilegivel\n" "$TWM_TAG" "$TWM_USER"
        return 1
    fi
    
    luser="${creds%%&pass=*}"
    luser="${luser##login=}"
    lpass="${creds##*&pass=}"
    unset creds

    login_lock
    run_curl "${URL}/?sign_in=1" > /dev/null 2>&1

    run_curl --data-urlencode "login=${luser}" \
             --data-urlencode "pass=${lpass}" \
             "${URL}/?sign_in=1" > /dev/null
    unset luser lpass

    _rc2=$?
    PAGE=$(run_curl "${URL}/user" 2>/dev/null)
    _rc3=$?

    login_unlock

    if [ "$_rc2" -ne 0 ] || [ "$_rc3" -ne 0 ] || [ -z "$PAGE" ]; then
        LOGIN_ERRO=rede
        unset PAGE
        return 1
    fi
    LOGIN_ERRO=credencial
    if is_logged_in "$PAGE"; then
        ACC=$(extract_username "$PAGE")
        [ -z "$ACC" ] && ACC="$TWM_USER"
        export ACC
        fetch_max_hp 2>/dev/null
        parse_status "$PAGE"
        messages_info
        printf "[%s] %s — login OK\n" "$TWM_TAG" "$ACC"
        unset PAGE
        return 0
    fi
    unset PAGE
    return 1
}

login_delay=30
login_try=0
while true; do
    if do_login; then
        break
    fi

    if [ "${LOGIN_ERRO:-credencial}" = "rede" ]; then
        _wait=$(( 20 + ($$ % 20) ))
        printf "[%s] %s — servidor nao respondeu, nova tentativa em %ss\n" \
            "$TWM_TAG" "$TWM_USER" "$_wait"
        [ -n "$TWM_STATUS_FILE" ] && echo "login_retry" > "$TWM_STATUS_FILE"
        sleep "$_wait"
        login_delay=30
        login_try=0
        rm -f "$TMP_COOKIE"
        continue
    fi

    login_try=$((login_try + 1))

    _half=$(( login_delay / 2 ))
    _wait=$(( _half + ( ($$ + login_try) % (_half + 1) ) ))

    printf "[%s] %s — login falhou (tentativa %s), nova tentativa em %ss\n" \
        "$TWM_TAG" "$TWM_USER" "$login_try" "$_wait"
    [ -n "$TWM_STATUS_FILE" ] && echo "login_retry" > "$TWM_STATUS_FILE"
    sleep "$_wait"

    if   [ "$login_try" -le 3 ]; then _cap=60
    elif [ "$login_try" -le 6 ]; then _cap=300
    else                               _cap=900
    fi
    [ "$login_delay" -lt "$_cap" ] && login_delay=$((login_delay * 2))
    [ "$login_delay" -gt "$_cap" ] && login_delay=$_cap
    rm -f "$TMP_COOKIE"
done

clan_id 2>/dev/null
func_proxy

twm_start() {
    case "$RUN" in
        *-cv*) cave_start ;;
        *-cl*) twm_play ;;
        *)     twm_play ;;
    esac
}

func_unset() {
    unset HP1 HP2 YOU USER CLAN ENTER ATK ATKRND DODGE HEAL GRASS STONE \
          BEXIT OUTGATE LEAVEFIGHT WDRED CAVE BREAK NEWCAVE \
          FULL RHP HLHP ACCESS SHIELD UNRIP KINGATK
}

[ -n "$TWM_STATUS_FILE" ] && echo "running" > "$TWM_STATUS_FILE"
printf "[%s] %s — loop principal iniciado\n" "$TWM_TAG" "$ACC"

while true; do
    if [ -f "$HOME/.twm/PAUSED" ] || [ -f "$TMP/PAUSED" ]; then
        [ -n "$TWM_STATUS_FILE" ] && echo "paused" > "$TWM_STATUS_FILE"
        sleep 30
        continue
    fi
    [ -n "$TWM_STATUS_FILE" ] && echo "running" > "$TWM_STATUS_FILE"
    twm_start
done
