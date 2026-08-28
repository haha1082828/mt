#!/bin/sh
# panel.sh - Painel do TWM (Parte 1 de 2)

if [ -t 1 ]; then HAS_TTY=1; else HAS_TTY=0; fi

# Cores
C_RESET='\033[0m';   C_DIM='\033[2m';      C_BOLD='\033[1m'
C_CYAN='\033[1;36m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'
C_RED='\033[1;31m';  C_MAG='\033[1;35m';   C_WHITE='\033[1;37m'
C_GOLD='\033[0;33m'; C_GRAY='\033[0;37m';  C_BLUE='\033[1;34m'
ESC=$(printf '\033')

# Emoji e Tema (DRAGONS)
I_HP="❤️ "; I_EN="⚡ "; I_LV="⭐ "; I_GO="🪙 "; I_SI="🥈 "
I_TIT="🎮 "; I_ACT="📋 "; I_EVT="⌚ "; I_ARROW="▸"; I_LIVE="⚔️ "
S_ON="🟢"; S_WAIT="🟡"; S_ERR="🔴"; S_OFF="⚫"; S_UNK="⚪"; S_PAUSE="⏸️"
A_CLANFIGHT="🏆  Torneio do Clã";   A_ALTARES="🔥  Altares dos Deuses"
A_VALE="🌘  Vale dos Imortais";     A_REI="👑  Rei dos Imortais"
A_CLANCOL="🏛️  Coliseu do Clã";     A_MASMORRA="🗝️  Masmorra do Clã"
A_CLANQUEST="📜  Missões do Clã";   A_BANDEIRAS="🚩  Batalha de Bandeiras"
A_COLISEU="🏟️  Coliseu";            A_ARENA="⚔️  Arena"
A_CARREIRA="🎖️  Carreira";          A_CAVERNA="⛏️  Caverna"
A_CAMPANHA="🗺️  Campanha";          A_LIGA="🥇  Liga dos Favoritos"
A_TROCA="💱  Troca Prata/Ouro";     A_SABIO="🧙  Cabana do Sábio"
A_EVENTO="🎉  Evento Especial";     A_DESCANSO="💤  Descansando"
A_NONE="—"

painel_largura() {
    case "${TWM_COLS:-}" in
        ''|*[!0-9]*) ;;
        *) printf '%s' "$TWM_COLS"; return 0 ;;
    esac

    _pw=$(stty size 2>/dev/null | cut -d" " -f2)
    case "$_pw" in ''|*[!0-9]*) _pw="" ;; esac
    if [ -z "$_pw" ] && command -v tput > /dev/null 2>&1; then
        _pw=$(tput cols 2>/dev/null)
        case "$_pw" in ''|*[!0-9]*) _pw="" ;; esac
    fi
    [ -z "$_pw" ] && _pw="$COLUMNS"
    case "$_pw" in ''|*[!0-9]*) _pw=80 ;; esac
    [ "$_pw" -lt 36 ] && _pw=36
    [ "$_pw" -gt 120 ] && _pw=120
    printf '%s' "$_pw"
}

painel_regua() {
    _rn=$1
    _rs=""
    while [ "${#_rs}" -lt "$_rn" ]; do
        _rs="$_rs----------"
    done
    printf '%b%.*s%b\n' "$C_BLUE" "$_rn" "$_rs" "$C_RESET"
    unset _rn _rs
}

EVENTOS="0030|Coliseu
0925|Evento especial
0955|Imortais
1010|Batalha de Bandeiras
1025|Coliseu do Cla
1055|Batalha de Clas
1225|Rei dos Imortais
1355|Altares
1455|Coliseu do Cla
1555|Imortais
1610|Batalha de Bandeiras
1625|Rei dos Imortais
1855|Batalha de Clas
2055|Altares
2125|Evento especial
2155|Imortais
2225|Rei dos Imortais"

painel_desatualizado() {
    for _pd_f in "$TWMDIR"/*.sh; do
        [ -f "$_pd_f" ] || continue
        if [ "$_pd_f" -nt "/proc/$$" ]; then unset _pd_f; return 0; fi
    done
    unset _pd_f
    return 1
}

_hhmm_min() {
    _hm_t="$1"
    case "$_hm_t" in ????) ;; *) _HM=-1; return 1 ;; esac
    _hm_h=${_hm_t%??}
    _hm_m=${_hm_t#??}
    case "$_hm_h$_hm_m" in *[!0-9]*) _HM=-1; return 1 ;; esac
    while :; do case "$_hm_h" in 0?*) _hm_h=${_hm_h#0} ;; *) break ;; esac; done
    while :; do case "$_hm_m" in 0?*) _hm_m=${_hm_m#0} ;; *) break ;; esac; done
    [ -z "$_hm_h" ] && _hm_h=0
    [ -z "$_hm_m" ] && _hm_m=0
    _HM=$(( _hm_h * 60 + _hm_m ))
    unset _hm_t _hm_h _hm_m
    return 0
}

_scan_eventos() {
    _SC_NOW=""; _SC_NOW_T=0; _SC_T=""; _SC_N=""; _SC_HM=""
    _sc_1t=""; _sc_1n=""; _sc_1hm=""
    _sc_oifs=$IFS
    IFS='
'
    for _sc_e in $1; do
        [ -n "$_sc_e" ] || continue
        _sc_hm=${_sc_e%%|*}; _sc_n=${_sc_e#*|}
        [ -n "$_sc_n" ] || continue
        _hhmm_min "$_sc_hm" || continue
        _sc_v=$_HM
        [ -n "$_sc_1t" ] || { _sc_1t=$_sc_v; _sc_1n=$_sc_n; _sc_1hm=$_sc_hm; }
        if [ "$_sc_v" -le "$2" ] && [ $(( $2 - _sc_v )) -lt "$3" ]; then
            if [ -z "$_SC_NOW" ] || [ "$_sc_v" -gt "$_SC_NOW_T" ]; then
                _SC_NOW=$_sc_n; _SC_NOW_T=$_sc_v
            fi
        fi
        if [ "$_sc_v" -gt "$2" ]; then
            if [ -z "$_SC_T" ] || [ "$_sc_v" -lt "$_SC_T" ]; then
                _SC_T=$_sc_v; _SC_N=$_sc_n; _SC_HM=$_sc_hm
            fi
        fi
    done
    IFS=$_sc_oifs
    if [ -z "$_SC_T" ] && [ -n "$_sc_1t" ]; then
        _SC_T=$(( _sc_1t + 1440 )); _SC_N=$_sc_1n; _SC_HM=$_sc_1hm
    fi
    unset _sc_e _sc_hm _sc_n _sc_v _sc_1t _sc_1n _sc_1hm _sc_oifs
}

proximo_evento() {
    _pe_agenda=""
    _pe_ag="$HOME/.twm/agenda"
    if [ -s "$_pe_ag" ]; then
        _pe_idade=$(( $(date +%s) - $(stat -c %Y "$_pe_ag" 2>/dev/null || echo 0) ))
        [ "$_pe_idade" -lt 7200 ] && _pe_agenda=`cat "$_pe_ag"`
    fi

    _hhmm_min "`TZ=America/Bahia date +%H%M`"
    _pe_ai=$_HM
    [ "$_pe_ai" -lt 0 ] && _pe_ai=0

    _pe_dur=${FUNC_evento_min:-10}
    case "$_pe_dur" in ''|*[!0-9]*) _pe_dur=10 ;; esac
    _pe_jan=$(( _pe_dur + 5 ))

    _scan_eventos "$EVENTOS" "$_pe_ai" "$_pe_jan"
    _pe_fnow=$_SC_NOW; _pe_fnow_t=$_SC_NOW_T
    _pe_ft=$_SC_T; _pe_fn=$_SC_N; _pe_fhm=$_SC_HM

    _pe_anow=""; _pe_anow_t=0; _pe_at=""; _pe_an=""; _pe_ahm=""
    if [ -n "$_pe_agenda" ]; then
        _scan_eventos "$_pe_agenda" "$_pe_ai" "$_pe_dur"
        _pe_anow=$_SC_NOW; _pe_anow_t=$_SC_NOW_T
        _pe_at=$_SC_T; _pe_an=$_SC_N; _pe_ahm=$_SC_HM
    fi

    if [ -n "$_pe_anow" ] || [ -n "$_pe_fnow" ]; then
        if [ -n "$_pe_anow" ]; then _pe_fim=$(( _pe_anow_t + _pe_dur ))
        else                         _pe_fim=$(( _pe_fnow_t + _pe_jan ))
        fi
        _pe_fim=$(( _pe_fim % 1440 ))
        printf "AGORA: %s  (ate %02d:%02d)" "${_pe_anow:-$_pe_fnow}" \
               $(( _pe_fim / 60 )) $(( _pe_fim % 60 ))
        unset _pe_fim
        unset _pe_agenda _pe_ag _pe_idade _pe_ai _pe_jan _pe_dur \
              _pe_fnow _pe_fnow_t _pe_ft _pe_fn _pe_fhm _pe_anow _pe_anow_t _pe_at _pe_an _pe_ahm
        return 0
    fi

    _pe_t=$_pe_ft; _pe_n=$_pe_fn; _pe_hm=$_pe_fhm
    if [ -n "$_pe_at" ]; then
        if [ -z "$_pe_t" ] || [ "$_pe_at" -lt "$_pe_t" ]; then
            _pe_t=$_pe_at; _pe_n=$_pe_an; _pe_hm=$_pe_ahm
        elif [ $(( _pe_at - _pe_t )) -le 10 ]; then
            _pe_t=$_pe_at; _pe_n=$_pe_an; _pe_hm=$_pe_ahm
        fi
    fi

    if [ -z "$_pe_t" ]; then
        printf "Proximo: --"
    else
        _pe_falta=$(( _pe_t - _pe_ai ))
        [ "$_pe_falta" -lt 0 ] && _pe_falta=0
        _pe_h=${_pe_hm%??}; _pe_m=${_pe_hm#??}
        if [ "$_pe_falta" -ge 60 ]; then
            printf "Proximo: %s  %s:%s BRT  (em %dh%02dm)" \
                   "$_pe_n" "$_pe_h" "$_pe_m" $((_pe_falta/60)) $((_pe_falta%60))
        else
            printf "Proximo: %s  %s:%s BRT  (em %dm)" \
                   "$_pe_n" "$_pe_h" "$_pe_m" "$_pe_falta"
        fi
        unset _pe_falta _pe_h _pe_m
    fi
    unset _pe_agenda _pe_ag _pe_idade _pe_ai _pe_jan _pe_dur \
          _pe_fnow _pe_fnow_t _pe_ft _pe_fn _pe_fhm _pe_anow _pe_anow_t _pe_at _pe_an _pe_ahm \
          _pe_t _pe_n _pe_hm
}

_CR=$(printf '\r')
limpa_campo() {
    _CF="$1"
    while :; do
        case "$_CF" in
            *"$_CR") _CF="${_CF%"$_CR"}" ;;
            *)       break ;;
        esac
    done
}

ler_arq() {
    _LIDO=""
    [ -r "$1" ] || return 0
    read -r _LIDO < "$1" 2>/dev/null || :
    return 0
}

# panel.sh - Painel do TWM (Parte 2 de 2)

estado_cor() {
    case "$1" in
        running)                                echo "$C_GREEN" ;;
        paused)                                 echo "$C_CYAN" ;;
        starting|loading|login_retry|restarting) echo "$C_YELLOW" ;;
        dead)                                   echo "$C_RED" ;;
        stopped)                                echo "$C_GRAY" ;;
        *)                                      echo "$C_GRAY" ;;
    esac
}
estado_simbolo() {
    case "$1" in
        running)                                echo "$S_ON" ;;
        paused)                                 echo "$S_PAUSE" ;;
        starting|loading|login_retry|restarting) echo "$S_WAIT" ;;
        dead)                                   echo "$S_ERR" ;;
        stopped)                                echo "$S_OFF" ;;
        *)                                      echo "$S_UNK" ;;
    esac
}

aba_de() {
    ler_arq "$1/pagina"; _p="$_LIDO"
    case "$_p" in
        ""|"/"|"/?out_gate_confirm=true") echo "Página Principal" ;;
        "/?sign_in=1")    echo "Entrando" ;;
        /fights*)         echo "Agenda de Batalhas" ;;
        /arena*)          echo "Arena" ;;
        /career*)         echo "Carreira" ;;
        /cave*)           echo "Caverna" ;;
        /campaign*)       echo "Campanha" ;;
        /coliseum*)       echo "Coliseu" ;;
        /clancoliseum*)   echo "Coliseu do Clã" ;;
        /clanfight*)      echo "Torneio dos Clãs" ;;
        /clandungeon*)    echo "Masmorra do Clã" ;;
        /clandmgfight*)   echo "Duelo do Clã" ;;
        /clan/*quest*)    echo "Missões do Clã" ;;
        /clan/*built*)    echo "Estátua do Clã" ;;
        /clan*)           echo "Clã" ;;
        /altars*)         echo "Altares dos Deuses" ;;
        /undying*)        echo "Vale dos Imortais" ;;
        /king*)           echo "Rei dos Imortais" ;;
        /flagfight*)      echo "Batalha de Bandeiras" ;;
        /league*)         echo "Liga dos Favoritos" ;;
        /trade*)          echo "Troca" ;;
        /effshop*|/lab*)  echo "Aprimoramento" ;;
        /quest*)          echo "Missões" ;;
        /collector*)      echo "Coleções" ;;
        /relic*)          echo "Relíquias" ;;
        /sage*)           echo "Cabana do Sábio" ;;
        /inv*)            echo "Inventário" ;;
        /train*)          echo "Treino" ;;
        /fault*)          echo "Falha" ;;
        /collfight*)      echo "Batalha Coletiva" ;;
        /marathon*)       echo "Maratona" ;;
        /user*)           echo "Meu Herói" ;;
        /settings*)       echo "Configurações" ;;
        /mail*)           echo "Mensagens" ;;
        /questrnd*)       echo "Missão Aleatória" ;;
        /logout*)         echo "Saindo" ;;
        *)                echo "$_p" ;;
    esac
    unset _p
}

combate_de() {
    _d="$1"
    ler_arq "$_d/HP";     _hp="$_LIDO"
    ler_arq "$_d/old_HP"; _old="$_LIDO"
    case "$_hp"  in ''|*[!0-9]*) _hp=""  ;; esac
    case "$_old" in ''|*[!0-9]*) _old="" ;; esac
    [ -n "$_hp" ] || { echo ""; return; }

    if [ "$_hp" -eq 0 ] 2>/dev/null; then
        echo "VOCÊ ESTÁ MORTO"
        unset _d _hp _old
        return
    fi

    if [ -n "$_old" ] && [ "$_old" -gt 0 ] 2>/dev/null; then
        _dif=$((_hp - _old))
        if [ "$_dif" -lt 0 ]; then
            printf 'HP %s  (%s de dano recebido)' "$_hp" "$_dif"
        elif [ "$_dif" -gt 0 ]; then
            printf 'HP %s  (+%s recuperado)' "$_hp" "$_dif"
        else
            printf 'HP %s' "$_hp"
        fi
    else
        printf 'HP %s' "$_hp"
    fi
    unset _d _hp _old _dif
}

pagina_batalha() {
    _pb_f=""
    for _pb_c in "$1/SRC" "$1/src.html" "$1/ccol_src" "$1/col_src" \
                 "$1/flag_src" "$1/ARENA"; do
        [ -s "$_pb_c" ] || continue
        if [ -z "$_pb_f" ] || [ "$_pb_c" -nt "$_pb_f" ]; then _pb_f="$_pb_c"; fi
    done
    printf '%s' "$_pb_f"
    unset _pb_c _pb_f
}

combate_log() {
    _cl_f=`pagina_batalha "$1"`
    [ -n "$_cl_f" ] || return 0
    _cl_n="${2:-2}"
    _cl_w="${3:-60}"
    [ "$_cl_w" -lt 24 ] && _cl_w=24

    awk -v lim="$_cl_n" -v larg="$_cl_w" -v pre="      " \
        -v cLevou="${ESC}[1;31m" -v cUsou="${ESC}[1;32m" \
        -v cDeles="${ESC}[0;37m" -v cFim="${ESC}[0m" '
        { todo = todo $0 " " }
        END {
            gsub(/<\/div>|<\/p>|<\/li>|<\/tr>|<br[^>]*>/, "\n", todo)
            gsub(/<[^>]*>/, " ", todo)
            gsub(/&nbsp;|&#160;/, " ", todo)
            gsub(/\\/, " ", todo)
            n = split(todo, linha, "\n")

            for (i = 1; i <= n; i++) {
                t = limpa(linha[i])
                if (t ~ /acert/ && t ~ /[Vv]oc/ && t !~ /^[Vv]oc/) {
                    quem = t
                    sub(/ +acert.*$/, "", quem)
                    if (length(quem) > 0 && length(quem) < 30) bate[quem] = 1
                }
            }

            achou = 0
            for (i = 1; i <= n && achou < lim; i++) {
                t = limpa(linha[i])
                if (length(t) < 6) continue

                cor = ""
                if (t ~ /^[Vv]oc/)          cor = cUsou
                else if (t ~ /[Vv]oc/)      cor = cLevou
                else {
                    autor = t
                    sub(/ +usou.*$/, "", autor)
                    if (t ~ / usou / && autor in bate) cor = cDeles
                }
                if (cor == "") continue

                if (length(t) > larg) {
                    corte = substr(t, 1, larg - 1)
                    p = match(corte, / [^ ]*$/)
                    if (p > larg / 2) corte = substr(corte, 1, p - 1)
                    t = corte "…"
                }
                print pre cor t cFim
                achou++
            }
        }
        function limpa(x) {
            gsub(/[ \t\r]+/, " ", x)
            sub(/^ /, "", x); sub(/ $/, "", x)
            return x
        }
    ' "$_cl_f" 2>/dev/null

    unset _cl_f _cl_n _cl_w
}

PANEL_LOG_LINHAS="${PANEL_LOG_LINHAS:-2}"
case "$PANEL_LOG_LINHAS" in ''|*[!0-9]*) PANEL_LOG_LINHAS=2 ;; esac

painel_loop() {
NL='
'

while true; do
    [ -t 1 ] && [ "${PANEL_ONCE:-0}" != "1" ] && clear
    agora=$(date +%H:%M:%S)
    _agora_ep=$(date +%s)

    LARG=$(painel_largura)
    if [ "$LARG" -lt 86 ]; then ESTREITO=1; else ESTREITO=0; fi

    n_on=0; n_up=0; n_off=0; n_fight=0; idx=0
    LISTA=""; BATALHAS=""

    while IFS='|' read -r srv user _enc <&3 || [ -n "$srv" ]; do
        limpa_campo "$srv";  srv="$_CF"
        limpa_campo "$user"; user="$_CF"
        case "$srv" in ''|\#*|*[!0-9]*) continue ;; esac
        [ -z "$user" ] && continue
        case "$srv" in 1) tag="BR" ;; *) continue ;; esac

        acc_id="${tag}_${user}"
        acc_dir="$HOME/.twm/${acc_id}"
        status_file="$STATUS_DIR/${acc_id}.status"
        pid_file="$STATUS_DIR/${acc_id}.pid"
        ler_arq "$status_file"; status="${_LIDO:-?}"
        ler_arq "$pid_file";    pid="$_LIDO"

        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            status="dead"
            if [ "${PANEL_SUPERVISE:-0}" = "1" ]; then
                echo "dead" > "$status_file"
                printf "[monitor] relancando worker\n" >> "$acc_dir/twm.log" 2>/dev/null
                launch_worker "$srv" "$user" "" > /dev/null 2>&1
            fi
        fi

        case "$status" in
            running)                                 n_on=$((n_on + 1)) ;;
            starting|loading|login_retry|restarting) n_up=$((n_up + 1)) ;;
            *)                                       n_off=$((n_off + 1)) ;;
        esac
        idx=$((idx + 1))

        nome="$user"; hp="-"; mp="-"; ene="-"; lvl="-"; ouro="-"; prata="-"
        _velho=""
        if [ -s "$acc_dir/stats" ]; then
            IFS='|' read -r nome hp mp ene lvl ouro prata _ts < "$acc_dir/stats"
            [ -z "$nome" ] && nome="$user"

            case "$_ts" in
                ''|*[!0-9]*) ;;
                *) _idade=$(( (_agora_ep - _ts) / 60 ))
                   [ "$_idade" -gt 10 ] && _velho="$_idade min" ;;
            esac
        fi

        case "$status" in
            running)     cor="$C_GREEN";  sim="$S_ON" ;;
            paused)      cor="$C_CYAN";   sim="$S_PAUSE" ;;
            starting|loading|login_retry|restarting)
                         cor="$C_YELLOW"; sim="$S_WAIT" ;;
            dead)        cor="$C_RED";    sim="$S_ERR" ;;
            stopped)     cor="$C_GRAY";   sim="$S_OFF" ;;
            *)           cor="$C_GRAY";   sim="$S_UNK" ;;
        esac

        _aba=$(aba_de "$acc_dir")
        if [ "$status" = "running" ] || [ "$status" = "paused" ]; then
            _cbt=$(combate_de "$acc_dir")
        else
            _cbt=""
        fi
        case "$_cbt" in
            *MORTO*) _cor_c="$C_RED" ;;
            *dano*)  _cor_c="$C_YELLOW" ;;
            *)       _cor_c="$C_GREEN" ;;
        esac

        if [ -n "$_cbt" ]; then
            n_fight=$((n_fight + 1))
            _nw=14; _bw=16
            BATALHAS="${BATALHAS}$(printf "  %b%s %b%-*.*s %b%-*.*s %b%s%b" \
                "$_cor_c" "$I_LIVE" "$C_WHITE" "$_nw" "$_nw" "$nome" \
                "$C_CYAN" "$_bw" "$_bw" "$_aba" "$_cor_c" "$_cbt" "$C_RESET")${NL}"

            if [ "$PANEL_LOG_LINHAS" -gt 0 ]; then
                _log=$(combate_log "$acc_dir" "$PANEL_LOG_LINHAS" $((LARG - 7)))
                [ -n "$_log" ] && BATALHAS="${BATALHAS}$(printf '%s' "$_log")${NL}"
            fi
        fi

        case "$status" in
            running) _estado="ON" ;;
            paused) _estado="PAUSE" ;;
            starting|loading|login_retry|restarting) _estado="UP" ;;
            dead) _estado="OFF" ;;
            stopped) _estado="STOP" ;;
            *) _estado="?" ;;
        esac

        [ "$idx" -gt 1 ] && LISTA="${LISTA}${NL}"

        LISTA="${LISTA}$(printf '%b%s [%d] %b%-20.*s%b %s%b' \
            "$cor" "$sim" "$idx" "$C_WHITE" "20" "$nome" "$C_RESET" "$_estado" "$C_RESET")${NL}"

        LISTA="${LISTA}$(printf '%b%s %s   %s %s   %s %s%b' \
            "$C_GRAY" "$I_HP" "$hp" "$I_EN" "$ene" "$I_LV" "$lvl" "$C_RESET")${NL}"

        LISTA="${LISTA}$(printf '%b%s %s   %s %s%b' \
            "$C_GRAY" "$I_GO" "$ouro" "$I_SI" "$prata" "$C_RESET")${NL}"

        if [ -n "$_velho" ]; then
            LISTA="${LISTA}$(printf '%b📋 %s  %b(parado %s)%b' "$C_CYAN" "$_aba" "$C_YELLOW" "$_velho" "$C_RESET")${NL}"
        else
            LISTA="${LISTA}$(printf '%b📋 %s%b' "$C_CYAN" "$_aba" "$C_RESET")${NL}"
        fi

        if [ -n "$_cbt" ]; then
            LISTA="${LISTA}$(printf '%b⚔️  %s%b' "$_cor_c" "$_cbt" "$C_RESET")${NL}"
        fi

    done 3< "$ACCOUNTS_FILE"

    if [ "${PANEL_DRAW:-$HAS_TTY}" = 1 ]; then
        painel_regua "$LARG"
        _pad=$((LARG - 38))
        [ "$_pad" -lt 1 ] && _pad=1
        printf "  %b%sTWM Multi-contas%b %b· BR%b%*s%b⌚ %s%b\n" \
               "$C_CYAN$C_BOLD" "$I_TIT" "$C_RESET" "$C_DIM" "$C_RESET" \
               "$_pad" '' "$C_WHITE" "$agora" "$C_RESET"
        printf "  %bDRAGONS 🐉%b\n" "$C_DIM" "$C_RESET"
        painel_regua "$LARG"
        printf "%b" "$LISTA"
        painel_regua "$LARG"

        if [ "$n_fight" -gt 0 ]; then
            printf "  %b%sAO VIVO — BATALHAS (%s)%b\n" \
                "$C_RED$C_BOLD" "$I_LIVE" "$n_fight" "$C_RESET"
            printf "%b" "$BATALHAS"
            painel_regua "$LARG"
        fi

        if [ "$LARG" -ge 100 ]; then
            printf "  %b%s %s online%b  %b%s %s subindo%b  %b%s %s parada(s)%b   %b%s%s%b\n" \
                   "$C_GREEN" "$S_ON" "$n_on" "$C_RESET" \
                   "$C_YELLOW" "$S_WAIT" "$n_up" "$C_RESET" \
                   "$C_RED" "$S_ERR" "$n_off" "$C_RESET" \
                   "$C_YELLOW" "$I_EVT" "$(proximo_evento)" "$C_RESET"
        else
            if [ "$ESTREITO" = 1 ]; then
                printf "  %b%s %s%b  %b%s %s%b  %b%s %s%b\n" \
                       "$C_GREEN" "$S_ON" "$n_on" "$C_RESET" \
                       "$C_YELLOW" "$S_WAIT" "$n_up" "$C_RESET" \
                       "$C_RED" "$S_ERR" "$n_off" "$C_RESET"
            else
                printf "  %b%s %s online%b  %b%s %s subindo%b  %b%s %s parada(s)%b\n" \
                       "$C_GREEN" "$S_ON" "$n_on" "$C_RESET" \
                       "$C_YELLOW" "$S_WAIT" "$n_up" "$C_RESET" \
                       "$C_RED" "$S_ERR" "$n_off" "$C_RESET"
            fi
            printf "  %b%s%.*s%b\n" "$C_YELLOW" "$I_EVT" \
                   "$((LARG - 2))" "$(proximo_evento)" "$C_RESET"
        fi

        if [ "${PANEL_SUPERVISE:-0}" != "1" ]; then
            if [ "$LARG" -lt 44 ]; then
                _msg="somente leitura"
            elif [ "$ESTREITO" = 1 ]; then
                _msg="somente leitura — ctrl+c nao para nada"
            else
                _msg="somente leitura — nao interfere nas contas; ctrl+c sai sem parar nada"
            fi
            printf "  %b%.*s%b\n" "$C_DIM" "$((LARG - 2))" "$_msg" "$C_RESET"
        fi

        if painel_desatualizado; then
            if [ "${PANEL_SUPERVISE:-0}" = "1" ]; then
                _msg="codigo atualizado — reinicie: ./stop.sh && ./play.sh"
            elif [ "$LARG" -lt 50 ]; then
                _msg="codigo novo — ctrl+c e ./status.sh"
            else
                _msg="codigo atualizado — feche e abra o painel: ctrl+c e ./status.sh"
            fi
            printf "  %b%.*s%b\n" "$C_YELLOW" "$((LARG - 2))" "$_msg" "$C_RESET"
        fi

        if [ "$n_off" -gt 0 ] && [ "${PANEL_SUPERVISE:-0}" != "1" ]; then
            if [ "$LARG" -lt 50 ]; then
                _msg="$n_off fora do ar - rode ./play.sh"
            else
                _msg="$n_off conta(s) fora do ar — suba com: ./play.sh"
            fi
            printf "  %b%.*s%b\n" "$C_RED" "$((LARG - 2))" "$_msg" "$C_RESET"
        fi
        painel_regua "$LARG"
    fi

    [ "${PANEL_ONCE:-0}" = "1" ] && break

    sleep "${PANEL_INTERVAL:-5}"
done
}
