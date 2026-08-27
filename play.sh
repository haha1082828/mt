#!/bin/sh
# play.sh - Orquestrador multi-contas TWM

# CORRECAO (seguranca): sem umask, ~/.twm e o accounts.conf nasciam 755/644.
umask 077

TOYBOX="$HOME/.multcf/toybox"
if [ ! -x "$TOYBOX" ]; then
    TOYBOX="sh"
fi
export TOYBOX

# Resolve o caminho real do script, seguindo links simbolicos.
#
# CORRECAO: era so "dirname $0". Chamado por um link simbolico (ou por um
# atalho em $PREFIX/bin), o TWMDIR apontava para a pasta do LINK e nao para
# a do repositorio — e o accounts.conf lido era outro.
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

# Localiza o arquivo de contas.
#
# CORRECAO: o caminho vinha exclusivamente do diretorio do script. Com mais
# de uma copia do repositorio no aparelho — o caso mais comum e clonar de
# novo depois de um problema — o ./setup.sh cadastrava num accounts.conf e
# o ./play.sh lia outro. O sintoma e justamente o menu anunciar
# "Contas cadastradas: 0" enquanto o ./play.sh sobe as contas normalmente.
#
# Agora, se o arquivo local nao existir, os lugares conhecidos sao
# procurados antes de desistir — e o caminho em uso passa a ser SEMPRE
# impresso, para o numero nunca mais ficar sem explicacao.
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

# --restart / -r : derruba e sobe tudo de novo. Sem ele, as contas que ja
# estao rodando sao preservadas e o play.sh so se acopla ao painel.
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

GREEN='\033[32m'
GOLD='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[01;36m'
YELLOW='\033[1;33m'
RESET='\033[00m'

mkdir -p "$STATUS_DIR"

# PID do proprio orquestrador. Sem isto o stop.sh nao conseguia
# encerrar o monitor: ele roda como "./play.sh" (caminho relativo) e
# um pgrep por caminho absoluto nao casa. Cada ./play.sh deixava mais
# um monitor vivo, todos supervisionando as mesmas contas.
echo "$$" > "$STATUS_DIR/orchestrator.pid"
chmod 700 "$HOME/.twm" 2>/dev/null
[ -f "$ACCOUNTS_FILE" ] && chmod 600 "$ACCOUNTS_FILE" 2>/dev/null

chmod +x "$TWMDIR/worker.sh" "$TWMDIR/twm.sh" 2>/dev/null

# setsid torna o worker lider de grupo de processos. Sem isso, matar o worker
# deixa o twm.sh filho ORFAO e vivo, e ao rodar ./play.sh de novo a conta
# passa a ter duas sessoes simultaneas disputando o mesmo cookie.
if command -v setsid > /dev/null 2>&1; then
    SETSID="setsid"
else
    SETSID=""
fi

# ============================================================
#  SOMENTE SERVIDOR BR (furiadetitas.net)
#  O suporte aos outros 12 servidores foi removido a pedido.
#  O campo de servidor continua no accounts.conf (sempre "1")
#  para nao quebrar cadastros existentes.
# ============================================================
server_url()    { case "$1" in 1) echo "furiadetitas.net" ;; esac; }
server_tag()    { case "$1" in 1) echo "BR" ;; esac; }
server_scheme() { echo "https"; }

# Remove CR (accounts.conf editado no Windows) e caracteres de controle.
clean_field() {
    printf '%s' "$1" | tr -d '\r' | tr -d '\000-\037'
}

# Mata o worker E seus filhos, mas so se o PID ainda for realmente um worker.
#
# CORRECAO: antes era "kill -0 PID && kill -9 PID". O kill -0 verifica
# EXISTENCIA, nao IDENTIDADE: com o PID reciclado pelo kernel, o kill -9
# acertava um processo inocente. Alem disso matava so o pai, deixando o
# twm.sh filho orfao e ativo.
kill_worker_tree() {
    kw_pid="$1"
    [ -n "$kw_pid" ] || return 1
    case "$kw_pid" in *[!0-9]*) return 1 ;; esac

    # worker.sh OU twm.sh: apos o exec do worker.sh o cmdline e o do twm.sh.
    if [ -r "/proc/$kw_pid/cmdline" ]; then
        tr '\0' ' ' < "/proc/$kw_pid/cmdline" 2>/dev/null \
            | grep -qE 'worker\.sh|twm\.sh' || return 1
    else
        kill -0 "$kw_pid" 2>/dev/null || return 1
    fi

    kill -TERM "-$kw_pid" 2>/dev/null || kill -TERM "$kw_pid" 2>/dev/null
    sleep 2
    if kill -0 "$kw_pid" 2>/dev/null; then
        kill -KILL "-$kw_pid" 2>/dev/null || kill -KILL "$kw_pid" 2>/dev/null
    fi
    return 0
}

# O PID ainda e um worker deste bot, vivo?
#
# Confere a IDENTIDADE pelo cmdline, nao so a existencia: o kernel recicla
# PIDs, e um "kill -0" que acerta um processo qualquer do usuario faria o
# play.sh achar que a conta esta no ar quando nao esta.
worker_vivo() {
    wv_pid="$1"
    [ -n "$wv_pid" ] || return 1
    case "$wv_pid" in *[!0-9]*) return 1 ;; esac
    kill -0 "$wv_pid" 2>/dev/null || return 1
    # Aceita worker.sh E twm.sh: o worker.sh faz exec do twm.sh, entao
    # depois da troca o PID e o mesmo mas o cmdline e o do twm.sh.
    if [ -r "/proc/$wv_pid/cmdline" ]; then
        tr '\0' ' ' < "/proc/$wv_pid/cmdline" 2>/dev/null \
            | grep -qE 'worker\.sh|twm\.sh' || return 1
    fi
    return 0
}

# Sobe o worker de uma conta.  $1=srv  $2=usuario  $3=credencial (opcional)
# Retorna 0 = subiu, 1 = falhou, 2 = ja estava rodando e foi mantida.
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

    # CORRECAO (seguranca): a credencial era passada como argv[3] do
    # worker.sh e ficava legivel em /proc/PID/cmdline durante toda a vida do
    # processo (o worker roda para sempre). Agora e gravada aqui, em arquivo
    # modo 600, e o worker recebe apenas o caminho do diretorio da conta.
    if [ -n "$lw_enc" ]; then
        printf '%s\n' "$lw_enc" > "$lw_dir/cript_file"
        chmod 600 "$lw_dir/cript_file"
    fi

    if [ ! -s "$lw_dir/cript_file" ]; then
        printf "   sem credencial para %s - pulando\n" "$lw_id"
        return 1
    fi

    # NAO derruba um worker que esta vivo e saudavel.
    #
    # CORRECAO (este era o defeito): o launch_worker matava incondicionalmente
    # o worker daquela conta antes de subir outro. Como o painel so existia
    # dentro do play.sh, a UNICA forma de voltar a ver as contas depois que o
    # Termux era fechado (ou morto com SIGKILL) era rodar ./play.sh de novo —
    # e isso derrubava as 6 contas que estavam jogando normalmente, forcando
    # 6 logins simultaneos do mesmo IP. O servidor recusa essa rajada com a
    # mesma mensagem de "senha incorreta", e as contas caiam no backoff de
    # 30s ate 15min: painel inteiro em [..], tudo em "-", "0 online".
    #
    # Ou seja: o ato de olhar quebrava o que estava funcionando.
    #
    # Agora o worker vivo e MANTIDO e o play.sh apenas se acopla ao painel.
    # Para forcar o reinicio de tudo: ./play.sh --restart
    if [ -f "$lw_pidf" ]; then
        lw_old=$(cat "$lw_pidf" 2>/dev/null)
        if [ "$FORCE_RESTART" != "1" ] && worker_vivo "$lw_old"; then
            printf "   ${GREEN}ja rodando${RESET} (PID %s) - mantida\n" "$lw_old"
            unset lw_old
            return 2
        fi
        kill_worker_tree "$lw_old"
        rm -f "$lw_pidf"
        unset lw_old
    fi

    # Limpa o modo salvo para que a flag de linha de comando vença num
    # inicio limpo (o cave.sh regrava em runtime se trocar de modo).
    rm -f "$lw_dir/runmode_file"

    echo "starting" > "$lw_status"

    TOYBOX="$TOYBOX" _TOYBOX_RUNNING="1" \
    nohup $SETSID "$TOYBOX" "$TWMDIR/worker.sh" \
        "$lw_srv" "$lw_user" "$lw_tag" \
        "${lw_scheme}://${lw_host}" "$lw_dir" "$lw_status" "$RUN" \
        < /dev/null >> "$lw_log" 2>&1 &

    return 0
}

if [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ]; then
    printf "${RED}Nenhuma conta cadastrada.${RESET}\n"
    printf "Execute: ${GOLD}./setup.sh${RESET}\n"
    exit 1
fi

# CORRECAO: era "grep -c '|' ... || echo 0". Quando o grep nao acha nada ele
# imprime 0 E sai com status 1, entao o "|| echo 0" acrescentava um segundo 0
# e a variavel virava "0\n0". Alem disso contava linhas comentadas.
total=$(grep -c -E '^[0-9]+\|' "$ACCOUNTS_FILE" 2>/dev/null)
case "$total" in *[!0-9]*) total=0 ;; esac
[ -z "$total" ] && total=0

printf "${CYAN}TWM Multi-contas - %s conta(s) [%s]${RESET}\n" "$total" "$TOYBOX"
printf "${GOLD}Contas:${RESET} %s\n" "$ACCOUNTS_FILE"
printf "${GOLD}Mod Author:${RESET} Stephenn Curry\n\n"

# Android 12+ derruba a sessao inteira com SIGKILL.
#
# O sistema classifica como "processo fantasma" todo filho do Termux que
# ele nao reconhece e, passando de 32 simultaneos, mata sem aviso — o
# "[Process completed (signal 9)]" no meio do lancamento das contas. O
# consumo por conta foi cortado (veja info.sh: fetch_page e time_exit nao
# gastam mais um fork de "sleep" por segundo de espera), mas com muitas
# contas ainda vale desligar o monitor.
# Limpa workers orfaos de execucoes anteriores.
#
# Os workers sobem com nohup+setsid: quando o Android mata a sessao com
# SIGKILL, eles SOBREVIVEM. A cada nova tentativa sobra mais uma leva, e
# esses processos contam para o limite de 32 do Android 12 — o bot vai
# ficando cada vez mais perto do teto sem ninguem perceber. Aqui morrem os
# que nao correspondem a nenhuma conta em execucao registrada.
limpa_orfaos() {
    _lo_n=0
    for _lo_p in /proc/[0-9]*; do
        _lo_pid=${_lo_p#/proc/}
        case "$_lo_pid" in *[!0-9]*) continue ;; esac
        [ "$_lo_pid" = "$$" ] && continue
        [ -r "$_lo_p/cmdline" ] || continue
        case "$(tr '\0' ' ' < "$_lo_p/cmdline" 2>/dev/null)" in
            *"$TWMDIR/worker.sh"*|*"$TWMDIR/twm.sh"*) ;;
            *) continue ;;
        esac
        # Esta entre os PIDs que os arquivos de estado conhecem?
        _lo_conhecido=0
        for _lo_f in "$STATUS_DIR"/*.pid; do
            [ -f "$_lo_f" ] || continue
            [ "$(cat "$_lo_f" 2>/dev/null)" = "$_lo_pid" ] && _lo_conhecido=1 && break
        done
        [ "$_lo_conhecido" = 1 ] && continue
        kill -TERM "$_lo_pid" 2>/dev/null
        _lo_n=$((_lo_n + 1))
    done
    [ "$_lo_n" -gt 0 ] && \
        printf "${GOLD}%s processo(s) orfao(s) de execucoes anteriores encerrado(s).${RESET}\n\n" "$_lo_n"
    unset _lo_n _lo_p _lo_pid _lo_conhecido _lo_f
}
limpa_orfaos

# Modo economico de processos.
#
# O Android 12+ mata a sessao inteira acima de 32 processos filhos. Medido
# num Moto E22 (Android 12): o Termux marcava 26 processos com apenas duas
# contas no ar — com seis nao havia como caber. Acima de 3 contas o
# espacamento entre requisicoes passa a ser o proprio tempo de rede, o que
# dispensa um "sleep" parado por conta.
if [ -d /data/data/com.termux ] && [ "$total" -gt 3 ] && [ -z "$TWM_PACING" ]; then
    TWM_PACING=0
    export TWM_PACING
fi

if [ -d /data/data/com.termux ] && [ "$total" -gt 3 ]; then
    printf "${YELLOW}AVISO (Android 12+): o sistema pode matar o bot com SIGKILL (signal 9).${RESET}\n"
    printf "  Deixe o Termux em ${CYAN}Bateria > Sem restricoes${RESET} e, com o celular no PC:\n"
    printf "  ${CYAN}adb shell settings put global settings_enable_monitor_phantom_procs false${RESET}\n\n"
fi

n=0
n_kept=0

while IFS='|' read -r srv user encoded <&3; do
    srv=$(clean_field "$srv")
    user=$(clean_field "$user")
    encoded=$(clean_field "$encoded")

    case "$srv" in
        ''|\#*) continue ;;
        *[!0-9]*) continue ;;
    esac
    [ -z "$user" ] || [ -z "$encoded" ] && continue
    case "$user" in
        */*) printf "${RED}Nome invalido (contem barra): %s${RESET}\n" "$user"; continue ;;
    esac

    tag=$(server_tag "$srv")
    if [ -z "$tag" ]; then
        printf "${RED}Servidor desconhecido: %s - pulando${RESET}\n" "$srv"
        continue
    fi

    n=$((n + 1))
    acc_id="${tag}_${user}"
    log_file="$HOME/.twm/${acc_id}/twm.log"
    pid_file="$STATUS_DIR/${acc_id}.pid"

    printf "${GOLD}[%d/%d]${RESET} [%s] %s\n" "$n" "$total" "$tag" "$user"
    if [ "$(server_scheme "$srv")" = "http" ]; then
        printf "   ${YELLOW}AVISO: este servidor nao suporta HTTPS - senha em texto claro${RESET}\n"
    fi

    launch_worker "$srv" "$user" "$encoded"
    case "$?" in
        1) continue ;;
        2) n_kept=$((n_kept + 1)); continue ;;   # ja rodava, nao mexeu
    esac

    pid=""
    _w=0
    # 5s bastam: o worker grava o PID como primeira acao. Com 20 contas,
    # o limite antigo de 10s somava ate 200s de espera no pior caso.
    while [ -z "$pid" ] && [ "$_w" -lt 5 ]; do
        sleep 1
        pid=$(cat "$pid_file" 2>/dev/null)
        _w=$((_w + 1))
    done
    printf "   PID: %s | Log: %s\n" "${pid:-FALHOU}" "$log_file"
    [ -z "$pid" ] && printf "   ${RED}AVISO: worker nao iniciou. Verifique %s${RESET}\n" "$log_file"

    # Espacamento entre contas. Sem isso todas autenticavam no mesmo segundo,
    # do mesmo IP: o rate-limit derrubava quase todas e o backoff exponencial
    # (ate 300s) mantinha as contas sincronizadas reincidindo em bloco.
    if [ "$n" -lt "$total" ]; then
        # Escalonamento adaptativo. O valor fixo de 5-20s por conta
        # levaria ate 6,7 minutos so para subir 20 contas. Agora a
        # janela total fica em torno de 3 minutos, qualquer que seja o
        # numero de contas, com um piso de 3s para nao autenticar todas
        # no mesmo instante (o servidor limita login por IP).
        _base=$(( 180 / total ))
        [ "$_base" -lt 3 ] && _base=3
        [ "$_base" -gt 15 ] && _base=15
        _jit=$(( _base + (n + $$) % 4 ))
        printf "   aguardando %ss antes da proxima conta\n" "$_jit"
        sleep "$_jit"
    fi

done 3< "$ACCOUNTS_FILE"

if [ "$n" -eq 0 ]; then
    printf "${RED}Nenhuma conta valida encontrada em accounts.conf${RESET}\n"
    printf "Verifique o formato: srv|usuario|credencial_base64\n"
    exit 1
fi

printf "\n${GREEN}%s conta(s): %s iniciada(s), %s ja rodando.${RESET}\n\n" \
    "$n" "$((n - n_kept))" "$n_kept"
printf "Ver o painel:  ${CYAN}./status.sh${RESET}  (nao mexe nas contas)\n"
printf "Log de conta:  ${CYAN}tail -f ~/.twm/BR_NomeConta/twm.log${RESET}\n"
printf "Reiniciar:     ${CYAN}./play.sh --restart${RESET}\n"
printf "Parar tudo:    ${CYAN}./stop.sh${RESET}\n\n"

# ============================================================
#  PAINEL
#  Mora no panel.sh, compartilhado com o status.sh. Aqui ele
#  roda em modo supervisor: relanca worker que morrer.
# ============================================================
. "$TWMDIR/panel.sh"
PANEL_SUPERVISE=1
[ "$HAS_TTY" = 0 ] && echo "[monitor] supervisionando $n conta(s); painel oculto (sem terminal)"
painel_loop
