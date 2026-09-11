flagfight_fight() {
  src_ram="$TMP/flag_src"
  full_ram="$TMP/flag_full"

  cd "$TMP" || return 1

  LA=4
  HPER=40
  RPER=15

  cf_access() {
    [ -f "$src_ram" ] || return 1
    grep -o -E '(/[a-z]+/[a-z]{0,4}at[a-z]{0,3}k/[?]r[=][0-9]+)' "$src_ram" | sed -n '1p' > ATK 2>/dev/null
    grep -o -E '(/[a-z]+/at[a-z]{0,3}k[a-z]{3,6}/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > ATKRND 2>/dev/null
    grep -o -E '(/flagfight/dodge/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > DODGE 2>/dev/null
    grep -o -E '(/flagfight/heal/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > HEAL 2>/dev/null
    grep -o -E '(/[a-z]+/shield/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > SHIELD 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,20}( [[:upper:]][[:lower:]]{0,17})?)[[:space:]]\(' "$src_ram" | sed -n 's,\ [(],,;s,\ ,_,;2p' > CLAN 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:]]s' "$src_ram" | sed -n 's,\ [<]s,,;s,\ ,_,;2p' > USER 2>/dev/null
    grep -o -E "(hp)[^A-Za-z0-9]{1,4}[0-9]{1,6}" "$src_ram" | grep -o -E '[0-9]+' | head -n 1 > USH 2>/dev/null
    grep -o -E "(nbsp)[^A-Za-z0-9]{1,2}[0-9]{1,6}" "$src_ram" | grep -o -E '[0-9]+' | head -n 1 > ENH 2>/dev/null

    read -r ush < USH 2>/dev/null
    read -r full < "$full_ram" 2>/dev/null

    awk -v ush="${ush:-0}" -v rper="$RPER" 'BEGIN { printf "%.0f", ush * rper / 100 + ush }' > RHP
    awk -v ush="${full:-0}" -v hper="$HPER" 'BEGIN { printf "%.0f", ush * hper / 100 }' > HLHP

    if grep -q -o '/dodge/' "$src_ram"; then
      sessao_marcar
      printf "Em batalha flagfight - HP: %s\n" "${ush:-0}"
    else
      echo 1 > BREAK_LOOP
      printf "Battle over!\n"
      sleep 2s
    fi
  }

  cf_access
  > BREAK_LOOP
  cat USH > old_HP
  FIRST_DODGE=1
  FIRST_HEAL=1
  echo $(($(date +%s) - 20)) > last_dodge
  echo $(($(date +%s) - 90)) > last_heal
  echo $(($(date +%s) - LA)) > last_atk

  FIGHT_BREAK=$(($(date +%s) + 600))
  until [ -s "BREAK_LOOP" ] || [ "$(date +%s)" -gt "$FIGHT_BREAK" ]; do
    if awk -v ush="$(cat USH)" -v hlhp="$(cat HLHP)" 'BEGIN { exit !(ush < hlhp) }' && \
       ([ "$FIRST_HEAL" -eq 1 ] || { [ "$(($(date +%s) - $(cat last_heal)))" -gt 90 ] && [ "$(($(date +%s) - $(cat last_heal)))" -lt 300 ]; }); then
      (
        run_curl_exec "${URL}$(cat SHIELD)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat USH > "$full_ram"
      cat USH > old_HP
      date +%s > last_heal
      FIRST_HEAL=0

    elif ! grep -q -o 'txt smpl grey' "$src_ram" && \
         ([ "$FIRST_DODGE" -eq 1 ] || { [ "$(($(date +%s) - $(cat last_dodge)))" -gt 20 ] && [ "$(($(date +%s) - $(cat last_dodge)))" -lt 300 ]; }) && \
         awk -v ush="$(cat USH)" -v oldhp="$(cat old_HP)" 'BEGIN { exit !(ush < oldhp) }'; then
      (
        run_curl_exec "${URL}$(cat DODGE)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat USH > old_HP
      date +%s > last_dodge
      FIRST_DODGE=0

    elif awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$src_ram" && \
         awk -v rhp="$(cat RHP)" -v enh="$(cat ENH)" 'BEGIN { exit !(rhp < enh) }' || \
         awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$src_ram" && \
         grep -q -o "$(cat CLAN)" "$TMP/callies.txt"; then
      (
        run_curl_exec "${URL}$(cat ATKRND)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      date +%s > last_atk

    elif awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk > atktime) }'; then
      (
        run_curl_exec "${URL}$(cat ATK)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      date +%s > last_atk
    else
      fetch_page "/flagfight" "$src_ram"
      cf_access
      sleep 1s
    fi
  done

  rm -f "$src_ram" "$full_ram"
  unset src_ram full_ram ACCESS cf_access
  printf "Flagfight ok\n"
  sleep 10s
  apply_event flagfight
  [ -t 1 ] && clear
}

flagfight_start() {
  src_ram="$TMP/flag_src"
  full_ram="$TMP/flag_full"

  case `date +%H:%M` in
  (10:1[0-4]|16:1[0-4])
    (
      run_curl_exec "$URL/train" | grep -o -E '\(([0-9]+)\)' | sed 's/[()]//g' > "$full_ram"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    fetch_page "/flagfight/?close=reward" "$src_ram"
    fetch_page "/flagfight/enterFight" "$src_ram"
    printf "Flagfight will be started...\n"

    while (case `date +%M:%S` in (14:[3-5][0-9]) exit 1;; esac); do
      sleep 3s
    done

    (
      run_curl_exec "$URL/flagfight/enterFight" > "$src_ram"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    grep -o -E '(/[a-z]+/[a-z]+/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+)' "$src_ram" | sed -n '1p' > "$TMP/ACCESS" 2>/dev/null
    printf " Entering...\n"
    printf " Waiting...\n"

    BREAK=$(($(date +%s) + 60))

    until grep -q -o 'flagfight/dodge/' "$TMP/ACCESS" || [ "$(date +%s)" -gt "$BREAK" ]; do
      printf " ...\n%s\n" "`cat "$TMP/ACCESS"`"
      fetch_page "/flagfight/" "$src_ram"
      grep -o -E '(/flagfight/[a-z]+/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+)' "$src_ram" | sed -n '1p' > "$TMP/ACCESS" 2>/dev/null
      sleep 3
    done

    if [ -s "$TMP/ACCESS" ]; then
      flagfight_fight
    else
      rm -f "$src_ram" "$full_ram"
      unset src_ram full_ram
    fi
    ;;
  esac
}
