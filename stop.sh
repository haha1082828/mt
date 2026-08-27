#!/bin/sh
# stop.sh - Para todos os workers do TWM Multi-contas

_dir=`dirname "$0"`
TWMDIR=`cd "$_dir" && pwd`
unset _dir

STATUS_DIR="$HOME/.twm/status"

GREEN='\033[32m'
RED='\033[0;31m'
GOLD='\033[0;33m'
RESET='\033[00m'

printf "${GOLD}Parando todos os workers TWM...${RESET}\n\n"

stopped=0

for pid_file in "$STATUS_DIR"/*.pid; do
    [ -f "$pid_file" ] || continue

    acc_id=`basename "$pid_file" .pid`
    # orchestrator.pid e o PID do proprio play.sh, nao de uma conta:
    # sem isto ele virava uma linha "orchestrator  stopped" no painel.
    [ "$acc_id" = "orchestrator" ] && continue
    pid=`cat "$pid_file" 2>/dev/null`

    case "$pid" in
        ''|*[!0-9]*)
            printf "  ${GOLD}[PID INVALIDO]${RESET} %s\n" "$acc_id"
            rm -f "$pid_file"
            continue
            ;;
    esac

    # CORRECAO: antes bastava "kill -0 $pid" para disparar o kill. O kill -0
    # verifica EXISTENCIA, nao IDENTIDADE — com o PID reciclado pelo kernel,
    # o kill -9 acertava um processo inocente do usuario. Agora confere o
    # cmdline antes de sinalizar.
    ours=0
    if [ -r "/proc/$pid/cmdline" ]; then
        tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null \
            | grep -qE 'worker\.sh|twm\.sh' && ours=1
    elif kill -0 "$pid" 2>/dev/null; then
        ours=1
    fi

    if [ "$ours" -eq 1 ]; then
        # Sinaliza o GRUPO de processos: o worker foi lancado com setsid,
        # entao isso alcanca tambem o twm.sh filho. Antes so o pai morria e
        # o filho continuava rodando orfao, mantendo a sessao do jogo ativa.
        kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
        fi
        echo "stopped" > "$STATUS_DIR/${acc_id}.status"
        printf "  ${GREEN}[OK]${RESET} %s (PID %s)\n" "$acc_id" "$pid"
        stopped=$((stopped + 1))
    else
        echo "stopped" > "$STATUS_DIR/${acc_id}.status"
        printf "  ${GOLD}[JA PARADO]${RESET} %s\n" "$acc_id"
    fi

    rm -f "$pid_file"
done

# CORRECAO: o stop.sh encerrava os workers mas NAO o proprio play.sh,
# que continua rodando como monitor e relancando workers. Cada ./play.sh
# deixava mais um monitor vivo, e varios supervisores concorriam pelas
# mesmas contas. Agora o orquestrador tambem e encerrado.
orch_pid=$(cat "$STATUS_DIR/orchestrator.pid" 2>/dev/null)
case "$orch_pid" in
    ""|*[!0-9]*) ;;
    *) kill -TERM "$orch_pid" 2>/dev/null ;;
esac
rm -f "$STATUS_DIR/orchestrator.pid"

# Rede de seguranca: qualquer play.sh cujo diretorio de trabalho seja
# o do bot. Comparar o cwd evita acertar um play.sh de outro projeto.
for p in $(pgrep -f "play\.sh" 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    _cwd=$(readlink -f "/proc/$p/cwd" 2>/dev/null)
    [ "$_cwd" = "$TWMDIR" ] || continue
    kill -TERM "$p" 2>/dev/null
done
sleep 1
for p in $(pgrep -f "play\.sh" 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    _cwd=$(readlink -f "/proc/$p/cwd" 2>/dev/null)
    [ "$_cwd" = "$TWMDIR" ] && kill -KILL "$p" 2>/dev/null
done

# Rede de seguranca para orfaos de execucoes antigas (antes do setsid).
pkill -f "$TWMDIR/twm.sh" 2>/dev/null
pkill -f "$TWMDIR/worker.sh" 2>/dev/null

printf "\n${GREEN}%s worker(s) encerrado(s).${RESET}\n" "$stopped"
termux-wake-unlock 2>/dev/null
