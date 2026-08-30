#!/bin/sh
# V2 conservadora: funcao preservada; unica otimização é cache local de timestamp.
coliseum_fight() {
    # Arquivos de batalha gravados no diretorio da conta (sem mktemp)
    src_ram="$TMP/col_src"
    full_ram="$TMP/col_full"

    LA=5
    HPER=38
    RPER=5

    printf "Coliseum\n"

    # HP maximo
    (
        run_curl_exec "$URL/train" | grep -o -E '\(([0-9]+)\)' | sed 's/[()]//g' > "$full_ram"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 20

    # Desativa graficos
    (
        run_curl_exec "$URL/settings/graphics/0" > /dev/null
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17

    # Pagina do coliseu
    (
        run_curl_exec "$URL/coliseum" > "$src_ram"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17

    # Encerra luta pendente
    if grep -q -o '?end_fight' "$src_ram"; then
        (
            run_curl_exec "$URL/coliseum/?end_fight=true" > /dev/null
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        (
            run_curl_exec "$URL/coliseum" > "$src_ram"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
    fi

    access_link=`grep -o -E '/coliseum(/[A-Za-z]+/[?]r[=][0-9]+|/)' "$src_ram" | sed -n '1p'`
    go_stop=`grep -o -E '/coliseum/enterFight/[?]r[=][0-9]+' "$src_ram"`

    if [ -n "$go_stop" ]; then
        printf "  Entering...\n"
        (
            run_curl_exec "${URL}${go_stop}" > "$src_ram"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17

        access_link=`grep -o -E '/coliseum(/[A-Za-z]+/[?]r[=][0-9]+|/)' "$src_ram" | grep -v 'dodge' | sed -n 1p`
        printf " Preparing for battle, waiting for other players...\n"

        first_time=`date +%s`
        until grep -q -o 'coliseum/dodge/' "$src_ram" || awk -v ltime="$(($(date +%s) - first_time))" 'BEGIN { exit !(ltime > 30) }'; do
            (
                run_curl_exec "${URL}${access_link}" > "$src_ram"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            access_link=`grep -o -E '/(coliseum/[A-Za-z]+/[?]r[=][0-9]+|coliseum)' "$src_ram" | grep -v 'dodge' | sed -n 1p`
            printf " Preparing...\n"
            sleep 3s
        done

        cl_access() {
            USH=`grep -o -E '(hp)[^A-z0-9]{1,4}[0-9]{2,5}' "$src_ram" | grep -o -E '[0-9]{2,5}' | sed 's,\ ,,g'`
            ENH=`grep -o -E '(nbsp)[^A-Za-z0-9]{1,2}[0-9]{1,6}' "$src_ram" | sed -n 's,nbsp[;],,;s,\ ,,;1p'`
            USER=`grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:]]s' "$src_ram" | sed -n 's,\ [<]s,,;s,\ ,_,;2p'`

            ATK=`grep -o -E '/coliseum/atk/[?]r[=][0-9]+' "$src_ram" | sed -n 1p`
            ATKRND=`grep -o -E '/coliseum/atkrnd/[?]r[=][0-9]+' "$src_ram"`
            DODGE=`grep -o -E '/coliseum/dodge/[?]r[=][0-9]+' "$src_ram"`
            HEAL=`grep -o -E '/coliseum/heal/[?]r[=][0-9]+' "$src_ram"`

            RHP=`awk -v ush="$USH" -v rper="$RPER" 'BEGIN { printf "%.0f", ush * rper / 100 + ush }'`
            HLHP=`awk -v ush="$(cat "$full_ram")" -v hper="$HPER" 'BEGIN { printf "%.0f", ush * hper / 100 }'`

            if grep -q -o '/dodge/' "$src_ram"; then
                # A pagina respondeu com a luta: sessao confirmada.
                sessao_marcar
                printf "Em batalha - HP: %s\n" "$USH"
            else
                if grep -q -o '?end_fight=true' "$src_ram"; then
                    if awk -v ltime="$(($(date +%s) - first_time))" 'BEGIN { exit !(ltime < 300) }'; then
                        (
                            run_curl_exec "${URL}/coliseum" > "$src_ram"
                        ) </dev/null > /dev/null 2>&1 &
                        time_exit 17
                        printf "Fim de batalha detectado.\n"
                    fi
                else
                    BREAK_LOOP=1
                    printf "Battle over.\n"
                    sleep 2s
                fi
            fi
        }

        last_heal=$(($(date +%s) - 90))
        last_dodge=$(($(date +%s) - 20))
        last_atk=$(($(date +%s) - LA))
        cl_access
        OLDHP=$USH
        BREAK_LOOP=""
        first_time=`date +%s`

        # Limite de tempo: BREAK_LOOP so e definido quando a luta
        # termina. Se o estado nunca resolver, o laco era infinito.
        COL_BREAK=$(($(date +%s) + 600))
        until [ -n "$BREAK_LOOP" ] || [ "$(date +%s)" -gt "$COL_BREAK" ]; do
            now=`date +%s`
            time_since_last_heal=$((now - last_heal))
            time_since_last_dodge=$((now - last_dodge))
            time_since_last_atk=$((now - last_atk))

            if awk -v ush="$USH" -v hlhp="$HLHP" 'BEGIN { exit !(ush < hlhp) }' && \
               [ "$time_since_last_heal" -gt 90 ] && [ "$time_since_last_heal" -lt 300 ]; then
                (
                    run_curl_exec "${URL}${HEAL}" > "$src_ram"
                ) </dev/null > /dev/null 2>&1 &
                time_exit 17
                cl_access
                last_heal=$now
                last_atk=$now

            elif ! grep -q -o 'txt smpl grey' "$src_ram" && \
                 [ "$time_since_last_dodge" -gt 20 ] && [ "$time_since_last_dodge" -lt 300 ] && \
                 awk -v ush="$USH" -v oldhp="$OLDHP" 'BEGIN { exit !(ush < oldhp) }'; then
                (
                    run_curl_exec "${URL}${DODGE}" > "$src_ram"
                ) </dev/null > /dev/null 2>&1 &
                time_exit 17
                cl_access
                OLDHP=$USH
                last_dodge=$now
                last_atk=$now

            elif awk -v latk="$time_since_last_atk" -v atktime="$LA" 'BEGIN { exit !(latk != atktime) }' && \
                 ! grep -q -o 'txt smpl grey' "$src_ram" && \
                 awk -v rhp="$RHP" -v enh="$ENH" 'BEGIN { exit !(rhp < enh) }'; then
                (
                    run_curl_exec "${URL}${ATKRND}" > "$src_ram"
                ) </dev/null > /dev/null 2>&1 &
                time_exit 17
                cl_access
                last_atk=$now

            elif awk -v latk="$time_since_last_atk" -v atktime="$LA" 'BEGIN { exit !(latk > atktime) }'; then
                (
                    run_curl_exec "${URL}${ATK}" > "$src_ram"
                ) </dev/null > /dev/null 2>&1 &
                time_exit 17
                cl_access
                last_atk=$now

            else
                (
                    run_curl_exec "${URL}/coliseum" > "$src_ram"
                ) </dev/null > /dev/null 2>&1 &
                time_exit 17
                cl_access
                sleep 0.5s
            fi
        done

        rm -f "$src_ram" "$full_ram"
        unset last_heal last_dodge last_atk USH ENH USER ATK ATKRND DODGE HEAL BREAK_LOOP
        func_unset

        printf "The battle is over!\n"
    else
        printf "It was not possible to start the battle at this time.\n"
    fi
}
