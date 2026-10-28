# shellcheck disable=SC2154
# shellcheck disable=SC2317

# CORREÇÃO CRÍTICA (UBUNTU / MULTI-CONTAS):
# Garante que $TMP está definida. Se estiver vazia (comum no Ubuntu VPS),
# usa a diretoria temporária relativa a $TWMDIR ou /tmp/twm_tmp.
: "${TMP:=${TWMDIR:-/tmp}/tmp}"
mkdir -p "$TMP" 2>/dev/null

func_crono() {
    HOUR=`date +%H | sed 's/^0//'`
    MIN=`date +%M | sed 's/^0//'`
    [ -z "$HOUR" ] && HOUR=0
    [ -z "$MIN" ] && MIN=0
    printf "%s %s\n" "$URL" "`date +%H:%M`"
}

# Lista as funcoes disponiveis (comando "info" no modo interativo).
info() {
    printf "\n"
    grep -h -o -E '^[[:alnum:]_]+\(\) \{' "${TWMDIR:-.}"/*.sh 2>/dev/null \
        | sed 's/() {//' | sort -u
}

# Ha pedido de varredura imediata para esta conta?
runnow_pedido() {
    [ -f "$TMP/RUNNOW" ]
}

# Consome o pedido e abre os portoes das atividades.
runnow_consumir() {
    rm -f "$TMP/RUNNOW" 2>/dev/null
    rm -f "$TMP/last_arena"  "$TMP/last_carreira" "$TMP/last_campanha" \
          "$TMP/last_caverna" "$TMP/last_sabio"   "$TMP/last_liga" \
          "$TMP/last_troca"   "$TMP/last_clanquest" "$TMP/last_evento" \
          "$TMP/last_cq"      "$TMP/last_stats" 2>/dev/null
    printf "Varredura sob demanda: portoes liberados\n"
}

# Dorme em fatias, atendendo ao pedido de varredura no meio do caminho.
espera_interrompivel() {
    _ei_total="$1"
    case "$_ei_total" in ''|*[!0-9]*) _ei_total=60 ;; esac
    _ei_gasto=0
    while [ "$_ei_gasto" -lt "$_ei_total" ]; do
        if runnow_pedido; then
            runnow_consumir
            unset _ei_total _ei_gasto
            return 0
        fi
        sleep 5
        _ei_gasto=$((_ei_gasto + 5))
    done
    unset _ei_total _ei_gasto
    return 0
}

func_cat() {
    func_crono
    [ -f "$TMP/msg_file" ] && cat "$TMP/msg_file"

    _i="${i:-60}"
    case "$_i" in ''|*[!0-9]*) _i=60 ;; esac

    descansar

    if [ ! -t 0 ]; then
        printf "Sem batalhas agora, aguardando %ss\n" "$_i"
        espera_interrompivel "$_i"
        return 0
    fi

    while true; do
        printf "Sem batalhas agora, aguardando %ss\n" "$_i"
        printf "Digite um comando (ou 'info' / 'config'):\n"

        read -r -t "$_i" cmd || return 0

        [ -z "$cmd" ] && return 0
        [ "$cmd" = " " ] && return 0

        printf "\n"

        case "$cmd" in
            config)      config ;      sleep 1 ; continue ;;
            requer_func) requer_func ; sleep 1 ; continue ;;
            info)        info ;        sleep 1 ; continue ;;
            *) printf "Comando desconhecido: %s\n" "$cmd" ; sleep 1 ; continue ;;
        esac
    done
}

func_sleep() {
    [ -t 1 ] && clear

    if [ "`date +%d`" -eq 01 ] 2>/dev/null; then
        if [ "${HOUR:-99}" -lt 9 ] 2>/dev/null; then
            coliseum_start
            i=60
            func_cat
            return 0
        fi
    fi

    _fs_min=`date +%M | sed 's/^0//'`
    case "$_fs_min" in ''|*[!0-9]*) _fs_min=0 ;; esac
    case "$_fs_min" in
        9|10|11|12|13|24|25|26|27|28|29|30|54|55|56|57) i=15 ;;
        *)                                              i=60 ;;
    esac
    unset _fs_min
    func_cat
}

cq_liberado() {
    _m=${FUNC_cq_min:-15}
    case "$_m" in ''|*[!0-9]*) _m=15 ;; esac
    _u=`cat "$TMP/last_cq" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_m * 60)) ]
}
cq_marcar() { date +%s > "$TMP/last_cq" 2>/dev/null; }

stats_liberado() {
    _m=${FUNC_stats_min:-3}
    case "$_m" in ''|*[!0-9]*) _m=3 ;; esac
    _u=`cat "$TMP/last_stats" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_m * 60)) ]
}

atualiza_stats() {
    _aba_ant=`cat "${TMP}/pagina" 2>/dev/null`

    fetch_train_stats 2>/dev/null

    _pg=`run_curl "${URL}/user" 2>/dev/null`

    if [ -n "$_pg" ] && ! is_logged_in "$_pg"; then
        printf "Sessao caiu no ocio - reconectando\n"
        if type login_logoff > /dev/null 2>&1 && login_logoff; then
            _pg=`run_curl "${URL}/user" 2>/dev/null`
        fi
    fi

    if [ -z "$_pg" ] || ! is_logged_in "$_pg"; then
        printf %s "$_aba_ant" > "${TMP}/pagina" 2>/dev/null
        unset _pg _aba_ant
        return 1
    fi
    _a=`extract_username "$_pg"`
    [ -n "$_a" ] && ACC="$_a"
    parse_status "$_pg"
    messages_info
    date +%s > "$TMP/last_stats" 2>/dev/null
    printf %s "$_aba_ant" > "${TMP}/pagina" 2>/dev/null
    unset _pg _a _aba_ant
}

masmorra_liberada() {
    [ "${FUNC_masmorra:-y}" = "y" ] || return 1
    _u=`cat "$TMP/next_masmorra" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ "`date +%s`" -ge "$_u" ]
}
masmorra_marcar() { echo $(( `date +%s` + 25200 )) > "$TMP/next_masmorra" 2>/dev/null; }
masmorra_adiar() {
    _mm=${FUNC_masmorra_min:-45}
    case "$_mm" in ''|*[!0-9]*) _mm=45 ;; esac
    echo $(( `date +%s` + _mm * 60 )) > "$TMP/next_masmorra" 2>/dev/null
    unset _mm
}

tarefas_livres() {
    [ -n "$CLD" ] || clan_id 2>/dev/null

    if stats_liberado; then
        atualiza_stats 2>/dev/null
    fi

    if [ -n "$CLD" ] && cq_liberado; then
        printf "Checklist do cla\n"
        cq_concluir    2>/dev/null
        cq_ajudar      2>/dev/null
        cq_forcar_ouro 2>/dev/null
        cq_elixir      2>/dev/null
        cq_mercador    2>/dev/null
        cq_marcar
    fi

    if [ -n "$CLD" ] && masmorra_liberada; then
        if clanDungeon; then masmorra_marcar; else masmorra_adiar; fi
    fi

    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        arena_marcar
    fi

    if ativ_liberada carreira 15; then
        cq_antes carreira 2>/dev/null
        career_func
        ativ_marcar carreira
    fi

    if ativ_liberada campanha 15; then
        campaign_func
        ativ_marcar campanha
    fi

    if ativ_liberada caverna 20; then
        cq_antes caverna 2>/dev/null
        cave_routine
        ativ_marcar caverna
    fi

    if ativ_liberada sabio 20; then
        check_missions
        check_rewards
        ativ_marcar sabio
    fi

    if ativ_liberada liga 30; then
        cq_antes liga 2>/dev/null
        league_play 2>/dev/null
        ativ_marcar liga
    fi

    if ativ_liberada troca 60; then
        func_trade 2>/dev/null
        ativ_marcar troca
    fi

    if [ -n "$CLD" ] && [ "${FUNC_clan_missions:-y}" = "y" ] && ativ_liberada clanquest 20; then
        clanQuests 2>/dev/null
        ativ_marcar clanquest
    fi

    if [ "${FUNC_auto_events:-y}" = "y" ] && ativ_liberada evento 30; then
        specialEvent 2>/dev/null
        ativ_marcar evento
    fi
}

arena_liberada() {
    _m=${FUNC_arena_min:-30}
    case "$_m" in ''|*[!0-9]*) _m=30 ;; esac
    _ultimo=`cat "$TMP/last_arena" 2>/dev/null`
    case "$_ultimo" in ''|*[!0-9]*) _ultimo=0 ;; esac
    _agora=`date +%s`
    [ $((_agora - _ultimo)) -ge $((_m * 60)) ]
}
arena_marcar() { date +%s > "$TMP/last_arena" 2>/dev/null; }

ativ_liberada() {
    _an="$1"; _am="${2:-15}"
    case "$_am" in ''|*[!0-9]*) _am=15 ;; esac
    _au=`cat "$TMP/last_$_an" 2>/dev/null`
    case "$_au" in ''|*[!0-9]*) _au=0 ;; esac
    if [ $(( $(date +%s) - _au )) -ge $((_am * 60)) ]; then
        unset _an _am _au; return 0
    fi
    unset _an _am _au; return 1
}
ativ_marcar() { date +%s > "$TMP/last_$1" 2>/dev/null; }

evento_dedicar() {
    _ed_m=`date +%M | sed 's/^0//'`
    case "$_ed_m" in ''|*[!0-9]*) _ed_m=0 ;; esac
    _ed_s=`date +%S | sed 's/^0//'`
    case "$_ed_s" in ''|*[!0-9]*) _ed_s=0 ;; esac
    if   [ "$_ed_m" -ge 50 ]; then _ed_f=$(( 60 - _ed_m ))
    elif [ "$_ed_m" -ge 20 ] && [ "$_ed_m" -lt 30 ]; then _ed_f=$(( 30 - _ed_m ))
    else _ed_f=0
    fi

    _ed_resta=$(( _ed_f * 60 - _ed_s - 5 ))
    _ed_esp=$(( $$ % 10 ))
    [ "$_ed_esp" -gt "$_ed_resta" ] && _ed_esp=0
    [ "$_ed_esp" -gt 0 ] && sleep "$_ed_esp"

    echo $(( `date +%s` + _ed_f * 60 - _ed_esp )) > "$TMP/em_evento" 2>/dev/null
    unset _ed_m _ed_s _ed_f _ed_resta _ed_esp
}

evento_espera() {
    _ee_ini=`cat "$TMP/em_evento" 2>/dev/null`
    rm -f "$TMP/em_evento" 2>/dev/null
    case "$_ee_ini" in ''|*[!0-9]*) unset _ee_ini; return 0 ;; esac

    _ee_dur=${FUNC_evento_min:-10}
    case "$_ee_dur" in ''|*[!0-9]*) _ee_dur=10 ;; esac
    _ee_fim=$(( _ee_ini + _ee_dur * 60 ))

    while [ "`date +%s`" -lt "$_ee_fim" ]; do
        printf "Evento em andamento - atividades suspensas (%ss)\n" \
            $(( _ee_fim - `date +%s` ))
        descansar
        sleep 30
    done
    unset _ee_ini _ee_dur _ee_fim
    return 0
}

limpar_combate() {
    rm -f "$TMP/HP" "$TMP/old_HP" "$TMP/FULL" "$TMP/USH" 2>/dev/null
}

sessao_viva_arquivo() {
    [ -s "$1" ] || return 1
    grep -qiE "name=['\"]?pass['\"]?|action=[^>]*sign_in" "$1" && return 1
    grep -q "icon/level\.png" "$1" && return 0
    grep -qiE "/logout|[?&]exit" "$1" && return 0
    return 1
}

descansar() {
    fetch_page "/?out_gate_confirm=true" "$TMP/REST" 2>/dev/null
    fetch_page "/" "$TMP/REST" 2>/dev/null
    printf %s "/" > "$TMP/pagina" 2>/dev/null
    limpar_combate

    if sessao_viva_arquivo "$TMP/REST"; then
        date +%s > "$TMP/last_ok" 2>/dev/null
        return 0
    fi

    _ds_min=${FUNC_reconn_min:-60}
    case "$_ds_min" in ''|*[!0-9]*) _ds_min=60 ;; esac
    _ds_min=$(( _ds_min + ($$ % 45) ))

    _ds_ult=`cat "$TMP/last_reconn" 2>/dev/null`
    case "$_ds_ult" in ''|*[!0-9]*) _ds_ult=0 ;; esac
    if [ $(( `date +%s` - _ds_ult )) -lt "$_ds_min" ]; then
        unset _ds_ult _ds_min
        return 1
    fi
    unset _ds_min
    date +%s > "$TMP/last_reconn" 2>/dev/null
    unset _ds_ult

    printf "Sessao caiu no descanso - reconectando\n"
    if type login_logoff > /dev/null 2>&1 && login_logoff; then
        date +%s > "$TMP/last_ok" 2>/dev/null
        return 0
    fi
    return 1
}

start() {
    load_config

    if type login_logoff > /dev/null 2>&1; then
        if ! login_logoff; then
            printf "Sessao invalida — pulando este ciclo\n"
            func_crono
            func_sleep
            return 1
        fi
    fi

    pause_missions_weekend
    clan_id 2>/dev/null

    clan_statue

    if [ -n "$CLD" ]; then
        cq_concluir    2>/dev/null
        cq_ajudar      2>/dev/null
        cq_forcar_ouro 2>/dev/null
        cq_elixir      2>/dev/null
        cq_mercador    2>/dev/null
    fi

    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        arena_marcar
    fi

    atualiza_agenda 2>/dev/null

    cq_antes carreira 2>/dev/null
    career_func
    ativ_marcar carreira

    cq_antes caverna 2>/dev/null
    cave_routine
    ativ_marcar caverna

    cq_antes liga 2>/dev/null
    league_play 2>/dev/null
    ativ_marcar liga

    cq_antes elixir 2>/dev/null
    use_elixir
    use_blessing 2>/dev/null

    campaign_func
    ativ_marcar campanha

    if [ -n "$CLD" ] && masmorra_liberada; then
        if clanDungeon; then masmorra_marcar; else masmorra_adiar; fi
    fi

    func_trade
    ativ_marcar troca

    check_missions
    check_rewards
    ativ_marcar sabio

    if [ "${FUNC_auto_events:-y}" = "y" ]; then
        specialEvent
        ativ_marcar evento
    fi

    if [ "${FUNC_clan_missions:-y}" = "y" ]; then
        clanQuests
        ativ_marcar clanquest
    fi

    messages_info
    descansar
    func_crono
    func_sleep
}
