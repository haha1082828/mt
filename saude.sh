#!/bin/sh
# saude.sh - Relatorio unico do estado de todas as contas
#
# Feito para quem NAO esta com o aparelho: uma execucao imprime, numa tela
# so, tudo que costuma ser perguntado num diagnostico remoto. Basta um print
# da saida.
#
# Somente leitura: nao toca em processo, nao faz login, nao usa a rede.
#
# Uso:  ./saude.sh

umask 077
TWMHOME="$HOME/.twm"
STATUS_DIR="$TWMHOME/status"

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" 2>/dev/null && pwd -P) || TWMDIR="."
unset _dir

G='\033[1;32m'; Y='\033[1;33m'; R='\033[0;31m'; C='\033[1;36m'; D='\033[2m'; N='\033[0m'

[ -d "$TWMHOME" ] || { printf "${R}Bot nunca executado neste aparelho.${N}\n"; exit 1; }

AGORA=$(date +%s)

idade() {   # $1 = epoch -> "Nm" ou "-"
    case "$1" in ''|*[!0-9]*) printf '%s' "-"; return ;; esac
    printf '%sm' "$(( (AGORA - $1) / 60 ))"
}

# Data de modificacao de um arquivo, em epoch. Vazio se nao der para ler.
# O coreutils usa "stat -c"; o toybox/busybox do Termux e do iSH aceitam os
# dois, mas nem toda versao traz o stat — dai o "date -r" como reserva.
mtime() {
    _mt=$(stat -c %Y "$1" 2>/dev/null)
    case "$_mt" in ''|*[!0-9]*) _mt=$(date -r "$1" +%s 2>/dev/null) ;; esac
    case "$_mt" in ''|*[!0-9]*) _mt="" ;; esac
    printf '%s' "$_mt"
    unset _mt
}

printf "${C}=== SAUDE DAS CONTAS ===${N}  %s\n" "$(date '+%d/%m %H:%M')"

# --- ambiente
printf "\n${C}Aparelho${N}\n"
printf "  memoria livre: %s\n" "$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{printf "%d MB", $2/1024}')"
_pb=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
printf "  processos totais: %s\n" "$_pb"
_pw=0
for _p in /proc/[0-9]*; do
    [ -r "$_p/cmdline" ] || continue
    tr '\0' ' ' < "$_p/cmdline" 2>/dev/null | grep -qE 'worker\.sh|twm\.sh' && _pw=$((_pw + 1))
done
printf "  processos do bot: %s\n" "$_pw"
[ "$_pw" -gt 28 ] && printf "  ${Y}perto do limite de 32 do Android 12+${N}\n"

# --- versao do codigo em disco
#
# POR QUE ISTO EXISTE
#
# Depois de um "git pull" os arquivos no disco sao novos, mas as contas que
# ja estavam no ar seguem rodando o codigo ANTIGO: o worker.sh le os .sh uma
# unica vez, no arranque, e nunca mais. Sem reiniciar, qualquer correcao
# recem-baixada simplesmente nao existe para elas.
#
# Isso enganava o proprio relatorio: campos gravados por codigo novo
# apareciam vazios em TODAS as contas e o resumo acusava falha geral, quando
# o problema era so nao ter reiniciado.
_code_ts=0
for _f in "$TWMDIR"/*.sh; do
    [ -f "$_f" ] || continue
    _t=$(mtime "$_f")
    case "$_t" in ''|*[!0-9]*) continue ;; esac
    [ "$_t" -gt "$_code_ts" ] && _code_ts=$_t
done
if [ "$_code_ts" -gt 0 ]; then
    printf "  codigo atualizado ha: %s\n" "$(idade "$_code_ts")"
fi

# --- contas
printf "\n${C}Contas${N}\n"
printf "  %-16s %-6s %-8s %-8s %-9s %s\n" "CONTA" "PROC" "SESSAO" "NUMEROS" "RELOGINS" "ULTIMA LINHA DO LOG"

_tot=0; _on=0; _sess_ok=0; _sess_caida=0; _sess_sem=0; _velhos=0
_lista_off=""; _lista_velha=""
for _d in "$TWMHOME"/BR_*/; do
    [ -d "$_d" ] || continue
    _acc=$(basename "${_d%/}")
    _nome=$(printf '%s' "$_acc" | sed 's/^BR_//')
    _tot=$((_tot + 1))

    # processo vivo?
    _pid=$(cat "$STATUS_DIR/${_acc}.pid" 2>/dev/null)
    if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
        _proc="on"; _on=$((_on + 1))
        # O worker.sh faz "exec twm.sh", entao o processo mantem o mesmo PID
        # do arranque: a data de /proc/PID e a hora em que este codigo foi
        # carregado. Mais antiga que os .sh do disco = codigo velho no ar.
        _pts=$(mtime "/proc/$_pid")
        case "$_pts" in
            ''|*[!0-9]*) ;;
            *) if [ "$_code_ts" -gt 0 ] && [ "$_pts" -lt "$_code_ts" ]; then
                   _proc="on/old"
                   _velhos=$((_velhos + 1))
                   _lista_velha="$_lista_velha $_nome"
               fi ;;
        esac
    else
        _proc="OFF"
        _lista_off="$_lista_off $_nome"
    fi

    # sessao no jogo
    #
    # Dentro de um evento a conta passa minutos sem pedir pagina (o modulo
    # entra em :55 e espera a hora cheia), entao nao ha confirmacao a cobrar.
    # O em_evento guarda o instante do evento; vale como janela.
    _eve=$(cat "${_d}em_evento" 2>/dev/null)
    _emev=0
    case "$_eve" in
        ''|*[!0-9]*) ;;
        *) [ "$AGORA" -gt $((_eve - 600)) ] && [ "$AGORA" -lt $((_eve + 900)) ] && _emev=1 ;;
    esac

    _ok=$(cat "${_d}last_ok" 2>/dev/null)
    _si=$(idade "$_ok")
    if [ "$_emev" = 1 ]; then
        _sess="evento"; _sess_ok=$((_sess_ok + 1))
    else
        case "$_ok" in
            ''|*[!0-9]*) _sess="?" ; _sess_sem=$((_sess_sem + 1)) ;;
            *) if [ $(( (AGORA - _ok) / 60 )) -gt 4 ]; then _sess="CAIDA"; _sess_caida=$((_sess_caida + 1))
               else _sess="$_si"; _sess_ok=$((_sess_ok + 1)); fi ;;
        esac
    fi

    # idade dos numeros do painel
    _num="-"
    if [ -s "${_d}stats" ]; then
        _ts=$(awk -F'|' '{print $8}' "${_d}stats" 2>/dev/null)
        _num=$(idade "$_ts")
    fi

    # quantos relogins nas ultimas 200 linhas do log
    _rel=$(tail -n 200 "${_d}twm.log" 2>/dev/null | grep -c 'reconectando\|login falhou\|nao respondeu\|falha ao reconectar')

    _ult=$(tail -n 1 "${_d}twm.log" 2>/dev/null | cut -c1-32)

    printf "  %-16.16s %-6s %-8s %-8s %-9s %s\n" \
        "$_nome" "$_proc" "$_sess" "$_num" "$_rel" "$_ult"
done

printf "\n${C}Resumo${N}\n"
printf "  contas: %s   processo vivo: %s   sessao ok: %s   caida: %s   sem dado: %s\n" \
    "$_tot" "$_on" "$_sess_ok" "$_sess_caida" "$_sess_sem"

# --- leitura
printf "\n${C}Como ler${N}\n"
printf "  ${D}PROC${N}     worker rodando (nao significa online no jogo)\n"
printf "  ${D}         on/old = rodando codigo anterior ao ultimo git pull${N}\n"
printf "  ${D}SESSAO${N}   ha quanto tempo a sessao foi confirmada no jogo\n"
printf "  ${D}         CAIDA = passou de 4 min;  ? = a conta ainda nao gravou${N}\n"
printf "  ${D}         evento = em evento, onde o silencio e esperado${N}\n"
printf "  ${D}NUMEROS${N}  idade dos dados do painel (HP, energia, ouro)\n"
printf "  ${D}RELOGINS${N} reconexoes e recusas nas ultimas 200 linhas do log\n"

# --- diagnostico
printf "\n${C}Diagnostico${N}\n"
_algo=0

if [ "$_velhos" -gt 0 ]; then
    _algo=1
    printf "${Y}%s conta(s) rodando codigo antigo:${N}%s\n" "$_velhos" "$_lista_velha"
    printf "  ${D}O git pull ja trouxe os arquivos novos, mas quem estava no ar${N}\n"
    printf "  ${D}continua com os antigos. Reinicie:  ./stop.sh && ./play.sh${N}\n"
    printf "  ${D}Enquanto isso, a coluna SESSAO fica em '?' — e falta de dado,${N}\n"
    printf "  ${D}nao sessao caida.${N}\n"
fi

if [ -n "$_lista_off" ]; then
    _algo=1
    printf "${R}Sem processo:${N}%s\n" "$_lista_off"
    printf "  ${D}Suba de novo com ./play.sh (as contas boas nao sao derrubadas).${N}\n"
fi

# "?" so preocupa quando o codigo no ar E o novo: ai a conta realmente
# nunca chegou ao descanso.
if [ "$_sess_sem" -gt 0 ] && [ "$_velhos" -eq 0 ]; then
    _algo=1
    printf "${Y}%s conta(s) sem confirmacao de sessao.${N}\n" "$_sess_sem"
    printf "  ${D}Recem-iniciada: normal, a primeira confirmacao leva ate 2 min.${N}\n"
    printf "  ${D}Passando disso, veja a coluna NUMEROS: fresca = a conta esta${N}\n"
    printf "  ${D}logada e so nao completou um ciclo.${N}\n"
fi

if [ "$_sess_caida" -gt 0 ]; then
    _algo=1
    printf "${Y}%s conta(s) com sessao caida.${N}\n" "$_sess_caida"
    printf "  ${D}Poucas e passageiras: normal, o bot reconecta sozinho.${N}\n"
    printf "  ${D}Muitas e persistentes, com RELOGINS alto: o servidor esta${N}\n"
    printf "  ${D}derrubando sessao por excesso de contas no mesmo IP.${N}\n"
fi

[ "$_algo" = 0 ] && printf "${G}Tudo certo: todas as contas com processo vivo e sessao confirmada.${N}\n"

exit 0
