# setup.sh - Gerenciamento de contas do TWM Multi-contas (Completo)

# CORRECAO (seguranca): sem umask o accounts.conf nascia 644 (legivel por
# qualquer processo do mesmo UID no Termux).
umask 077

# Resolve o caminho real do script, seguindo links simbolicos.
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

# Localiza o arquivo de contas — MESMA regra do play.sh.
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

# Carrega funcoes de verificacao de sessao
. "$TWMDIR/session_check.sh"

# Paleta sorteada a cada abertura do menu.
_seed=$(( ($$ + $(date +%s)) % 6 ))
case "$_seed" in
    0) A1=' \033[1;36m'; A2=' \033[1;34m' ;;
    1) A1=' \033[1;35m'; A2=' \033[1;31m' ;;
    2) A1=' \033[1;32m'; A2=' \033[1;33m' ;;
    3) A1=' \033[1;33m'; A2=' \033[0;33m' ;;
    4) A1=' \033[1;34m'; A2=' \033[1;35m' ;;
    *) A1=' \033[1;31m'; A2=' \033[1;36m' ;;
esac

GREEN=' \033[1;32m'
GOLD=' \033[1;33m'
RED=' \033[1;31m'
CYAN="$A1"
DIM=' \033[2m'
WHITE=' \033[1;37m'
RESET=' \033[0m'

# ============================================================
#  SOMENTE SERVIDOR BR (furiadetitas.net)
# ============================================================
server_url()    { case "$1" in 1) echo "furiadetitas.net" ;; esac; }
server_tag()    { case "$1" in 1) echo "BR" ;; esac; }
server_scheme() { echo "https"; }

show_menu() {
    clear
    _L="────────────────────────────────────────────────────────────────────"
    ACCOUNTS_FILE=$(resolve_accounts_file)
    n=0
    [ -f "$ACCOUNTS_FILE" ] && n=$(grep -c -E '^[0-9]+[|]' "$ACCOUNTS_FILE" 2>/dev/null)
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    printf " \033[1;92m🐉 DRAGONS \033[0m     \033[1;37mTWM MULTI-CONTAS \033[0m     \033[0;90mBR \033[0m\n"
    printf " \033[0;90m──────────────────────────────────────────── \033[0m\n"
    printf " \033[1;92mCLÃ \033[0m  %s conta(s) cadastrada(s)\n\n" "$n"
    printf " \033[1;92m[1] \033[0m  Listar contas\n"
    printf " \033[1;92m[2] \033[0m  Adicionar conta\n"
    printf " \033[1;92m[3] \033[0m  Remover conta\n"
    printf " \033[1;92m[4] \033[0m  Testar login\n"
    printf " \033[1;92m[5] \033[0m  Iniciar 🤖\n"
    printf " \033[1;92m[6] \033[0m  Atualizar Script\n"
    printf " \033[1;92m[7] \033[0m  Aliados (clas aliados e lista)\n"
    printf " \033[1;91m[0] \033[0m  Sair\n\n"
    printf " \033[1;92mDRAGONS \033[0m ▸ "
}

list_accounts() {
    clear
    printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}CONTAS CADASTRADAS${RESET}\n${GRAY}────────────────────────────────────────────${RESET}\n\n"
    if [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ]; then
        printf "${RED}Nenhuma conta cadastrada ainda.${RESET}\n"
    else
        n=1
        while IFS='|' read -r srv user _enc; do
            case "$srv" in ''|\#*) continue ;; esac
            [ -z "$user" ] && continue
            url=$(server_url "$srv")
            tag=$(server_tag "$srv")
            printf "${GOLD}%d)${RESET} [%s] %-20s\n" "$n" "$tag" "$user"
            n=$((n + 1))
        done < "$ACCOUNTS_FILE"
    fi
    printf "\n\033[2mENTER para voltar ▸\033[0m"
    read -r _d
}

show_servers() {
    printf "\n${CYAN}Servidor: BR - furiadetitas.net${RESET}\n"
}

add_account() {
    clear
    printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}NOVA CONTA${RESET}\n${GRAY}────────────────────────────────────────────${RESET}\n"
    show_servers
    srv=1

    url=$(server_url "$srv")
    tag=$(server_tag "$srv")

    printf "\033[1;92m👤 USUÁRIO\033[0m\n\033[0;90m%s\033[0m\n> " "$url"
    read -r user
    user=$(printf %s "$user" | tr -d '[:cntrl:]')

    case "$user" in
        *"|"*) printf "${RED}Nome nao pode conter | ${RESET}\n"; sleep 2; return ;;
        */*)   printf "${RED}Nome nao pode conter / ${RESET}\n"; sleep 2; return ;;
    esac
    [ -z "$user" ] && printf "${RED}Usuario vazio.${RESET}\n" && sleep 2 && return

    if [ -f "$ACCOUNTS_FILE" ] && grep -q "^${srv}|${user}|" "$ACCOUNTS_FILE" 2>/dev/null; then
        printf "${RED}Conta [%s] %s ja existe.${RESET}\n" "$tag" "$user"
        sleep 2; return
    fi

    printf "\033[1;92m🔐 SENHA\033[0m\n> "
    read -r pass
    printf "\n"
    [ -z "$pass" ] && printf "${RED}Senha vazia.${RESET}\n" && sleep 2 && return

    printf "Testando login em %s...\n" "$url"

    if [ "$(server_scheme "$srv")" = "http" ]; then
        printf "${RED}AVISO: este servidor nao suporta HTTPS.${RESET}\n"
        printf "A senha trafegara em texto claro. Continuar? (y/n): "
        read -r _ok
        case "$_ok" in y|Y) ;; *) printf "Cancelado.\n"; sleep 2; return ;; esac
    fi

    if test_login "$(server_scheme "$srv")://$url" "$user" "$pass"; then
        encoded=$(printf "login=%s&pass=%s" "$user" "$pass" | base64 | tr -d '[:space:]')
        printf "%s|%s|%s\n" "$srv" "$user" "$encoded" >> "$ACCOUNTS_FILE"
        chmod 600 "$ACCOUNTS_FILE" 2>/dev/null
        printf "${GREEN}[OK] Conta [%s] %s adicionada!${RESET}\n" "$tag" "$user"
    else
        printf "${RED}Login nao confirmado automaticamente.${RESET}\n"
        printf "Isso pode ocorrer por bloqueio de IP no teste.\n"
        printf "Salvar mesmo assim? (y/n): "
        read -r force
        case "$force" in
            y|Y)
                encoded=$(printf "login=%s&pass=%s" "$user" "$pass" | base64 | tr -d '[:space:]')
                printf "%s|%s|%s\n" "$srv" "$user" "$encoded" >> "$ACCOUNTS_FILE"
                chmod 600 "$ACCOUNTS_FILE" 2>/dev/null
                printf "${GOLD}Conta salva sem validacao.${RESET}\n"
                ;;
            *) printf "Conta nao salva.\n" ;;
        esac
    fi

    unset pass encoded
    sleep 2
}

remove_account() {
    clear
    printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}REMOVER CONTA${RESET}\n${GRAY}────────────────────────────────────────────${RESET}\n\n"
    [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ] && \
        printf "${RED}Nenhuma conta.${RESET}\n" && sleep 2 && return

    n=1
    while IFS='|' read -r srv user _enc; do
        case "$srv" in ''|\#*) continue ;; esac
        [ -z "$user" ] && continue
        tag=$(server_tag "$srv")
        printf "${GOLD}%d)${RESET} [%s] %s\n" "$n" "$tag" "$user"
        n=$((n + 1))
    done < "$ACCOUNTS_FILE"

    printf "\n\033[1;92mEscolha a conta\033[0m\n\033[0;90mDigite 0 para cancelar.\033[0m\n> "
    read -r choice
    [ "$choice" = "0" ] || [ -z "$choice" ] && return

    total=$(grep -c -E '^[0-9]+[|]' "$ACCOUNTS_FILE" 2>/dev/null)
    case "$total" in ''|*[!0-9]*) total=0 ;; esac
    case "$choice" in
        *[!0-9]*) printf "${RED}Invalido.${RESET}\n"; sleep 2; return ;;
    esac
    [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ] && \
        printf "${RED}Invalido.${RESET}\n" && sleep 2 && return

    line=$(grep '|' "$ACCOUNTS_FILE" | sed -n "${choice}p")
    srv=$(echo "$line" | cut -d'|' -f1)
    user=$(echo "$line" | cut -d'|' -f2)
    tag=$(server_tag "$srv")

    printf "Remover [%s] %s? (y/n): " "$tag" "$user"
    read -r confirm
    case "$confirm" in
        y|Y)
            acc_id="${tag}_${user}"
            pid_file="$STATUS_DIR/${acc_id}.pid"
            pid=$(cat "$pid_file" 2>/dev/null)
            ours=0
            case "$pid" in
                ''|*[!0-9]*) ;;
                *)
                    if [ -r "/proc/$pid/cmdline" ]; then
                        tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null \
                            | grep -qE 'worker\.sh|twm\.sh' && ours=1
                    elif kill -0 "$pid" 2>/dev/null; then
                        ours=1
                    fi
                    ;;
            esac
            if [ "$ours" -eq 1 ]; then
                printf "Parando worker de [%s] %s...\n" "$tag" "$user"
                kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
                _stop_wait=0
                while kill -0 "$pid" 2>/dev/null && [ "$_stop_wait" -lt 2 ]; do
                    sleep 1
                    _stop_wait=$((_stop_wait + 1))
                done
                if kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
                fi
                rm -f "$pid_file"
                echo "stopped" > "$STATUS_DIR/${acc_id}.status"
                unset _stop_wait
            fi

            awk -F'|' -v s="$srv" -v u="$user" '!($1==s && $2==u)' \
                "$ACCOUNTS_FILE" > "$ACCOUNTS_FILE.tmp" && \
                mv "$ACCOUNTS_FILE.tmp" "$ACCOUNTS_FILE"
            printf "${GREEN}Removida.${RESET}\n"
            acc_dir="$HOME/.twm/${tag}_${user}"
            if [ -d "$acc_dir" ]; then
                printf "Remover dados em %s? (y/n): " "$acc_dir"
                read -r rd
                case "$rd" in y|Y) rm -rf "$acc_dir" && printf "Dados removidos.\n" ;; esac
            fi
            ;;
        *) printf "Cancelado.\n" ;;
    esac
    sleep 2
}

test_account() {
    clear
    printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}TESTAR LOGIN${RESET}\n${GRAY}────────────────────────────────────────────${RESET}\n\n"
    [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ] && \
        printf "${RED}Nenhuma conta.${RESET}\n" && sleep 2 && return

    n=1
    while IFS='|' read -r srv user _enc; do
        case "$srv" in ''|\#*) continue ;; esac
        [ -z "$user" ] && continue
        tag=$(server_tag "$srv")
        printf "${GOLD}%d)${RESET} [%s] %s\n" "$n" "$tag" "$user"
        n=$((n + 1))
    done < "$ACCOUNTS_FILE"

    printf "\n\033[1;92mEscolha a conta\033[0m\n> "
    read -r choice
    total=$(grep -c -E '^[0-9]+[|]' "$ACCOUNTS_FILE" 2>/dev/null)
    case "$total" in ''|*[!0-9]*) total=0 ;; esac
    case "$choice" in *[!0-9]*) printf "${RED}Invalido.${RESET}\n"; sleep 2; return ;; esac
    [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ] && \
        printf "${RED}Invalido.${RESET}\n" && sleep 2 && return

    line=$(grep '|' "$ACCOUNTS_FILE" | sed -n "${choice}p")
    srv=$(echo "$line" | cut -d'|' -f1)
    user=$(echo "$line" | cut -d'|' -f2)
    encoded=$(echo "$line" | cut -d'|' -f3)
    tag=$(server_tag "$srv")
    url=$(server_url "$srv")

    creds=$(echo "$encoded" | base64 -d 2>/dev/null)
    luser=$(echo "$creds" | sed 's/login=//;s/&pass=.*//')
    lpass=$(echo "$creds" | sed 's/.*&pass=//')
    unset creds

    printf "Testando [%s] %s...\n" "$tag" "$user"

    if test_login "$(server_scheme "$srv")://$url" "$luser" "$lpass"; then
        printf "${GREEN}[OK] Login confirmado.${RESET}\n"
    else
        printf "${RED}[FALHOU] Login nao confirmado.${RESET}\n"
        printf "Nota: pode ser bloqueio de IP. O bot pode funcionar mesmo assim.\n"
    fi
    unset lpass
    sleep 3
}

update_script() {
    clear
    printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}ATUALIZAR SCRIPT${RESET}\n${GRAY}────────────────────────────────────────────${RESET}\n\n"
    printf "${GOLD}Baixando atualizações do repositório...${RESET}\n\n"
    
    if ! cd "$TWMDIR"; then
        printf "${RED}Erro: Diretório não encontrado (${TWMDIR}).${RESET}\n"
        sleep 3
        return
    fi

    if [ -d ".git" ]; then
        git reset --hard HEAD
        if ! git pull; then
            printf "${RED}Erro ao baixar a atualização. Verifique sua conexão.${RESET}\n"
            sleep 3
            return
        fi
    else
        printf "${RED}Aviso: Esta pasta não é um repositório Git válido.${RESET}\n"
        sleep 3
        return
    fi

    chmod +x ./*.sh 2>/dev/null
    printf "${GREEN}[OK] Permissões aplicadas a todos os scripts!${RESET}\n"

    if [ -f "./stop.sh" ]; then
        printf "${GOLD}Executando ./stop.sh...${RESET}\n"
        ./stop.sh
    fi

    printf "${GREEN}Atualização concluída com sucesso! Reiniciando...${RESET}\n"
    sleep 2

    exec "$TWMDIR/setup.sh"
}

# Loop principal
# ---- acesso ao jogo com a sessao (cookie.txt) de uma conta ----
aliados_cookie_ref() {
    # O bot grava a sessao atual em $TMP/cookie.txt (na VPS: /dev/shm, na memoria),
    # e a copia em ~/.twm pode estar velha. Usa o cookie MAIS RECENTE de todos.
    _cands=`find "$HOME/.twm" /dev/shm "${PREFIX:-/nonexistent}/tmp" -maxdepth 4 -name cookie.txt -size +0c 2>/dev/null`
    _best=""
    if [ -n "$_cands" ]; then
        _best=`find "$HOME/.twm" /dev/shm "${PREFIX:-/nonexistent}/tmp" -maxdepth 4 -name cookie.txt -size +0c -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-`
        [ -n "$_best" ] || _best=`printf '%s\n' "$_cands" | head -n1`
    fi
    printf '%s' "$_best"
    unset _cands _best
}

aliados_http() {   # $1 = caminho (ex.: /clan/123/1). Imprime o HTML. Usa copia do cookie.
    command -v curl >/dev/null 2>&1 || { printf '  ⚠️  curl nao instalado: rode "sudo apt install curl"\n' >&2; return 1; }
    _h_ck=`aliados_cookie_ref`
    if [ -z "$_h_ck" ]; then printf '  ⚠️  nenhum cookie.txt encontrado: rode uma conta uma vez\n' >&2; return 1; fi
    _h_tmp="$HOME/.twm/.ck_setup.$$"
    cp "$_h_ck" "$_h_tmp" 2>/dev/null || return 1
    curl -sS -L --compressed --max-time 30 --proto =https --proto-redir =https \
         -A "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36" \
         -c "$_h_tmp" -b "$_h_tmp" "https://$(server_url 1)$1" 2>/dev/null
    rm -f "$_h_tmp"
    unset _h_ck _h_tmp
}


# ---------------------------------------------------------------------------
# [7] ALIADOS - menu unico
# Configuracao central: $HOME/.twm/aliados_central.txt
#   MODE=5 (so meu cla) | 6 (so clas aliados) | 7 (os dois)
#   uma linha com o ID de cada cla aliado
# Cada cla cadastrado tem $HOME/.twm/aliados_membros_ID.txt (nomes)
#   e $HOME/.twm/aliados_membros_ID.txt.diag (perfis x nomes lidos)
# ---------------------------------------------------------------------------

al_cfg_set() {   # $1 arquivo  $2 chave  $3 valor
    touch "$1" 2>/dev/null
    grep -v "^$2=" "$1" > "$1.tmp" 2>/dev/null
    printf '%s=%s\n' "$2" "$3" >> "$1.tmp"
    mv "$1.tmp" "$1"
}

aliados_pausa() { printf "\033[2mENTER para continuar ▸\033[0m"; read -r _d; unset _d; }

# Extrai IDs de CLA de links /clan/ID, um por linha (aceita varios na mesma linha).
aliados_extrai_clas() {
    tr ' ,' '\n\n' | sed -n 's,.*/clan/\([0-9][0-9]*\).*,\1,p' | sort -u
}

# Nomes de membros a partir do HTML de uma pagina de cla (stdin).
# Usa o TEXTO do link de cada jogador (/user/ID ... >NOME<) e, como reforco,
# o padrao antigo "Nome, <s". Junta os dois, tira duplicados e ruido de interface.
aliados_so_membros() {
    # Mantem so os blocos <li> de membro: tem /user/ID e NAO tem /chat/ (o chat do cla
    # tambem traz links /user/ID, mas fora de <li>, e nao sao membros).
    tr '\n\r' '  ' | sed 's,<li[^>]*>,\n&,g; s,</li>,&\n,g' | grep '^<li' | grep '/user/' | grep -v '/chat/'
}

aliados_extrai_nomes() {
    # Achata quebras de linha: um nome que quebra de linha tambem e lido.
    _en_t=`cat | tr '\n\r' '  '`
    {
        # Padrao antigo (lia 41 de 50): "/>Nome, <s" com nome em maiuscula.
        printf '%s\n' "$_en_t" | grep -o -E "[/]>([[:upper:]][[:lower:]]{0,15}[[:space:]]{0,1}[[:upper:]]{0,1}[[:lower:]]{0,14},[[:space:]])<s" | awk -F"[>]" '{print $2}' | awk -F"[,]" '{print $1}'
        if [ "$1" != antigo ]; then
            # Ampliado: nome entre um ">" e ", <tag", aceitando ate 2 marcadores curtos
            # <span ...>'</span> entre o nome e a virgula (ex.: class='not_here'), acento,
            # numero, minuscula, "_" e quebras de linha.
            printf '%s\n' "$_en_t" | grep -o -E "[>][^<>,/]{2,40}(<span[^>]*>[^<]{0,3}</span>){0,2},[[:space:]]*<" | sed -E 's/^[>]//; s/[<,].*$//'
        fi
    } | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      | awk 'length($0) > 1 && $0 !~ /[\/=<>]/ && $0 !~ /^[0-9]+$/ { gsub(/ /, "_"); print }' \
      | sort -u
}

# Le as 5 paginas do cla. Grava nomes em $2 e diagnostico em $2.diag.
aliados_membros_cla() {   # $1 = cid   $2 = arquivo de saida
    # Le as paginas do cla (1,2,3...) so com os MEMBROS (ignora chat) e para sozinho
    # quando uma pagina nao traz perfil novo. Serve para cla de 1, 30 ou 50 membros.
    _mc_seen="$HOME/.twm/.mc_seen.$$"
    _dbg="$HOME/.twm/aliados_debug_clan_$1.html"
    : > "$_mc_seen"; : > "$2.raw"; : > "$2.raw_antigo"; : > "$_dbg"
    _mp=1
    while [ "$_mp" -le 8 ]; do
        _pg=`aliados_http "/clan/$1/$_mp"`
        _mem=`printf '%s\n' "$_pg" | aliados_so_membros`
        _novo=0
        for _x in `printf '%s\n' "$_mem" | grep -o -E '/user/[0-9]+' | sort -u`; do
            if ! grep -q -x -F "$_x" "$_mc_seen"; then
                printf '%s\n' "$_x" >> "$_mc_seen"
                _novo=1
            fi
        done
        [ "$_novo" -eq 1 ] || break
        printf '%s\n' "$_mem" >> "$_dbg"
        printf '%s\n' "$_mem" | aliados_extrai_nomes >> "$2.raw"
        printf '%s\n' "$_mem" | aliados_extrai_nomes antigo >> "$2.raw_antigo"
        _mp=$((_mp + 1))
    done
    _np=`grep -c . "$_mc_seen"`
    sort -u "$2.raw" | grep -v '^$' > "$2"
    sort -u "$2.raw_antigo" | grep -v '^$' > "$2.antigo"
    _na=`grep -c . "$2.antigo"`
    _nn=`grep -c . "$2"`
    _ruido=""
    if [ "$_np" -gt 0 ] && [ "$_nn" -gt "$_np" ]; then
        cp "$2.antigo" "$2"
        _nn=$_na
        _ruido=" (leitura ampliada descartada)"
    fi
    rm -f "$2.raw" "$2.raw_antigo" "$2.antigo" "$_mc_seen"
    printf 'membros lidos: %s de %s perfis%s\n' "$_nn" "$_np" "$_ruido" > "$2.diag"
    if [ "$_np" -eq 0 ]; then
        _ck=`aliados_cookie_ref`
        printf '  ⚠️  pagina sem membros. Cookie usado: %s\n' "$_ck"
        printf '  Causas comuns:\n'
        printf '      1) sessao antiga: o cookie so renova com a conta rodando\n'
        [ -n "$_ck" ] && printf '         cookie atualizado em: %s\n' "`date -r "$_ck" '+%d/%m %H:%M' 2>/dev/null || stat -c %y "$_ck" 2>/dev/null | cut -c1-16`"
        printf '         -> rode uma conta (./play.sh) por alguns minutos e tente de novo\n'
        printf '      2) link de cla errado ou curl sem resposta\n'
        unset _ck
    elif [ "$_nn" -lt "$_np" ]; then
        printf '  ⚠️  %s\n' "`cat "$2.diag"`"
        printf '  Exemplos nao lidos (copie e me envie, trocando nomes por NOME):\n'
        tr '\n\r' '  ' < "$_dbg" | sed 's,/user/,\n/user/,g' | grep '^/user/' | while IFS= read -r _ch; do
            if ! printf '%s\n' "$_ch" | aliados_extrai_nomes | grep -q .; then
                printf '%s\n' "$_ch" | cut -c1-200 | sed 's/^/      /'
            fi
        done | head -n 3
    fi
    unset _mp _pg _mem _np _nn _na _mc_seen _dbg _novo _x _ruido _ch
}

# ID do meu cla: primeiro cla que aparece na propria pagina /user
aliados_meu_cla() {
    aliados_http "/user" | grep -o -E '/clan/[0-9]+' | cut -d/ -f3 | head -n1
}

aliados_ler_central() {
    _al_f="$HOME/.twm/aliados_central.txt"
    [ -s "$_al_f" ] || return 1
    _al_mode=`grep -E '^MODE=' "$_al_f" | tail -n1 | cut -d= -f2`
    _al_ids=`grep -E '^[0-9]+$' "$_al_f" | sort -u`
    return 0
}

aliados_gravar_central() {   # $1 modo  $2 ids (texto, um por linha)
    mkdir -p "$HOME/.twm" 2>/dev/null
    {
        printf 'MODE=%s\n' "$1"
        [ -n "$2" ] && printf '%s\n' "$2"
    } > "$HOME/.twm/aliados_central.txt"
}

# Grava a configuracao em TODAS as contas e marca para reaplicar.
aliados_aplicar_contas() {
    aliados_ler_central || return 1
    [ -s "$ACCOUNTS_FILE" ] || { printf "Nenhuma conta cadastrada.\n"; return 1; }
    _n=0
    while IFS='|' read -r _srv _usr _enc; do
        case "$_srv" in ''|\#*) continue ;; esac
        [ -z "$_usr" ] && continue
        _tag=$(server_tag "$_srv")
        _dir="$HOME/.twm/${_tag}_${_usr}"
        mkdir -p "$_dir" 2>/dev/null
        chmod 700 "$_dir" 2>/dev/null
        if [ "$_al_mode" = 5 ]; then
            : > "$_dir/allies_clas.txt"
        else
            printf '%s\n' "$_al_ids" > "$_dir/allies_clas.txt"
        fi
        al_cfg_set "$_dir/config.cfg" "ALLIES" "$_al_mode"
        rm -f "$_dir/allies_state" "$_dir/allies_try" 2>/dev/null
        _n=$((_n + 1))
    done < "$ACCOUNTS_FILE"
    printf "Configuracao aplicada em %s conta(s). Entra em vigor na proxima volta de cada conta.\n" "$_n"
    unset _srv _usr _enc _tag _dir _n
    return 0
}

# Paginacao generica: $1 arquivo, $2 titulo. ENTER = proxima, q = sair.
aliados_paginar() {
    _pg_f="$1"; _pg_t="$2"
    _pg_total=`grep -c . "$_pg_f"`
    _pg_ini=1
    while [ "$_pg_ini" -le "$_pg_total" ]; do
        _pg_fim=$((_pg_ini + 24))
        clear
        printf "${WHITE}%s${RESET}  👥 %s no total\n\n" "$_pg_t" "$_pg_total"
        sed -n "${_pg_ini},${_pg_fim}p" "$_pg_f" | awk -v base="$_pg_ini" '{ gsub(/_/, " "); printf "%4d) %s\n", base + NR - 1, $0 }'
        _pg_ini=$((_pg_fim + 1))
        if [ "$_pg_ini" -le "$_pg_total" ]; then
            printf "\n▶️  ENTER = próxima página   ·   q = sair: "
            read -r _pg_op
            case "$_pg_op" in q|Q) break ;; esac
        fi
    done
    unset _pg_f _pg_t _pg_total _pg_ini _pg_fim _pg_op
}

# Lista combinada: meu cla (se o modo inclui) + todos os clas cadastrados.
aliados_lista_combinada() {
    _lc="$HOME/.twm/aliados_lista_combinada.txt"
    : > "$_lc"
    aliados_ler_central
    if [ "$_al_mode" = 5 ] || [ "$_al_mode" = 7 ]; then
        [ -s "$HOME/.twm/aliados_meu_cla.txt" ] && cat "$HOME/.twm/aliados_meu_cla.txt" >> "$_lc"
    fi
    if [ "$_al_mode" = 6 ] || [ "$_al_mode" = 7 ]; then
        for _id in $_al_ids; do
            [ -s "$HOME/.twm/aliados_membros_$_id.txt" ] && cat "$HOME/.twm/aliados_membros_$_id.txt" >> "$_lc"
        done
    fi
    sort -u "$_lc" | grep -v '^$' > "$_lc.tmp" && mv "$_lc.tmp" "$_lc"
    printf '%s' "$_lc"
    unset _lc _id
}

# Le os clas adicionados (e meu cla, se for o caso) e grava a lista.
aliados_ler_clas() {   # $1 = IDs a ler (um por linha)
    for _nid in $1; do
        printf "  ⚔️  cla %s: lendo membros... " "$_nid"
        aliados_membros_cla "$_nid" "$HOME/.twm/aliados_membros_$_nid.txt"
        printf "✅ %s membros  (%s)\n" "`grep -c . "$HOME/.twm/aliados_membros_$_nid.txt"`" "`cat "$HOME/.twm/aliados_membros_$_nid.txt.diag" 2>/dev/null`"
    done
}

aliados_menu() {
    while true; do
        clear
        printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}⚔️  ALIADOS${RESET}\n"
        printf "${DIM}╭──────────────────────────────────────────╮${RESET}\n"
        if ! aliados_ler_central; then
            printf "  Nenhuma configuracao ainda. Escolha o modo:\n\n"
            printf "   1️⃣  🛡️  So meu cla\n   2️⃣  ⚔️  So clas aliados\n   3️⃣  🤝 Os dois\n\n"
            printf "Escolha (0 = voltar): "
            read -r _m
            case "$_m" in
                1) aliados_gravar_central 5 ""; aliados_aplicar_contas ;;
                2) aliados_gravar_central 6 ""; aliados_aplicar_contas ;;
                3) aliados_gravar_central 7 ""; aliados_aplicar_contas ;;
                *) return 0 ;;
            esac
            aliados_pausa
            continue
        fi
        case "$_al_mode" in
            5) _md="🛡️  So meu cla" ;;
            6) _md="⚔️  So clas aliados" ;;
            7) _md="🤝 Meu cla + clas aliados" ;;
            *) _md="?" ;;
        esac
        printf "  Modo: ${WHITE}%s${RESET}\n" "$_md"
        printf "${DIM}╰──────────────────────────────────────────╯${RESET}\n\n"
        _i=0
        for _id in $_al_ids; do
            _i=$((_i + 1))
            _mf="$HOME/.twm/aliados_membros_$_id.txt"
            if [ -s "$_mf" ]; then
                printf "  %2d) ⚔️  cla %-8s 👥 %s membros  ✅\n" "$_i" "$_id" "`grep -c . "$_mf"`"
            else
                printf "  %2d) ⚔️  cla %-8s ❓ ainda nao lido\n" "$_i" "$_id"
            fi
        done
        [ "$_i" -eq 0 ] && printf "  (nenhum clã aliado cadastrado)\n"
        printf "\n  ➕ a  adicionar clãs (links /clan/NUMERO)\n"
        printf "  ➖ r  remover clãs pelo número (ex.: 2 ou 1,3)\n"
        printf "  🔄 l  reler membros dos clãs\n"
        printf "  📤 p  reaplicar nas contas (após cadastrar contas novas)\n"
        printf "  🔀 m  trocar modo\n"
        printf "  👀 v  ver lista de aliados\n"
        printf "  ↩️  0  voltar\n\n"
        printf "Escolha: "
        read -r _op
        case "$_op" in
            0|'') return 0 ;;

            a|A)
                printf "Cole os links dos clãs (um por linha ou separados por espaço). Linha vazia para terminar:\n"
                _raw=""
                while IFS= read -r _l; do [ -z "$_l" ] && break; _raw="$_raw $_l"; done
                _novos=`printf '%s\n' "$_raw" | aliados_extrai_clas`
                if [ -z "$_novos" ]; then
                    printf "❌ Nenhum link de clã válido (use /clan/NÚMERO). Nada mudou.\n"
                    aliados_pausa; continue
                fi
                _ids=`printf '%s\n%s\n' "$_al_ids" "$_novos" | grep -E '^[0-9]+$' | sort -u`
                aliados_gravar_central "$_al_mode" "$_ids"
                printf "\n🔎 Lendo os clãs novos:\n"
                aliados_ler_clas "$_novos"
                printf "\n📤 Aplicando nas contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            r|R)
                printf "Número(s) para remover: "
                read -r _nums
                _ids=""
                _i=0
                for _id in $_al_ids; do
                    _i=$((_i + 1))
                    case ",`printf '%s' "$_nums" | tr -d ' '`," in
                        *",$_i,"*) rm -f "$HOME/.twm/aliados_membros_$_id.txt" "$HOME/.twm/aliados_membros_$_id.txt.diag" ;;
                        *) _ids="$_ids
$_id" ;;
                    esac
                done
                _ids=`printf '%s\n' "$_ids" | grep -E '^[0-9]+$' | sort -u`
                aliados_gravar_central "$_al_mode" "$_ids"
                printf "\n🗑️  Clãs removidos. 📤 Aplicando nas contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            l|L)
                if [ -z "$_al_ids" ]; then
                    printf "\n❌ Nenhum clã cadastrado.\n"
                else
                    printf "\n🔎 Relendo os clãs cadastrados:\n"
                    aliados_ler_clas "$_al_ids"
                fi
                aliados_pausa
                ;;

            p|P)
                printf "\n📤 Reaplicando em todas as contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            m|M)
                printf "  1️⃣  🛡️  só meu clã    2️⃣  ⚔️  só clãs aliados    3️⃣  🤝 os dois\nEscolha: "
                read -r _nm
                case "$_nm" in
                    1) _novo=5 ;; 2) _novo=6 ;; 3) _novo=7 ;; *) continue ;;
                esac
                aliados_gravar_central "$_novo" "$_al_ids"
                printf "\n🔀 Modo trocado. 📤 Aplicando nas contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            v|V)
                if [ "$_al_mode" = 5 ] || [ "$_al_mode" = 7 ]; then
                    _mc=`aliados_meu_cla`
                    [ -n "$_mc" ] && aliados_membros_cla "$_mc" "$HOME/.twm/aliados_meu_cla.txt" >/dev/null
                fi
                _vazios=""
                for _id in $_al_ids; do
                    [ -s "$HOME/.twm/aliados_membros_$_id.txt" ] || _vazios="$_vazios
$_id"
                done
                _vazios=`printf '%s\n' "$_vazios" | grep -E '^[0-9]+$'`
                if [ -n "$_vazios" ] && { [ "$_al_mode" = 6 ] || [ "$_al_mode" = 7 ]; }; then
                    printf "\n🔎 Lendo clãs que ainda estavam vazios:\n"
                    aliados_ler_clas "$_vazios"
                fi
                _lc=`aliados_lista_combinada`
                if [ ! -s "$_lc" ]; then
                    printf "\n❌ Ainda não há nomes. Adicione um clã ou verifique a sessão.\n"
                    aliados_pausa
                else
                    aliados_paginar "$_lc" "👀 Lista de aliados"
                    printf "\n"; aliados_pausa
                fi
                ;;
            *) ;;
        esac
    done
}

while true; do
    show_menu
    read -r opt
    case "$opt" in
        1) list_accounts ;;
        2) add_account ;;
        3) remove_account ;;
        4) test_account ;;
        5) 
            clear
            printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}ESCOLHER MODO DE INICIALIZAÇÃO${RESET}\n${GRAY}────────────────────────────────────────────${RESET}\n\n"
            printf " [1] Modo Padrão (boot)\n"
            printf " [2] Modo Caverna (-cv)\n"
            printf " [3] Modo Coliseu (-cl)\n\n"
            printf " Escolha o modo [1-3] (Enter para Padrão): "
            read -r mode_opt
            case "$mode_opt" in
                2) clear; "$TWMDIR/play.sh" -cv ;;
                3) clear; "$TWMDIR/play.sh" -cl ;;
                *) clear; "$TWMDIR/play.sh" ;;
            esac
            exit 0
            ;;
        6) update_script ;;
        7) aliados_menu ;;
        0) printf "\nSaindo...\n"; exit 0 ;;
    esac
done
