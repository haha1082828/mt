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
            click=`grep -o -E "/quest/(take|help)/$quest_id/\?r=[0-9]{8}" "$TMP/SRC" | sed -n '1p'`
            ;;
        end)
            click=`grep -o -E "/quest/(deleteHelp|end)/$quest_id/\?r=[0-9]{8}" "$TMP/SRC" | sed -n '1p'`
            ;;
        *)
            return 1
            ;;
    esac

    if [ -n "$click" ]; then
        fetch_page "$click"
        return 0
    fi

    return 1
}

# Masmorra do Cla.
#
# A versao anterior acessava /clan/<CLD>/dungeon/, URL que NAO existe no
# jogo — por isso o log registrava "Clan Dungeon" dezenas de vezes e
# nenhum ataque. A pagina real e /clandungeon/, e o ataque sai por
# /clandungeon/attack/?r=N. A propria pagina informa:
#   "10 acessos gratis disponiveis a cada 8 horas a partir das 10:00"
# e mostra "Golpes mais: N" com os golpes restantes.
clanDungeon() {
    [ -n "$CLD" ] || return 1

    printf "Masmorra do cla\n"
    fetch_page "/clandungeon/" "$TMP/DUNGEON"
    [ -s "$TMP/DUNGEON" ] || return 1

    # Golpes gratuitos restantes. O numero vem separado por tags no
    # HTML cru, entao e preciso remove-las antes de casar.
    _golpes=`sed 's/<[^>]*>//g' "$TMP/DUNGEON" | grep -oE "Golpes mais:[^0-9]{0,8}[0-9]{1,3}" | grep -oE '[0-9]{1,3}$' | head -n1`
    [ -n "$_golpes" ] && printf "Masmorra: %s golpes disponiveis\n" "$_golpes"

    # SOMENTE GOLPES GRATUITOS.
    #
    # A pagina traz um unico link acionavel, /clandungeon/attack/, que
    # consome os 10 acessos gratis da janela de 8h. Nao existe ali
    # nenhum link de compra — verificado: nada com gold, pay, buy ou
    # chance. Quando os gratuitos acabam o link some e o laco encerra,
    # entao nao ha como gastar ouro por golpe extra.
    _br=$(($(date +%s) + 180))
    _n=0
    while [ "$(date +%s)" -lt "$_br" ]; do
        _cl=`grep -o -E '/clandungeon/attack/[?]r=[0-9]+' "$TMP/DUNGEON" | sed -n 1p`
        [ -n "$_cl" ] || break
        fetch_page "$_cl" "$TMP/DUNGEON"
        _n=$((_n + 1))
        printf "Masmorra: ataque %s\n" "$_n"
        sleep 1
    done

    if [ "$_n" -gt 0 ]; then
        printf "Masmorra do cla ok (%s ataques)\n" "$_n"
    else
        printf "Masmorra: sem ataque disponivel agora\n"
    fi
    unset _golpes _br _n _cl
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
