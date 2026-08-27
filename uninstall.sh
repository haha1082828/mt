#!/bin/sh
# uninstall.sh - Remove COMPLETAMENTE o TWM do sistema
#
# Apaga: processos, o servico do systemd, os dados das contas (~/.twm),
# instalacoes antigas e o proprio diretorio do bot.
#
# ATENCAO: isto apaga o accounts.conf. As contas cadastradas serao perdidas
# e voce tera de cadastra-las de novo. As contas no JOGO nao sao afetadas.

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)

R='\033[0;31m'; G='\033[32m'; Y='\033[1;33m'; C='\033[01;36m'; N='\033[00m'

printf "${C}=== Desinstalacao do TWM ===${N}\n\n"
printf "Sera removido:\n"

_ach=0
for p in "$TWMDIR" "$HOME/.twm" "$HOME/twm" "$HOME/twm_ANTIGO_NAO_USAR" "$HOME/.multcf"; do
    if [ -e "$p" ]; then
        printf "  %-38s %s\n" "$p" "$(du -sh "$p" 2>/dev/null | cut -f1)"
        _ach=1
    fi
done
[ -f /etc/systemd/system/twm.service ] && { printf "  %-38s (servico)\n" "/etc/systemd/system/twm.service"; _ach=1; }
[ "$_ach" = 0 ] && printf "  (nada encontrado)\n"

_n=0
[ -s "$TWMDIR/accounts.conf" ] && _n=$(grep -cE '^[0-9]+\|' "$TWMDIR/accounts.conf" 2>/dev/null)
if [ "${_n:-0}" -gt 0 ]; then
    printf "\n${Y}Voce tem %s conta(s) cadastrada(s). As credenciais serao apagadas.${N}\n" "$_n"
    printf "${Y}Suas contas no jogo NAO sao afetadas — so o cadastro local.${N}\n"
fi

printf "\n${R}Esta acao nao pode ser desfeita.${N}\n"
printf "Digite ${C}REMOVER${N} para confirmar: "
read -r _ok
[ "$_ok" = "REMOVER" ] || { printf "\nCancelado. Nada foi alterado.\n"; exit 1; }

printf "\n"

# 1. servico do systemd
if [ -f /etc/systemd/system/twm.service ]; then
    printf "Removendo servico do systemd (pede sudo)...\n"
    sudo systemctl stop twm 2>/dev/null
    sudo systemctl disable twm 2>/dev/null
    sudo rm -f /etc/systemd/system/twm.service
    sudo systemctl daemon-reload 2>/dev/null
    printf "  ${G}servico removido${N}\n"
fi

# 2. processos
printf "Encerrando processos...\n"
[ -x "$TWMDIR/stop.sh" ] && sh "$TWMDIR/stop.sh" > /dev/null 2>&1
for pat in "$TWMDIR/play.sh" "$TWMDIR/worker.sh" "$TWMDIR/twm.sh" "$HOME/twm/twm.sh"; do
    pkill -TERM -f "$pat" 2>/dev/null
done
sleep 2
for pat in "$TWMDIR/play.sh" "$TWMDIR/worker.sh" "$TWMDIR/twm.sh" "$HOME/twm/twm.sh"; do
    pkill -KILL -f "$pat" 2>/dev/null
done
printf "  ${G}processos encerrados${N}\n"

# 3. wake lock (Termux)
termux-wake-unlock 2>/dev/null

# 4. dados e instalacoes
printf "Removendo arquivos...\n"
rm -rf "$HOME/.twm" "$HOME/twm" "$HOME/twm_ANTIGO_NAO_USAR" "$HOME/.multcf"
rm -f /tmp/play_out.log /tmp/twm_* /tmp/diag_* 2>/dev/null
printf "  ${G}dados removidos${N}\n"

# 5. o proprio diretorio, por ultimo
printf "Removendo %s...\n" "$TWMDIR"
cd "$HOME" || cd /
rm -rf "$TWMDIR"

printf "\n${G}TWM removido por completo.${N}\n"
printf "O sistema esta como antes da instalacao.\n\n"
printf "Os pacotes instalados (git, curl, jq) foram mantidos —\n"
printf "sao utilitarios comuns. Para remover tambem:\n"
printf "  ${C}sudo apt remove --purge jq${N}          (Debian/Ubuntu)\n"
printf "  ${C}pkg uninstall jq${N}                    (Termux)\n"
