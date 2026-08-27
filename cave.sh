# shellcheck disable=SC2155
# shellcheck disable=SC2154

SILVER_SPENT_TOTAL=0
GOLD_SPENT_TOTAL=0

read_boost_gold_cost() {
    BOOST_GOLD_COST=`
        grep -o -E '/cave/chance/2/[?]r=[0-9]+' "$TMP/SRC" \
        | head -n1 \
        | grep -o -E "gold.png[^0-9]*[0-9][0-9,]*[KMB]?" "$TMP/SRC" \
        | grep -v -E '[KMB]' \
        | head -n1 \
        | sed -E 's/.*gold.png[^0-9]*([0-9][0-9,]*).*/\1/' \
        | tr -d "'"
    `
    BOOST_GOLD_COST=${BOOST_GOLD_COST:-0}
}

read_speedup_silver_cost() {
    SPEEDUP_SILVER_COST=`
        grep -o -E '/cave/speedUp/[^ ]+' "$TMP/SRC" \
        | head -n1 \
        | grep -o -E "silver.png[^0-9]*[0-9][0-9,]*[KMB]?" "$TMP/SRC" \
        | grep -v -E '[KMB]' \
        | head -n1 \
        | sed -E 's/.*silver.png[^0-9]*([0-9][0-9,]*).*/\1/' \
        | tr -d ','
    `
    SPEEDUP_SILVER_COST=${SPEEDUP_SILVER_COST:-0}
}

check_cave_limits() {
    # CORRECAO: comparava "$CAVE_GOLD_LIMIT" -gt 0 sem garantir que a
    # variavel tivesse valor. Com set_cave_limits travado (ver abaixo) ela
    # ficava vazia e o teste virava erro de operando a cada volta do laco.
    _gl=${CAVE_GOLD_LIMIT:-0}
    _sl=${CAVE_SILVER_LIMIT:-0}
    case "$_gl" in ''|*[!0-9]*) _gl=0 ;; esac
    case "$_sl" in ''|*[!0-9]*) _sl=0 ;; esac

    # CORRECAO (multi-contas): gravava em "$TWMDIR/runmode_file", arquivo
    # compartilhado por todas as contas. Agora e por conta, em $TMP.
    # E a re-execucao aninhada ("$TWMDIR/twm.sh" -boot seguida de exit 0)
    # foi removida: bastava sair, porque o worker.sh desta conta ja reinicia
    # o twm.sh em ~15s e ele le o runmode_file atualizado.
    if [ "$_gl" -gt 0 ] && [ "${GOLD_SPENT_TOTAL:-0}" -ge "$_gl" ]; then
        printf "Limite de ouro atingido (%s/%s)\n" "${GOLD_SPENT_TOTAL:-0}" "$_gl"
        sleep 3
        echo "-boot" > "$TMP/runmode_file"
        exit 0
    fi

    if [ "$_sl" -gt 0 ] && [ "${SILVER_SPENT_TOTAL:-0}" -ge "$_sl" ]; then
        printf "Limite de prata atingido (%s/%s)\n" "${SILVER_SPENT_TOTAL:-0}" "$_sl"
        sleep 3
        echo "-boot" > "$TMP/runmode_file"
        exit 0
    fi
    unset _gl _sl
}

set_cave_limits() {
    # CORRECAO CRITICA: sem terminal (o worker roda com stdin em /dev/null)
    # o "read" retornava vazio, o valor caia no ramo ''|*[!0-9]* e o
    # "while true" girava para sempre imprimindo "Invalid value". Ou seja:
    # "./play.sh -cv" nunca chegava a iniciar a caverna e o log crescia ate
    # encher o armazenamento. Agora, sem TTY, usa os limites salvos no
    # config da conta e segue em frente.
    CAVE_GOLD_LIMIT=${CAVE_GOLD_LIMIT:-0}
    CAVE_SILVER_LIMIT=${CAVE_SILVER_LIMIT:-0}

    if [ ! -t 0 ]; then
        _g=$(get_config CAVE_GOLD_LIMIT 2>/dev/null)
        _s=$(get_config CAVE_SILVER_LIMIT 2>/dev/null)
        case "$_g" in ''|*[!0-9]*) _g=0 ;; esac
        case "$_s" in ''|*[!0-9]*) _s=0 ;; esac
        CAVE_GOLD_LIMIT="$_g"
        CAVE_SILVER_LIMIT="$_s"
        printf "Caverna: limites ouro=%s prata=%s (0 = sem limite)\n" \
            "$CAVE_GOLD_LIMIT" "$CAVE_SILVER_LIMIT"
        unset _g _s
        return 0
    fi

    printf "Configure os gastos na Caverna\n"

    while true; do
        printf "Limite de ouro (0 = sem limite) [atual: %s]: " "$CAVE_GOLD_LIMIT"
        read -r input_gold || break
        case "$input_gold" in
            ''|*[!0-9]*) printf "Valor invalido. Somente numeros.\n" ;;
            *) CAVE_GOLD_LIMIT="$input_gold"; break ;;
        esac
    done

    while true; do
        printf "Limite de prata (0 = sem limite) [atual: %s]: " "$CAVE_SILVER_LIMIT"
        read -r input_silver || break
        case "$input_silver" in
            ''|*[!0-9]*) printf "Valor invalido. Somente numeros.\n" ;;
            *) CAVE_SILVER_LIMIT="$input_silver"; break ;;
        esac
    done

    set_config CAVE_GOLD_LIMIT "$CAVE_GOLD_LIMIT" 2>/dev/null
    set_config CAVE_SILVER_LIMIT "$CAVE_SILVER_LIMIT" 2>/dev/null

    printf "Limites definidos! Ouro: %s | Prata: %s\n" "$CAVE_GOLD_LIMIT" "$CAVE_SILVER_LIMIT"
    sleep 3
}

check_cave_keypress() {
    # CORRECAO: "read -n" e bashism — nao existe em sh/dash/toybox, e o
    # play.sh executa tudo via $TOYBOX. Sem terminal nao ha tecla a ler.
    [ -t 0 ] || return 0
    key=""
    read -r -t 1 key 2>/dev/null || return 0
    case "$key" in
        x|X)
            printf "Voltando ao modo rotina...\n"
            sleep 3
            echo "-boot" > "$TMP/runmode_file"
            exit 0
            ;;
    esac
}

bottom_info() {
    printf "%s | HP %s (%s%%) | MP %s (%s%%)\n" "$ACC" "$NOWHP" "$HPPER" "$NOWMP" "$MPPER" > "$TMP/bottom_file"
    printf " ~ Press [x] to exit\n" >> "$TMP/bottom_file"
    cat "$TMP/bottom_file"
}

cave_start() {
    clan_id
    fetch_page "/cave/"
    set_cave_limits

    while echo "$RUN" | grep -q -E '[-]cv'; do
        CAVE=`grep -o -E '/cave/(gather|down|speedUp)/[?]r[=][0-9]+' "$TMP/SRC" | sed -n '1p'`
        RESULT=`echo "$CAVE" | cut -d'/' -f3`

        RESOURCES=`grep -o -E 'res/[0-9]+\.png' "$TMP/SRC" | sed 's/res\///;s/.png//'`
        MINERALS_FOUND=`echo "$RESOURCES" | grep -E '^[1-5]$' | wc -l`
        HERBS_FOUND=`echo "$RESOURCES" | grep -E '^(6|7|8|9)$' | wc -l`
        BOOST_LINK=`grep -o -E '/cave/chance/2/[?]r=[0-9]+' "$TMP/SRC" | head -n 1`

        CAN_ATTACK_MONSTER=${CAN_ATTACK_MONSTER:-0}
        MONSTER_ATTACK=`grep -o -E '/cave/attack/[?]r=[0-9]+' "$TMP/SRC" | head -n1`
        MONSTER_RUNAWAY=`grep -o -E '/cave/runaway/[?]r=[0-9]+' "$TMP/SRC" | head -n1`

        check_cave_keypress

        if [ "$MINERALS_FOUND" -eq 3 ] && [ "$HERBS_FOUND" -eq 0 ] && [ -n "$BOOST_LINK" ]; then
            read_boost_gold_cost
            # /cave/chance/2/ custa OURO. A politica nega, entao o link nao
            # e acessado e CAN_ATTACK_MONSTER fica 0: o monstro logo abaixo
            # e evitado em vez de enfrentado.
            if resource_allow gold "$BOOST_GOLD_COST" cave_gold_boost; then
                printf "3 ores detected! Increasing chance by 100%%\n"
                fetch_page "$BOOST_LINK"
                if [ "$BOOST_GOLD_COST" -gt 0 ]; then
                    GOLD_SPENT_TOTAL=$((GOLD_SPENT_TOTAL + BOOST_GOLD_COST))
                    CAN_ATTACK_MONSTER=1
                fi
            fi
        fi

        if [ -n "$MONSTER_ATTACK" ] && [ -n "$MONSTER_RUNAWAY" ]; then
            if [ "$CAN_ATTACK_MONSTER" -eq 1 ]; then
                printf "Monster found - attacking (gold spent)\n"
                fetch_page "$MONSTER_ATTACK"
            else
                printf "Monster found - running away (no gold spent)\n"
                fetch_page "$MONSTER_RUNAWAY"
            fi
        fi

        read_speedup_silver_cost
        fetch_page "$CAVE"

        case $RESULT in
            down*)
                printf "New search\n"
                CAN_ATTACK_MONSTER=0
                ;;
            gather*)
                printf "Start mining\n"
                ;;
            speedUp*)
                printf "Speeding up mining\n"
                ;;
        esac

        if [ "$SPEEDUP_SILVER_COST" -gt 0 ]; then
            SILVER_SPENT_TOTAL=$((SILVER_SPENT_TOTAL + SPEEDUP_SILVER_COST))
        fi

        bottom_info
        fetch_page "/cave/"
        check_cave_limits
    done
}

cave_routine() {
    printf "Cave\n"

    if checkQuest 5 apply; then
        count=0
        printf "Quests available speeding up mine to complete!\n"
    else
        count=8
    fi

    # LIMITE DE TEMPO: o laco abaixo era "while true", sem limite e sem
    # saida quando nao ha acao disponivel. Com a caverna em espera, CAVE
    # ficava vazio, o case nao casava com nada, e o laco repetia
    # fetch_page "/cave/" indefinidamente — cerca de 3600 requisicoes por
    # hora, por conta. Era a maior fonte de carga do bot.
    CAVE_BREAK=$(($(date +%s) + 240))

    fetch_page "/cave/"

    while [ "$(date +%s)" -lt "$CAVE_BREAK" ]; do
        CAVE=`grep -o -E '/cave/(gather|down|runaway|speedUp)/[?]r[=][0-9]+' "$TMP/SRC" | sed -n '1p'`
        RESULT=`echo "$CAVE" | cut -d'/' -f3`

        # Sem link de acao, a caverna esta em espera: sai em vez de
        # repetir a mesma requisicao ate o tempo acabar.
        if [ -z "$CAVE" ]; then
            printf "Caverna sem acao disponivel agora
"
            break
        fi

        RESOURCES=`grep -o -E 'res/[0-9]+\.png' "$TMP/SRC" | sed 's/res\///;s/.png//'`
        MINERALS_FOUND=`echo "$RESOURCES" | grep -E '^[1-5]$' | wc -l`
        HERBS_FOUND=`echo "$RESOURCES" | grep -E '^(6|7|8|9)$' | wc -l`
        BOOST_LINK=`grep -o -E '/cave/chance/2/[?]r=[0-9]+' "$TMP/SRC" | head -n 1`

        # Segundo ponto de boost. Mesma politica: custa ouro, entao nao vai.
        if [ "$FUNC_cave_boost" = "y" ]; then
            if [ "$MINERALS_FOUND" -eq 3 ] && [ "$HERBS_FOUND" -eq 0 ] && [ -n "$BOOST_LINK" ]; then
                read_boost_gold_cost
                if resource_allow gold "$BOOST_GOLD_COST" cave_gold_boost; then
                    printf "3 ores detected! Increasing chance by 100%%\n"
                    fetch_page "$BOOST_LINK"
                fi
            fi
        fi

        if [ "$RESULT" = "speedUp" ] && [ "$count" -ge 8 ]; then
            printf "Cave limit reached\n"
            break
        fi

        case $RESULT in
            gather|down|runaway|speedUp)
                fetch_page "$CAVE"
                case $RESULT in
                    down*)
                        printf "New search\n"
                        count=$((count + 1))
                        ;;
                    gather*)
                        printf "Start mining\n"
                        ;;
                    runaway*)
                        printf "Running away\n"
                        ;;
                    speedUp*)
                        printf "Speed up mining\n"
                        ;;
                esac
                ;;
        esac

        fetch_page "/cave/"
    done

    checkQuest 5 end
    printf "Cave ok\n"
}
