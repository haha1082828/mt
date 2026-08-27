#!/bin/sh
# logout.sh - Encerra a sessao de todas as contas no servidor
#
# Diferente do stop.sh, que apenas para os processos, este script chama
# /?exit para cada conta — o mesmo "Sair do jogo" da pagina de
# configuracoes — e so entao apaga o cookie local. Verificado no jogo:
# antes do /?exit a sessao responde como logada, depois nao.
#
# Uso:  ./logout.sh          pede confirmacao
#       ./logout.sh -y       sem perguntar

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
TWMHOME="$HOME/.twm"

G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; C='\033[1;36m'; D='\033[2m'; N='\033[0m'
UA="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"

[ -d "$TWMHOME" ] || { printf "Nenhuma conta encontrada em %s\n" "$TWMHOME"; exit 1; }

_n=0
for _d in "$TWMHOME"/BR_*/; do
    [ -s "${_d}cookie.txt" ] && _n=$((_n + 1))
done

if [ "$_n" -eq 0 ]; then
    printf "Nenhuma sessao ativa para encerrar.\n"
    exit 0
fi

printf "${C}Encerrar a sessao de %s conta(s) no servidor.${N}\n" "$_n"
printf "${D}As contas continuam cadastradas; o bot reconecta no proximo inicio.${N}\n\n"

if [ "$1" != "-y" ]; then
    printf "Continuar? (y/n): "
    read -r _ok
    case "$_ok" in y|Y) ;; *) printf "Cancelado.\n"; exit 1 ;; esac
    printf "\n"
fi

# Para o bot antes: sem isso um worker reconecta no meio do processo.
if [ -x "$TWMDIR/stop.sh" ]; then
    printf "Parando o bot...\n"
    sh "$TWMDIR/stop.sh" > /dev/null 2>&1
    sleep 2
fi

_ok_n=0
for _d in "$TWMHOME"/BR_*/; do
    [ -d "$_d" ] || continue
    _ck="${_d}cookie.txt"
    _nome=$(basename "$_d" | cut -c4-)
    [ -s "$_ck" ] || { printf "  ${D}%-22s sem sessao${N}\n" "$_nome"; continue; }

    curl -s -L -A "$UA" -b "$_ck" -c "$_ck" --max-time 25 \
         "https://furiadetitas.net/?exit" -o /dev/null 2>/dev/null

    # Confere se saiu mesmo
    if curl -s -L -A "$UA" -b "$_ck" --max-time 20 \
        "https://furiadetitas.net/user" 2>/dev/null | grep -q "icon/level"; then
        printf "  ${Y}%-22s ainda logada${N}\n" "$_nome"
    else
        printf "  ${G}%-22s deslogada${N}\n" "$_nome"
        _ok_n=$((_ok_n + 1))
    fi

    rm -f "$_ck"
    rm -f "${_d}stats" "${_d}pagina" "${_d}msg_file" 2>/dev/null
done

printf "\n${G}%s de %s sessao(oes) encerrada(s).${N}\n" "$_ok_n" "$_n"
printf "${D}Cookies removidos. Para voltar: ./play.sh${N}\n"
