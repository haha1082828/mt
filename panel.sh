#!/bin/sh
# panel.sh - Painel do TWM (biblioteca, nao roda sozinho)
#
# Compartilhado pelo play.sh e pelo status.sh. Por padrao e SOMENTE LEITURA:
# desenha o que os workers escreveram em ~/.twm e nao toca em processo nenhum.
#
# O play.sh liga a supervisao com PANEL_SUPERVISE=1, que faz o laco relancar
# worker morto. O status.sh deixa em 0 e por isso pode ser aberto e fechado a
# vontade, sem derrubar conta nenhuma.
#
# Espera receber de quem sourceia: TWMDIR, STATUS_DIR, ACCOUNTS_FILE,
# server_tag(), clean_field() e — so quando PANEL_SUPERVISE=1 — launch_worker().

# ============================================================
#  PAINEL
#  So faz sentido com terminal. Sob systemd (ou qualquer saida
#  redirecionada) seria reimpresso a cada 20s no journal; nesse
#  caso o laco segue supervisionando e relancando, em silencio.
# ============================================================
if [ -t 1 ]; then HAS_TTY=1; else HAS_TTY=0; fi

# Cores
C_RESET='\033[0m';   C_DIM='\033[2m';      C_BOLD='\033[1m'
C_CYAN='\033[1;36m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'
C_RED='\033[1;31m';  C_MAG='\033[1;35m';   C_WHITE='\033[1;37m'
C_GOLD='\033[0;33m'; C_GRAY='\033[0;37m';  C_BLUE='\033[1;34m'

# Emoji ou ASCII.
#
# Muitos terminais (Windows Terminal sem fonte de emoji, consoles antigos)
# desenham quadrados no lugar dos simbolos. Por isso o padrao e ASCII com
# cor, que funciona em qualquer lugar. Para ligar os emoji:
#     TWM_EMOJI=1 ./play.sh
if [ "${TWM_EMOJI:-1}" = "1" ]; then
    I_HP="❤️ "; I_EN="⚡ "; I_LV="⭐ "; I_GO="🪙 "; I_SI="🥈 "
    I_TIT="🎮 "; I_ACT="📋 "; I_EVT="⏰ "; I_ARROW="▸"
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
else
    I_HP="HP"; I_EN="Eng"; I_LV="LV"; I_GO="Ouro"; I_SI="PR"
    I_TIT=""; I_ACT=""; I_EVT=""; I_ARROW="->"
    S_ON="[on]"; S_WAIT="[..]"; S_ERR="[off]"; S_OFF="[--]"; S_UNK="[??]"; S_PAUSE="[||]"
    A_CLANFIGHT="Torneio do Clã";   A_ALTARES="Altares dos Deuses"
    A_VALE="Vale dos Imortais";     A_REI="Rei dos Imortais"
    A_CLANCOL="Coliseu do Clã";     A_MASMORRA="Masmorra do Clã"
    A_CLANQUEST="Missões do Clã";   A_BANDEIRAS="Batalha de Bandeiras"
    A_COLISEU="Coliseu";            A_ARENA="Arena"
    A_CARREIRA="Carreira";          A_CAVERNA="Caverna"
    A_CAMPANHA="Campanha";          A_LIGA="Liga dos Favoritos"
    A_TROCA="Troca Prata/Ouro";     A_SABIO="Cabana do Sábio"
    A_EVENTO="Evento Especial";     A_DESCANSO="Descansando"
    A_NONE="-"
fi

# Largura do terminal.
#
# CORRECAO: o painel era fixo em 68 colunas. A tela de um celular no Termux
# tem por volta de 56, entao cada conta quebrava no meio ("Ouro 3" numa
# linha e "16" na seguinte), o rodape partia "Proximo: Eve / nto especial" e
# o painel virava um bloco ilegivel.
#
# Tres fontes, da mais confiavel para a menos: stty (sempre presente e le o
# tamanho REAL da janela), tput (precisa do ncurses) e $COLUMNS (so existe
# em shell interativo, e nao acompanha o giro da tela).
painel_largura() {
    # Override manual: TWM_COLS=50 ./status.sh
    # Serve para quem usa fonte grande no Termux, onde a deteccao acerta o
    # numero de colunas mas o texto ainda estoura.
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
    # 36 e a largura minima em que todo o painel cabe (verificado de 36 a 120).
    [ "$_pw" -lt 36 ] && _pw=36
    [ "$_pw" -gt 120 ] && _pw=120
    printf '%s' "$_pw"
}

# Desenha a linha separadora na largura da tela.
painel_regua() {
    _rn=$1
    _rs=""
    while [ "${#_rs}" -lt "$_rn" ]; do
        _rs="$_rs----------"
    done
    printf '%b%.*s%b\n' "$C_BLUE" "$_rn" "$_rs" "$C_RESET"
    unset _rn _rs
}

# Agenda de eventos, extraida do case de horarios do run.sh.
# Horarios em America/Bahia (BRT), que e o fuso usado pelos workers.
EVENTOS="0030|Coliseu
0925|Evento especial
0955|Imortais
1010|Batalha de Bandeiras
1028|Coliseu do Cla
1055|Batalha de Clas
1225|Rei dos Imortais
1355|Altares
1458|Coliseu do Cla
1555|Imortais
1610|Batalha de Bandeiras
1625|Rei dos Imortais
1855|Batalha de Clas
2055|Altares
2125|Evento especial
2155|Imortais
2225|Rei dos Imortais"

# Devolve: "Nome  HH:MM BRT  (em Xh Ym)"
proximo_evento() {
    # Agenda oficial do jogo, escrita pelo worker a partir de /fights/.
    # Usada quando tiver menos de 2 horas; caso contrario cai na lista
    # fixa abaixo, que foi conferida contra o jogo e bate com folga de
    # 2 a 5 minutos (janela em que o bot se prepara para entrar).
    _ag="$HOME/.twm/agenda"
    if [ -s "$_ag" ]; then
        _idade=$(( $(date +%s) - $(stat -c %Y "$_ag" 2>/dev/null || echo 0) ))
        if [ "$_idade" -lt 7200 ]; then
            # Aqui o cat continua: sao varias linhas, e o read builtin le
            # so a primeira. E uma vez por desenho, nao por conta.
            EVENTOS=`cat "$_ag"`
        fi
    fi
    _agora=`TZ=America/Bahia date +%H%M`
    _ai=`printf %s "$_agora" | sed "s/^0*//"`; [ -z "$_ai" ] && _ai=0
    _pn=""; _pt=""
    # IFS so de nova linha: sem isto o "for" divide tambem nos espacos
    # e nomes como "Coliseu do Cla" viram tres iteracoes.
    _oifs=$IFS
    IFS="
"
    for _e in $EVENTOS; do
        _t=${_e%%|*}; _n=${_e#*|}
        _ti=`printf %s "$_t" | sed "s/^0*//"`; [ -z "$_ti" ] && _ti=0
        if [ "$_ti" -gt "$_ai" ]; then _pn=$_n; _pt=$_t; break; fi
    done
    IFS=$_oifs
    # Nenhum restante hoje: o proximo e o primeiro de amanha.
    if [ -z "$_pt" ]; then
        _pe=`printf %s "$EVENTOS" | head -n1`
        _pt=${_pe%%|*}; _pn=${_pe#*|}
        _ti=`printf %s "$_pt" | sed "s/^0*//"`; [ -z "$_ti" ] && _ti=0
        _falta=$(( (24*60) - (_ai/100*60 + _ai%100) + (_ti/100*60 + _ti%100) ))
    else
        _falta=$(( (_ti/100*60 + _ti%100) - (_ai/100*60 + _ai%100) ))
    fi
    _hh=`printf %s "$_pt" | cut -c1-2`; _mm=`printf %s "$_pt" | cut -c3-4`
    if [ "$_falta" -ge 60 ]; then
        printf "%s  %s:%s BRT  (em %dh%02dm)" "$_pn" "$_hh" "$_mm" $((_falta/60)) $((_falta%60))
    else
        printf "%s  %s:%s BRT  (em %dm)" "$_pn" "$_hh" "$_mm" "$_falta"
    fi
}


# Le a primeira linha de um arquivo para $_LIDO, SEM criar processo.
#
# CORRECAO (SIGKILL / "signal 9"): cada `cat arquivo` numa substituicao de
# comando e um fork+exec. O painel fazia ~12 por conta a cada desenho
# (estado, simbolo, aba, combate, status, pid) — com 6 contas, uma rajada
# de ~72 processos a cada 20 segundos, no mesmo instante em que os workers
# estavam requisitando. Isso sozinho ja passava do limite de 32 processos
# filhos do Android 12+.
#
# O "read" e builtin do shell: zero processos. O "|| :" existe porque o
# arquivo e gravado com printf sem quebra de linha, e nesse caso o read
# preenche a variavel mas devolve 1.
# Limpa um campo do accounts.conf para $_CF, SEM criar processo.
#
# CORRECAO: o clean_field faz `printf | tr -d | tr -d` — um subshell e dois
# tr por chamada. O painel o chamava duas vezes por conta (servidor e
# usuario): 36 processos por desenho, so para tirar um \r que quase nunca
# existe. Aqui a limpeza e feita com substituicao de parametro, que e
# interna ao shell.
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

# Nome da aba em que a conta esta agora.
#
# O fetch_page grava o caminho acessado em $TMP/pagina, entao aqui e so
# traduzir. Descanso deixa de ser um rotulo generico: quando a conta volta
# para "/", o painel mostra "Pagina Principal", que e onde ela de fato esta.
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
        /clandungeon*|/clandmgfight*) echo "Masmorra do Clã" ;;
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

# Relatorio de combate: HP ao vivo e dano recebido.
#
# Os modulos de combate mantem os arquivos HP e old_HP no diretorio da
# conta durante a luta. Comparando os dois sai o dano levado desde a
# ultima acao, sem precisar alterar os sete modulos de batalha.
#
# Devolve uma das formas:
#   "VOCE ESTA MORTO"            HP zerado
#   "-142 de dano recebido"      perdeu vida desde a ultima leitura
#   "+380 recuperado"            curou
#   ""                           fora de combate
combate_de() {
    _d="$1"
    # Antes: `cat X | tr -cd 0-9` — dois processos por arquivo, quatro por
    # conta. O read e builtin e o case valida sem chamar o tr.
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

painel_loop() {
while true; do
    [ -t 1 ] && [ "${PANEL_ONCE:-0}" != "1" ] && clear
    agora=$(date +%H:%M:%S)

    # Remede a cada volta: o celular pode ser girado com o painel aberto.
    LARG=$(painel_largura)
    # 86 e a largura que o layout de coluna unica realmente ocupa:
    # indice + simbolo + nome(18) + os cinco pares rotulo/valor. Medido, nao
    # estimado — com 72 ele ainda estourava em telas de 72 e 80 colunas.
    if [ "$LARG" -lt 86 ]; then ESTREITO=1; else ESTREITO=0; fi

    n_on=0; n_up=0; n_off=0; idx=0
    LISTA=""; ATIV=""

    while IFS='|' read -r srv user _enc <&3; do
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

        # O PID esta gravado mas o processo sumiu.
        #
        # Supervisionando (play.sh), relanca. Somente leitura (status.sh),
        # apenas mostra "off" — abrir o painel NUNCA pode mexer nos workers,
        # e esse era justamente o defeito: a unica forma de rever o painel
        # era rodar o play.sh, que derrubava as 6 contas que estavam boas.
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            status="dead"
            if [ "${PANEL_SUPERVISE:-0}" = "1" ]; then
                echo "dead" > "$status_file"
                printf "[monitor] relancando worker\n" >> "$acc_dir/twm.log" 2>/dev/null
                launch_worker "$srv" "$user" "" > /dev/null 2>&1
            fi
        fi

        # CORRECAO: tudo que nao fosse "running" entrava em "parada(s)" —
        # inclusive "loading" e "login_retry", que sao contas SUBINDO. Seis
        # contas autenticando viravam "6 parada(s)", uma leitura que nao
        # corresponde ao que esta acontecendo.
        case "$status" in
            running)                                 n_on=$((n_on + 1)) ;;
            starting|loading|login_retry|restarting) n_up=$((n_up + 1)) ;;
            *)                                       n_off=$((n_off + 1)) ;;
        esac
        idx=$((idx + 1))

        nome="$user"; hp="-"; mp="-"; ene="-"; lvl="-"; ouro="-"; prata="-"
        if [ -s "$acc_dir/stats" ]; then
            IFS='|' read -r nome hp mp ene lvl ouro prata _ts < "$acc_dir/stats"
            [ -z "$nome" ] && nome="$user"
        fi

        # Atribuicao direta no lugar de "cor=$(estado_cor ...)": a
        # substituicao de comando forka mesmo para uma funcao de uma linha.
        case "$status" in
            running)     cor="$C_GREEN";  sim="$S_ON" ;;
            paused)      cor="$C_CYAN";   sim="$S_PAUSE" ;;
            starting|loading|login_retry|restarting)
                         cor="$C_YELLOW"; sim="$S_WAIT" ;;
            dead)        cor="$C_RED";    sim="$S_ERR" ;;
            stopped)     cor="$C_GRAY";   sim="$S_OFF" ;;
            *)           cor="$C_GRAY";   sim="$S_UNK" ;;
        esac

        # Aba atual + relatorio de combate (HP ao vivo, dano, morte)
        _aba=$(aba_de "$acc_dir")
        # Os arquivos HP/old_HP ficam no disco depois que o worker morre.
        # Mostrar "-1110 de dano recebido" numa conta fora do ar e uma
        # leitura falsa de combate — o combate acabou junto com o processo.
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

        if [ "$ESTREITO" = 1 ]; then
            LISTA="${LISTA}$(printf "\n%b[%02s]%b  %b%s%b  %b%s%b\n" \
                "$C_RED$C_BOLD" "$idx" "$C_RESET" "$C_WHITE$C_BOLD" "$nome" "$C_RESET" "$cor" "$sim" "$C_RESET")"
            LISTA="${LISTA}$(printf "     %bHP%b %s    %bEN%b %s    %bLV%b %s\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$hp" "$C_GREEN$C_BOLD" "$C_RESET" "$ene" "$C_GREEN$C_BOLD" "$C_RESET" "$lvl")"
            LISTA="${LISTA}$(printf "     %bOURO%b %s    %bPR%b %s\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$ouro" "$C_GREEN$C_BOLD" "$C_RESET" "$prata")"
            LISTA="${LISTA}$(printf "     %b%s%b" "$C_GRAY" "$_aba" "$C_RESET")"
            [ -n "$_cbt" ] && LISTA="${LISTA}$(printf "  %b%s%b" "$_cor_c" "$_cbt" "$C_RESET")"
            LISTA="${LISTA}\n"
        else
            LISTA="${LISTA}$(printf "\n%b[%02s]%b  %b%-22.22s%b  %b%s%b\n" \
                "$C_RED$C_BOLD" "$idx" "$C_RESET" "$C_WHITE$C_BOLD" "$nome" "$C_RESET" "$cor" "$sim" "$C_RESET")"
            LISTA="${LISTA}$(printf "     %bHP%b %-8s  %bEN%b %-7s  %bLV%b %-5s  %bOURO%b %-9s  %bPR%b %s\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$hp" "$C_GREEN$C_BOLD" "$C_RESET" "$ene" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$lvl" "$C_GREEN$C_BOLD" "$C_RESET" "$ouro" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$prata")"
            if [ -n "$_cbt" ]; then
                ATIV="${ATIV}$(printf "     %b%s%b  %b▸%b  %b%s%b  %b%s%b\n" \
                    "$C_WHITE" "$nome" "$C_RESET" "$C_DIM" "$C_RESET" "$C_CYAN" "$_aba" "$C_RESET" "$_cor_c" "$_cbt" "$C_RESET")"
            else
                ATIV="${ATIV}$(printf "     %b%s%b  %b▸%b  %b%s%b\n" \
                    "$C_WHITE" "$nome" "$C_RESET" "$C_DIM" "$C_RESET" "$C_CYAN" "$_aba" "$C_RESET")"
            fi
        fi
    done 3< "$ACCOUNTS_FILE"

    if [ "${PANEL_DRAW:-$HAS_TTY}" = 1 ]; then
        # ============================================================
        # DRAGONS — apresentação limpa e responsiva
        # ============================================================
        if [ "$ESTREITO" = 1 ]; then
            printf "%b🐉 DRAGONS%b  %bTWM MULTI-CONTAS%b\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$C_WHITE$C_BOLD" "$C_RESET"
            printf "%b%s%b  •  %s conta(s)  •  %b%s%b\n" \
                "$C_GRAY" "$tag" "$C_RESET" "$n" "$C_GRAY" "$agora" "$C_RESET"

            printf "\n%b⚔️  CONTAS EM CAMPO%b\n" "$C_GREEN$C_BOLD" "$C_RESET"
            printf "%b%s%b" "$C_WHITE" "$LISTA" "$C_RESET"

            printf "\n%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$C_RED" "$C_RESET"
            printf "%b📊  RESUMO%b\n" "$C_GREEN$C_BOLD" "$C_RESET"
            printf "   %b🟢 Online%b     %s\n" "$C_GREEN$C_BOLD" "$C_RESET" "$n_on"
            printf "   %b🟡 Subindo%b    %s\n" "$C_YELLOW$C_BOLD" "$C_RESET" "$n_up"
            printf "   %b🔴 Fora%b       %s\n" "$C_RED$C_BOLD" "$C_RESET" "$n_off"

            printf "\n%b⚔️  PRÓXIMA BATALHA%b\n" "$C_RED$C_BOLD" "$C_RESET"
            printf "   %b%s%b\n" "$C_GREEN$C_BOLD" "$(proximo_evento)" "$C_RESET"

            if [ "$n_off" -gt 0 ] && [ "${PANEL_SUPERVISE:-0}" != "1" ]; then
                printf "\n%b⚠  %s conta(s) fora do ar%b\n" "$C_RED$C_BOLD" "$n_off" "$C_RESET"
            fi
            printf "\n%b🐉 DRAGONS%b  •  atualização a cada %ss\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "${PANEL_INTERVAL:-20}"
        else
            printf "%b🐉 DRAGONS%b   %bTWM MULTI-CONTAS%b   %b%s%b\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$C_WHITE$C_BOLD" "$C_RESET" "$C_GRAY" "$agora" "$C_RESET"
            printf "%b%s%b  •  %s conta(s) em campo\n" "$C_GRAY" "$tag" "$C_RESET" "$n"

            printf "\n%b⚔️  CONTAS EM CAMPO%b\n" "$C_GREEN$C_BOLD" "$C_RESET"
            printf "%b%s%b" "$C_WHITE" "$LISTA" "$C_RESET"

            printf "\n%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$C_RED" "$C_RESET"
            printf "%b📊  RESUMO%b    %b🟢 Online %s%b    %b🟡 Subindo %s%b    %b🔴 Fora %s%b\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "$C_GREEN$C_BOLD" "$n_on" "$C_RESET" \
                "$C_YELLOW$C_BOLD" "$n_up" "$C_RESET" "$C_RED$C_BOLD" "$n_off" "$C_RESET"

            printf "\n%b⚔️  PRÓXIMA BATALHA%b\n" "$C_RED$C_BOLD" "$C_RESET"
            printf "   %b%s%b\n" "$C_GREEN$C_BOLD" "$(proximo_evento)" "$C_RESET"

            if [ -n "$ATIV" ]; then
                printf "\n%b📋  ATIVIDADE%b\n" "$C_GREEN$C_BOLD" "$C_RESET"
                printf "%b%s%b" "$C_WHITE" "$ATIV" "$C_RESET"
            fi
            if [ "${PANEL_SUPERVISE:-0}" != "1" ]; then
                printf "\n%bSomente leitura%b  •  Ctrl+C sai sem parar as contas\n" "$C_GRAY" "$C_RESET"
            fi
            if [ "$n_off" -gt 0 ] && [ "${PANEL_SUPERVISE:-0}" != "1" ]; then
                printf "%b⚠  %s conta(s) fora do ar — use ./play.sh%b\n" "$C_RED$C_BOLD" "$n_off" "$C_RESET"
            fi
            printf "\n%b🐉 DRAGONS%b  •  atualização a cada %ss\n" \
                "$C_GREEN$C_BOLD" "$C_RESET" "${PANEL_INTERVAL:-20}"
        fi
    fi

    # CORRECAO: eram 20 chamadas de "sleep 1" a cada volta do painel, ou
    # seja 60 forks por minuto so para nao fazer nada. Um unico sleep tem
    # o mesmo efeito e conta um processo em vez de vinte — o que importa
    # no Android, onde o total de processos filhos e limitado.
    # Uma volta so (status.sh -1): desenha e sai, sem dormir.
    [ "${PANEL_ONCE:-0}" = "1" ] && break

    sleep "${PANEL_INTERVAL:-20}"
done
}
