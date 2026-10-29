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
    printf " \033[1;92m[7] \033[0m  Aliados em todas as contas\n"
    printf " \033[1;92m[8] \033[0m  Reaplicar aliados (contas novas)\n"
    printf " \033[1;92m[9] \033[0m  Lideres de aliados (ver/remover)\n"
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
# ---------------------------------------------------------------------------
# [7] Aliados em todas as contas  |  [8] Reaplicar  |  [9] Lideres
# Configuracao central: $TWMHOME/aliados_central.txt
#   MODE=5|6|7
#   um ID de lider por linha (so para 6 e 7)
# ---------------------------------------------------------------------------
al_cfg_set() {   # $1 arquivo  $2 chave  $3 valor
    touch "$1" 2>/dev/null
    grep -v "^$2=" "$1" > "$1.tmp" 2>/dev/null
    printf '%s=%s\n' "$2" "$3" >> "$1.tmp"
    mv "$1.tmp" "$1"
}

aliados_central_file() { printf '%s' "$HOME/.twm/aliados_central.txt"; }

# Extrai IDs de texto livre (links /user/ID ou numeros soltos), um por linha.
aliados_extrai_ids() {
    tr ', ' '\n\n' | sed -n 's,.*/user/\([0-9][0-9]*\).*,\1,p; /^[0-9][0-9]*$/p' | sort -u
}

# Le a configuracao central. Preenche _al_mode e _al_ids. Retorna 1 se nao existe.
aliados_ler_central() {
    _al_f=`aliados_central_file`
    [ -s "$_al_f" ] || return 1
    _al_mode=`grep -E '^MODE=' "$_al_f" | tail -n1 | cut -d= -f2`
    _al_ids=`grep -E '^[0-9]+$' "$_al_f" | sort -u`
    return 0
}

aliados_gravar_central() {   # $1 modo  $2 ids (texto)
    _al_f=`aliados_central_file`
    mkdir -p "$HOME/.twm" 2>/dev/null
    {
        printf 'MODE=%s\n' "$1"
        [ -n "$2" ] && printf '%s\n' "$2"
    } > "$_al_f"
}

# Grava a configuracao central em TODAS as contas cadastradas e marca para
# reaplicar na proxima volta. Contas novas tambem entram aqui.
aliados_aplicar_contas() {
    aliados_ler_central || { printf "Nenhuma configuracao de aliados salva ainda.\n"; return 1; }
    _n=0
    if [ ! -s "$ACCOUNTS_FILE" ]; then
        printf "Nenhuma conta cadastrada.\n"
        return 1
    fi
    while IFS='|' read -r _srv _usr _enc; do
        case "$_srv" in ''|\#*) continue ;; esac
        [ -z "$_usr" ] && continue
        _tag=$(server_tag "$_srv")
        _dir="$HOME/.twm/${_tag}_${_usr}"
        mkdir -p "$_dir" 2>/dev/null
        chmod 700 "$_dir" 2>/dev/null
        if [ "$_al_mode" = 5 ]; then
            : > "$_dir/allies_lideres.txt"
        else
            printf '%s\n' "$_al_ids" > "$_dir/allies_lideres.txt"
        fi
        al_cfg_set "$_dir/config.cfg" "ALLIES" "$_al_mode"
        rm -f "$_dir/allies_state" "$_dir/allies_try" 2>/dev/null
        printf "  [%s] %s -> ALLIES=%s\n" "$_tag" "$_usr" "$_al_mode"
        _n=$((_n + 1))
    done < "$ACCOUNTS_FILE"
    printf "\n%s conta(s) configurada(s). A lista e aplicada na proxima volta de cada conta.\n" "$_n"
    unset _srv _usr _enc _tag _dir _n
    return 0
}

aliados_pausa() { printf "\033[2mENTER para voltar ▸\033[0m"; read -r _d; unset _d; }

# [7] Definir modo e lideres, e aplicar em todas as contas
aliados_todas_contas() {
    clear
    printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}ALIADOS EM TODAS AS CONTAS${RESET}\n${DIM}────────────────────────────────────────────${RESET}\n\n"
    printf " 1- So os aliados do meu cla (membros)\n"
    printf " 2- So os cla(s) dos lideres que eu informar\n"
    printf " 3- Os dois (meu cla + cla(s) dos lideres)\n"
    printf " 0- Cancelar\n\n"
    printf "Escolha: "
    read -r _am
    case "$_am" in
        1) _mode=5 ;;
        2) _mode=6 ;;
        3) _mode=7 ;;
        *) return 0 ;;
    esac

    _ids=""
    if [ "$_mode" != 5 ]; then
        printf "\nCole os links ou IDs dos LIDERES (ex.: furiadetitas.net/user/12345).\n"
        printf "Pode colar varios, um por linha. Linha vazia para terminar:\n"
        _raw=""
        while IFS= read -r _l; do
            [ -z "$_l" ] && break
            _raw="$_raw $_l"
        done
        _ids=`printf '%s\n' "$_raw" | aliados_extrai_ids`
        if [ -z "$_ids" ]; then
            printf "\nNenhum ID valido. Nada foi alterado.\n"
            aliados_pausa
            return 0
        fi
        printf "\nLideres informados: %s\n" "`printf '%s\n' "$_ids" | wc -l | tr -d ' '`"
    fi

    printf "\nAplicar nas contas cadastradas? (y/n): "
    read -r _ok
    case "$_ok" in y|Y) ;; *) printf "Cancelado.\n"; aliados_pausa; return 0 ;; esac

    aliados_gravar_central "$_mode" "$_ids"
    aliados_aplicar_contas
    aliados_pausa
    unset _am _mode _ids _raw _l _ok
}

# [8] Reaplicar a configuracao salva (use depois de adicionar contas)
aliados_reaplicar() {
    clear
    printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}REAPLICAR ALIADOS${RESET}\n${DIM}────────────────────────────────────────────${RESET}\n\n"
    if ! aliados_ler_central; then
        printf "Nenhuma configuracao de aliados salva. Use a opcao [7] primeiro.\n"
        aliados_pausa
        return 0
    fi
    printf "Modo salvo: %s  |  lideres: %s\n\n" "$_al_mode" "`printf '%s\n' "$_al_ids" | grep -c . | tr -d ' '`"
    printf "Reaplicar em todas as contas, inclusive as novas? (y/n): "
    read -r _ok
    case "$_ok" in
        y|Y) printf "\n"; aliados_aplicar_contas ;;
        *)   printf "Cancelado.\n" ;;
    esac
    aliados_pausa
    unset _ok
}

# [9] Ver, adicionar e remover lideres
aliados_lideres() {
    while true; do
        clear
        printf "${GREEN}🐉 DRAGONS${RESET}  ${WHITE}LIDERES DE ALIADOS${RESET}\n${DIM}────────────────────────────────────────────${RESET}\n\n"
        if ! aliados_ler_central; then
            printf "Nenhuma configuracao salva. Use a opcao [7] primeiro.\n"
            aliados_pausa
            return 0
        fi
        printf "Modo: %s  (5 = so meu cla, sem lideres)\n\n" "$_al_mode"
        _i=0
        for _id in $_al_ids; do
            _i=$((_i + 1))
            printf " %2d) %s\n" "$_i" "$_id"
        done
        [ "$_i" -eq 0 ] && printf " (nenhum lider cadastrado)\n"
        printf "\n a) adicionar lideres\n r) remover lider(es) pelo numero (ex.: 2 ou 1,3)\n 0) voltar\n\nEscolha: "
        read -r _op
        case "$_op" in
            0|'') return 0 ;;
            a|A)
                printf "Cole os links ou IDs (linha vazia para terminar):\n"
                _raw=""
                while IFS= read -r _l; do [ -z "$_l" ] && break; _raw="$_raw $_l"; done
                _novos=`printf '%s\n' "$_raw" | aliados_extrai_ids`
                _ids=`printf '%s\n%s\n' "$_al_ids" "$_novos" | grep -E '^[0-9]+$' | sort -u`
                aliados_gravar_central "$_al_mode" "$_ids"
                printf "\nLider(es) adicionado(s). Reaplicando nas contas...\n"
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
                        *",$_i,"*) ;;
                        *) _ids="$_ids
$_id" ;;
                    esac
                done
                _ids=`printf '%s\n' "$_ids" | grep -E '^[0-9]+$' | sort -u`
                aliados_gravar_central "$_al_mode" "$_ids"
                printf "\nLider(es) removido(s). Reaplicando nas contas...\n"
                aliados_aplicar_contas
                aliados_pausa
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
        7) aliados_todas_contas ;;
        8) aliados_reaplicar ;;
        9) aliados_lideres ;;
        0) printf "\nSaindo...\n"; exit 0 ;;
    esac
done
