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
flagfight_fight() {
  src_ram="$TMP/flag_src"
  full_ram="$TMP/flag_full"

  cd "$TMP" || return 1

  LA=4
  HPER=25
  RPER=15
  
  rm -f "$full_ram"

  cf_access() {
    [ -f "$src_ram" ] || return 1
    grep -o -E '(/[a-z]+/[a-z]{0,4}at[a-z]{0,3}k/?[?]r[=][0-9]+)' "$src_ram" | sed -n '1p' > ATK 2>/dev/null
    grep -o -E '(/[a-z]+/at[a-z]{0,3}k[a-z]{3,6}/?[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > ATKRND 2>/dev/null
    grep -o -E '(/flagfight/dodge/?[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > DODGE 2>/dev/null
    grep -o -E '(/flagfight/heal/?[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > HEAL 2>/dev/null
    grep -o -E '(/[a-z]+/shield/?[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > SHIELD 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,20}( [[:upper:]][[:lower:]]{0,17})?)[[:space:]]\(' "$src_ram" | sed -n 's,\ [(],,;s,\ ,_,;2p' > CLAN 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:]]s' "$src_ram" | sed -n 's,\ [<]s,,;s,\ ,_,;2p' > USER 2>/dev/null
    grep -o -E "(hp)[^A-Za-z0-9]{1,4}[0-9]{1,6}" "$src_ram" | grep -o -E '[0-9]+' | head -n 1 > USH 2>/dev/null
    grep -o -E "(nbsp)[^A-Za-z0-9]{1,2}[0-9]{1,6}" "$src_ram" | grep -o -E '[0-9]+' | head -n 1 > ENH 2>/dev/null

    if [ ! -s "$full_ram" ]; then
      cat USH > "$full_ram" 2>/dev/null
    fi

    read -r ush < USH 2>/dev/null
    read -r full < "$full_ram" 2>/dev/null

    awk -v ush="${ush:-0}" -v rper="$RPER" 'BEGIN { printf "%.0f", ush * rper / 100 + ush }' > RHP
    awk -v ush="${full:-0}" -v hper="$HPER" 'BEGIN { printf "%.0f", ush * hper / 100 }' > HLHP

    if grep -q -o '/dodge/' "$src_ram"; then
      sessao_marcar
      printf "Em batalha flagfight - HP: %s\n" "${ush:-0}"
    else
      echo 1 > BREAK_LOOP
      printf "Battle over!\n"
      sleep 2s
    fi
  }

  cf_access
  > BREAK_LOOP
  cat USH > old_HP
  FIRST_DODGE=1
  FIRST_HEAL=1
  echo $(($(date +%s) - 20)) > last_dodge
  echo $(($(date +%s) - 90)) > last_heal
  echo $(($(date +%s) - LA)) > last_atk

  FIGHT_BREAK=$(($(date +%s) + 600))
  until [ -s "BREAK_LOOP" ] || [ "$(date +%s)" -gt "$FIGHT_BREAK" ]; do
    if awk -v ush="$(cat USH)" -v hlhp="$(cat HLHP)" 'BEGIN { exit !(ush < hlhp) }' && \
       ([ "$FIRST_HEAL" -eq 1 ] || { [ "$(($(date +%s) - $(cat last_heal)))" -gt 90 ] && [ "$(($(date +%s) - $(cat last_heal)))" -lt 300 ]; }); then
      (
        run_curl_exec "${URL}$(cat SHIELD)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat USH > old_HP
      date +%s > last_heal
      FIRST_HEAL=0

    elif ! grep -q -o 'txt smpl grey' "$src_ram" && \
         ([ "$FIRST_DODGE" -eq 1 ] || { [ "$(($(date +%s) - $(cat last_dodge)))" -gt 20 ] && [ "$(($(date +%s) - $(cat last_dodge)))" -lt 300 ]; }) && \
         awk -v ush="$(cat USH)" -v oldhp="$(cat old_HP)" 'BEGIN { exit !(ush < oldhp) }'; then
      (
        run_curl_exec "${URL}$(cat DODGE)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat USH > old_HP
      date +%s > last_dodge
      FIRST_DODGE=0

    elif awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$src_ram" && \
         awk -v rhp="$(cat RHP)" -v enh="$(cat ENH)" 'BEGIN { exit !(rhp < enh) }' || \
         awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$src_ram" && \
         grep -q -o "$(cat CLAN)" "$TMP/callies.txt"; then
      (
        run_curl_exec "${URL}$(cat ATKRND)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      date +%s > last_atk

    elif awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }'; then
      (
        run_curl_exec "${URL}$(cat ATK)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      date +%s > last_atk
    else
      fetch_page "/flagfight" "$src_ram"
      cf_access
      sleep 1s
    fi
  done

  rm -f "$src_ram" "$full_ram"
  unset src_ram full_ram ACCESS cf_access
  printf "Flagfight ok\n"
  sleep 10s
  apply_event flagfight
  [ -t 1 ] && clear
}

flagfight_start() {
  src_ram="$TMP/flag_src"
  full_ram="$TMP/flag_full"

  case `date +%H:%M` in
  (10:1[0-4]|16:1[0-4])
    fetch_page "/flagfight/?close=reward" "$src_ram"
    fetch_page "/flagfight/enterFight" "$src_ram"
    printf "Flagfight will be started...\n"

    while (case `date +%M:%S` in (14:[3-5][0-9]) exit 1;; esac); do
      sleep 3s
    done

    (
      run_curl_exec "$URL/flagfight/enterFight" > "$src_ram"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    grep -o -E '(/[a-z]+/[a-z]+/?[?]r[=][0-9]+)' "$src_ram" | sed -n '1p' > "$TMP/ACCESS" 2>/dev/null
    printf " Entering...\n"
    printf " Waiting...\n"

    BREAK=$(($(date +%s) + 60))

    until grep -q -o 'flagfight/dodge/' "$TMP/ACCESS" || [ "$(date +%s)" -gt "$BREAK" ]; do
      printf " ...\n%s\n" "`cat "$TMP/ACCESS"`"
      fetch_page "/flagfight/" "$src_ram"
      grep -o -E '(/flagfight/[a-z]+/?[?]r[=][0-9]+)' "$src_ram" | sed -n '1p' > "$TMP/ACCESS" 2>/dev/null
      sleep 3
    done

    if [ -s "$TMP/ACCESS" ]; then
      flagfight_fight
    else
      rm -f "$src_ram" "$full_ram"
      unset src_ram full_ram
    fi
    ;;
  esac
}
# Global variable to control loop exits
EXIT_CONFIG="n"

update_config() {
    key="$1"
    value="$2"

    if [ ! -f "$CONFIG_FILE" ]; then
        printf "Configuration file not found. Creating new...\n"
        touch "$CONFIG_FILE"
    fi

    if grep -q "^${key}=" "$CONFIG_FILE"; then
        # CORRECAO: "sed s/^k=.*/k=$value/" quebra se o valor contiver
        # / ou &. Delegado ao set_config, que reescreve por linha inteira.
        set_config "$key" "$value"
        printf "Configuration %s updated to %s.\n" "$key" "$value"
    else
        echo "${key}=${value}" >> "$CONFIG_FILE"
        printf "Added new configuration key %s with value %s.\n" "$key" "$value"
    fi
}

request_update() {
    key=""
    value=""
    success=1

    while [ "$success" -ne 0 ]; do
        printf "  Macro settings - type option number:\n"
        printf " 1- Collect relics. Current: %s\n" "$FUNC_check_rewards"
        printf " 2- Use elixir. Current: %s\n" "$FUNC_use_elixir"
        printf " 3- Auto update. Current: %s\n" "$FUNC_AUTO_UPDATE"
        printf " 4- Get to top in league. Current: %s\n" "$FUNC_play_league"
        printf " 5- Change language. Current: %s\n" "$LANGUAGE"
        printf " 6- Change allies. Current: %s\n" "$ALLIES"
        printf " 7- Collect mission rewards. Current: %s\n" "$FUNC_collect_mission_rewards"
        printf " 8- Pause mission rewards on weekends. Current: %s\n" "$FUNC_pause_weekends"
        printf " 9- Complete events. Current: %s\n" "$FUNC_auto_events"
        printf " A- Complete clan missions. Current: %s\n" "$FUNC_clan_missions"
        printf " B- Enable clan statue automatically. Current: %s\n" "$FUNC_clan_statue"
        printf " C- Use gold to collect 3 ores in the cave. Current: %s\n" "$FUNC_cave_boost"
        printf " Press ENTER to exit.\n"

        read -r key

        case $key in
            1)
                printf "Collect the relics (y or n): "
                key="FUNC_check_rewards"
                ;;
            2)
                printf "Use elixir before all valleys? (y or n): "
                key="FUNC_use_elixir"
                ;;
            3)
                printf "Update the script automatically? (y or n): "
                key="FUNC_AUTO_UPDATE"
                ;;
            4)
                printf "League number to reach the top (1-999): "
                while true; do
                    read -r value
                    case "$value" in
                        [0-9]|[0-9][0-9]|[0-9][0-9][0-9])
                            set_config "FUNC_play_league" "$value"
                            break
                            ;;
                        *)
                            printf "Invalid input. Enter a number between 1 and 999: "
                            ;;
                    esac
                done
                key="FUNC_play_league"
                ;;
            6)
                aliados_menu
                break
                ;;
            7)
                printf "Collect mission rewards automatically? (y or n): "
                key="FUNC_collect_mission_rewards"
                ;;
            8)
                printf "Pause mission rewards on weekends? (y or n): "
                key="FUNC_pause_weekends"
                ;;
            9)
                printf "Run special events? (y or n): "
                key="FUNC_auto_events"
                ;;
            a|A)
                printf "Complete the clan missions? (y or n): "
                key="FUNC_clan_missions"
                ;;
            b|B)
                printf "Enable clan statue automatically? (y or n): "
                key="FUNC_clan_statue"
                ;;
            c|C)
                printf "Use gold to collect 3 ores in the cave? (y or n): "
                key="FUNC_cave_boost"
                ;;
                d|D)
                    # A Bencao esta bloqueada por politica (nao se gasta
                    # ouro). A opcao continua no menu para nao mudar as
                    # letras das outras, mas avisa em vez de enganar.
                    printf "Bencao: bloqueada por politica, o bot nao gasta ouro.\n"
                    printf "Para reativar e preciso editar blessing.sh e resource_guard.sh.\n"
                    EXIT_CONFIG=""
                    continue
                    ;;
            *)
                printf "Exiting configuration update mode.\n"
                EXIT_CONFIG="y"
                return
                ;;
        esac

        case "$key" in
            FUNC_*)
                while true; do
                    read -r value
                    echo
                    case "$value" in
                        [yYnN]) break ;;
                        *) printf "Invalid input. Please enter 'y' or 'n': " ;;
                    esac
                done
                update_config "$key" "$value"
                success=$?
                if [ "$success" -ne 0 ]; then
                    printf "Invalid key. Please try again.\n"
                else
                    printf "Configuration updated successfully!\n"
                    config
                    break
                fi
                ;;
        esac
    done
}

# Valores padrao. Uma chave por linha.
config_defaults() {
    cat <<'EOF'
FUNC_check_rewards=y
FUNC_use_elixir=n
FUNC_use_blessing=n
FUNC_blessing_gold_min=0
FUNC_trade=y
FUNC_trade_dias=1
FUNC_coliseum=y
FUNC_AUTO_UPDATE=n
FUNC_play_league=999
FUNC_clan_fight=y
FUNC_collect_mission_rewards=y
FUNC_pause_weekends=n
FUNC_auto_events=y
FUNC_clan_missions=y
FUNC_clan_quests=y
FUNC_clan_help=y
FUNC_quest_force_gold=y
FUNC_quest_gold_min=1200
FUNC_arena_min=30
FUNC_cq_min=15
FUNC_masmorra=y
FUNC_masmorra_min=45
FUNC_masmorra_max=15
FUNC_estatua_horas=6
FUNC_stats_min=3
FUNC_clan_statue=y
FUNC_cave_boost=y
SCRIPT_PAUSED=n
ALLIES=
EOF
}

# Carrega a configuracao da conta.
#
# CORRECAO 1 (multi-contas): a versao anterior so gravava os defaults quando
# o arquivo NAO existia. Como o info.sh criava config.cfg com apenas
# "LANGUAGE=en" no momento do source, o ramo dos defaults nunca rodava e
# TODAS as FUNC_* ficavam vazias. Efeito pratico: use_elixir e check_rewards
# comparavam com "n", vazio != "n", e executavam mesmo desligados; e
# league.sh fazia [ "$N" -gt "" ] -> erro de operando a cada ciclo.
# Agora as chaves ausentes sao completadas SEMPRE, o que tambem repara
# configs ja gravados de forma incompleta.
#
# CORRECAO 2 (seguranca): antes era ". $CONFIG_FILE", ou seja, o arquivo de
# configuracao era EXECUTADO como shell script. Agora e lido como dado, com
# allowlist de chaves e validacao de valor. Configuracao e dado, nunca codigo.
load_config() {
    CONFIG_FILE="${TMP:-.}/config.cfg"
    [ -f "$CONFIG_FILE" ] || : > "$CONFIG_FILE"

    config_defaults | while IFS='=' read -r _dk _dv; do
        [ -n "$_dk" ] || continue
        grep -q "^${_dk}=" "$CONFIG_FILE" 2>/dev/null || \
            printf '%s=%s\n' "$_dk" "$_dv" >> "$CONFIG_FILE"
    done

    while IFS='=' read -r _ck _cv; do
        case "$_ck" in
            FUNC_*|LANGUAGE|ALLIES|SCRIPT_PAUSED|CAVE_GOLD_LIMIT|CAVE_SILVER_LIMIT) ;;
            *) continue ;;
        esac
        case "$_cv" in
            *[!A-Za-z0-9_.:/-]*) continue ;;
        esac
        eval "${_ck}=\"\$_cv\""
    done < "$CONFIG_FILE"

    unset _ck _cv _dk _dv
}

get_config() {
    _gc_key="$1"
    load_config
    # Lê o valor diretamente do arquivo (compatível com sh, sem ${!var})
    grep -E "^${_gc_key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-
}

set_config() {
    key="$1"
    value="$2"
    load_config

    grep -v "^${key}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null || true
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "${key}=${value}" >> "$CONFIG_FILE"
}

config() {
    load_config
    EXIT_CONFIG="n"

    while true; do
        if [ "$EXIT_CONFIG" = "n" ]; then
            printf "Script paused. Waiting for reactivation...\n"
            sleep 1s
            request_update
        else
            printf "Exiting configuration update mode...\n"
            EXIT_CONFIG="n"
            sleep 1s
            break
        fi
    done
}

pause_missions_weekend() {
    if [ "$FUNC_pause_weekends" = "n" ]; then
        return
    fi

    current_day=`date +%u`
    current_hour=`date +%H`
    CONFIG_FILE="$TMP/config.cfg"
    [ -f "$CONFIG_FILE" ] || return

    if [ "$current_day" -eq 6 ] || [ "$current_day" -eq 7 ]; then
        sed -i "s/^FUNC_collect_mission_rewards=.*/FUNC_collect_mission_rewards=n/" "$CONFIG_FILE"
        printf "Mission rewards collection paused for the weekend.\n"
        return
    fi

    if [ "$current_day" -eq 1 ] && [ "$current_hour" -eq 0 ]; then
        sed -i "s/^FUNC_collect_mission_rewards=.*/FUNC_collect_mission_rewards=y/" "$CONFIG_FILE"
        printf "Mission rewards collection reactivated automatically.\n"
        return
    fi
}
