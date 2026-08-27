#!/bin/sh
# pause.sh - Pausa ou retoma o bot SEM deslogar as contas
#
# Pausar apenas faz os workers pararem de agir. Os processos continuam
# vivos e a sessao no jogo permanece valida — ao retomar, nao ha novo
# login. Para encerrar de vez, use ./stop.sh
#
# Uso:
#   ./pause.sh              alterna: pausa se estiver rodando, retoma se pausado
#   ./pause.sh on           pausa todas as contas
#   ./pause.sh off          retoma todas as contas
#   ./pause.sh on  NOME     pausa somente a conta NOME
#   ./pause.sh off NOME     retoma somente a conta NOME
#   ./pause.sh status       mostra o estado atual

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
TWMHOME="$HOME/.twm"
FLAG="$TWMHOME/PAUSED"

G='\033[1;32m'; Y='\033[1;33m'; C='\033[1;36m'; D='\033[2m'; N='\033[0m'

[ -d "$TWMHOME" ] || { printf "Bot nao instalado ou nunca executado.\n"; exit 1; }

acc_flag() {
    for _d in "$TWMHOME"/BR_*/; do
        [ -d "$_d" ] || continue
        case "$(basename "$_d")" in
            *"$1"*) printf '%s' "${_d%/}/PAUSED"; return 0 ;;
        esac
    done
    return 1
}

mostra() {
    printf "${C}Estado:${N}\n"
    if [ -f "$FLAG" ]; then
        printf "  ${Y}PAUSADO${N} (todas as contas)\n"
    else
        printf "  ${G}ATIVO${N}\n"
    fi
    for _d in "$TWMHOME"/BR_*/; do
        [ -d "$_d" ] || continue
        _n=$(basename "$_d")
        if [ -f "${_d}PAUSED" ]; then
            printf "  ${Y}pausada${N}  %s\n" "$_n"
        else
            _s=$(cat "$TWMHOME/status/${_n}.status" 2>/dev/null || echo "?")
            printf "  ${D}%-9s${N} %s\n" "$_s" "$_n"
        fi
    done
}

case "${1:-toggle}" in
    on)
        if [ -n "$2" ]; then
            _f=$(acc_flag "$2") || { printf "Conta nao encontrada: %s\n" "$2"; exit 1; }
            : > "$_f"
            printf "${Y}Conta pausada:${N} %s\n" "$2"
        else
            : > "$FLAG"
            printf "${Y}Bot pausado.${N} As contas seguem logadas.\n"
        fi
        ;;
    off)
        if [ -n "$2" ]; then
            _f=$(acc_flag "$2") || { printf "Conta nao encontrada: %s\n" "$2"; exit 1; }
            rm -f "$_f"
            printf "${G}Conta retomada:${N} %s\n" "$2"
        else
            rm -f "$FLAG"
            printf "${G}Bot retomado.${N}\n"
        fi
        ;;
    status)
        mostra
        ;;
    toggle)
        if [ -f "$FLAG" ]; then
            rm -f "$FLAG"
            printf "${G}Bot retomado.${N}\n"
        else
            : > "$FLAG"
            printf "${Y}Bot pausado.${N} As contas seguem logadas.\n"
        fi
        ;;
    *)
        printf "Uso: ./pause.sh [on|off|status] [conta]\n"
        exit 1
        ;;
esac

printf "\n"
mostra
printf "\n${D}Retomar: ./pause.sh off   |   Encerrar de vez: ./stop.sh${N}\n"
