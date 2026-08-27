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
                printf "Change your allies for battle? (y or n): "
                while true; do
                    read -r value
                    echo
                    case "$value" in
                        [yYnN]) break ;;
                        *) printf "Invalid input. Enter 'y' or 'n': " ;;
                    esac
                done
                if [ "$value" != "n" ]; then
                    set_config "ALLIES" ""
                    key="ALLIES"
                    : > "$TMP/allies.txt"
                    : > "$TMP/callies.txt"
                    conf_allies
                fi
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
FUNC_use_elixir=y
FUNC_use_blessing=n
FUNC_blessing_gold_min=0
FUNC_trade=y
FUNC_trade_dias=365
FUNC_coliseum=y
FUNC_AUTO_UPDATE=n
FUNC_play_league=999
FUNC_clan_figth=y
FUNC_collect_mission_rewards=y
FUNC_pause_weekends=n
FUNC_auto_events=y
FUNC_clan_missions=y
FUNC_clan_quests=y
FUNC_clan_help=y
FUNC_quest_force_gold=n
FUNC_quest_gold_min=1200
FUNC_arena_min=30
FUNC_cq_min=15
FUNC_masmorra=y
FUNC_estatua_horas=6
FUNC_stats_min=3
FUNC_clan_statue=y
FUNC_cave_boost=n
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
