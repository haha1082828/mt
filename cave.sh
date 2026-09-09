# shellcheck disable=SC2155
# shellcheck disable=SC2154

SILVER_SPENT_TOTAL=0
GOLD_SPENT_TOTAL=0

read_boost_gold_cost() {
    BOOST_GOLD_COST=`
        grep -o -E '(gold\.png[^0-9]*[0-9]+|[0-9]+[^<]*gold\.png)' "$TMP/SRC" \
        | grep -o -E '[0-9]+' \
        | head -n1
    `
    BOOST_GOLD_COST=${BOOST_GOLD_COST:-0}
}

read_speedup_silver_cost() {
    SPEEDUP_SILVER_COST=`
        grep -o -E '/cave/speedUp/[^"'\'' >]+' "$TMP/SRC" \
        | head -n1 \
        | grep -o -E '(silver\.png[^0-9]*[0-9]+|[0-9]+[^<]*silver\.png)' "$TMP/SRC" \
        | grep -o -E '[0-9]+' \
        | head -n1
    `
    if [ -z "$SPEEDUP_SILVER_COST" ]; then
        SPEEDUP_SILVER_COST=`grep -i "silver" "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1`
    fi
    SPEEDUP_SILVER_COST=${SPEEDUP_SILVER_COST:-0}
}

check_cave_limits() {
    _gl=${CAVE_GOLD_LIMIT:-0}
    _sl=${CAVE_SILVER_LIMIT:-0}
    case "$_gl" in ''|*[!0-9]*) _gl=0 ;; esac
    case "$_sl" in ''|*[!0-9]*) _sl=0 ;; esac

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
        # CAPTURA INTELIGENTE: Pega o link inteiro independentemente do que vier depois na URL
        CAVE=`grep -o -E '/cave/(gather|down|speedUp|attack|runaway)[^"'\'' >]*' "$TMP/SRC" | sed -n '1p'`
        RESULT=`echo "$CAVE" | cut -d'/' -f3`

        if [ -z "$CAVE" ]; then
            printf "Caverna sem acao disponivel agora\n"
            break
        fi

        RESOURCES=`grep -o -E 'res/[0-9]+\.png' "$TMP/SRC" | sed 's/res\///;s/.png//'`
        MINERALS_FOUND=`echo "$RESOURCES" | grep -E '^[1-5]$' | wc -l`
        HERBS_FOUND=`echo "$RESOURCES" | grep -E '^(6|7|8|9)$' | wc -l`
        BOOST_LINK=`grep -o -E '/cave/chance/2/[^"'\'' >]*' "$TMP/SRC" | head -n 1`

        CAN_ATTACK_MONSTER=${CAN_ATTACK_MONSTER:-0}
        MONSTER_ATTACK=`grep -o -E '/cave/attack[^"'\'' >]*' "$TMP/SRC" | head -n1`
        MONSTER_RUNAWAY=`grep -o -E '/cave/runaway[^"'\'' >]*' "$TMP/SRC" | head -n1`

        check_cave_keypress

        if [ "$MINERALS_FOUND" -eq 3 ] && [ "$HERBS_FOUND" -eq 0 ] && [ -n "$BOOST_LINK" ]; then
            read_boost_gold_cost
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

        if [ "$RESULT" = "speedUp" ]; then
            read_speedup_silver_cost
            if [ "$SPEEDUP_SILVER_COST" -gt 0 ]; then
                if resource_allow silver "$SPEEDUP_SILVER_COST" cave_silver_speedup; then
                    printf "Speeding up mining with silver (cost: %s)\n" "$SPEEDUP_SILVER_COST"
                    fetch_page "$CAVE"
                    SILVER_SPENT_TOTAL=$((SILVER_SPENT_TOTAL + SPEEDUP_SILVER_COST))
                else
                    printf "Speedup with silver skipped due to budget/policy limit.\n"
                    fetch_page "$CAVE"
                fi
            else
                printf "Speedup with silver executed (forcing click).\n"
                fetch_page "$CAVE"
            fi
        else
            fetch_page "$CAVE"
        fi

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

    CAVE_BREAK=$(($(date +%s) + 240))

    fetch_page "/cave/"

    while [ "$(date +%s)" -lt "$CAVE_BREAK" ]; do
        # CAPTURA INTELIGENTE: Blindado contra mudancas na URL
        CAVE=`grep -o -E '/cave/(gather|down|runaway|speedUp)[^"'\'' >]*' "$TMP/SRC" | sed -n '1p'`
        RESULT=`echo "$CAVE" | cut -d'/' -f3`

        if [ -z "$CAVE" ]; then
            printf "Caverna sem acao disponivel agora\n"
            break
        fi

        RESOURCES=`grep -o -E 'res/[0-9]+\.png' "$TMP/SRC" | sed 's/res\///;s/.png//'`
        MINERALS_FOUND=`echo "$RESOURCES" | grep -E '^[1-5]$' | wc -l`
        HERBS_FOUND=`echo "$RESOURCES" | grep -E '^(6|7|8|9)$' | wc -l`
        BOOST_LINK=`grep -o -E '/cave/chance/2[^"'\'' >]*' "$TMP/SRC" | head -n 1`

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
                if [ "$RESULT" = "speedUp" ]; then
                    read_speedup_silver_cost
                    if [ "$SPEEDUP_SILVER_COST" -gt 0 ]; then
                        if resource_allow silver "$SPEEDUP_SILVER_COST" cave_silver_speedup; then
                            printf "Speed up mining with silver (cost: %s)\n" "$SPEEDUP_SILVER_COST"
                            fetch_page "$CAVE"
                            SILVER_SPENT_TOTAL=$((SILVER_SPENT_TOTAL + SPEEDUP_SILVER_COST))
                        else
                            printf "Speedup policy blocked silver spending, forcing click.\n"
                            fetch_page "$CAVE"
                        fi
                    else
                        fetch_page "$CAVE"
                    fi
                else
                    fetch_page "$CAVE"
                fi

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
