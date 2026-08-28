#!/bin/sh
# agora.sh - Roda a varredura de atividades AGORA, sem esperar o ciclo
#
# Equivale ao ENTER do bot de conta unica: la o worker lia o teclado com
# prazo e qualquer tecla quebrava a espera. Aqui os workers sobem com
# "< /dev/null" (nohup+setsid), para sobreviverem ao fechamento do Termux,
# entao nenhum ENTER chega neles — e com 15 contas nao ha um teclado para
# cada uma. O pedido passa a ser um arquivo, do mesmo jeito que a pausa.
#
# O worker atende em ate ~5 segundos, libera os portoes das atividades
# (arena, carreira, campanha, caverna, cabana do sabio, liga, troca,
# missoes do cla e eventos) e faz o que estiver disponivel no jogo.
#
# Uso:
#   ./agora.sh            todas as contas
#   ./agora.sh NOME       somente a conta cujo nome contenha NOME
#   ./agora.sh status     mostra se ha pedido pendente

umask 077

TWMHOME="$HOME/.twm"

G='\033[1;32m'; Y='\033[1;33m'; C='\033[1;36m'; D='\033[2m'; N='\033[0m'

[ -d "$TWMHOME" ] || { printf "Bot nao instalado ou nunca executado.\n"; exit 1; }

case "${1:-}" in
    status)
        _achou=0
        for _d in "$TWMHOME"/BR_*/; do
            [ -d "$_d" ] || continue
            if [ -f "${_d}RUNNOW" ]; then
                printf "  ${Y}pendente:${N} %s\n" "$(basename "${_d%/}")"
                _achou=1
            fi
        done
        [ "$_achou" = 0 ] && printf "${D}Nenhum pedido pendente.${N}\n"
        exit 0
        ;;
    -h|--help)
        printf "uso: ./agora.sh [NOME|status]\n"
        printf "  (sem argumento)  varredura em todas as contas\n"
        printf "  NOME             somente a conta com esse nome\n"
        printf "  status           mostra pedidos pendentes\n"
        exit 0
        ;;
esac

if [ -n "${1:-}" ]; then
    # Uma conta so.
    _alvo=""
    for _d in "$TWMHOME"/BR_*/; do
        [ -d "$_d" ] || continue
        case "$(basename "${_d%/}")" in
            *"$1"*) _alvo="${_d%/}" ; break ;;
        esac
    done
    if [ -z "$_alvo" ]; then
        printf "Conta nao encontrada: %s\n" "$1"
        printf "Contas disponiveis:\n"
        for _d in "$TWMHOME"/BR_*/; do
            [ -d "$_d" ] && printf "  %s\n" "$(basename "${_d%/}")"
        done
        exit 1
    fi
    : > "$_alvo/RUNNOW"
    printf "${G}Varredura pedida${N} para %s\n" "$(basename "$_alvo")"
    printf "${D}O worker atende em ate ~5s. Acompanhe:${N} ${C}tail -f %s/twm.log${N}\n" "$_alvo"
    exit 0
fi

# Todas as contas.
#
# Um arquivo por conta, nunca um global: um sinal global so seria apagado
# por um dos workers, e os demais continuariam a encontra-lo, disparando
# varredura em laco. Cada worker apaga o seu.
_n=0
for _d in "$TWMHOME"/BR_*/; do
    [ -d "$_d" ] || continue
    : > "${_d}RUNNOW"
    _n=$((_n + 1))
done

if [ "$_n" = 0 ]; then
    printf "Nenhuma conta encontrada em %s\n" "$TWMHOME"
    exit 1
fi

printf "${G}Varredura pedida${N} para %s conta(s)\n" "$_n"
printf "${D}Os workers atendem em ate ~5s. Acompanhe:${N} ${C}./status.sh${N}\n"
