#!/bin/sh
# diagnose.sh - Diagnostico de login de uma conta
#
# Usa a credencial ja salva no accounts.conf e reporta EXATAMENTE o que o
# servidor responde, para distinguir entre:
#   - senha incorreta ou conta banida  (o servidor recusa)
#   - bloqueio de IP                   (o servidor nao responde como esperado)
#   - login OK mas o bot nao detecta   (falha na deteccao de sessao)
#
# A SENHA NUNCA E EXIBIDA.
#
# Uso:  ./diagnose.sh        lista as contas
#       ./diagnose.sh 3      diagnostica a conta numero 3

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
export TWMDIR
ACCOUNTS_FILE="$TWMDIR/accounts.conf"

G='\033[32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[01;36m'; N='\033[00m'

# ============================================================
#  SOMENTE SERVIDOR BR (furiadetitas.net)
#  O suporte aos outros 12 servidores foi removido a pedido.
#  O campo de servidor continua no accounts.conf (sempre "1")
#  para nao quebrar cadastros existentes.
# ============================================================
server_url()    { case "$1" in 1) echo "furiadetitas.net" ;; esac; }
server_tag()    { case "$1" in 1) echo "BR" ;; esac; }
server_scheme() { echo "https"; }

[ -s "$ACCOUNTS_FILE" ] || { printf "${R}Nenhuma conta cadastrada.${N}\n"; exit 1; }

if [ -z "$1" ]; then
    printf "${C}Contas cadastradas:${N}\n\n"
    n=1
    grep -E '^[0-9]+\|' "$ACCOUNTS_FILE" | while IFS='|' read -r s u _e; do
        printf "  %d) [%s] %s\n" "$n" "$(server_tag "$s")" "$u"
        n=$((n+1))
    done
    printf "\nUse: ${Y}./diagnose.sh N${N}   (N = numero da conta)\n"
    exit 0
fi

case "$1" in *[!0-9]*|'') printf "${R}Numero invalido.${N}\n"; exit 1 ;; esac

line=$(grep -E '^[0-9]+\|' "$ACCOUNTS_FILE" | sed -n "${1}p")
[ -n "$line" ] || { printf "${R}Conta %s nao existe.${N}\n" "$1"; exit 1; }

srv=$(printf '%s' "$line" | cut -d'|' -f1)
user=$(printf '%s' "$line" | cut -d'|' -f2)
enc=$(printf '%s' "$line" | cut -d'|' -f3)
# Servidor unico (BR): o teste cruzado entre servidores foi removido
# junto com o suporte multi-servidor.
srv_orig="$srv"

tag=$(server_tag "$srv"); host=$(server_url "$srv"); sch=$(server_scheme "$srv")
URL="${sch}://${host}"

printf "${C}=== Diagnostico: [%s] %s ===${N}\n" "$tag" "$user"
printf "  servidor: %s\n\n" "$URL"

CK=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/diag_$$.txt")
UA="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"
rm -f "$CK"

# ---- 1. conectividade
printf "1) Conectividade... "
code=$(curl -s -o /dev/null -w '%{http_code}' -A "$UA" --max-time 25 "$URL/" 2>/dev/null)
if [ "$code" = "200" ]; then printf "${G}OK (HTTP 200)${N}\n"
else printf "${R}FALHOU (HTTP %s)${N}\n" "$code"
     printf "   O servidor nao respondeu. Pode ser queda, DNS ou bloqueio de rede.\n"
     rm -f "$CK"; exit 1; fi

# ---- 2. cookie de sessao
printf "2) Cookie de sessao... "
curl -s -o /dev/null -A "$UA" -c "$CK" -b "$CK" --max-time 25 "$URL/?sign_in=1" 2>/dev/null
if grep -q PHPSESSID "$CK" 2>/dev/null; then printf "${G}recebido${N}\n"
else printf "${R}NAO recebido${N}\n"; printf "   O servidor nao criou sessao. Indicio de bloqueio de IP.\n"; fi

# ---- 3. caracteres do usuario
printf "3) Nome de usuario... "
if printf '%s' "$user" | LC_ALL=C grep -q '[^ -~]'; then
    printf "${Y}contem caracteres nao-ASCII${N} (cirilico/acentos)\n"
    printf "   Isso pode afetar a codificacao. Anote como possivel causa.\n"
else printf "${G}so ASCII${N}\n"; fi

# ---- 4. login real, com TRES tentativas
#
# Uma amostra so engana. Medido nesta mesma base: uma conta com credencial
# CORRETA e recusada em cerca de 1 de cada 3 tentativas quando ha varias
# contas do mesmo IP no ar. Um unico "recusado" levava a conclusao errada
# de senha invalida — foi exatamente o que aconteceu aqui.
printf "4) Enviando login (senha nao e exibida)... "
creds=$(printf '%s' "$enc" | base64 -d 2>/dev/null)
lu=$(printf '%s' "$creds" | sed 's/login=//;s/&pass=.*//')
lp=$(printf '%s' "$creds" | sed 's/.*&pass=//')
unset creds
[ -n "$lp" ] || { printf "${R}credencial ilegivel${N}\n"; rm -f "$CK"; exit 1; }
printf "(usuario: %s, senha: %s caracteres)\n" "$lu" "$(printf '%s' "$lp" | wc -c | tr -d ' ')"

RESP="${TMPDIR:-/tmp}/diag_resp_$$.html"
PAGE="${TMPDIR:-/tmp}/diag_user_$$.html"
LOGGED=0; AUTHERR=0; FORM=0
_ok=0; _rec=0

printf "5) Tentativas:\n"
_i=1
while [ "$_i" -le 3 ]; do
    rm -f "$CK"
    curl -s -o /dev/null -A "$UA" -c "$CK" -b "$CK" --max-time 25 "$URL/?sign_in=1" 2>/dev/null
    curl -s -L -A "$UA" -c "$CK" -b "$CK" \
         --data-urlencode "login=${lu}" --data-urlencode "pass=${lp}" \
         --max-time 30 "$URL/?sign_in=1" -o "$RESP" 2>/dev/null
    curl -s -L -A "$UA" -c "$CK" -b "$CK" --max-time 30 "$URL/user" -o "$PAGE" 2>/dev/null

    if grep -qE "icon/level\.png|/logout" "$PAGE" 2>/dev/null; then
        printf "   %s) ${G}entrou${N}   (%s bytes)\n" "$_i" "$(wc -c < "$PAGE" 2>/dev/null)"
        _ok=$((_ok + 1)); LOGGED=1
    else
        printf "   %s) ${Y}recusado${N} (%s bytes)\n" "$_i" "$(wc -c < "$RESP" 2>/dev/null)"
        _rec=$((_rec + 1))
        grep -qE "error\.png|class='[^']*error" "$RESP" 2>/dev/null && AUTHERR=1
        grep -qE "name='pass'" "$RESP" 2>/dev/null && FORM=1
    fi
    _i=$((_i + 1))
    [ "$_i" -le 3 ] && sleep 8
done
unset lp
printf "   resultado: %s de 3 entraram\n" "$_ok"
printf "\n${C}=== CONCLUSAO ===${N}\n"
# CORRECAO DE ORDEM: antes o AUTHERR (heuristica de mensagem de erro) era
# testado primeiro e mascarava um login bem-sucedido, chegando a reportar
# "RECUSOU" para uma conta que estava logada. A checagem da sessao real
# em /user e evidencia direta e passa a ter prioridade.
if [ "$_ok" -eq 3 ]; then
    printf "${G}LOGIN FUNCIONOU.${N}
"
    printf "  As tres tentativas entraram. A credencial esta correta.
"
elif [ "$_ok" -gt 0 ]; then
    printf "${Y}CREDENCIAL CORRETA, mas o servidor recusou %s de 3.${N}
" "$_rec"
    printf "  A senha esta certa: entrar uma vez ja prova isso.
"
    printf "  A recusa intermitente vem do limite por IP, que responde
"
    printf "  com a MESMA mensagem de senha incorreta. Com varias contas
"
    printf "  no ar, e esperado. O bot tenta de novo sozinho.
"
elif [ "$LOGGED" = 1 ]; then
    printf "${G}LOGIN FUNCIONOU.${N}
"
    printf "  A pagina /user mostra sessao ativa para esta conta.
"
elif [ "$AUTHERR" = 1 ]; then
    printf "${R}O SERVIDOR RECUSOU a credencial.${N}\n"
    printf "  Mensagem encontrada na resposta:\n"
    grep -oE "error\.png[^<]*<[^>]*>[^<]{0,90}" "$RESP" | head -2 | sed "s/.*alt=''\/>//" | sed "s/^/    > /"
    printf "\n  Causas, em ordem de probabilidade:\n"
    printf "    1. Senha alterada ou digitada errada no cadastro\n"
    printf "    2. Conta banida ou suspensa\n"
    printf "    3. O nome de usuario nao e exatamente o de login\n"
    printf "\n  Teste a MESMA senha no navegador em %s\n" "$URL"
elif [ "$FORM" = 1 ]; then
    printf "${Y}Ainda aparece o formulario de login, mas SEM mensagem de erro.${N}\n"
    printf "  Isso normalmente indica bloqueio de IP ou sessao descartada.\n"
    printf "  Teste o mesmo login pelo navegador NESTA mesma rede.\n"
else
    printf "${Y}Resposta inesperada.${N}\n"
    printf "  Guarde os arquivos abaixo e reporte:\n"
    printf "    %s\n    %s\n" "$RESP" "$PAGE"
    RESP=""; PAGE=""
fi

printf "\n  IP de saida desta maquina: %s\n" "$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo 'nao detectado')"
[ -n "$RESP" ] && rm -f "$RESP"
[ -n "$PAGE" ] && rm -f "$PAGE"
rm -f "$CK"
