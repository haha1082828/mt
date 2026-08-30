#!/bin/sh
# V2 conservadora: funcao preservada; unica otimização é cache local de timestamp.
altars_fight() {
  cd "$TMP" || return 1
  apply_event

  LA=4
  echo "48" > HPER
  echo "15" > RPER

  cf_access() {
    grep -o -E '(/[a-z]+/[a-z]{0,4}at[a-z]{0,3}k/[?]r[=][0-9]+)' "$TMP/src.html" | sed -n 1p > ATK 2>/dev/null
    grep -o -E '(/[a-z]+/at[a-z]{0,3}k[a-z]{3,6}/[?]r[=][0-9]+)' "$TMP/src.html" | sed -n 1p > ATKRND 2>/dev/null
    grep -o -E '(/altars/dodge/[?]r[=][0-9]+)' "$TMP/src.html" | sed -n 1p > DODGE 2>/dev/null
    grep -o -E '(/altars/heal/[?]r[=][0-9]+)' "$TMP/src.html" | sed -n 1p > HEAL 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,20}( [[:upper:]][[:lower:]]{0,17})?)[[:space:]]\(' "$TMP/src.html" | sed -n 's,\ [(],,;s,\ ,_,;2p' > CLAN 2>/dev/null
    grep -o -E "(hp)[^A-Za-z0-9]{1,4}[0-9]{1,6}" "$TMP/src.html" | sed "s,hp[']\\/[>],,;s,\ ,," > HP 2>/dev/null
    grep -o -E "(nbsp)[^A-Za-z0-9]{1,2}[0-9]{1,6}" "$TMP/src.html" | sed -n 's,nbsp[;],,;s,\ ,,;1p' > HP2 2>/dev/null
    awk -v ush="$(cat HP)" -v rper="$(cat RPER)" 'BEGIN { printf "%.0f", ush * rper / 100 + ush }' > RHP
    awk -v ush="$(cat FULL)" -v hper="$(cat HPER)" 'BEGIN { printf "%.0f", ush * hper / 100 }' > HLHP
    if grep -q -o '/dodge/' "$TMP/src.html"; then
      printf "Em batalha - HP: %s\n" "`cat HP`"
    else
      echo 1 > BREAK_LOOP
      printf "Battle over!\n"
      sleep 2s
    fi
  }

  cf_access
  : > BREAK_LOOP; cat HP > old_HP
  _fight_now=`date +%s`
  echo $((_fight_now - 20)) > last_dodge
  echo $((_fight_now - 90)) > last_heal
  echo $((_fight_now - LA)) > last_atk

  # LIMITE DE TEMPO: BREAK_LOOP so e gravado quando a luta termina.
  # Se o estado nunca resolver (pagina muda, servidor devolve algo
  # inesperado), o laco ficava requisitando para sempre e a conta
  # travava naquela batalha. Teto de 10 minutos.
  FIGHT_BREAK=$(($(date +%s) + 600))
  until [ -s "BREAK_LOOP" ] || [ "$(date +%s)" -gt "$FIGHT_BREAK" ]; do
    _fight_now=`date +%s`
    cf_access
    if ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
       [ "$((_fight_now - $(cat last_dodge)))" -gt 20 ] && \
       [ "$((_fight_now - $(cat last_dodge)))" -lt 300 ] && \
       awk -v ush="$(cat HP)" -v oldhp="$(cat old_HP)" 'BEGIN { exit !(ush < oldhp) }'; then
      (
        run_curl_exec "${URL}$(cat DODGE)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat HP > old_HP; printf "%s\n" "$_fight_now" > last_dodge

    elif awk -v ush="$(cat HP)" -v hlhp="$(cat HLHP)" 'BEGIN { exit !(ush < hlhp) }' && \
         [ "$((_fight_now - $(cat last_heal)))" -gt 90 ] && \
         [ "$((_fight_now - $(cat last_heal)))" -lt 300 ]; then
      (
        run_curl_exec "${URL}$(cat HEAL)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat HP > old_HP
      printf "%s\n" "$_fight_now" > last_heal

    elif awk -v latk="$_fight_now - $(cat last_atk)" -v atktime="$LA" 'BEGIN { exit !(latk != atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
         awk -v rhp="$(cat RHP)" -v enh="$(cat HP2)" 'BEGIN { exit !(rhp < enh) }' || \
         awk -v latk="$_fight_now - $(cat last_atk)" -v atktime="$LA" 'BEGIN { exit !(latk != atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
         grep -q -o "$(cat CLAN)" "$TMP/callies.txt"; then
      (
        run_curl_exec "${URL}$(cat ATKRND)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      printf "%s\n" "$_fight_now" > last_atk

    elif awk -v latk="$_fight_now - $(cat last_atk)" -v atktime="$LA" 'BEGIN { exit !(latk > atktime) }'; then
      (
        run_curl_exec "${URL}$(cat ATK)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      printf "%s\n" "$_fight_now" > last_atk
    else
      (
        run_curl_exec "${URL}/altars" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      sleep 0.5s
    fi
  done

  unset cf_access _random
  func_unset
  apply_event
  printf "Altars ok\n"
  sleep 10s
  [ -t 1 ] && clear
}
