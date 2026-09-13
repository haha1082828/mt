#!/bin/sh

# CORRECAO: versionNum era definido apenas DENTRO de script_slogan(),
# funcao que nunca e chamada no fluxo do worker. Resultado: o messages_info
# imprimia "TWM - Titans War Macro v | ..." com a versao vazia.
versionNum="3.9.28"
# shellcheck disable=SC2034
colors() {
    BLACK_BLACK='\033[00;30m'
    BLACK_CYAN='\033[01;36m\033[01;07m'
    BLACK_GREEN='\033[00;32m\033[01;07m'
    BLACK_GRAY='\033[01;30m\033[01;07m'
    BLACK_PINK='\033[01;35m\033[01;07m'
    BLACK_RED='\033[01;31m\033[01;07m'
    BLACK_YELLOW='\033[00;33m\033[01;07m'
    CYAN_BLACK='\033[04;36m\033[02;04m'
    CYAN_CYAN='\033[01;36m\033[08;07m'
    BLUE_BLACK='\033[0;34m'
    COLOR_RESET='\033[00m'
    GOLD_BLACK='\033[0;33m'
    GREEN_BLACK='\033[32m'
    GREENb_BLACK='\033[1;32m'
    RED_BLACK='\033[0;31m'
    PURPLEi_BLACK='\033[03;34m\033[02;03m'
    PURPLEis_BLACK='\033[03;34m\033[02;04m'
    WHITE_BLACK='\033[37m'
    WHITEb_BLACK='\033[01;38m\033[05;01m'
}

script_slogan() {
    :  # valor definido no topo do arquivo
    printf "TWM - Titans War Macro v%s\n" "$versionNum"
}

# Aguarda o ultimo job em background terminar, ate N segundos.
time_exit() {
    TEFPID=$!
    [ -z "$TEFPID" ] && return 0

    _te_pace="${TWM_PACING:-1}"
    case "$_te_pace" in ''|*[!0-9]*) _te_pace=1 ;; esac
    [ "$_te_pace" -gt 0 ] && sleep "$_te_pace"
    unset _te_pace

    wait "$TEFPID" 2>/dev/null
    _te_rc=$?

    if [ "$_te_rc" = "28" ]; then
        printf "timeout: requisicao abortada\n" >> "${TMP:-.}/ERROR_DEBUG"
        unset _te_rc
        return 1
    fi
    unset _te_rc
    return 0
}

_rc_track() {
    [ -n "$TMP" ] || return 0
    [ -n "$URL" ] || return 0
    for _rc_a in "$@"; do
        case "$_rc_a" in
            "$URL")
                printf %s "/" > "$TMP/pagina" 2>/dev/null
                unset _rc_a
                return 0
                ;;
            "$URL"/*|"$URL"\?*)
                _rc_pp=${_rc_a#"$URL"}
                printf %s "$_rc_pp" > "$TMP/pagina" 2>/dev/null
                unset _rc_a _rc_pp
                return 0
                ;;
        esac
    done
    unset _rc_a
    return 0
}

_rc_run() {
    _rc_mode="$1"
    shift

    case "$URL" in
        http://*) _rc_p="--proto =http,https --proto-redir =http,https" ;;
        *)        _rc_p="--proto =https --proto-redir =https" ;;
    esac

    _rc_mt="${TWM_MAXTIME:-45}"
    case "$_rc_mt" in ''|*[!0-9]*) _rc_mt=45 ;; esac

    _rc_track "$@"

    # shellcheck disable=SC2086
    if [ "$_rc_mode" = "exec" ]; then
        if [ -n "$TMP_COOKIE" ]; then
            exec curl -sS -L --compressed --max-redirs 5 \
                 --connect-timeout 15 --max-time "$_rc_mt" \
                 $_rc_p -A "$vUserAgent" \
                 -c "$TMP_COOKIE" -b "$TMP_COOKIE" "$@"
        else
            exec curl -sS -L --compressed --max-redirs 5 \
                 --connect-timeout 15 --max-time "$_rc_mt" \
                 $_rc_p -A "$vUserAgent" "$@"
        fi
    fi

    # shellcheck disable=SC2086
    if [ -n "$TMP_COOKIE" ]; then
        curl -sS -L --compressed --max-redirs 5 \
             --connect-timeout 15 --max-time "$_rc_mt" \
             $_rc_p -A "$vUserAgent" \
             -c "$TMP_COOKIE" -b "$TMP_COOKIE" "$@"
    else
        curl -sS -L --compressed --max-redirs 5 \
             --connect-timeout 15 --max-time "$_rc_mt" \
             $_rc_p -A "$vUserAgent" "$@"
    fi
}

run_curl() { _rc_run "" "$@"; }

run_curl_exec() { _rc_run "exec" "$@"; }

fetch_page() {
    relative_url="$1"
    output_file="${2:-$TMP/SRC}"

    TWM_MAXTIME=7
    run_curl_exec "${URL}${relative_url}" > "$output_file" 2>/dev/null &
    _fp_pid=$!
    unset TWM_MAXTIME

    _fp_pace="${TWM_PACING:-1}"
    case "$_fp_pace" in ''|*[!0-9]*) _fp_pace=1 ;; esac
    [ "$_fp_pace" -gt 0 ] && sleep "$_fp_pace"

    wait "$_fp_pid" 2>/dev/null
    _fp_rc=$?
    unset _fp_pid _fp_pace

    if [ "$_fp_rc" != "0" ]; then
        run_curl_exec "${URL}${relative_url}" > "$output_file" 2>/dev/null
        _fp_rc=$?
        if [ "$_fp_rc" != "0" ]; then
            printf "curl %s: %s\n" "$_fp_rc" "$relative_url" >> "${TMP:-.}/ERROR_DEBUG"
            unset _fp_rc
            return 1
        fi
    fi
    unset _fp_rc
    return 0
}

combate_ler() {
    awk -v sec="$1" -v hper="$2" -v rper="$3" '
        function grava(nome, valor) {
            if (valor == "") printf "" > nome
            else             printf "%s\n", valor > nome
            close(nome)
        }
        function grava_num(nome, valor) {
            printf "%s", valor > nome
            close(nome)
        }
        { todo = todo $0 " " }
        END {
            resto = todo
            while (match(resto, "/" sec "/[a-z]+/[?]r[=][0-9]+")) {
                link = substr(resto, RSTART, RLENGTH)
                resto = substr(resto, RSTART + RLENGTH)

                verbo = link
                sub("^/" sec "/", "", verbo)
                sub("/.*$", "", verbo)

                alvo = ""
                if      (verbo == "attack")  alvo = "ATK"
                else if (verbo == "kingatk") alvo = "KINGATK"
                else if (verbo == "dodge")   alvo = "DODGE"
                else if (verbo == "heal")    alvo = "HEAL"
                else if (verbo == "stone")   alvo = "STONE"
                else if (verbo == "grass")   alvo = "GRASS"
                else if (verbo ~ /^at.*k./)  alvo = "ATKRND"

                if (alvo != "" && !(alvo in achado)) achado[alvo] = link
            }

            n = split("ATK ATKRND DODGE HEAL STONE KINGATK GRASS", lista, " ")
            for (i = 1; i <= n; i++)
                grava(lista[i], (lista[i] in achado) ? achado[lista[i]] : "")

            hp = ""
            if (match(todo, "hp[^A-Za-z0-9_][^A-Za-z0-9_]*[0-9][0-9]*")) {
                hp = substr(todo, RSTART, RLENGTH)
                sub(/^hp[^0-9]*/, "", hp)
            }
            grava("HP", hp)

            hp2 = ""
            if (match(todo, "nbsp[^A-Za-z0-9_][^A-Za-z0-9_]*[0-9][0-9]*")) {
                hp2 = substr(todo, RSTART, RLENGTH)
                sub(/^nbsp[^0-9]*/, "", hp2)
            }
            grava("HP2", hp2)

            full = ""
            getline full < "FULL"; close("FULL")
            rhp  = sprintf("%.0f", hp * rper / 100 + hp)
            hlhp = sprintf("%.0f", full * hper / 100)
            grava_num("RHP",  rhp)
            grava_num("HLHP", hlhp)

            printf "%s %s %s %s %s\n", \
                   (todo ~ /\/dodge\//) ? "1" : "0", \
                   (rhp  == "") ? "0" : rhp, \
                   (hlhp == "") ? "0" : hlhp, \
                   (hp   == "") ? "0" : hp, \
                   (hp2  == "") ? "0" : hp2
        }
    ' "$4" 2>/dev/null
}

sessao_marcar() { date +%s > "$TMP/last_ok" 2>/dev/null; }

link_acao() {
    _la_f="$1"; _la_p="$2"
    [ -r "$_la_f" ] || { printf ''; unset _la_f _la_p; return 1; }
    _la=`grep -o -E "/${_la_p}/[A-Za-z]+/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+" "$_la_f" 2>/dev/null | sed -n 1p`
    [ -n "$_la" ] && sessao_marcar
    [ -n "$_la" ] || _la=`grep -o -E "/${_la_p}/" "$_la_f" 2>/dev/null | sed -n 1p`
    printf '%s' "$_la"
    unset _la_f _la_p _la
    return 0
}

hpmp() {
    if echo "$@" | grep -q '\-fix'; then
        (
            run_curl_exec "$URL/train" > "$TMP/TRAIN"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 20
        FIXHP=`grep -o -E '\(([0-9]+)\)' "$TMP/TRAIN" | sed 's/[()]//g'`
        FIXMP=`grep -o -E ': [0-9]+' "$TMP/TRAIN" | sed -n '5s/: //p'`
    fi

    NOWHP=`grep -o -E "<img src='/images/icon/health.png' alt='hp'/> <span class='(dred|white)'>[ ]?[0-9]{1,7}[ ]?</span> | <img src='/images/icon/mana.png' alt='mp'/>" "$TMP/SRC" | tr -c -d '[:digit:]'`
    NOWMP=`grep -o -E "</span> | <img src='/images/icon/mana.png' alt='mp'/>[ ]?[0-9]{1,7}[ ]?</span><div class='clr'></div></div>" "$TMP/SRC" | tr -c -d '[:digit:]'`

    if [ -n "$NOWHP" ] && [ -n "$FIXHP" ] && [ "$FIXHP" -gt 0 ] 2>/dev/null; then
        HPPER=`awk -v nowhp="$NOWHP" -v fixhp="$FIXHP" 'BEGIN { printf "%.2f", nowhp / fixhp * 100 }'`
    else
        HPPER="0.00"
    fi

    if [ -n "$NOWMP" ] && [ -n "$FIXMP" ] && [ "$FIXMP" -gt 0 ] 2>/dev/null; then
        MPPER=`awk -v nowmp="$NOWMP" -v fixmp="$FIXMP" 'BEGIN { printf "%.2f", nowmp / fixmp * 100 }'`
    else
        MPPER="0.00"
    fi
}

parse_status() {
    _pg="$1"
    [ -n "$_pg" ] || return 1

    ACC_HP=`printf '%s' "$_pg" | grep -o -E "health\.png' alt='hp'/>[^0-9]{0,40}[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1`
    ACC_MP=`printf '%s' "$_pg" | grep -o -E "mana\.png' alt='mp'/>[^0-9]{0,40}[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1`
    ACC_LVL=`printf '%s' "$_pg" | grep -o -E "level\.png' alt='[^']*'/>[^0-9]{0,40}[0-9]{1,4}" | grep -o -E '[0-9]{1,4}$' | head -n1`

    ACC_GOLD=`printf '%s' "$_pg" | grep -o -E "gold\.png' alt='g'/>[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1`
    ACC_SILVER=`printf '%s' "$_pg" | grep -o -E "silver\.png' alt='s'/>[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1`

    NOWHP="$ACC_HP"; NOWMP="$ACC_MP"

    if [ -n "$ACC_HP" ] && [ -n "$FIXHP" ] && [ "$FIXHP" -gt 0 ] 2>/dev/null; then
        HPPER=`awk -v a="$ACC_HP" -v b="$FIXHP" 'BEGIN{printf "%.0f", a/b*100}'`
    else
        HPPER=""
    fi

    _ene_campo="-"
    if [ -n "$ACC_MP" ] && [ -n "$ACC_ENE" ]; then
        _ene_campo="${ACC_MP}/${ACC_ENE}"
    elif [ -n "$ACC_MP" ]; then
        _ene_campo="$ACC_MP"
    elif [ -n "$ACC_ENE" ]; then
        _ene_campo="$ACC_ENE"
    fi

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "${ACC:-$TWM_USER}" "${ACC_HP:--}" "${ACC_MP:--}" "$_ene_campo" \
        "${ACC_LVL:--}" "${ACC_GOLD:--}" "${ACC_SILVER:--}" "$(date +%s)" \
        > "$TMP/stats" 2>/dev/null
    unset _ene_campo

    unset _pg
}

fetch_train_stats() {
    ACC_ENE=""

    _t=`run_curl "${URL}/train" 2>/dev/null`
    [ -n "$_t" ] || return 1
    FIXHP=`printf '%s' "$_t" | grep -o -E '\([0-9]{1,9}\)' | head -n1 | tr -d '()'`
    ACC_ENE=`printf '%s' "$_t" | grep -o -E "Energia:?[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1`
    unset _t
}

fetch_max_hp() { fetch_train_stats; }

messages_info() {
    _a="${ACC:-$TWM_USER}"
    printf "TWM v%s | %s\n" "${versionNum:-?}" "$_a" > "$TMP/msg_file"
    if [ -n "$HPPER" ]; then
        printf "HP: %s (%s%%) | MP: %s | Energia: %s | Nivel: %s\n" \
            "${ACC_HP:--}" "$HPPER" "${ACC_MP:--}" "${ACC_ENE:--}" "${ACC_LVL:--}" >> "$TMP/msg_file"
    else
        printf "HP: %s | MP: %s | Energia: %s | Nivel: %s\n" \
            "${ACC_HP:--}" "${ACC_MP:--}" "${ACC_ENE:--}" "${ACC_LVL:--}" >> "$TMP/msg_file"
    fi
    unset _a
}

player_stats() {
    fetch_page "/train"
    STRENGTH=`grep -o -E ': [0-9]+' "$TMP/SRC" | sed -n '1s/: //p'`
    PLAYER_STRENGTH=`echo "$STRENGTH" | tr -cd '[:digit:]'`
    echo "$PLAYER_STRENGTH"
}

atualiza_agenda() {
    _ag="$HOME/.twm/agenda"

    TWM_MAXTIME=17
    _pg=`run_curl "${URL}/fights/" 2>/dev/null`
    unset TWM_MAXTIME
    [ -n "$_pg" ] || return 1

    _tmpf="${_ag}.$$.tmp"
    _rawf="${_ag}.$$.raw"
    : > "$_tmpf"

    printf '%s' "$_pg" \
        | sed 's/<br[^>]*>/\n/g; s/<\/div>/\n/g; s/<[^>]*>//g' \
        | grep -oE "(Vale dos Imortais|Coliseu do clã|Torneio dos Clãs|Rei dos Imortais|Altares dos Deuses|Batalha de Bandeiras)|[0-9]{1,2}:[0-9]{2} [A-Z]{2,5}" \
        > "$_rawf" 2>/dev/null

    _nome=""
    while IFS= read -r _ln; do
        case "$_ln" in
            [0-9]*:[0-9]*)
                [ -n "$_nome" ] || continue
                _h=${_ln%%:*}
                _m=${_ln#*:}; _m=${_m%% *}
                case "$_h$_m" in *[!0-9]*) continue ;; esac
                while :; do case "$_h" in 0?*) _h=${_h#0} ;; *) break ;; esac; done
                while :; do case "$_m" in 0?*) _m=${_m#0} ;; *) break ;; esac; done
                printf '%02d%02d|%s\n' "$_h" "$_m" "$_nome" >> "$_tmpf"
                ;;
            *)
                _nome="$_ln"
                ;;
        esac
    done < "$_rawf"
    rm -f "$_rawf"

    if [ -s "$_tmpf" ]; then
        sort -n "$_tmpf" > "${_tmpf}.s" 2>/dev/null && mv "${_tmpf}.s" "$_tmpf"
        mv "$_tmpf" "$_ag"
    else
        rm -f "$_tmpf"
    fi
    unset _ag _pg _tmpf _rawf _nome _ln _h _m
}

valor_num() {
    _v=`printf '%s' "$1" | tr -d ' '`
    case "$_v" in
        *K|*k) _mu=1000 ;;
        *M|*m) _mu=1000000 ;;
        *B|*b) _mu=1000000000 ;;
        *)     _mu=1 ;;
    esac
    _dg=`printf '%s' "$_v" | tr -d "'" | tr ',' '.' | tr -cd '0-9.'`
    [ -z "$_dg" ] && { echo 0; return; }
    awk -v d="$_dg" -v m="$_mu" 'BEGIN{ printf "%.0f", d*m }'
    unset _v _mu _dg
}

# ============================================================
#  NOVAS FUNCOES DE TAREFAS LIVRES E CHECKLIST INTEGRADAS
# ============================================================

check_info() {
    fetch_page "/user/info" "$TMP/USER_INFO" 2>/dev/null
    [ -s "$TMP/USER_INFO" ] || fetch_page "/main" "$TMP/USER_INFO"

    NOWHP=`grep -o -E 'hp[^0-9]*[0-9]+' "$TMP/USER_INFO" | grep -o -E '[0-9]+' | head -n1`
    NOWMP=`grep -o -E 'mp[^0-9]*[0-9]+' "$TMP/USER_INFO" | grep -o -E '[0-9]+' | head -n1`

    NOWHP=${NOWHP:-100}
    NOWMP=${NOWMP:-100}

    if [ -z "$CLD" ]; then
        clan_id 2>/dev/null
    fi
}

cq_liberado() {
    _ult_cq=`cat "$TMP/last_cq" 2>/dev/null`
    _hoje_cq=`date +%Y%m%d`
    if [ "$_ult_cq" = "$_hoje_cq" ]; then
        unset _ult_cq _hoje_cq
        return 1
    fi
    unset _ult_cq _hoje_cq
    return 0
}

cq_marcar() {
    date +%Y%m%d > "$TMP/last_cq" 2>/dev/null
}

cq_concluir() {
    fetch_page "/clan/${CLD}/quests" "$TMP/CLAN_QUESTS"
    _link=`grep -o -E '/clan/[0-9]+/quests/claim/[0-9]+/[?]r=[0-9]+' "$TMP/CLAN_QUESTS" | head -n1`
    if [ -n "$_link" ]; then
        fetch_page "$_link"
    fi
    unset _link
}

cq_ajudar() {
    fetch_page "/clan/${CLD}/quests" "$TMP/CLAN_QUESTS"
    _link=`grep -o -E '/clan/[0-9]+/quests/help/[0-9]+/[?]r=[0-9]+' "$TMP/CLAN_QUESTS" | head -n1`
    if [ -n "$_link" ]; then
        fetch_page "$_link"
    fi
    unset _link
}

cq_forcar_ouro() {
    fetch_page "/clan/${CLD}/quests" "$TMP/CLAN_QUESTS"
    _link=`grep -o -E '/clan/[0-9]+/quests/gold/[0-9]+/[?]r=[0-9]+' "$TMP/CLAN_QUESTS" | head -n1`
    if [ -n "$_link" ]; then
        fetch_page "$_link"
    fi
    unset _link
}

cq_elixir() {
    fetch_page "/clan/${CLD}/quests" "$TMP/CLAN_QUESTS"
    _link=`grep -o -E '/clan/[0-9]+/quests/elixir/[0-9]+/[?]r=[0-9]+' "$TMP/CLAN_QUESTS" | head -n1`
    if [ -n "$_link" ]; then
        fetch_page "$_link"
    fi
    unset _link
}

cq_mercador() {
    fetch_page "/clan/${CLD}/quests" "$TMP/CLAN_QUESTS"
    _link=`grep -o -E '/clan/[0-9]+/quests/merchant/[0-9]+/[?]r=[0-9]+' "$TMP/CLAN_QUESTS" | head -n1`
    if [ -n "$_link" ]; then
        fetch_page "$_link"
    fi
    unset _link
}

sellAll() {
    [ "${FUNC_sellAll:-y}" = "y" ] || return 0
    fetch_page "/inventory/sellAll" 2>/dev/null
}

tarefas_livres() {
    [ "${FUNC_tarefas_livres:-y}" = "y" ] || return 0

    # 1. Atualiza dados basicos da conta
    check_info 2>/dev/null

    # 2. Troca diaria de prata por ouro (trade.sh)
    func_trade 2>/dev/null

    # 3. Compra de bencao na loja de efeitos (trade.sh)
    use_blessing 2>/dev/null

    # 4. Checklist do cla e Doacao de Prata (clan_money)
    if [ -n "$CLD" ]; then
        if cq_liberado; then
            printf "Checklist do cla\n"
            cq_concluir    2>/dev/null
            cq_ajudar      2>/dev/null
            cq_forcar_ouro 2>/dev/null
            cq_elixir      2>/dev/null
            cq_mercador    2>/dev/null
            clan_money     2>/dev/null
            cq_marcar
        else
            if ativ_liberada "clan_money" 120 2>/dev/null; then
                clan_money 2>/dev/null
                ativ_marcar "clan_money" 2>/dev/null
            fi
        fi
    fi

    # 5. Modulo de campanha
    if ativ_liberada "campanha" 15 2>/dev/null; then
        campaign_func 2>/dev/null
        ativ_marcar "campanha" 2>/dev/null
    fi

    # 6. Limpeza e venda de itens da mochila
    sellAll 2>/dev/null

    return 0
}
