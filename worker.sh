#!/bin/sh
# worker.sh - Loop de uma conta individual
# Recebe TOYBOX e _TOYBOX_RUNNING via ambiente do play.sh

TOYBOX="${TOYBOX:-sh}"

# CORRECAO (seguranca): a credencial base64 chegava como argv[3] e ficava
# legivel em /proc/PID/cmdline durante toda a vida do worker (que roda para
# sempre). O "unset TWM_ENCODED" nao ajudava: ele limpa a variavel, nao o
# argv do kernel. Agora o play.sh grava a credencial em cript_file (modo 600)
# e o worker recebe apenas o caminho do diretorio da conta.
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

# Rotaciona o log da conta.
#
# CORRECAO: o play.sh redireciona a saida do worker com ">>" e nada limitava
# o crescimento. Com o busy-loop do crono.sh o twm.log chegava a encher o
# armazenamento do aparelho, e o Android passava a matar o processo — o que
# aparentava "bug aleatorio". O busy-loop foi corrigido; isto e a rede de
# protecao para qualquer coisa que volte a gerar log em excesso.
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

# SUBSTITUI este processo pelo twm.sh, em vez de ficar parado esperando por
# ele num laco.
#
# CORRECAO (SIGKILL / "signal 9" no Android 12): o worker.sh existia so
# para relancar o twm.sh quando ele saisse — um processo permanente POR
# CONTA que passava a vida bloqueado. Com 6 contas sao 6 processos parados,
# e o Android 12 mata a sessao inteira acima de 32 processos.
#
# Medido no aparelho do relato (Moto E22, Android 12, limite 32): o Termux
# ja marcava 26 processos com apenas DUAS contas no ar. Com seis nao havia
# como caber.
#
# Com o exec o twm.sh herda este PID, entao o arquivo .pid segue valido e o
# stop.sh continua encontrando a conta. Quem relanca agora e o play.sh, que
# ja verifica a cada volta do painel se o PID morreu — antes eram 15s de
# espera aqui, agora sao no maximo 20s la, sem custar um processo parado.
exec "$TOYBOX" "$TWMDIR/twm.sh" "$RUN" < /dev/null
