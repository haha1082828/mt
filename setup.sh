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
aliados_cookie_ref() {   # primeiro cookie.txt nao vazio entre as contas
    while IFS='|' read -r _srv _usr _enc; do
        case "$_srv" in ''|\#*) continue ;; esac
        [ -z "$_usr" ] && continue
        _t=$(server_tag "$_srv")
        if [ -s "$HOME/.twm/${_t}_${_usr}/cookie.txt" ]; then
            printf '%s' "$HOME/.twm/${_t}_${_usr}/cookie.txt"
            break
        fi
    done < "$ACCOUNTS_FILE"
    unset _srv _usr _enc _t
}

aliados_http() {   # $1 = caminho (ex.: /user/123). Imprime o HTML, so leitura (-b, nao -c)
    _h_ck=`aliados_cookie_ref`
    [ -n "$_h_ck" ] || return 1
    curl -sS -L --compressed --max-time 30 --proto =https --proto-redir =https \
         -A "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36" \
         -b "$_h_ck" "https://$(server_url 1)$1" 2>/dev/null
    unset _h_ck
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
    # Le as paginas do cla (1,2,3...) e PARA sozinho quando uma pagina nao traz
    # nenhum perfil novo: serve para cla de 1, 30 ou 50 membros.
    _mc_seen="$HOME/.twm/.mc_seen.$$"
    _dbg="$HOME/.twm/aliados_debug_clan_$1.html"
    : > "$_mc_seen"; : > "$2.raw"; : > "$2.raw_antigo"; : > "$_dbg"
    _mp=1
    _tam=""
    while [ "$_mp" -le 8 ]; do
        _pg=`aliados_http "/clan/$1/$_mp"`
        _novo=0
        for _x in `printf '%s' "$_pg" | grep -o -E '/user/[0-9]+' | sort -u`; do
            if ! grep -q -x -F "$_x" "$_mc_seen"; then
                printf '%s\n' "$_x" >> "$_mc_seen"
                _novo=1
            fi
        done
        [ "$_novo" -eq 1 ] || break
        _tam="$_tam p$_mp=$(printf '%s' "$_pg" | wc -c | tr -d ' ')B"
        printf '%s\n' "$_pg" >> "$_dbg"
        printf '%s\n' "$_pg" | aliados_extrai_nomes >> "$2.raw"
        printf '%s\n' "$_pg" | aliados_extrai_nomes antigo >> "$2.raw_antigo"
        _mp=$((_mp + 1))
    done
    _np=`grep -c . "$_mc_seen"`
    sort -u "$2.raw" | grep -v '^$' > "$2"
    sort -u "$2.raw_antigo" | grep -v '^$' > "$2.antigo"
    _na=`grep -c . "$2.antigo"`
    _nn=`grep -c . "$2"`
    _ruido=""
    # Teto de seguranca: mais nomes que perfis indica texto que nao e nome.
    if [ "$_np" -gt 0 ] && [ "$_nn" -gt "$_np" ]; then
        cp "$2.antigo" "$2"
        _nn=$_na
        _ruido=" [leitura ampliada descartada: tinha mais nomes que perfis]"
    fi
    rm -f "$2.raw" "$2.raw_antigo" "$2.antigo" "$_mc_seen"
    printf 'perfis encontrados: %s | nomes lidos: %s (padrao antigo: %s)%s |%s\n' "$_np" "$_nn" "$_na" "$_ruido" "$_tam" > "$2.diag"
    if [ "$_np" -eq 0 ]; then
        printf '  [diagnostico] a pagina veio sem nenhum perfil: sessao (cookie.txt) expirada ou cla errado\n'
    elif [ "$_nn" -lt "$_np" ]; then
        printf '  [diagnostico] %s\n' "`cat "$2.diag"`"
        printf '  [diagnostico] exemplos de membros NAO lidos (copie e me envie, trocando nomes por NOME):\n'
        tr '\n\r' '  ' < "$_dbg" | sed 's,/user/,\n/user/,g' | grep '^/user/' | while IFS= read -r _ch; do
            if ! printf '%s\n' "$_ch" | aliados_extrai_nomes | grep -q .; then
                printf '%s\n' "$_ch" | cut -c1-240 | sed 's/^/      /'
            fi
        done | head -n 3
    fi
    unset _mp _pg _np _nn _na _tam _mc_seen _dbg _novo _x _ruido _ch
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
        printf "${WHITE}%s${RESET}  (%s no total)\n\n" "$_pg_t" "$_pg_total"
        sed -n "${_pg_ini},${_pg_fim}p" "$_pg_f" | awk -v base="$_pg_ini" '{ gsub(/_/, " "); printf "%4d) %s\n", base + NR - 1, $0 }'
        _pg_ini=$((_pg_fim + 1))
        if [ "$_pg_ini" -le "$_pg_total" ]; then
            printf "\nENTER = proxima pagina, q = sair: "
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
        printf "  cla %s: lendo membros... " "$_nid"
        aliados_membros_cla "$_nid" "$HOME/.twm/aliados_membros_$_nid.txt"
        printf "%s membros  (%s)\n" "`grep -c . "$HOME/.twm/aliados_membros_$_nid.txt"`" "`cat "$HOME/.twm/aliados_membros_$_nid.txt.diag"`"
    done
}

aliados_menu() {
    while true; do
        clear
        printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}ALIADOS${RESET}\n${DIM}────────────────────────────────────────────${RESET}\n\n"
        if ! aliados_ler_central; then
            printf "Nenhuma configuracao ainda. Escolha o modo para comecar:\n"
            printf "  1- So meu cla    2- So clas aliados    3- Os dois\n"
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
            5) _md="so meu cla" ;;
            6) _md="so clas aliados" ;;
            7) _md="meu cla + clas aliados" ;;
            *) _md="?" ;;
        esac
        printf "Modo atual: %s\n\n" "$_md"
        _i=0
        for _id in $_al_ids; do
            _i=$((_i + 1))
            _mf="$HOME/.twm/aliados_membros_$_id.txt"
            if [ -s "$_mf" ]; then
                printf " %2d) cla %-10s %s membros   (%s)\n" "$_i" "$_id" "`grep -c . "$_mf"`" "`cat "$_mf.diag" 2>/dev/null`"
            else
                printf " %2d) cla %-10s (membros ainda nao lidos)\n" "$_i" "$_id"
            fi
        done
        [ "$_i" -eq 0 ] && printf " (nenhum cla aliado cadastrado)\n"
        printf "\n a) adicionar clas (cole os links /clan/NUMERO)\n"
        printf " r) remover clas pelo numero (ex.: 2 ou 1,3)\n"
        printf " l) reler membros dos clas\n"
        printf " p) reaplicar nas contas (use depois de cadastrar contas novas)\n"
        printf " m) trocar modo\n"
        printf " v) ver lista de aliados (paginada)\n"
        printf " 0) voltar\n\nEscolha: "
        read -r _op
        case "$_op" in
            0|'') return 0 ;;

            a|A)
                printf "Cole os links dos clas (um por linha ou separados por espaco). Linha vazia para terminar:\n"
                _raw=""
                while IFS= read -r _l; do [ -z "$_l" ] && break; _raw="$_raw $_l"; done
                _novos=`printf '%s\n' "$_raw" | aliados_extrai_clas`
                if [ -z "$_novos" ]; then
                    printf "Nenhum link de cla valido (use /clan/NUMERO). Nada mudou.\n"
                    aliados_pausa; continue
                fi
                _ids=`printf '%s\n%s\n' "$_al_ids" "$_novos" | grep -E '^[0-9]+$' | sort -u`
                aliados_gravar_central "$_al_mode" "$_ids"
                printf "\nLendo os clas novos:\n"
                aliados_ler_clas "$_novos"
                printf "\nAplicando nas contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            r|R)
                printf "Numero(s) para remover: "
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
                printf "\nClas removidos. Aplicando nas contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            p|P)
                printf "\nReaplicando em todas as contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            l|L)
                if [ -z "$_al_ids" ]; then
                    printf "\nNenhum cla cadastrado.\n"
                else
                    printf "\nLendo os clas cadastrados:\n"
                    aliados_ler_clas "$_al_ids"
                fi
                aliados_pausa
                ;;

            m|M)
                printf "  1- so meu cla    2- so clas aliados    3- os dois\nEscolha: "
                read -r _nm
                case "$_nm" in
                    1) _novo=5 ;; 2) _novo=6 ;; 3) _novo=7 ;; *) continue ;;
                esac
                aliados_gravar_central "$_novo" "$_al_ids"
                printf "\nModo trocado. Aplicando nas contas...\n"
                aliados_aplicar_contas
                aliados_pausa
                ;;

            v|V)
                # Se o modo inclui o meu cla, guarda a lista dele antes de mostrar
                if [ "$_al_mode" = 5 ] || [ "$_al_mode" = 7 ]; then
                    _mc=`aliados_meu_cla`
                    if [ -n "$_mc" ]; then
                        aliados_membros_cla "$_mc" "$HOME/.twm/aliados_meu_cla.txt"
                    fi
                fi
                # Clas ainda sem membros lidos: le agora
                _vazios=""
                for _id in $_al_ids; do
                    [ -s "$HOME/.twm/aliados_membros_$_id.txt" ] || _vazios="$_vazios
$_id"
                done
                _vazios=`printf '%s\n' "$_vazios" | grep -E '^[0-9]+$'`
                if [ -n "$_vazios" ] && { [ "$_al_mode" = 6 ] || [ "$_al_mode" = 7 ]; }; then
                    printf "\nLendo clas que ainda estavam vazios:\n"
                    aliados_ler_clas "$_vazios"
                fi
                _lc=`aliados_lista_combinada`
                if [ ! -s "$_lc" ]; then
                    printf "\nAinda nao ha nomes. Adicione um cla ou verifique a sessao.\n"
                    aliados_pausa
                else
                    aliados_paginar "$_lc" "Lista de aliados (combinada)"
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
