clan_id() {
    cd "$TMP" || return 1

    fetch_page "/clan" "$TMP/CLD"

    CLD=`grep -o -E '/clan/[0-9]+/' "$TMP/CLD" | head -n 1 | awk -F'/' '{ print $3 }'`

    if [ -z "$CLD" ]; then
        printf "CLAN ID not found!\n"
        return 1
    else
        echo "$CLD" > "$TMP/CLD"
    fi
}

checkQuest() {
    quest_id="$1"
    action="$2"

    if [ "${FUNC_clan_missions:-y}" != "y" ]; then
        return 1
    fi

    if [ -z "$CLD" ]; then
        printf "CLAN ID not available, trying to fetch it.\n"
        clan_id
        if [ -z "$CLD" ]; then
            printf "Failed to retrieve CLAN ID.\n"
            return 1
        fi
    fi

    fetch_page "/clan/${CLD}/quest/"

    if [ ! -s "$TMP/SRC" ]; then
        printf "Source file $TMP/SRC is empty, fetch_page may have failed.\n"
        return 1
    fi

    case "$action" in
        apply)
            click=`grep -o -E "/quest/take/$quest_id/[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
            ;;
        end)
            click=`grep -o -E "/quest/end/$quest_id/[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
            ;;
        *)
            return 1
            ;;
    esac

    if [ -n "$click" ]; then
        fetch_page "/clan/${CLD}${click}"
        return 0
    fi

    return 1
}

# ============================================================
#  MASMORRA DO CLA
#
# ERA A UNICA ATIVIDADE QUE NAO OLHAVA A PAGINA PARA DECIDIR.
#
# Todas as outras seguem a mesma regra: abre a pagina, procura o link de
# acao, executa se ele estiver la. A masmorra fugia disso em dois pontos, e
# os dois faziam a conta ficar parada com golpe disponivel no jogo:
#
#   1. O link de golpe era casado por um caminho FIXO,
#      /clandungeon/attack/?r=N. Qualquer variacao — outro nome de secao,
#      outro verbo — devolvia "sem ataque disponivel" com a pagina aberta
#      na frente. Agora a leitura e frouxa, como no modulo de batalha do
#      cla: serve qualquer /<secao>/attack/?r=N presente na pagina.
#
#   2. Quando nada era encontrado a funcao apenas desistia em silencio, e
#      quem chamava marcava a janela como cumprida do mesmo jeito — a conta
#      passava as 8 horas seguintes sem tentar de novo. Agora ela devolve
#      0 SOMENTE quando um golpe saiu de verdade, e o agendador reabre em
#      poucos minutos quando nao saiu.
#
# E quando mesmo assim nao houver link, a funcao IMPRIME NO LOG o que viu na
# pagina. Sem isso o diagnostico exige estar com o aparelho na mao.
# ============================================================

# Link de golpe, procurado na pagina ja baixada.
#
# Deliberadamente generico: casa /clandungeon/attack/?r=N e qualquer
# /<secao>/at(ta)k/?r=N que a pagina ofereca. Mesma leitura frouxa do
# clandmg.sh, que funciona ha tempo.
masmorra_golpe() {
    # O caminho conhecido tem prioridade: se ele estiver na pagina, e ele que
    # vale. A leitura frouxa e reserva, para nao ficar parado quando o nome da
    # secao mudar — nunca para escolher outro link tendo o certo a mao.
    _mg=`grep -o -E "/clandungeon/at[a-z]{0,3}k/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+" "$1" 2>/dev/null | sed -n 1p`
    [ -n "$_mg" ] || _mg=`grep -o -E "/[a-z]{4,20}/at[a-z]{0,3}k/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+" "$1" 2>/dev/null | sed -n 1p`
    printf '%s' "$_mg"
    unset _mg
}

# O que a pagina tem, quando nao tem o golpe. So para o log.
masmorra_dump() {
    printf "Masmorra: sem link de golpe na pagina. O que veio:\n"
    _mdz=`wc -c < "$1" 2>/dev/null`
    printf "  tamanho: %s bytes\n" "${_mdz:-0}"
    sed 's/<[^>]*>/ /g' "$1" 2>/dev/null | tr -s ' \t' ' ' \
        | grep -o -i -E ".{0,30}(golpe|acesso|masmorra|dungeon).{0,30}" \
        | head -n 3 | sed 's/^/  texto: /'
    grep -o -E "/[a-z0-9_-]{3,24}/[a-z0-9_-]{0,24}/?[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+" "$1" 2>/dev/null \
        | sort -u | head -n 6 | sed 's/^/  link: /'
    unset _mdz
}

clanDungeon() {
    [ -n "$CLD" ] || return 1

    printf "Masmorra do cla\n"
    # O "?close" dispensa o painel de recompensa da rodada anterior, que
    # fica na frente do link de golpe — mesmo recurso que o coliseu do cla,
    # os altares e as bandeiras ja usam.
    fetch_page "/clandungeon/?close" "$TMP/DUNGEON" 2>/dev/null
    [ -s "$TMP/DUNGEON" ] || { printf "Masmorra: pagina vazia\n"; return 1; }

    _cl=`masmorra_golpe "$TMP/DUNGEON"`

    # PORTA DE ENTRADA PROCURADA NO MENU DO CLA.
    #
    # Se a pagina fixa nao trouxe golpe, o proprio cla diz onde fica a
    # masmorra. Assim uma troca de endereco no jogo deixa de exigir
    # atualizacao do bot — a mesma razao de os demais modulos lerem o link
    # em vez de escreve-lo.
    if [ -z "$_cl" ]; then
        fetch_page "/clan/${CLD}/" "$TMP/CLANPG" 2>/dev/null
        # So caminhos: o "[a-z0-9/]" ja descarta /images/dungeon.png e
        # qualquer coisa com ponto, que seria um arquivo e nao uma pagina.
        _porta=`grep -o -E "/[a-z0-9/]{0,20}dungeon[a-z0-9/]{0,20}" "$TMP/CLANPG" 2>/dev/null \
                | grep -v -E "image|/js/|/css/" | sed -n 1p`
        if [ -n "$_porta" ] && [ "$_porta" != "/clandungeon/" ]; then
            printf "Masmorra: entrando por %s\n" "$_porta"
            fetch_page "$_porta" "$TMP/DUNGEON" 2>/dev/null
            _cl=`masmorra_golpe "$TMP/DUNGEON"`
        fi
        unset _porta
    fi

    # Golpes gratuitos restantes. O numero vem separado por tags no HTML
    # cru, entao e preciso remove-las antes de casar.
    _golpes=`sed 's/<[^>]*>//g' "$TMP/DUNGEON" 2>/dev/null \
             | grep -oE "Golpes mais:[^0-9]{0,8}[0-9]{1,3}" | grep -oE '[0-9]{1,3}$' | head -n1`
    [ -n "$_golpes" ] && printf "Masmorra: %s golpes disponiveis\n" "$_golpes"

    if [ -z "$_cl" ]; then
        masmorra_dump "$TMP/DUNGEON"
        unset _cl _golpes
        return 1
    fi

    # SOMENTE GOLPES GRATUITOS.
    #
    # O link seguido e sempre o de ataque; a pagina nao oferece compra de
    # golpe, e nenhum link com gold/pay/buy entra aqui. Quando os gratuitos
    # acabam o link some e o laco encerra.
    #
    # Dois tetos: 180s e FUNC_masmorra_max golpes. A janela da 10 acessos;
    # se algum dia o link parar de sumir quando eles acabarem, sem o teto de
    # golpes o laco martelaria o servidor por tres minutos.
    _max=${FUNC_masmorra_max:-15}
    case "$_max" in ''|*[!0-9]*) _max=15 ;; esac
    _br=$(($(date +%s) + 180))
    _n=0
    while [ "$(date +%s)" -lt "$_br" ] && [ "$_n" -lt "$_max" ]; do
        [ -n "$_cl" ] || break
        if ! fetch_page "$_cl" "$TMP/DUNGEON"; then
            printf "Masmorra: falha de rede no golpe %s\n" "$((_n + 1))"
            break
        fi
        _n=$((_n + 1))
        printf "Masmorra: golpe %s\n" "$_n"
        sleep 1
        _cl=`masmorra_golpe "$TMP/DUNGEON"`
    done

    unset _golpes _br _cl _max
    if [ "$_n" -gt 0 ]; then
        printf "Masmorra do cla ok (%s golpes)\n" "$_n"
        unset _n
        return 0
    fi
    unset _n
    return 1
}

# Conta e lider/oficial do cla?
# A pagina do cla so mostra o link de administracao para quem tem cargo.
clan_lider() {
    [ -n "$CLD" ] || return 1
    fetch_page "/clan/${CLD}/" "$TMP/CLANPG"
    grep -q -E "/clan/${CLD}/[0-9]+/adm/" "$TMP/CLANPG"
}

# Estatua do Cla: mantem os bonus ativos.
#
# A implementacao anterior usava /clan/<CLD>/statue/ e
# /statue/activate/ — URLs que nao existem no jogo. A pagina real e
# /clan/<CLD>/built/ e os bonus sao ativados por parametro:
#
#   ?privateUpgrade=true&r=N   Bonus Pessoal   (custa ouro)
#   ?goldUpgrade=true&r=N      Cla Bonus Ouro  (custa ouro do cla)
#   ?silverUpgrade=true&r=N    Cla Bonus Prata (custa prata do cla)
#
# Quando um bonus ja esta ativo o link some e a pagina mostra apenas
# "Tempo de sobra: HH:MM:SS" — por isso basta agir sobre o que aparecer.
# Espera antes de tentar de novo apos uma recusa.
#
# Sem isto o bot reclicava o link a cada ciclo. Em producao foram 31
# tentativas seguidas com o servidor respondendo "Voce nao tem prata
# suficiente para ativar um edificio" — a tesouraria do cla tinha
# 54.300 de prata e o bonus custa 222.000. Insistir de minuto em
# minuto nao muda o saldo, so gasta requisicao.
estatua_liberada() {
    _h=${FUNC_estatua_horas:-6}
    case "$_h" in ''|*[!0-9]*) _h=6 ;; esac
    _u=`cat "$TMP/last_estatua" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_h * 3600)) ]
}
estatua_marcar() { date +%s > "$TMP/last_estatua" 2>/dev/null; }

clan_statue() {
    [ "${FUNC_clan_statue:-y}" = "y" ] || return 1
    [ -n "$CLD" ] || return 1

    # Bonus do cla so podem ser ativados por quem tem cargo.
    if ! clan_lider; then
        return 1
    fi

    # Se a ultima tentativa foi recusada, espera antes de repetir.
    estatua_liberada || return 1

    fetch_page "/clan/${CLD}/built/" "$TMP/STATUE"
    [ -s "$TMP/STATUE" ] || return 1

    for _up in goldUpgrade silverUpgrade; do
        _cl=`grep -o -E "/clan/${CLD}/built/[?]${_up}=true&r=[0-9]+" "$TMP/STATUE" | sed -n 1p`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl" "$TMP/STATUE2"
            # Reler a PAGINA DA ESTATUA, nao a resposta do clique.
            #
            # A resposta do clique nao traz o link de ativacao mesmo
            # quando a ativacao falha, entao checar ali dava sempre
            # "ativado". Em producao: 31 sucessos no log enquanto o
            # link seguia na pagina e a tesouraria nao mudava.
            fetch_page "/clan/${CLD}/built/" "$TMP/STATUE2"
            # VERIFICA o resultado em vez de assumir sucesso.
            #
            # A versao anterior clicava e registrava "ativado" sempre. Em
            # producao isso gerou 31 mensagens de sucesso enquanto o link
            # de ativacao continuava na pagina — ou seja, nenhuma ativacao
            # tinha ocorrido. O bonus custa 222.000 de prata do cla e a
            # tesouraria nao cobria; o bot insistia a cada ciclo.
            if grep -q "${_up}=true" "$TMP/STATUE2" 2>/dev/null; then
                case "$_up" in
                    goldUpgrade)   printf "Estatua: bonus de OURO nao ativou (ouro do cla insuficiente)
" ;;
                    silverUpgrade) printf "Estatua: bonus de PRATA nao ativou (prata do cla insuficiente)
" ;;
                esac
            else
                case "$_up" in
                    goldUpgrade)   printf "Estatua do cla: bonus de OURO ativado
" ;;
                    silverUpgrade) printf "Estatua do cla: bonus de PRATA ativado
" ;;
                esac
            fi
        fi
    done
    # Marca a tentativa: com ou sem sucesso, so volta a mexer na
    # estatua depois do intervalo. Os bonus duram 48h, entao nao ha
    # perda em esperar 6h para reavaliar.
    estatua_marcar
    unset _up _cl
    return 0
}

clanQuests() {
    if [ -z "$CLD" ]; then
        return
    fi

    fetch_page "/clan/${CLD}/quest/"

    QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`

    # Limite de tempo: se a mesma missao continuar aparecendo (por
    # exemplo uma que nao pode ser concluida), o laco nao terminava.
    CQ_BREAK=$(($(date +%s) + 90))
    while [ -n "$QUEST" ] && [ "$(date +%s)" -lt "$CQ_BREAK" ]; do
        fetch_page "$QUEST"
        printf "Clan quest processed\n"
        fetch_page "/clan/${CLD}/quest/"
        QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`
    done
}
