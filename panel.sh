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
# O caractere ESC de verdade. As constantes acima sao strings com "\033"
# literal, que so viram cor quando passam pelo printf %b — e o awk do
# registro de combate imprime direto, sem esse tratamento.
ESC=$(printf '\033')

# Emoji ou ASCII.
#
# Muitos terminais (Windows Terminal sem fonte de emoji, consoles antigos)
# desenham quadrados no lugar dos simbolos. Por isso o padrao e ASCII com
# cor, que funciona em qualquer lugar. Para ligar os emoji:
#     TWM_EMOJI=1 ./play.sh
if [ "${TWM_EMOJI:-0}" = "1" ]; then
    I_HP="❤️ "; I_EN="⚡ "; I_LV="⭐ "; I_GO="🪙 "; I_SI="🥈 "
    I_TIT="🎮 "; I_ACT="📋 "; I_EVT="⏰ "; I_ARROW="▸"; I_LIVE="⚔️ "
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
    I_TIT=""; I_ACT=""; I_EVT=""; I_ARROW="->"; I_LIVE=""
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

# O codigo em disco e mais novo que ESTE processo de painel?
#
# POR QUE ISTO EXISTE
#
# O painel le o panel.sh uma unica vez, quando sobe. Depois de um git pull os
# arquivos no disco sao novos, mas um painel que ja estava aberto continua
# desenhando com o codigo anterior — e nao ha nada na tela que diga isso.
#
# Aparece mais no WSL do que no Termux por causa do jeito de usar: o README
# recomenda tmux, e o ./status.sh fica num painel do tmux que sobrevive a
# tudo — inclusive ao ./stop.sh, que so encerra os workers e o play.sh. No
# Termux o painel costuma morrer junto com a janela, entao o problema nao
# aparece.
#
# A data de /proc/$$ e a hora em que este processo comecou. O teste "-nt" e
# interno ao shell: 47 comparacoes por desenho, nenhum processo criado.
painel_desatualizado() {
    for _pd_f in "$TWMDIR"/*.sh; do
        [ -f "$_pd_f" ] || continue
        if [ "$_pd_f" -nt "/proc/$$" ]; then unset _pd_f; return 0; fi
    done
    unset _pd_f
    return 1
}

# "HHMM" -> minutos desde a meia-noite, em $_HM. Sem criar processo.
#
# O zero a esquerda e removido na mao: "$((10#$_h))" e bashism (o dash e o
# toybox recusam) e sem isso varias implementacoes leem "08" como octal.
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

# Percorre UMA lista de eventos e devolve, em variaveis:
#   _SC_NOW  nome do evento acontecendo agora (vazio se nenhum)
#   _SC_NOW_T  minuto em que ele comecou
#   _SC_T    minuto do proximo evento
#   _SC_N    nome do proximo
#   _SC_HM   horario "HHMM" do proximo
#
# CORRECAO: a versao anterior parava no PRIMEIRO horario maior que agora,
# confiando que a lista estivesse ordenada. Aqui procura o MENOR, entao uma
# agenda fora de ordem — a pagina /fights/ nao vem em ordem cronologica —
# deixa de apontar um evento qualquer.
#
# $1 lista, $2 agora em minutos, $3 duracao da janela do evento
_scan_eventos() {
    _SC_NOW=""; _SC_NOW_T=0; _SC_T=""; _SC_N=""; _SC_HM=""
    _sc_1t=""; _sc_1n=""; _sc_1hm=""
    _sc_oifs=$IFS
    # IFS so de nova linha: sem isto o "for" divide tambem nos espacos e
    # nomes como "Coliseu do Cla" viram tres iteracoes.
    IFS='
'
    for _sc_e in $1; do
        [ -n "$_sc_e" ] || continue
        _sc_hm=${_sc_e%%|*}; _sc_n=${_sc_e#*|}
        [ -n "$_sc_n" ] || continue
        _hhmm_min "$_sc_hm" || continue
        _sc_v=$_HM
        [ -n "$_sc_1t" ] || { _sc_1t=$_sc_v; _sc_1n=$_sc_n; _sc_1hm=$_sc_hm; }
        # Acontecendo agora: comecou ha menos que a duracao da janela.
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
    # Nao sobrou nada hoje: o proximo e o primeiro de amanha.
    if [ -z "$_SC_T" ] && [ -n "$_sc_1t" ]; then
        _SC_T=$(( _sc_1t + 1440 )); _SC_N=$_sc_1n; _SC_HM=$_sc_1hm
    fi
    unset _sc_e _sc_hm _sc_n _sc_v _sc_1t _sc_1n _sc_1hm _sc_oifs
}

# A linha de evento do rodape: "Proximo: Nome  HH:MM BRT  (em Xh Ym)" ou,
# enquanto um evento corre, "AGORA: Nome".
#
# DUAS FONTES, E A MAIS PROXIMA VENCE.
#
# CORRECAO (painel apontando um evento fora de hora): a agenda do jogo
# (~/.twm/agenda, lida de /fights/) substituia por completo a lista fixa. Se
# ela viesse sem um dos eventos — nome grafado de outro jeito, horario que a
# pagina nao mostrou como "HH:MM BRT", agenda escrita antes do evento entrar
# na pagina — aquele evento simplesmente sumia do painel, e o rodape pulava
# direto para o seguinte. Visto em producao: faltando 22 minutos para o Vale
# das 16:00, o painel ja anunciava o Torneio das 19:00.
#
# Agora as duas listas sao consultadas e vale a mais proxima. A lista fixa
# sai do proprio case de horarios do run.sh, ou seja e o que o bot REALMENTE
# vai fazer — com ela no jogo o painel nunca pode anunciar um evento mais
# tarde do que a proxima acao das contas.
#
# Quando as duas apontam o mesmo evento (a fixa marca a inscricao, 5 min
# antes; a agenda marca a hora oficial), prevalece a agenda: e o nome e o
# horario que o jogador ve no jogo.
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

    # DUAS JANELAS, PORQUE AS DUAS LISTAS MARCAM COISAS DIFERENTES.
    #
    # A lista fixa guarda o minuto da INSCRICAO, 5 minutos antes; a agenda do
    # jogo guarda a hora OFICIAL do evento. Usar a mesma janela nas duas faria
    # o "ate" mudar sozinho quando a agenda assumisse — como se o evento
    # tivesse ganhado 5 minutos no meio do caminho.
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

    # ACONTECENDO AGORA — o painel so avanca depois que o evento termina.
    if [ -n "$_pe_anow" ] || [ -n "$_pe_fnow" ]; then
        # Ate quando: o inicio da janela mais a duracao. Sem isso o rodape
        # diz que ha evento mas nao quanto falta para o painel voltar a
        # apontar o proximo.
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

    # A mais proxima das duas listas.
    _pe_t=$_pe_ft; _pe_n=$_pe_fn; _pe_hm=$_pe_fhm
    if [ -n "$_pe_at" ]; then
        if [ -z "$_pe_t" ] || [ "$_pe_at" -lt "$_pe_t" ]; then
            _pe_t=$_pe_at; _pe_n=$_pe_an; _pe_hm=$_pe_ahm
        elif [ $(( _pe_at - _pe_t )) -le 10 ]; then
            # Mesmo evento visto pelas duas: fica o nome e a hora do jogo.
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
        /clandungeon*)    echo "Masmorra do Clã" ;;
        # /clandmgfight e o duelo do cla (evento de 09:25 e 21:25), outra
        # atividade — vinha rotulado como Masmorra e confundia o painel.
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
        # Na tela do celular a frase por extenso empurra o numero para fora
        # do campo de visao. Com o registro da luta logo abaixo dizendo quem
        # bateu e com quanto, a forma curta nao perde nada.
        if [ "${ESTREITO:-0}" = 1 ]; then
            case "$_dif" in
                -*) printf 'HP %s (%s)' "$_hp" "$_dif" ;;
                0)  printf 'HP %s' "$_hp" ;;
                *)  printf 'HP %s (+%s)' "$_hp" "$_dif" ;;
            esac
        elif [ "$_dif" -lt 0 ]; then
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

# ============================================================
#  REGISTRO DA BATALHA AO VIVO
#
#  O painel mostrava so o HP e o dano do ultimo golpe. Isso diz QUANTO a
#  conta levou, nunca DE QUEM nem COM O QUE — e e justamente isso que se
#  quer ver enquanto o evento corre: quem esta batendo, se o golpe foi
#  critico, que habilidade, erva ou pedra a conta usou.
#
#  A pagina da luta ja esta no disco: cada modulo de batalha grava o HTML
#  que acabou de baixar no diretorio da conta. O painel le esse arquivo — o
#  mesmo que o modulo esta usando — e nao custa nenhuma requisicao nova,
#  nem exige alterar os sete modulos de combate.
# ============================================================

# Arquivo da pagina de luta mais recente desta conta.
#
# Cada modulo usa um nome proprio (SRC no torneio/rei/masmorra, src.html
# nos altares, ccol_src no coliseu do cla, e assim por diante). Em vez de
# adivinhar qual evento esta rodando, vale o mais novo: e sempre o da luta
# em andamento.
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

# As ultimas linhas do combate que dizem respeito A ESTA CONTA.
#
# Entram tres coisas, e so elas:
#
#   quem acertou a conta   "Bahamut acertar Voce por 2864 critico"
#   o que a conta usou     "Voce usou Posicao defensiva"
#   a habilidade de quem   "Bahamut usou Contra ataque"
#   esta batendo nela
#
# Golpe de terceiro em terceiro — "Stallone Blood acertar Bahamut" — fica
# de fora de proposito: numa batalha de cla o log inteiro nao caberia na
# tela do celular, e nao e o que se quer acompanhar. Por isso o "usou" so
# passa quando o nome ja apareceu acertando a conta: e a habilidade de quem
# esta batendo nela, nao a de um duelo alheio ao lado.
#
# O log do jogo vem do mais novo para o mais antigo, entao as primeiras
# linhas que casam ja sao as ultimas acoes.
#
# Um unico processo (awk) por conta em luta, e so enquanto ha luta: o bloco
# ao vivo so e montado para quem esta com HP/old_HP no disco.
combate_log() {
    _cl_f=`pagina_batalha "$1"`
    [ -n "$_cl_f" ] || return 0
    _cl_n="${2:-2}"
    _cl_w="${3:-60}"
    [ "$_cl_w" -lt 24 ] && _cl_w=24

    # Cores montadas com o ESC de verdade: quem imprime aqui e o awk, que
    # nao expande "\033" como o printf %b faz no resto do painel.
    awk -v lim="$_cl_n" -v larg="$_cl_w" -v pre="      " \
        -v cLevou="${ESC}[1;31m" -v cUsou="${ESC}[1;32m" \
        -v cDeles="${ESC}[0;37m" -v cFim="${ESC}[0m" '
        { todo = todo $0 " " }
        END {
            # Fim de bloco vira quebra de linha: e o que separa uma acao da
            # seguinte no log do jogo.
            gsub(/<\/div>|<\/p>|<\/li>|<\/tr>|<br[^>]*>/, "\n", todo)
            gsub(/<[^>]*>/, " ", todo)
            gsub(/&nbsp;|&#160;/, " ", todo)
            # O painel imprime tudo com printf %b: uma barra invertida vinda
            # da pagina viraria sequencia de escape no meio do texto.
            gsub(/\\/, " ", todo)
            n = split(todo, linha, "\n")

            # Passada 1: quem acertou esta conta.
            for (i = 1; i <= n; i++) {
                t = limpa(linha[i])
                if (t ~ /acert/ && t ~ /[Vv]oc/ && t !~ /^[Vv]oc/) {
                    quem = t
                    sub(/ +acert.*$/, "", quem)
                    if (length(quem) > 0 && length(quem) < 30) bate[quem] = 1
                }
            }

            # Passada 2: as ultimas acoes que interessam, do topo para baixo.
            achou = 0
            for (i = 1; i <= n && achou < lim; i++) {
                t = limpa(linha[i])
                if (length(t) < 6) continue

                cor = ""
                if (t ~ /^[Vv]oc/)          cor = cUsou      # a conta agiu
                else if (t ~ /[Vv]oc/)      cor = cLevou     # a conta levou
                else {
                    autor = t
                    sub(/ +usou.*$/, "", autor)
                    if (t ~ / usou / && autor in bate) cor = cDeles
                }
                if (cor == "") continue

                # Corta na ultima palavra que couber, e nao no meio de um
                # caractere: acentuado ocupa dois bytes, e um corte cego
                # deixaria meio caractere na tela.
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

# Quantas linhas do registro da luta aparecem por conta. 0 desliga.
#     PANEL_LOG_LINHAS=4 ./status.sh
PANEL_LOG_LINHAS="${PANEL_LOG_LINHAS:-2}"
case "$PANEL_LOG_LINHAS" in ''|*[!0-9]*) PANEL_LOG_LINHAS=2 ;; esac

painel_loop() {
while true; do
    [ -t 1 ] && [ "${PANEL_ONCE:-0}" != "1" ] && clear
    agora=$(date +%H:%M:%S)
    # Epoch uma vez por desenho, nao por conta: serve para medir ha
    # quanto tempo os numeros de cada conta nao sao atualizados.
    _agora_ep=$(date +%s)

    # Remede a cada volta: o celular pode ser girado com o painel aberto.
    LARG=$(painel_largura)
    # 86 e a largura que o layout de coluna unica realmente ocupa:
    # indice + simbolo + nome(18) + os cinco pares rotulo/valor. Medido, nao
    # estimado — com 72 ele ainda estourava em telas de 72 e 80 colunas.
    if [ "$LARG" -lt 86 ]; then ESTREITO=1; else ESTREITO=0; fi

    n_on=0; n_up=0; n_off=0; n_fight=0; idx=0
    LISTA=""; BATALHAS=""

    # Le tambem a ultima linha quando o arquivo nao termina em quebra de
    # linha; sem isto a ultima conta nunca aparecia no painel (ver play.sh).
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
        _velho=""
        if [ -s "$acc_dir/stats" ]; then
            IFS='|' read -r nome hp mp ene lvl ouro prata _ts < "$acc_dir/stats"
            [ -z "$nome" ] && nome="$user"

            # NUMEROS PARADOS: avisa em vez de mentir.
            #
            # O painel mostrava o que estivesse no arquivo, sem dizer de
            # quando era. Se a atualizacao parasse — sessao caida, worker
            # presa numa batalha longa, erro de leitura —, ele seguia
            # exibindo HP, energia, ouro e prata antigos como se fossem de
            # agora, e nao havia como perceber. O carimbo de tempo ja estava
            # gravado no proprio arquivo; faltava usa-lo.
            #
            # O limite e 10 min: a atualizacao normal e a cada 3 min, entao
            # passar de 10 significa que algo esta errado, nao que a conta
            # esta so ocupada.
            case "$_ts" in
                ''|*[!0-9]*) ;;
                *) _idade=$(( (_agora_ep - _ts) / 60 ))
                   [ "$_idade" -gt 10 ] && _velho="$_idade min" ;;
            esac
        fi

        # SESSAO NO JOGO, separada do estado do worker.
        #
        # "[on]" diz que o PROCESSO da conta esta vivo — nao que ela esteja
        # online no jogo. Sao coisas diferentes: com o cookie morto o worker
        # segue pedindo paginas normalmente, e o servidor o ve como visitante
        # anonimo. Era exatamente o caso de contas que apareciam online no
        # painel mas nao no jogo.
        #
        # O worker carimba $TMP/last_ok toda vez que confirma, na propria
        # pagina do descanso, que a sessao esta viva. Passando de 4 minutos
        # sem confirmacao — o descanso roda a cada ~1 min —, a conta ganha o
        # aviso "sessao caida".
        _sessao=""

        # DENTRO DE UM EVENTO O SILENCIO E ESPERADO.
        #
        # O modulo entra em :55, espera ate a hora cheia num laco de sleep e
        # so entao luta. Nessa espera a conta nao pede pagina nenhuma — nao
        # ha o que confirmar —, e cobrar confirmacao a cada 4 minutos fazia
        # o painel anunciar "sessao caida" em praticamente todo evento, com
        # a conta perfeitamente logada.
        #
        # O em_evento guarda o INSTANTE em que o evento comeca, gravado na
        # inscricao. Vale como janela: dez minutos antes (a inscricao) ate
        # quinze depois (a luta). Fora disso o aviso volta a valer — inclusive
        # se o worker morrer no meio e deixar o arquivo para tras.
        _em_ev=0
        ler_arq "$acc_dir/em_evento"; _eve="$_LIDO"
        case "$_eve" in
            ''|*[!0-9]*) ;;
            *) if [ "$_agora_ep" -gt $((_eve - 600)) ] && \
                  [ "$_agora_ep" -lt $((_eve + 900)) ]; then _em_ev=1; fi ;;
        esac

        ler_arq "$acc_dir/last_ok"; _ok="$_LIDO"
        if [ "$_em_ev" = 0 ]; then
            case "$_ok" in
                ''|*[!0-9]*) [ "$status" = "running" ] && _sessao="sessao ?" ;;
                *) [ $(( (_agora_ep - _ok) / 60 )) -gt 4 ] && _sessao="sessao caida" ;;
            esac
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

        # AO VIVO DAS BATALHAS — sobrepoe o painel.
        #
        # Uma conta so entra aqui quando ha combate DE VERDADE em andamento:
        # o combate_de so devolve texto enquanto os modulos de batalha
        # atualizam HP/old_HP, e o descansar()/func_cat apagam esses arquivos
        # ao fim da luta. E separado do indicador de atividade: aquele diz o
        # que a conta faz; este mostra a luta em detalhe (HP, dano, morte).
        if [ -n "$_cbt" ]; then
            n_fight=$((n_fight + 1))

            # LARGURA DA COLUNA DE ATIVIDADE: FIXA, NAO ELASTICA.
            #
            # CORRECAO: era "LARG - 30", ou seja a atividade era esticada ate
            # quase o fim da tela e empurrava o HP para a margem direita. Num
            # terminal largo isso abria um vao de dezenas de espacos entre o
            # nome e o dano — e no celular o HP saia do campo de visao, que e
            # exatamente a informacao que o bloco existe para mostrar.
            #
            # Agora a coluna tem o tamanho do maior rotulo de atividade e nada
            # mais, entao nome, atividade e HP ficam encostados.
            # Larguras derivadas da tela, e nao fixas: o que sobra depois
            # do HP (ate 16 colunas, "HP 41834 (-2864)") e repartido entre
            # nome e atividade. Assim a linha cabe tanto num terminal de 40
            # colunas quanto num de 120, sem estourar nem sobrar vao.
            if [ "$ESTREITO" = 1 ]; then
                _sobra=$((LARG - 22))
                [ "$_sobra" -lt 14 ] && _sobra=14
                _nw=$(( _sobra * 6 / 10 )); [ "$_nw" -gt 16 ] && _nw=16
                _bw=$(( _sobra - _nw ));    [ "$_bw" -gt 18 ] && _bw=18
                [ "$_bw" -lt 5 ] && _bw=5
            else
                _nw=14; _bw=16
            fi
            BATALHAS="${BATALHAS}$(printf "  %b%s %b%-*.*s %b%-*.*s %b%s%b" \
                "$_cor_c" "$I_LIVE" "$C_WHITE" "$_nw" "$_nw" "$nome" \
                "$C_CYAN" "$_bw" "$_bw" "$_aba" "$_cor_c" "$_cbt" "$C_RESET")
"
            # REGISTRO DA LUTA, LOGO ABAIXO DO NOME.
            #
            # Quem acertou a conta, com quanto e se foi critico; e o que a
            # conta usou. Comeca na margem esquerda, entao continua legivel
            # na tela do celular.
            if [ "$PANEL_LOG_LINHAS" -gt 0 ]; then
                # 6 colunas de recuo + o texto tem de caber na tela.
                _log=$(combate_log "$acc_dir" "$PANEL_LOG_LINHAS" $((LARG - 7)))
                # %s, e nao %b: o texto vem da pagina do jogo e nao deve ter
                # barra invertida interpretada como escape.
                [ -n "$_log" ] && BATALHAS="${BATALHAS}$(printf '%s' "$_log")
"
            fi
        fi

        if [ "$ESTREITO" = 1 ]; then
            # TELA ESTREITA (celular): duas linhas por conta. A primeira traz
            # o INDICADOR DE ATIVIDADE (a aba atual) junto do nome — e como se
            # sabe, num relance, o que cada conta esta fazendo e que o bot
            # continua vivo. Nome com largura util; o resto do espaco vai para
            # a atividade, que e a informacao que muda.
            _nw=$((LARG - 32))
            [ "$_nw" -gt 18 ] && _nw=18
            [ "$_nw" -lt 8 ]  && _nw=8
            _aw=$((LARG - _nw - 13))
            [ "$_aw" -lt 6 ] && _aw=6
            LISTA="${LISTA}$(printf "%b%2s %b%-5s %b%-*.*s %b%s %b%-.*s%b" \
                "$C_DIM" "$idx" "$cor" "$sim" \
                "$C_WHITE" "$_nw" "$_nw" "$nome" \
                "$C_DIM" "$I_ARROW" \
                "$C_CYAN" "$_aw" "$_aba" "$C_RESET")
"
            # Rotulos curtos e truncamento na largura da tela.
            #
            # "HP 98062 Eng 2195 LV 104 Ouro 5,2M PR 1477,8M" tem 45
            # colunas: cabe em 56, estoura em 46 e quebra a linha, que era
            # justamente o defeito. Abreviando fica em 42; o corte final
            # garante que NENHUMA largura quebre, mesmo com valores maiores
            # do que os de hoje.
            if [ "$LARG" -lt 56 ]; then
                _l1="HP"; _l2="En"; _l3="LV"; _l4="Ou"; _l5="PR"
            else
                _l1="$I_HP"; _l2="$I_EN"; _l3="$I_LV"; _l4="$I_GO"; _l5="$I_SI"
            fi
            _num=$((LARG - 4))
            LISTA="${LISTA}$(printf "    %b%.*s%b" "$C_GRAY" "$_num" \
                "$(printf "%s %s %s %s %s %s %s %s %s %s" \
                    "$_l1" "$hp" "$_l2" "$ene" "$_l3" "$lvl" \
                    "$_l4" "$ouro" "$_l5" "$prata")" "$C_RESET")
"
            if [ -n "$_sessao" ]; then
                LISTA="${LISTA}$(printf "    %b%s%b" "$C_RED" "$_sessao" "$C_RESET")
"
            elif [ -n "$_velho" ]; then
                LISTA="${LISTA}$(printf "    %bnumeros parados ha %s%b" \
                    "$C_YELLOW" "$_velho" "$C_RESET")
"
            fi
            # O combate ao vivo (dano/morte) aparece no overlay de batalhas,
            # nao aqui — evita uma terceira linha por conta no celular.
        else
            # CORRECAO: o simbolo ia embutido no %b, sem largura, entao
            # "[on]" (4 colunas) e "[off]" (5) empurravam o nome para
            # posicoes diferentes e a coluna inteira ficava torta. Agora o
            # simbolo tem campo proprio de largura fixa.
            LISTA="${LISTA}$(printf "%b%2s %b%-5s %b%-18.18s %b%s %-7s %b%s %-10s %b%s %-4s %b%s %-8s %b%s %s%b" \
                "$C_DIM" "$idx" "$cor" "$sim" \
                "$C_WHITE" "$nome" \
                "$C_RED" "$I_HP" "$hp" \
                "$C_YELLOW" "$I_EN" "$ene" \
                "$C_MAG" "$I_LV" "$lvl" \
                "$C_GOLD" "$I_GO" "$ouro" \
                "$C_GRAY" "$I_SI" "$prata" "$C_RESET")
"
            # INDICADOR DE ATIVIDADE por conta: uma linha compacta e recuada,
            # logo abaixo dos numeros, mostrando a aba atual (o que a conta
            # esta fazendo agora). Substitui a antiga secao "ATIVIDADE EM
            # CONJUNTO" — mesma confirmacao, sem repetir os nomes nem gastar
            # cabecalho e reguas. O combate ao vivo continua no overlay.
            _aw=$((LARG - 8)); [ "$_aw" -lt 6 ] && _aw=6
            if [ -n "$_sessao" ]; then
                _aw=$((_aw - 18)); [ "$_aw" -lt 6 ] && _aw=6
                LISTA="${LISTA}$(printf "     %b%s %b%-*.*s  %b%s%b" \
                    "$C_DIM" "$I_ARROW" "$C_CYAN" "$_aw" "$_aw" "$_aba" \
                    "$C_RED" "$_sessao" "$C_RESET")
"
            elif [ -n "$_velho" ]; then
                _aw=$((_aw - 24)); [ "$_aw" -lt 6 ] && _aw=6
                LISTA="${LISTA}$(printf "     %b%s %b%-*.*s  %bnumeros parados ha %s%b" \
                    "$C_DIM" "$I_ARROW" "$C_CYAN" "$_aw" "$_aw" "$_aba" \
                    "$C_YELLOW" "$_velho" "$C_RESET")
"
            else
                LISTA="${LISTA}$(printf "     %b%s %b%-.*s%b" \
                    "$C_DIM" "$I_ARROW" "$C_CYAN" "$_aw" "$_aba" "$C_RESET")
"
            fi
        fi
    done 3< "$ACCOUNTS_FILE"

    if [ "${PANEL_DRAW:-$HAS_TTY}" = 1 ]; then
        painel_regua "$LARG"
        # O relogio e alinhado a direita pela largura real, nao por um
        # recuo fixo de 26 espacos que so servia para uma tela de 68.
        _tit="  TWM Multi-contas · BR"
        _pad=$((LARG - ${#_tit} - ${#agora} - 1))
        [ "$_pad" -lt 1 ] && _pad=1
        printf "  %b%sTWM Multi-contas%b %b· BR%b%*s%b%s%b\n" \
               "$C_CYAN$C_BOLD" "$I_TIT" "$C_RESET" "$C_DIM" "$C_RESET" \
               "$_pad" '' "$C_WHITE" "$agora" "$C_RESET"
        printf "  %bMod Author: Stephenn Curry%b\n" "$C_DIM" "$C_RESET"
        painel_regua "$LARG"
        printf "%b" "$LISTA"
        painel_regua "$LARG"

        # AO VIVO DAS BATALHAS — sobrepoe o painel.
        #
        # Aparece logo abaixo das contas, em destaque, sempre que ha luta de
        # verdade em andamento (n_fight > 0). Some sozinho quando ninguem esta
        # lutando, sem ocupar espaco.
        if [ "$n_fight" -gt 0 ]; then
            printf "  %b%sAO VIVO — BATALHAS (%s)%b\n" \
                "$C_RED$C_BOLD" "$I_LIVE" "$n_fight" "$C_RESET"
            printf "%b" "$BATALHAS"
            painel_regua "$LARG"
        fi

        # O contador e o proximo evento so cabem na MESMA linha a partir de
        # 100 colunas. Abaixo disso vao em duas — a versao anterior somava
        # 100 caracteres fixos e quebrava em qualquer tela menor.
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
            # Truncado na largura: numa tela muito estreita o nome do evento
            # sozinho ja passa da borda.
            printf "  %b%s%.*s%b\n" "$C_YELLOW" "$I_EVT" \
                   "$((LARG - 2))" "$(proximo_evento)" "$C_RESET"
        fi

        # Aviso curto no celular; a frase longa quebrava em duas linhas.
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

        # PAINEL RODANDO CODIGO ANTIGO.
        #
        # Sem este aviso a atualizacao parece nao ter funcionado: os arquivos
        # sao novos, o bot ja subiu com eles, mas a tela continua igual —
        # porque quem desenha e um processo que subiu antes do git pull.
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

        # Quantas contas precisam de atencao, e o que fazer.
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

    # CORRECAO: eram 20 chamadas de "sleep 1" a cada volta do painel, ou
    # seja 60 forks por minuto so para nao fazer nada. Um unico sleep tem
    # o mesmo efeito e conta um processo em vez de vinte — o que importa
    # no Android, onde o total de processos filhos e limitado.
    # Uma volta so (status.sh -1): desenha e sai, sem dormir.
    [ "${PANEL_ONCE:-0}" = "1" ] && break

    sleep "${PANEL_INTERVAL:-5}"
done
}
