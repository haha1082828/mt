# shellcheck disable=SC2154
# shellcheck disable=SC2317
func_crono() {
    HOUR=`date +%H | sed 's/^0//'`
    MIN=`date +%M | sed 's/^0//'`
    [ -z "$HOUR" ] && HOUR=0
    [ -z "$MIN" ] && MIN=0
    printf "%s %s\n" "$URL" "`date +%H:%M`"
}

# Lista as funcoes disponiveis (comando "info" no modo interativo).
# CORRECAO: o caminho era "$HOME"/twm/*.sh, resquicio do layout de conta
# unica. No layout multi-contas o codigo fica em $TWMDIR.
info() {
    printf "\n"
    grep -h -o -E '^[[:alnum:]_]+\(\) \{' "$TWMDIR"/*.sh 2>/dev/null \
        | sed 's/() {//' | sort -u
}

# Pausa entre ciclos.
#
# CORRECAO CRITICA (multi-contas): a versao anterior fazia
#     read -r -t "$i" cmd
# para "dormir" $i segundos esperando um comando do usuario. Mas o worker e
# lancado com stdin em /dev/null (play.sh) — o read retorna EOF na hora, a
# pausa nunca acontecia, e o laco "while true; do twm_start; done" do twm.sh
# virava busy-loop de 100% de CPU POR CONTA, com o twm.log crescendo sem
# limite e o start() sendo reexecutado centenas de vezes dentro do mesmo
# minuto (rajada de requisicoes identicas).
#
# Agora: se nao ha terminal, dorme de verdade. Se ha, mantem o modo
# interativo original.
# ============================================================
#  "AGORA": varredura sob demanda, sem esperar o ciclo
#
#  No master bastava apertar ENTER: o func_cat lia o stdin com prazo e
#  qualquer tecla quebrava a espera, entao o laco voltava na hora e a
#  varredura rodava. Aqui isso nao funciona — os workers sobem com
#  "< /dev/null" (nohup+setsid), justamente para sobreviverem ao fechamento
#  do Termux, entao NENHUM ENTER chega neles. O terminal tambem esta ocupado
#  pelo painel, e com 15 contas nao ha um stdin para cada uma.
#
#  O equivalente multi-conta e um arquivo-sinal, como ja e feito com o
#  PAUSED: quem quer a varredura agora cria o arquivo, e o worker o encontra
#  durante a espera.
#
#     $TMP/RUNNOW    (um por conta, criado pelo ./agora.sh)
#
#  O sinal e SEMPRE por conta, nunca global. Um arquivo global so poderia
#  ser apagado por um dos workers, e os demais continuariam a encontra-lo —
#  disparando varredura em laco para sempre. O ./agora.sh escreve um arquivo
#  em cada conta, e cada worker apaga o seu.
# ============================================================

# Ha pedido de varredura imediata para esta conta?
runnow_pedido() {
    [ -f "$TMP/RUNNOW" ]
}

# Consome o pedido e abre os portoes das atividades.
#
# So quebrar a espera nao bastaria: cada atividade tem portao proprio
# (arena 30 min, carreira 15 min, liga 30 min...), entao a varredura
# encontraria tudo fechado e nao faria nada — que e justamente o oposto do
# que se espera ao pedir "agora". Apagando os marcadores, tudo que estiver
# DISPONIVEL no jogo roda na volta seguinte.
#
# Ficam de fora, de proposito, os portoes que espelham regra do jogo e nao
# preferencia nossa: a masmorra (janela de 8h) e a estatua (bonus de 48h).
runnow_consumir() {
    rm -f "$TMP/RUNNOW" 2>/dev/null
    rm -f "$TMP/last_arena"  "$TMP/last_carreira" "$TMP/last_campanha" \
          "$TMP/last_caverna" "$TMP/last_sabio"   "$TMP/last_liga" \
          "$TMP/last_troca"   "$TMP/last_clanquest" "$TMP/last_evento" \
          "$TMP/last_cq"      "$TMP/last_stats" 2>/dev/null
    printf "Varredura sob demanda: portoes liberados\n"
}

# Dorme em fatias, atendendo ao pedido de varredura no meio do caminho.
#
# Antes era um "sleep $i" unico: um pedido feito logo apos o inicio da
# espera so seria visto ate 60s depois. Em fatias de 5s a resposta e quase
# imediata, e continua sendo UM processo de sleep por vez — o que importa no
# Android, onde cada processo conta para o limite de 32.
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

    # DESCANSO REAL NA HOME.
    #
    # Antes aqui so gravava pagina="/" (mentira): a SESSAO no jogo continuava
    # na ultima pagina de verdade — tipicamente /user (stats) ou /clan
    # (checklist), buscadas pelo tarefas_livres no ciclo ocioso. Por isso a
    # "atividade" que os outros jogadores viam era sempre Perfil/Cla, enquanto
    # o painel dizia "Pagina Principal". Agora faz um GET real em "/", entao a
    # conta descansa de fato na home e o pagina="/" passa a ser verdade.
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

        # CORRECAO (seguranca): antes era "$cmd" sem aspas em posicao de
        # comando — qualquer string vinda do stdin era executada. Agora so
        # os comandos previstos rodam.
        case "$cmd" in
            config)      config ;      sleep 1 ; continue ;;
            requer_func) requer_func ; sleep 1 ; continue ;;
            info)        info ;        sleep 1 ; continue ;;
            *) printf "Comando desconhecido: %s\n" "$cmd" ; sleep 1 ; continue ;;
        esac
    done
}

# CORRECAO: "reset" foi removido. Ele executa "stty sane" no TTY que os
# workers herdam do play.sh, o que corrompia o monitor multi-contas na tela
# e enchia o twm.log de sequencias de escape. O "clear" so faz sentido com
# terminal, entao passou a ser condicional.
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

    # ESPERA CURTA NA APROXIMACAO DAS JANELAS DE EVENTO.
    #
    # CORRECAO: com i=60 o worker so reavaliava o relogio uma vez por minuto,
    # e a volta do laco ainda gasta tempo em requisicoes. Janelas estreitas —
    # Coliseu do Cla (:28-:29), Bandeiras (:10-:14), Rei (:25-:29), Torneio e
    # Altares (:55-:59) — podiam ser puladas inteiras: o bot acordava com a
    # janela ja fechada e o evento passava em branco.
    #
    # Perto desses minutos a espera cai para 15s, o que da 4 chances por
    # minuto de entrar na janela. Fora deles segue 60s, sem custo extra.
    #
    # O minuto e lido AQUI, e nao do $MIN: no ramo ocioso do run.sh o
    # func_sleep e chamado ANTES do func_crono, entao o $MIN esta defasado de
    # um ciclo (e vazio na primeira volta) — justamente o erro que faria a
    # espera curta cair no minuto errado.
    _fs_min=`date +%M | sed 's/^0//'`
    case "$_fs_min" in ''|*[!0-9]*) _fs_min=0 ;; esac
    case "$_fs_min" in
        9|10|11|12|13|24|25|26|27|28|29|30|54|55|56|57) i=15 ;;
        *)                                              i=60 ;;
    esac
    unset _fs_min
    func_cat
}

# Intervalo do checklist de missoes do cla.
cq_liberado() {
    _m=${FUNC_cq_min:-15}
    case "$_m" in ''|*[!0-9]*) _m=15 ;; esac
    _u=`cat "$TMP/last_cq" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_m * 60)) ]
}
cq_marcar() { date +%s > "$TMP/last_cq" 2>/dev/null; }

# Atualizacao dos numeros do painel (HP, energia, nivel, ouro, prata).
#
# O stats so era gravado dentro do start(), que roda nos minutos da
# agenda — com vaos de mais de uma hora. O painel exibia valores
# velhos: ouro 128 quando ja era 28, HP 583 quando ja era 656.
# Uma requisicao a /user a cada 3 minutos por conta resolve sem peso.
stats_liberado() {
    _m=${FUNC_stats_min:-3}
    case "$_m" in ''|*[!0-9]*) _m=3 ;; esac
    _u=`cat "$TMP/last_stats" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_m * 60)) ]
}

atualiza_stats() {
    # Preserva a aba atual em TODOS os caminhos de saida. O run_curl
    # registra cada pagina acessada, entao a consulta a /user (e a /train,
    # para a energia) sobrescreve $TMP/pagina.
    #
    # CORRECAO (descanso preso em "Meu Heroi"): a versao anterior so
    # restaurava a aba no caminho de sucesso. Uma falha de rede ou de sessao
    # fazia o `return 1` sair deixando "/user" gravado — e o painel exibia
    # "Meu Heroi" durante o descanso, a cada 3 minutos, ate a proxima escrita.
    _aba_ant=`cat "${TMP}/pagina" 2>/dev/null`

    # CORRECAO (energia congelada): energia e HP maximo so aparecem em /train
    # e regeneram com o tempo. Sem esta chamada, o painel repetia a energia
    # da ultima entrada em start() — que tem vaos de mais de uma hora —,
    # entao ela parecia travada.
    fetch_train_stats 2>/dev/null

    _pg=`run_curl "${URL}/user" 2>/dev/null`

    # SESSAO CAIDA NO OCIO: RECONECTA EM VEZ DE DESISTIR.
    #
    # Este era o motivo de a conta "aparecer no painel mas nao no jogo". O
    # login_logoff — unica funcao que revalida a sessao — so era chamado
    # dentro do start(), que roda apenas nos minutos da agenda. No ocio, que
    # e a maior parte do tempo, ninguem checava nada: aqui a sessao morta era
    # detectada e a funcao apenas devolvia 1, em silencio.
    #
    # Com a sessao morta o bot continua pedindo paginas, mas o servidor ve um
    # visitante anonimo — a conta NAO aparece online para os outros jogadores.
    # Ela so voltava quando o start() rodava num minuto da agenda e
    # reconectava, o que dava exatamente o sintoma: a conta so aparecia
    # durante os eventos do cronograma.
    #
    # Com muitas contas isso e bem mais frequente, porque o servidor derruba
    # sessao com mais facilidade quando ha varias do mesmo IP.
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

# MASMORRA DO CLA: QUEM DECIDE E A PAGINA, NAO O RELOGIO.
#
# CORRECAO: a masmorra era a UNICA atividade presa a uma hora fixa do dia.
# O portao masmorra_na_janela so deixava passar nas horas 02, 10 e 18 e,
# junto com ele, a execucao era marcada como cumprida mesmo quando nenhum
# golpe saia. Bastava a conta estar ocupada, a pagina falhar ou o link nao
# ser reconhecido dentro daquela hora para a janela inteira de 8h ser
# perdida em silencio — no jogo os golpes seguiam disponiveis e o bot nao
# voltava la. E exatamente o sintoma relatado: a atividade disponivel, a
# conta passando por ali e nada sendo feito.
#
# Agora o marcador guarda a PROXIMA TENTATIVA, e ela depende do resultado:
#
#   masmorra_marcar   golpe saiu -> proxima leva so em 7h
#   masmorra_adiar    nao saiu   -> tenta de novo em FUNC_masmorra_min
#
# O custo de reabrir a pagina e uma requisicao por conta a cada 45 min.
masmorra_liberada() {
    # A chave existia no config.cfg desde sempre e NINGUEM a lia: quem
    # desligasse a masmorra ali continuava com ela ligada.
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

# Tarefas que NAO dependem da agenda de eventos.
#
# A arena deve sair a cada 30 minutos, mas o start() so era chamado nos
# minutos da agenda — que tem vaos de 60 a 120 minutos, e nenhum durante
# as 4 horas do Coliseu. Medido em producao: a arena saia a cada ~52
# minutos, e contas recem-cadastradas ficavam com 1 unica execucao
# enquanto as antigas tinham 9.
#
# Aqui tambem entra o CHECKLIST DE MISSOES DO CLA. Durante a janela do
# Coliseu o bot passa a pausar entre as lutas para conferir a lista:
# recolhe as concluidas, apoia as dos companheiros e conclui com ouro as
# que estao paradas. Antes, essas quatro horas passavam sem nada disso.
#
# Cada bloco tem temporizador proprio, entao rodar a cada volta do laco
# (~1 min) nao significa executar a cada minuto.
#
# NAO e chamado durante os cinco eventos de prioridade: enquanto a conta
# esta aplicada num deles nada mais deve competir. Ao terminar o evento,
# o start() roda o checklist completo e as demais atividades.
tarefas_livres() {
    [ -n "$CLD" ] || clan_id 2>/dev/null

    # --- Numeros do painel, a cada 3 min
    if stats_liberado; then
        atualiza_stats 2>/dev/null
    fi

    # --- Checklist das missoes do cla
    if [ -n "$CLD" ] && cq_liberado; then
        printf "Checklist do cla\n"
        cq_concluir    2>/dev/null
        cq_ajudar      2>/dev/null
        cq_forcar_ouro 2>/dev/null
        # Missoes 7 e 8 tem atividade propria: alquimia e mercador do
        # Coliseu. Sem missao ativa, cq_tomar falha e nada e produzido.
        cq_elixir      2>/dev/null
        cq_mercador    2>/dev/null
        cq_marcar
    fi

    # --- Masmorra do cla
    #
    # Sem hora marcada: a pagina diz se ha golpe. Deu certo, so volta na
    # proxima leva de 8h; nao deu, volta em minutos.
    if [ -n "$CLD" ] && masmorra_liberada; then
        if clanDungeon; then masmorra_marcar; else masmorra_adiar; fi
    fi

    # --- Arena, sempre tomando antes a missao do cla que ela completa
    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        arena_marcar
    fi

    # --- Carreira, campanha, caverna e cabana do sabio: executa o que
    # estiver disponivel sem esperar os minutos :00/:30 do start(). Cada
    # uma so refaz apos o proprio intervalo (marcador em disco), entao a
    # varredura e barata. As proprias funcoes ja saem rapido quando nao ha
    # nada disponivel (sem link = sem acao).
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

    # --- Liga, Troca, Missoes do Cla e Eventos especiais.
    #
    # CORRECAO: estas quatro so existiam dentro do start(), que roda apenas
    # nos minutos exatos da agenda. Quando um evento de prioridade vencia o
    # case, ou quando o minuto simplesmente nao estava na lista, elas ficavam
    # de fora — a Liga chegava a passar o dia sem lutar. Agora tambem entram
    # na varredura ociosa, cada uma no seu intervalo.
    if ativ_liberada liga 30; then
        cq_antes liga 2>/dev/null
        league_play 2>/dev/null
        ativ_marcar liga
    fi

    # O func_trade tem portao proprio de uma vez ao dia, entao esta chamada
    # sai barata nas demais voltas; o intervalo aqui e so para nao reabrir a
    # pagina da troca a cada minuto.
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

# Arena a cada 30 minutos, controlada por marcador em disco para
# sobreviver a reinicios do worker.
arena_liberada() {
    _m=${FUNC_arena_min:-30}
    case "$_m" in ''|*[!0-9]*) _m=30 ;; esac
    _ultimo=`cat "$TMP/last_arena" 2>/dev/null`
    case "$_ultimo" in ''|*[!0-9]*) _ultimo=0 ;; esac
    _agora=`date +%s`
    [ $((_agora - _ultimo)) -ge $((_m * 60)) ]
}
arena_marcar() { date +%s > "$TMP/last_arena" 2>/dev/null; }

# Varredura periodica de atividades no ciclo ocioso.
#
# O sweep completo (start) so roda em :00 e :30. Entre esses minutos o bot
# ficava esperando, mesmo com carreira/campanha/caverna/cabana disponiveis.
# Agora o tarefas_livres tambem verifica e executa essas atividades, cada
# uma no seu proprio intervalo (marcador last_<nome> em disco, por conta,
# como a arena) — assim executa o que estiver disponivel sem esperar o :00/
# :30 e sem refazer a cada minuto (o que pesaria no Android/E22). O start()
# tambem marca ao rodar, para as duas vias nao duplicarem.
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

# ============================================================
#  PERIODO DEDICADO AO EVENTO
#
#  Durante os cinco eventos de prioridade — Torneio dos Clas, Coliseu do
#  Cla, Altares, Rei dos Imortais e Vale dos Imortais — nenhuma atividade
#  comum deve rodar: da inscricao ate o fim do evento a conta e so daquilo.
#
#  A varredura (tarefas_livres) ja nao e chamada nesses ramos do run.sh, e
#  enquanto o modulo do evento esta lutando ele bloqueia, entao nada mais
#  acontece. O furo esta no RETORNO ANTECIPADO: quando a conta cai da luta
#  antes da hora — o que se via no painel como a conta trocando o evento por
#  "Cla" no meio do horario —, o modulo devolve o controle e o start() logo
#  abaixo dispara a varredura inteira COM O EVENTO AINDA EM ANDAMENTO.
#
#  Aqui o inicio do evento e anotado antes de entrar, e depois do modulo a
#  conta espera o evento terminar antes de voltar as atividades. Durante a
#  espera ela descansa na pagina inicial, o que ainda mantem a sessao viva.
# ============================================================

# Epoch do inicio do evento: o proximo :00 ou :30 a partir de agora.
# Os ramos de prioridade entram em :55-:59 (evento em :00) ou :25-:29
# (evento em :30), entao a conta e direta.
evento_dedicar() {
    _ed_m=`date +%M | sed 's/^0//'`
    case "$_ed_m" in ''|*[!0-9]*) _ed_m=0 ;; esac
    if   [ "$_ed_m" -ge 50 ]; then _ed_f=$(( 60 - _ed_m ))
    elif [ "$_ed_m" -ge 20 ] && [ "$_ed_m" -lt 30 ]; then _ed_f=$(( 30 - _ed_m ))
    else _ed_f=0
    fi
    echo $(( `date +%s` + _ed_f * 60 )) > "$TMP/em_evento" 2>/dev/null
    unset _ed_m _ed_f
}

# Segura a conta ate o evento acabar. Volta na hora se o modulo ja tiver
# consumido o tempo todo lutando, que e o caso normal.
#
# A duracao vem de FUNC_evento_min (padrao 10). Se os eventos do seu
# servidor durarem mais ou menos que isso, e so ajustar essa chave no
# config.cfg da conta — nao ha como o bot descobrir a duracao sozinho.
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

# Apaga os marcadores de combate ao vivo deixados no disco.
#
# Os modulos de batalha (king, altares, torneio, masmorra, bandeiras,
# coliseu do cla) gravam HP/old_HP/FULL/USH no diretorio da conta durante a
# luta, e o painel os le para desenhar o "ao vivo das batalhas". Eles NAO
# eram apagados ao fim da luta, entao o painel continuava mostrando
# "-142 de dano recebido" com a conta ja parada na pagina inicial —
# combate fantasma. Apagados aqui (no descanso), o ao vivo passa a refletir
# apenas batalha de verdade em andamento.
limpar_combate() {
    rm -f "$TMP/HP" "$TMP/old_HP" "$TMP/FULL" "$TMP/USH" 2>/dev/null
}

# Volta para a pagina inicial. As contas devem descansar ali entre os
# ciclos, e nao numa pagina de combate ou de evento — o jogo mantem o
# personagem "em batalha" e a navegacao seguinte cai em "Fuja da batalha".
# A pagina baixada corresponde a uma sessao viva?
#
# Mesma regra do is_logged_in, mas lendo o ARQUIVO em vez de carregar a
# pagina inteira numa variavel: sao dois ou tres greps, sem o custo de
# guardar o HTML na memoria a cada ciclo, por conta.
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
    # A conta voltou para casa: registra a pagina inicial e encerra o
    # "ao vivo" da luta que acabou.
    printf %s "/" > "$TMP/pagina" 2>/dev/null
    limpar_combate

    # SESSAO CONFERIDA AQUI, DE GRACA.
    #
    # Esta pagina ja foi baixada acima e era descartada sem ninguem olhar.
    # Ela diz na hora se a sessao esta viva, entao a checagem nao custa
    # nenhuma requisicao nova.
    #
    # Antes a sessao so era verificada pelo atualiza_stats, a cada 3 minutos
    # e ao preco de duas requisicoes extras (/train e /user). No intervalo, a
    # conta seguia pedindo paginas com cookie morto: o servidor a via como
    # visitante anonimo e ela NAO aparecia online para os outros jogadores,
    # embora o painel a mostrasse rodando — porque o worker estava vivo.
    #
    # Como o descansar() roda ao fim de cada ciclo, a janela em que a conta
    # fica invisivel cai de ~3 minutos para ~1, sem custo.
    if sessao_viva_arquivo "$TMP/REST"; then
        date +%s > "$TMP/last_ok" 2>/dev/null
        return 0
    fi

    # NAO RECONECTA EM BLOCO.
    #
    # Com muitas contas no mesmo IP, uma queda costuma atingir varias ao
    # mesmo tempo — e se todas reconectam juntas, o servidor estrangula a
    # rajada e ainda pode derrubar sessao de quem estava bem, criando um
    # ciclo em que as contas se expulsam uma a outra. E o padrao que aparece
    # como "algumas online, outras nao, alternando".
    #
    # O intervalo minimo entre tentativas leva um deslocamento fixo por
    # conta, derivado do PID: cada uma tenta num segundo diferente dentro da
    # janela, em vez de todas no mesmo instante. Sem isso o intervalo apenas
    # adia a rajada, nao a dispersa.
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

    # Lider do cla: mantem a estatua ativa (bonus de ouro e de prata).
    clan_statue

    # Missoes do cla vem antes de tudo: recolhe as concluidas, apoia as
    # dos companheiros e forca com ouro as que estao paradas.
    if [ -n "$CLD" ]; then
        cq_concluir    2>/dev/null
        cq_ajudar      2>/dev/null
        cq_forcar_ouro 2>/dev/null
        # Missoes 7 e 8 tem atividade propria: alquimia e mercador do
        # Coliseu. Sem missao ativa, cq_tomar falha e nada e produzido.
        cq_elixir      2>/dev/null
        cq_mercador    2>/dev/null
    fi

    # Atividades. Cada uma verifica antes se ha missao do cla que ela
    # completa; havendo, toma a missao para o progresso contar.
    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        arena_marcar
    fi

    # Agenda oficial do jogo, para o painel
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

    # Batalhas sempre com elixir e bencao
    cq_antes elixir 2>/dev/null
    use_elixir
    use_blessing 2>/dev/null

    campaign_func
    ativ_marcar campanha

    # Masmorra do cla: mesmo portao que o tarefas_livres usa, entao os dois
    # pontos de chamada nao se atropelam.
    if [ -n "$CLD" ] && masmorra_liberada; then
        if clanDungeon; then masmorra_marcar; else masmorra_adiar; fi
    fi

    func_trade
    ativ_marcar troca

    # Cabana do Sabio: missoes, colecoes e reliquias
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
