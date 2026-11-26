check_missions() {
    printf "Checking Missions\n"

    fetch_page "/quest/"

    for i in 1 2; do
        click=`grep -o -E "/quest/openChest/$i/[?]r=[0-9]+" "$TMP/SRC" | head -n1`
        if [ -n "$click" ]; then
            fetch_page "$click"
            printf "Chest %s opened\n" "$i"
        fi
    done

    if [ "$FUNC_collect_mission_rewards" = "n" ]; then
        return
    fi

    i=0
    while [ "$i" -le 16 ]; do
        click=`grep -o -E "/quest/end/${i}[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
        if [ -n "$click" ]; then
            fetch_page "$click"
            printf "Mission %s Completed\n" "$i"
        fi
        i=$((i + 1))
    done

    fetch_page "/collector/"
    click=`grep -o -E "/collector/reward/element/[?]r=[0-9]+" "$TMP/SRC"`
    if [ -n "$click" ]; then
        fetch_page "$click"
        printf "Collection collected\n"
    fi

    printf "Missions ok\n"
}

check_rewards() {
    if [ "$FUNC_check_rewards" = "n" ]; then
        return
    fi

    fetch_page "/relic/reward/"

    i=0
    while [ "$i" -le 11 ]; do
        click=`grep -o -E "/relic/reward/${i}/[?]r=[0-9]+" "$TMP/SRC"`
        if [ -n "$click" ]; then
            fetch_page "$click"
            printf "Relic %s collected\n" "$i"
        fi
        i=$((i + 1))
    done
}

apply_event() {
    event_path="${1}"
    fetch_page "/${event_path}/"
    if grep -o -E "/${event_path}/enter(Game|Fight)/[?]r=[0-9]+" "$TMP/SRC"; then
        APPLY=`grep -o -E "/${event_path}/enter(Game|Fight)/[?]r=[0-9]+" "$TMP/SRC"`
        fetch_page "$APPLY"
        printf "Applied for battle\n"
    fi
}

use_elixir() {
    if [ "$FUNC_use_elixir" = "n" ]; then
        return
    fi

    # Uma aplicacao por janela (padrao 5h = menor intervalo entre as batalhas
    # em vale). Marca ANTES de usar: reinicio ou falha nao geram segunda leva.
    _el_h=${FUNC_elixir_horas:-5}
    case "$_el_h" in ''|*[!0-9]*) _el_h=5 ;; esac
    _el_agora=`date +%s`
    _el_ult=`cat "$TMP/last_elixir" 2>/dev/null`
    case "$_el_ult" in ''|*[!0-9]*) _el_ult=0 ;; esac
    if [ $((_el_agora - _el_ult)) -lt $((_el_h * 3600)) ]; then
        unset _el_h _el_agora _el_ult
        return
    fi
    printf '%s' "$_el_agora" > "$TMP/last_elixir" 2>/dev/null
    unset _el_h _el_agora _el_ult

    fetch_page "/inv/chest/"

    i=1
    while [ "$i" -le 4 ]; do
        click=`grep -o -E "/inv/chest/use/[0-9]+/1/[?]r=[0-9]+" "$TMP/SRC" | sed -n "${i}p"`
        if [ -z "$click" ]; then
            printf "No more URLs to process.\n"
            break
        fi
        fetch_page "$click"
        i=$((i + 1))
    done

    printf "Applied all elixir\n"
}
