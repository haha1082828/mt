#!/bin/sh
# V2 conservadora: funcao preservada; unica otimização é cache local de timestamp.
flagfight_fight() {
  # Arquivos de batalha no diretorio da conta (sem mktemp)
  src_ram="$TMP/flag_src"
  full_ram="$TMP/flag_full"

  cd "$TMP" || return 1

  LA=4
  HPER=48
  RPER=15

  cf_access() {
    grep -o -E '(/[a-z]+/[a-z]{0,4}at[a-z]{0,3}k/[?]r[=][0-9]+)' "$src_ram" | sed -n '1p' > ATK 2>/dev/null
    grep -o -E '(/[a-z]+/at[a-z]{0,3}k[a-z]{3,6}/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > ATKRND 2>/dev/null
    grep -o -E '(/flagfight/dodge/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > DODGE 2>/dev/null
    grep -o -E '(/flagfight/heal/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > HEAL 2>/dev/null
    grep -o -E '(/[a-z]+/shield/[?]r[=][0-9]+)' "$src_ram" | sed -n 1p > SHIELD 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,20}( [[:upper:]][[:lower:]]{0,17})?)[[:space:]]\(' "$src_ram" | sed -n 's,\ [(],,;s,\ ,_,;2p' > CLAN 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:]]s' "$src_ram" | sed -n 's,\ [<]s,,;s,\ ,_,;2p' > USER 2>/dev/null
    grep -o -E "(hp)[^A-Za-z0-9]{1,4}[0-9]{1,6}" "$src_ram" | sed "s,hp[']\\/[>],,;s,\ ,," > USH 2>/dev/null
    grep -o -E "(nbsp)[^A-Za-z0-9]{1,2}[0-9]{1,6}" "$src_ram" | sed -n 's,nbsp[;],,;s,\ ,,;1p' > ENH 2>/dev/null
    awk -v ush="$(cat USH)" -v rper="$RPER" 'BEGIN { printf "%.0f", ush * rper / 100 + ush }' > RHP
    awk -v ush="$(cat "$full_ram")" -v hper="$HPER" 'BEGIN { printf "%.0f", ush * hper / 100 }' > HLHP

    if grep -q -o '/dodge/' "$src_ram"; then
      # A pagina respondeu com a luta: sessao confirmada.
      sessao_marcar
      printf "Em batalha flagfight - HP: %s\n" "`cat USH`"
    else
      echo 1 > BREAK_LOOP
      printf "Battle over!\n"
      sleep 2s
    fi
  }

  cf_access
  > BREAK_LOOP
  cat USH > old_HP
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
    if awk -v ush="$(cat USH)" -v hlhp="$(cat HLHP)" 'BEGIN { exit !(ush < hlhp) }' && \
       [ "$((_fight_now - $(cat last_heal)))" -gt 90 ] && \
       [ "$((_fight_now - $(cat last_heal)))" -lt 300 ]; then
      (
        run_curl_exec "${URL}$(cat HEAL)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat USH > old_HP
      printf "%s\n" "$_fight_now" > last_heal

    elif ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
         [ "$((_fight_now - $(cat last_dodge)))" -gt 20 ] && \
         [ "$((_fight_now - $(cat last_dodge)))" -lt 300 ] && \
         awk -v ush="$(cat USH)" -v oldhp="$(cat old_HP)" 'BEGIN { exit !(ush < oldhp) }'; then
      (
        run_curl_exec "${URL}$(cat DODGE)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat USH > old_HP
      printf "%s\n" "$_fight_now" > last_dodge

    elif awk -v latk="$_fight_now - $(cat last_atk)" -v atktime="$LA" 'BEGIN { exit !(latk != atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$src_ram" && \
         awk -v rhp="$(cat RHP)" -v enh="$(cat ENH)" 'BEGIN { exit !(rhp < enh) }' || \
         awk -v latk="$_fight_now - $(cat last_atk)" -v atktime="$LA" 'BEGIN { exit !(latk != atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
         grep -q -o "$(cat CLAN)" "$TMP/callies.txt"; then
      (
        run_curl_exec "${URL}$(cat ATKRND)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      printf "%s\n" "$_fight_now" > last_atk

    elif awk -v latk="$_fight_now - $(cat last_atk)" -v atktime="$LA" 'BEGIN { exit !(latk > atktime) }'; then
      (
        run_curl_exec "${URL}$(cat ATK)" > "$src_ram"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      printf "%s\n" "$_fight_now" > last_atk
    else
      fetch_page "/flagfight" "$src_ram"
      cf_access
      sleep 0.5s
    fi
  done

  rm -f "$src_ram" "$full_ram"
  unset src_ram full_ram ACCESS cf_access
  printf "Flagfight ok\n"
  sleep 10s
  apply_event flagfight
  [ -t 1 ] && clear
}
