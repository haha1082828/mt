#!/bin/sh
# play.sh - Orquestrador multi-contas TWM

umask 077

TOYBOX="$HOME/.multcf/toybox"
if [ ! -x "$TOYBOX" ]; then
    TOYBOX="sh"
fi
export TOYBOX

_self="$0"
_hops=0
while [ -L "$_self" ] && [ "$_hops" -lt 20 ]; do
    _link=$(readlink "$_self")
    case "$_link" in
        /*) _self="$_link" ;;
        *)  _self="$(dirname "$_self")/$_link" ;;
    esac
    _hops=$((_hops + 1))
done
_dir=$(dirname "$_self")
TWMDIR=$(cd "$_dir" && pwd -P)
unset _dir _self _link _hops
export TWMDIR

resolve_accounts_file() {
    if [ -s "$TWMDIR/accounts.conf" ]; then
        printf '%s' "$TWMDIR/accounts.conf"
        return 0
    fi
    for _cand in "$HOME/Furia-de-titas/accounts.conf" \
                 "$HOME/.twm/accounts.conf" \
                 "$HOME/twm/accounts.conf"; do
        if [ -s "$_cand" ]; then
            printf '%s' "$_cand"
            unset _cand
            return 0
        fi
    done
    unset _cand
    printf '%s' "$TWMDIR/accounts.conf"
}

ACCOUNTS_FILE=$(resolve_accounts_file)

termux-wake-lock 2>/dev/null
STATUS_DIR="$HOME/.twm/status"
LAST_RUN_FILE="$HOME/.twm/last_runmode"

FORCE_RESTART=0
RUN=""
for _arg in "$@"; do
    case "$_arg" in
        --restart|-r) FORCE_RESTART=1 ;;
        *)            [ -z "$RUN" ] && RUN="$_arg" ;;
    esac
done
unset _arg
[ -z "$RUN" ] && RUN="-boot"

clear

# Função auxiliar para traduzir o modo em nome amigável para o aviso
get_mode_name() {
    case "$1" in
        -cv*) echo "caverna" ;;
        -cl*) echo "coliseu" ;;
        *)    echo "padrão" ;;
    esac
}

PREV_RUN=""
[ -f "$LAST_RUN_FILE" ] && read -r PREV_RUN < "$LAST_RUN_FILE" 2>/dev/null

# Se o modo mudou, limpamos internamente os PIDs ativos e avisa de forma amigável
if [ "$RUN" != "$PREV_RUN" ] && [ -n "$PREV_RUN" ]; then
    _prev_name=$(get_mode_name "$PREV_RUN")
    _curr_name=$(get_mode_name "$RUN")
    
    printf "\n⚠️  Modo alterado de [%s] para [%s]. Limpando ambiente anterior...\n\n" "$_prev_name" "$_curr_name"
    
    if [ -d "$STATUS_DIR" ]; then
        for _pidf in "$STATUS_DIR"/*.pid; do
            [ -f "$_pidf" ] || continue
            _p=$(cat "$_pidf" 2>/dev/null)
            case "$_p" in *[!0-9]*) continue ;; esac
            kill -TERM "$_p" >/dev/null 2>&1
            kill -KILL "$_p" >/dev/null 2>&1
        done
        rm -rf "$STATUS_DIR"/*
    fi
    FORCE_RESTART=1
fi

printf "%s" "$RUN" > "$LAST_RUN_FILE" 2>/dev/null

if [ -n "$RUN" ]; then
    for _d in "$HOME/.twm"/*; do
        [ -d "$_d" ] && printf "%s" "$RUN" > "$_d/runmode_file" 2>/dev/null
    done
    unset _d
fi

GREEN='\033[32m'
GOLD='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[01;36m'
YELLOW='\033[1;33m'
RESET='\033[00m'

mkdir -p "$STATUS_DIR"

echo "$$" > "$STATUS_DIR/orchestrator.pid"
chmod 700 "$HOME/.twm" 2>/dev/null
[ -f "$ACCOUNTS_FILE" ] && chmod 600 "$ACCOUNTS_FILE" 2>/dev/null

chmod +x "$TWMDIR/worker.sh" "$TWMDIR/twm.sh" 2>/dev/null

if command -v setsid > /dev/null 2>&1; then
    SETSID="setsid"
else
    SETSID=""
fi

server_url()    { case "$1" in 1) echo "furiadetitas.net" ;; esac; }
server_tag()    { case "$1" in 1) echo "BR" ;; esac; }
server_scheme() { echo "https"; }

clean_field() {
    printf '%s' "$1" | tr -d '\000-\037'
}

kill_worker_tree() {
    kw_pid="$1"
    [ -n "$kw_pid" ] || return 1
    case "$kw_pid" in *[!0-9]*) return 1 ;; esac

    if [ -r "/proc/$kw_pid/cmdline" ]; then
        tr '\0' ' ' < "/proc/$kw_pid/cmdline" 2>/dev/null \
            | grep -qE 'worker\.sh|twm\.sh' || return 1
    else
        kill -0 "$kw_pid" 2>/dev/null || return 1
    fi

    kill -TERM "-$kw_pid" >/dev/null 2>&1
    kill -TERM "$kw_pid" >/dev/null 2>&1
    sleep 2
    if kill -0 "$kw_pid" 2>/dev/null; then
        kill -KILL "-$kw_pid" >/dev/null 2>&1
        kill -KILL "$kw_pid" >/dev/null 2>&1
    fi
    return 0
}

worker_vivo() {
    wv_pid="$1"
    [ -n "$wv_pid" ] || return 1
    case "$wv_pid" in *[!0-9]*) return 1 ;; esac
    kill -0 "$wv_pid" 2>/dev/null || return 1
    if [ -r "/proc/$wv_pid/cmdline" ]; then
        tr '\0' ' ' < "/proc/$wv_pid/cmdline" 2>/dev/null \
            | grep -qE 'worker\.sh|twm\.sh' || return 1
    fi
    return 0
}

launch_worker() {
    lw_srv="$1"
    lw_user="$2"
    lw_enc="$3"

    lw_tag=$(server_tag "$lw_srv")
    lw_host=$(server_url "$lw_srv")
    lw_scheme=$(server_scheme "$lw_srv")
    [ -n "$lw_tag" ] && [ -n "$lw_host" ] || return 1

    lw_id="${lw_tag}_${lw_user}"
    lw_dir="$HOME/.twm/${lw_id}"
    lw_status="$STATUS_DIR/${lw_id}.status"
    lw_pidf="$STATUS_DIR/${lw_id}.pid"
    lw_log="$lw_dir/twm.log"

    mkdir -p "$lw_dir"
    chmod 700 "$lw_dir" 2>/dev/null

    [ ! -f "$lw_dir/userAgent.txt" ] && [ -f "$TWMDIR/userAgent.txt" ] && \
        cp "$TWMDIR/userAgent.txt" "$lw_dir/userAgent.txt"

    if [ -n "$lw_enc" ]; then
        printf '%s\n' "$lw_enc" > "$lw_dir/cript_file"
        chmod 600 "$lw_dir/cript_file"
    fi

    if [ ! -s "$lw_dir/cript_file" ]; then
        printf "   sem credencial para %s - pulando\n" "$lw_id"
        return 1
    fi

    printf "%s" "$RUN" > "$lw_dir/runmode_file" 2>/dev/null

    if [ -f "$lw_pidf" ]; then
        lw_old=$(cat "$lw_pidf" 2>/dev/null)
        if [ "$FORCE_RESTART" != "1" ] && worker_vivo "$lw_old"; then
            _run_name=$(get_mode_name "$RUN")
            printf "   ${GREEN}🟢 ja rodando${RESET} (PID %s) - mantida (modo: %s)\n" "$lw_old" "$_run_name"
            unset lw_old
            return 2
        fi
        kill_worker_tree "$lw_old"
        rm -f "$lw_pidf"
        unset lw_old
    fi

    echo "starting" > "$lw_status"

    TOYBOX="$TOYBOX" _TOYBOX_RUNNING="1" \
    nohup $SETSID "$TOYBOX" "$TWMDIR/worker.sh" \
        "$lw_srv" "$lw_user" "$lw_tag" \
        "${lw_scheme}://${lw_host}" "$lw_dir" "$lw_status" "$RUN" \
        < /dev/null >> "$lw_log" 2>&1 &

    return 0
}

if [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ]; then
    printf "${RED}🔴 Nenhuma conta cadastrada.${RESET}\n"
    printf "Execute: ${GOLD}./setup.sh${RESET}\n"
    exit 1
fi

total=$(grep -c -E '^[0-9]+\|' "$ACCOUNTS_FILE" 2>/dev/null)
case "$total" in *[!0-9]*) total=0 ;; esac
[ -z "$total" ] && total=0

_display_mode=$(get_mode_name "$RUN")
printf "${CYAN}🎮 TWM Multi-contas - %s conta(s) [%s] (Modo: %s)${RESET}\n" "$total" "$TOYBOX" "$_display_mode"
[ "$ACCOUNTS_FILE" = "$TWMDIR/accounts.conf" ] || \
    printf "${GOLD}Contas:${RESET} %s\n" "$ACCOUNTS_FILE"
printf "${CYAN}DRAGONS 🐉${RESET}\n\n"

limpa_orfaos() {
    _lo_n=0
    _known_pids=$(cat "$STATUS_DIR"/*.pid 2>/dev/null | tr '\n' ' ')
    for _lo_p in /proc/[0-9]*; do
        _lo_pid=${_lo_p#/proc/}
        case "$_lo_pid" in *[!0-9]*) continue ;; esac
        [ "$_lo_pid" = "$$" ] && continue
        [ -r "$_lo_p/cmdline" ] || continue
        case "$(tr '\0' ' ' < "$_lo_p/cmdline" 2>/dev/null)" in
            *"$TWMDIR/worker.sh"*|*"$TWMDIR/twm.sh"*) ;;
            *) continue ;;
        esac
        _lo_conhecido=0
        case " $_known_pids " in
            *" $_lo_pid "*) _lo_conhecido=1 ;;
        esac
        [ "$_lo_conhecido" = 1 ] && continue
        kill -TERM "$_lo_pid" 2>/dev/null
        _lo_n=$((_lo_n + 1))
    done
    [ "$_lo_n" -gt 0 ] && \
        printf "${GOLD}%s processo(s) orfao(s) encerrado(s).${RESET}\n\n" "$_lo_n"
    unset _lo_n _lo_p _lo_pid _lo_conhecido _known_pids
}
limpa_orfaos

if [ -d /data/data/com.termux ] && [ "$total" -gt 3 ] && [ -z "$TWM_PACING" ]; then
    TWM_PACING=0
    export TWM_PACING
fi

n=0
n_kept=0

while IFS='|' read -r srv user encoded <&3 || [ -n "$srv" ]; do
    srv=$(clean_field "$srv")
    user=$(clean_field "$user")
    encoded=$(clean_field "$encoded")

    case "$srv" in
        ''|\#*) continue ;;
        *[!0-9]*) continue ;;
    esac
    [ -z "$user" ] || [ -z "$encoded" ] && continue
    case "$user" in
        */*) printf "${RED}Nome invalido: %s${RESET}\n" "$user"; continue ;;
    esac

    tag=$(server_tag "$srv")
    if [ -z "$tag" ]; then
        printf "${RED}Servidor desconhecido: %s${RESET}\n" "$srv"
        continue
    fi

    n=$((n + 1))
    acc_id="${tag}_${user}"
    log_file="$HOME/.twm/${acc_id}/twm.log"
    pid_file="$STATUS_DIR/${acc_id}.pid"

    printf "${GOLD}[%d/%d]${RESET} [%s] %s\n" "$n" "$total" "$tag" "$user"

    launch_worker "$srv" "$user" "$encoded"
    case "$?" in
        1) continue ;;
        2) n_kept=$((n_kept + 1)); continue ;;
    esac

    pid=""
    _w=0
    while [ -z "$pid" ] && [ "$_w" -lt 5 ]; do
        sleep 1
        pid=$(cat "$pid_file" 2>/dev/null)
        _w=$((_w + 1))
    done
    printf "   PID: %s | Log: %s\n" "${pid:-FALHOU}" "$log_file"
    [ -z "$pid" ] && printf "   ${RED}AVISO: worker nao iniciou.${RESET}\n"

    if [ "$n" -lt "$total" ]; then
        _base=$(( 180 / total ))
        [ "$_base" -lt 3 ] && _base=3
        [ "$_base" -gt 15 ] && _base=15
        _jit=$(( _base + (n + $$) % 4 ))
        printf "   aguardando %ss\n" "$_jit"
        sleep "$_jit"
    fi

done 3< "$ACCOUNTS_FILE"

if [ "$n" -eq 0 ]; then
    printf "${RED}Nenhuma conta valida encontrada em accounts.conf${RESET}\n"
    exit 1
fi

printf "\n${GREEN}🟢 %s conta(s): %s iniciada(s), %s ja rodando (Modo: %s).${RESET}\n\n" \
    "$n" "$((n - n_kept))" "$n_kept" "$_display_mode"

if [ "$n" -lt "$total" ]; then
    printf "${RED}AVISO: %s conta(s) nao foram iniciadas.${RESET}\n\n" "$((total - n))"
fi

printf "Ver o painel:  ${CYAN}./status.sh${RESET}\n"
printf "Reiniciar:     ${CYAN}./play.sh --restart${RESET}\n"
printf "Parar tudo:    ${CYAN}./stop.sh${RESET}\n\n"

. "$TWMDIR/panel.sh"
PANEL_SUPERVISE=1
[ "$HAS_TTY" = 0 ] && echo "[monitor] supervisionando $n conta(s)"
painel_loop
