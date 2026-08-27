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
#
# CORRECAO: a versao original rodava dentro de ( ... ) e extraia o PID com
#   TEFPID=`echo "$!" | grep -o -E '([0-9]{2,6})'`
# A regex trunca PIDs com 7+ digitos (pid_max pode chegar a 4194304), o que
# fazia o kill acertar um processo QUALQUER do usuario. Agora usa $! direto.
# O "sleep antes do teste" foi mantido de proposito: ele impoe ~1s de
# espacamento entre requisicoes, que e um limitador de taxa natural.
time_exit() {
    TEFPID=$!
    [ -z "$TEFPID" ] && return 0

    # Espacamento deliberado entre requisicoes: limitador de taxa natural,
    # herdado da versao original (que o obtinha do primeiro "sleep 1" do
    # laco de espera).
    sleep 1

    # CORRECAO CRITICA (SIGKILL / "signal 9" no Android 12+):
    #
    # A versao anterior esperava com
    #     while [ n -lt 17 ]; do sleep 1; kill -0 PID; done
    # ou seja ate 17 forks de /bin/sleep POR REQUISICAO, mais o subshell e
    # o curl. Cada conta faz dezenas de requisicoes por ciclo; com 6 contas
    # em paralelo a arvore de processos do Termux passa facilmente dos 32
    # processos "fantasma" que o Android 12+ tolera — e o sistema responde
    # matando a sessao inteira com SIGKILL, sem aviso. E exatamente o
    # "[Process completed (signal 9)]" que aparece no meio do lancamento.
    #
    # O prazo agora e imposto pelo proprio curl (--max-time, em run_curl),
    # entao o processo em segundo plano TEM hora marcada para morrer e
    # basta um "wait" — que nao cria processo nenhum.
    #
    # O argumento continua sendo aceito por compatibilidade com os 100+
    # pontos de chamada, mas quem corta agora e o curl. Nos pontos que
    # chamam run_curl direto o prazo passa de 17s para os 45s padrao do
    # run_curl; o --connect-timeout de 15s ja cobre o caso comum (servidor
    # fora do ar) e o valor maior foi mantido de proposito para nao
    # apertar o login, que e a parte mais fragil do fluxo. Quem precisar
    # de prazo curto define TWM_MAXTIME antes da chamada, como o
    # fetch_page faz.
    wait "$TEFPID" 2>/dev/null
    _te_rc=$?

    # 28 = CURLE_OPERATION_TIMEDOUT.
    if [ "$_te_rc" = "28" ]; then
        printf "timeout: requisicao abortada\n" >> "${TMP:-.}/ERROR_DEBUG"
        unset _te_rc
        return 1
    fi
    unset _te_rc
    return 0
}

# Funcao central de requisicao via curl.
#
# CORRECOES:
#  --proto/--proto-redir : impede que um redirect leve a requisicao (e o
#                          corpo do POST de login) para fora de HTTPS.
#  --max-redirs          : limita cadeia de redirecionamento.
#  --connect-timeout /
#  --max-time            : sem isso, um socket pendurado travava o worker
#                          para sempre (as chamadas de login sao sincronas).
#                          O valor agora sai de $TWM_MAXTIME (45s por
#                          padrao): antes era fixo e o corte real de 17s
#                          vinha do laco de "sleep 1" do time_exit. Quem
#                          impoe o prazo passa a ser o curl; o time_exit so
#                          espera, sem gastar processo.
#  -sS em vez de -s      : mantem silencio de progresso MAS mostra erros,
#                          que antes eram engolidos ("parou e nao sei por que").
#
# Registra em $TMP/pagina o caminho da requisicao que esta saindo.
#
# CORRECAO (painel "ATIVIDADE EM CONJUNTO" congelado): esse registro ficava
# dentro do fetch_page, com o comentario "como todo acesso passa por aqui,
# basta uma linha para cobrir o jogo inteiro". Nao passa. allies.sh,
# altars.sh, arena.sh, clancoliseum.sh, clandmg.sh, clanfight.sh,
# coliseum.sh, flagfight.sh, king.sh, loginlogoff.sh e undying.sh — ou seja
# TODO o codigo de batalha, mais de 100 pontos de chamada — usam run_curl
# direto e nunca tocavam nesse arquivo.
#
# Como o unico fetch_page do fim do ciclo e o descansar(), que volta para
# "/", o painel lia "/" e mostrava "Pagina Principal" praticamente o tempo
# todo, sem nunca acompanhar a batalha em andamento. Registrando aqui, no
# unico ponto por onde TODA requisicao passa de verdade, a coluna passa a
# seguir a conta ao vivo.
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

# Uso normal: roda o curl como filho e devolve a saida.
run_curl() { _rc_run "" "$@"; }

# Uso em segundo plano: SUBSTITUI o processo pelo curl, em vez de deixar um
# shell parado esperando por ele.
#
# CORRECAO (SIGKILL / "signal 9"): "run_curl ... &" forka um shell que so
# serve para lancar o curl e esperar — dois processos onde um basta. Com o
# exec o filho VIRA o curl (comprovado: sem exec ficam dash+sleep, com exec
# fica so o sleep).
#
# Isso importa porque o Android 12+ mata a sessao inteira acima de 32
# processos filhos, e a conta estava justamente no limite:
#     13 persistentes (play.sh + 6 worker.sh + 6 twm.sh)
#   + 6 x 3 por requisicao (subshell + curl + sleep)  = 31
# Qualquer grep de parsing que nascesse junto estourava. Sem o subshell:
#     13 + 6 x 2 = 25, com folga para os processos transitorios.
run_curl_exec() { _rc_run "exec" "$@"; }

# Acessa qualquer pagina pelo caminho relativo.
#
# CORRECAO (SIGKILL / "signal 9"): a espera era feita com time_exit, que
# sondava com "sleep 1" — subshell + curl + ate 17 forks de sleep, ou seja
# ate 19 processos POR PAGINA. Com 6 contas e dezenas de paginas por ciclo,
# o limite de processos "fantasma" do Android 12+ era estourado e a sessao
# do Termux inteira morria com SIGKILL.
#
# Agora sao 3 processos fixos por pagina (subshell + curl + o sleep de
# espacamento) e o prazo e imposto pelo proprio curl. Medido em 10 paginas
# contra um servidor de 2,5s: 30 forks de sleep antes, 10 depois, no mesmo
# tempo total. De quebra o codigo passa a saber POR QUE a requisicao
# falhou, em vez de so "acabou o tempo".
fetch_page() {
    relative_url="$1"
    output_file="${2:-$TMP/SRC}"

    TWM_MAXTIME=17
    run_curl_exec "${URL}${relative_url}" > "$output_file" 2>/dev/null &
    _fp_pid=$!
    unset TWM_MAXTIME

    # ESPACAMENTO ENTRE REQUISICOES
    #
    # O "sleep 1" fica EM PARALELO com a requisicao, nao depois dela.
    #
    # E o mesmo espacamento minimo de 1s por requisicao que a versao
    # anterior tinha — nela a primeira volta do laco de espera corria
    # junto com o curl. Colocado depois do curl, ele viraria 1s de atraso
    # somado a CADA pagina: com ~90 paginas por ciclo, mais de um minuto
    # perdido por conta, por ciclo. Medido: 10 paginas em 30s (em paralelo)
    # contra 35s (em serie).
    # TWM_PACING=0 dispensa esse processo: o proprio tempo de ida e volta
    # da requisicao (meio segundo a dois no servidor do jogo) ja espaca as
    # chamadas. Vale no Android 12, onde CADA processo conta para o limite
    # de 32 — sao 6 "sleep" parados, um por conta, so para esperar.
    # O play.sh liga isso sozinho quando detecta que o limite aperta.
    _fp_pace="${TWM_PACING:-1}"
    case "$_fp_pace" in ''|*[!0-9]*) _fp_pace=1 ;; esac
    [ "$_fp_pace" -gt 0 ] && sleep "$_fp_pace"

    wait "$_fp_pid" 2>/dev/null
    _fp_rc=$?
    unset _fp_pid _fp_pace

    if [ "$_fp_rc" != "0" ]; then
        printf "curl %s: %s\n" "$_fp_rc" "$relative_url" >> "${TMP:-.}/ERROR_DEBUG"
        unset _fp_rc
        return 1
    fi
    unset _fp_rc
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

    # CORRECAO: se a requisicao foi cortada pelo time_exit, FIXHP/FIXMP ficam
    # vazios e o awk fazia divisao por zero -> "nan"/"inf" nas comparacoes.
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

# Extrai os dados da conta de uma pagina /user ja baixada e grava em
# $TMP/stats, que o painel do play.sh le. Nenhuma requisicao extra: o
# login_logoff() ja baixa essa pagina a cada ciclo.
#
# Campos nao encontrados viram "-" em vez de ficarem vazios, para o painel
# nao mentir sobre um valor que nao conseguiu ler.
#
# Padroes confirmados contra o HTML real do jogo:
#   <title>Grimlock</title>
#   health.png' alt='hp'/> <span class='white'>65312</span>
#   mana.png' alt='mp'/> 470</span>
#   icon/level.png' alt=''/> 40 nivel
#   mana.png' alt=''/> Energia: 2125

# Extrai os dados da conta de uma pagina /user ja baixada e grava em
# $TMP/stats, lido pelo painel do play.sh. Sem requisicao extra: o
# login_logoff() ja baixa essa pagina a cada ciclo.
#
# Padroes confirmados contra o HTML real:
#   <title>Grimlock</title>
#   health.png' alt='hp'/> <span class='white'>65312</span>
#   mana.png' alt='mp'/> 346
#   icon/level.png' alt='lvl'/> 90
#   icon/gold.png' alt='g'/> 396
#   icon/silver.png' alt='s'/> 408,1M
# Energia so aparece em /train: mana.png' alt=''/> Energia: 2125
parse_status() {
    _pg="$1"
    [ -n "$_pg" ] || return 1

    ACC_HP=`printf '%s' "$_pg" | grep -o -E "health\.png' alt='hp'/> <span[^>]*>[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1`
    ACC_MP=`printf '%s' "$_pg" | grep -o -E "mana\.png' alt='mp'/>[^0-9<]{0,4}[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1`
    ACC_LVL=`printf '%s' "$_pg" | grep -o -E "level\.png' alt='[^']*'/> ?[0-9]{1,4}" | grep -o -E '[0-9]{1,4}$' | head -n1`

    # Ouro e prata: guarda o texto como o jogo mostra (pode vir "408,1M").
    ACC_GOLD=`printf '%s' "$_pg" | grep -o -E "gold\.png' alt='g'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" | sed -E "s@.*/> ?@@" | head -n1`
    ACC_SILVER=`printf '%s' "$_pg" | grep -o -E "silver\.png' alt='s'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" | sed -E "s@.*/> ?@@" | head -n1`

    NOWHP="$ACC_HP"; NOWMP="$ACC_MP"

    if [ -n "$ACC_HP" ] && [ -n "$FIXHP" ] && [ "$FIXHP" -gt 0 ] 2>/dev/null; then
        HPPER=`awk -v a="$ACC_HP" -v b="$FIXHP" 'BEGIN{printf "%.0f", a/b*100}'`
    else
        HPPER=""
    fi

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "${ACC:-$TWM_USER}" "${ACC_HP:--}" "${ACC_MP:--}" "${ACC_ENE:--}" \
        "${ACC_LVL:--}" "${ACC_GOLD:--}" "${ACC_SILVER:--}" "$(date +%s)" \
        > "$TMP/stats" 2>/dev/null

    unset _pg
}

# Dados que so existem na pagina /train: HP maximo e energia.
# Uma requisicao por ciclo de start(), nao por minuto.
fetch_train_stats() {
    _t=`run_curl "${URL}/train" 2>/dev/null`
    [ -n "$_t" ] || return 1
    FIXHP=`printf '%s' "$_t" | grep -o -E '\([0-9]{1,9}\)' | head -n1 | tr -d '()'`
    ACC_ENE=`printf '%s' "$_t" | grep -o -E "Energia:? ?[0-9][0-9.,']{0,14}[KMBkmb]?" | sed -E 's@.*:? ?@@' | head -n1`
    [ -z "$ACC_ENE" ] && ACC_ENE=`printf '%s' "$_t" | grep -o -E "Energia:? ?[0-9.,']{1,15}" | grep -o -E "[0-9.,']{1,15}$" | head -n1`
    unset _t
}

# Compatibilidade: nome antigo usado pelo twm.sh
fetch_max_hp() { fetch_train_stats; }

# Linha de status no log da conta. Imprime so o que existe.
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

# Le a agenda oficial do jogo em /fights/ e grava em ~/.twm/agenda.
#
# A pagina traz contagem regressiva por evento ("Para iniciar: 10:12:03"),
# confirmado comparando duas leituras espacadas: em 90 segundos o valor
# caiu 1:31. Convertendo para horario absoluto, a agenda do jogo bate com
# a do run.sh, que dispara de 2 a 5 minutos antes para preparar a entrada.
#
# Escreve uma linha por evento: HHMM|Nome
# Uma requisicao por ciclo de start(), e o painel apenas le o arquivo.
atualiza_agenda() {
    _ag="$HOME/.twm/agenda"

    TWM_MAXTIME=17
    _pg=`run_curl "${URL}/fights/" 2>/dev/null`
    unset TWM_MAXTIME
    [ -n "$_pg" ] || return 1

    # CORRECAO 1 (corrida entre as contas): o arquivo temporario era
    # "$_ag.tmp" — o MESMO para as 6 contas, porque a agenda mora em
    # ~/.twm e nao no diretorio da conta. Os workers escreviam nele ao
    # mesmo tempo e o "mv" de um publicava o arquivo pela metade do outro.
    # Agora o temporario leva o PID.
    _tmpf="${_ag}.$$.tmp"
    _rawf="${_ag}.$$.raw"
    : > "$_tmpf"

    printf '%s' "$_pg" \
        | sed 's/<br[^>]*>/\n/g; s/<\/div>/\n/g; s/<[^>]*>//g' \
        | grep -oE "(Vale dos Imortais|Coliseu do clã|Torneio dos Clãs|Rei dos Imortais|Altares dos Deuses|Batalha de Bandeiras)|Para iniciar: [0-9]{1,2}:[0-9]{2}:[0-9]{2}" \
        > "$_rawf" 2>/dev/null

    # CORRECAO 2 (portabilidade — este e o motivo de a agenda nunca
    # aparecer no Termux): a conversao da contagem regressiva para horario
    # absoluto era feita com `date -d "@epoch"`, que e EXTENSAO DO GNU
    # coreutils. O toybox/busybox do Android nao aceita -d: a substituicao
    # devolvia vazio e o arquivo saia com linhas "|Nome". Como o painel so
    # testa se o arquivo tem conteudo, ele trocava a agenda fixa (correta)
    # por essa lista sem horario. A conta agora e aritmetica pura, com o
    # date usado apenas para ler a hora atual — o que funciona em qualquer
    # implementacao.
    #
    # CORRECAO 3 (pareamento): o "paste - -" assumia que todo nome vem
    # seguido do seu contador. Um evento em andamento aparece SEM contador
    # e desalinhava todos os horarios seguintes — cada evento herdava o
    # horario do proximo. O laco abaixo so fecha um par quando o contador
    # vem logo depois do nome, e descarta nome solto.
    _nh=`date +%H | sed 's/^0//'`; [ -z "$_nh" ] && _nh=0
    _nm=`date +%M | sed 's/^0//'`; [ -z "$_nm" ] && _nm=0
    _ns=`date +%S | sed 's/^0//'`; [ -z "$_ns" ] && _ns=0
    _base=$(( _nh * 3600 + _nm * 60 + _ns ))

    _nome=""
    # Le de ARQUIVO, nao de pipe: num pipe o laco roda em subshell e o
    # "$_nome" guardado de uma volta para a outra se perderia.
    while IFS= read -r _ln; do
        case "$_ln" in
            "Para iniciar: "*)
                [ -n "$_nome" ] || continue
                _falta=${_ln#Para iniciar: }
                _h=`printf %s "$_falta" | cut -d: -f1 | sed 's/^0//'`; [ -z "$_h" ] && _h=0
                _m=`printf %s "$_falta" | cut -d: -f2 | sed 's/^0//'`; [ -z "$_m" ] && _m=0
                _s=`printf %s "$_falta" | cut -d: -f3 | sed 's/^0//'`; [ -z "$_s" ] && _s=0
                _abs=$(( (_base + _h * 3600 + _m * 60 + _s) % 86400 ))
                printf '%02d%02d|%s\n' \
                    $(( _abs / 3600 )) $(( _abs % 3600 / 60 )) "$_nome" >> "$_tmpf"
                _nome=""
                ;;
            *)
                _nome="$_ln"
                ;;
        esac
    done < "$_rawf"
    rm -f "$_rawf"

    # CORRECAO 4 (ordem): o proximo_evento do play.sh percorre a lista de
    # cima para baixo e para no primeiro horario MAIOR que agora — ele
    # espera uma agenda diaria ordenada, como a lista fixa. A pagina
    # /fights/ nao vem em ordem cronologica, entao o painel apontava um
    # evento qualquer. Ordena antes de publicar.
    if [ -s "$_tmpf" ]; then
        sort -n "$_tmpf" > "${_tmpf}.s" 2>/dev/null && mv "${_tmpf}.s" "$_tmpf"
        mv "$_tmpf" "$_ag"
    else
        rm -f "$_tmpf"
    fi
    unset _ag _pg _tmpf _rawf _nome _nh _nm _ns _base
}

# Converte "408,7M" / "12K" / "1.234" em numero inteiro.
# O jogo abrevia valores grandes; sem isto "408,7M" viraria 4087.
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
