king_fight() {
  cd "$TMP" || return 1
  LA=4
  HPER="38"
  RPER=5
  rm -f FULL

  cl_access() {
    local src="$TMP/SRC"
    [ -f "$src" ] || return 1

    set -- `combate_ler king "$HPER" "$RPER" "$src"`
    _emluta="$1"; RHP="$2"; HLHP="$3"; _hpat="$4"; _hp2at="$5"
    
    # Grava o HP máximo assim que pegar o hp atual (_hpat) e refaz HLHP pra não depender do modulo externo
    if [ ! -s FULL ] && [ -n "$_hpat" ]; then
      echo "$_hpat" > FULL
    fi
    read -r _fullat < FULL 2>/dev/null
    HLHP=$(awk -v ush="${_fullat:-0}" -v hper="$HPER" 'BEGIN { printf "%.0f", ush * hper / 100 }')
    
    grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:][:space:]]' "$src" | sed -n 's,\ [<]s,,;s,\ ,_,;2p' > USER 2>/dev/null
    
    grep -o -E '(/king/dodge/?[?]r[=][0-9]+)' "$src" | sed -n 1p > DODGE 2>/dev/null
    grep -o -E '(/king/heal/?[?]r[=][0-9]+)' "$src" | sed -n 1p > HEAL 2>/dev/null
    grep -o -E '(/king/kingatk/?[?]r[=][0-9]+)' "$src" | sed -n 1p > KINGATK 2>/dev/null
    grep -o -E '(/king/stone/?[?]r[=][0-9]+)' "$src" | sed -n 1p > STONE 2>/dev/null
    grep -o -E '(/king/at[a-z]{0,3}k[a-z]{3,6}/?[?]r[=][0-9]+)' "$src" | sed -n 1p > ATKRND 2>/dev/null
    grep -o -E '(/king/[a-z]{0,4}at[a-z]{0,3}k/?[?]r[=][0-9]+)' "$src" | grep -v 'kingatk' | sed -n 1p > ATK 2>/dev/null

    if [ "$_emluta" = "1" ] || grep -q -E '/king/(dodge|atk|heal)/' "$src"; then
      sessao_marcar
      printf "Em batalha King/PvP - HP: %s\n" "${_hpat:-0}"
    else
      (
        run_curl_exec "${URL}/king" > "$src"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      
      grep -o -E '(/king/unrip/?[?]r[=][0-9]+)' "$src" | sed -n 1p > UNRIP 2>/dev/null
      if [ -s UNRIP ]; then
        (
          run_curl_exec "${URL}$(cat UNRIP)" > "$src"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
      elif grep -q -E '/king/(dodge|atk|heal)/' "$src"; then
        sessao_marcar
        printf "Fase PvP secundária ativa.\n"
      else
        echo 1 > BREAK_LOOP
        printf "Battle over.\n"
        sleep 3s
      fi
    fi
  }

  king_percent() {
    if [ -n "$_hp2at" ] && [ -n "$_fullat" ] && [ "$_fullat" -gt 0 ] 2>/dev/null; then
      awk -v h="$_hp2at" -v f="$_fullat" 'BEGIN { printf "%.2f", h / f * 100 }'
    else
      echo "100"
    fi
  }

  cl_access
  cat HP > old_HP 2>/dev/null || echo "0" > old_HP
  _agora=`date +%s`
  FIRST_DODGE=1
  FIRST_HEAL=1
  _last_dodge=$(( _agora - 20 ))
  _last_heal=$(( _agora - 90 ))
  _last_atk=$(( _agora - LA ))
  echo "$_last_dodge" > last_dodge
  echo "$_last_heal"  > last_heal
  echo "$_last_atk"   > last_atk
  : > BREAK_LOOP

  FIGHT_BREAK=$(($(date +%s) + 600))
  until [ -s "BREAK_LOOP" ] || [ "$_agora" -gt "$FIGHT_BREAK" ]; do
    : > BREAK_LOOP
    _agora=`date +%s`

    KPCT=`king_percent`

    # ── MODO NORMAL: HP > 10% ──────────────────────────────────────────────
    if awk -v p="$KPCT" 'BEGIN { exit !(p > 10) }'; then

      if ! grep -q -o 'txt smpl grey' "$TMP/SRC" && \
         ([ "$FIRST_DODGE" -eq 1 ] || { [ $(( _agora - _last_dodge )) -gt 20 ] && [ $(( _agora - _last_dodge )) -lt 300 ]; }) && \
         awk -v ush="${_hpat:-0}" -v oldhp="$(cat old_HP 2>/dev/null || echo 0)" 'BEGIN { exit !(ush < oldhp) }' && \
         [ -s DODGE ]; then
        (
          run_curl_exec "${URL}$(cat DODGE)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        echo "${_hpat:-0}" > old_HP
        _last_dodge=`date +%s`; echo "$_last_dodge" > last_dodge; FIRST_DODGE=0

      elif awk -v ush="${_hpat:-0}" -v hlhp="$HLHP" 'BEGIN { exit !(ush < hlhp) }' && \
         ([ "$FIRST_HEAL" -eq 1 ] || { [ $(( _agora - _last_heal )) -gt 90 ] && [ $(( _agora - _last_heal )) -lt 300 ]; }) && \
         [ -s HEAL ]; then
        (
          run_curl_exec "${URL}$(cat HEAL)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        echo "$_hpat" > old_HP
        _last_heal=`date +%s`; echo "$_last_heal" > last_heal; FIRST_HEAL=0
        sleep 0.3s

      elif [ $(( _agora - _last_atk )) -gt "$LA" ]; then
        if [ -s KINGATK ]; then
          (
            run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
          if awk -v ush="${_hp2at:-100}" 'BEGIN { exit !(ush < 25) }' && [ -s STONE ]; then
            (
              run_curl_exec "${URL}$(cat STONE)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
          fi
        else
          if [ $(( _agora - _last_atk )) -ge "$LA" ] && \
             ! grep -q -o 'txt smpl grey' "$TMP/SRC" && \
             awk -v rhp="$RHP" -v enh="${_hp2at:-0}" 'BEGIN { exit !(rhp < enh) }' || \
             [ $(( _agora - _last_atk )) -ge "$LA" ] && \
             ! grep -q -o 'txt smpl grey' "$TMP/SRC" && \
             grep -q -o "`cat USER`" allies.txt 2>/dev/null && [ -s ATKRND ]; then
            (
              run_curl_exec "${URL}$(cat ATKRND)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
            _last_atk=`date +%s`; echo "$_last_atk" > last_atk
          fi
          
          if [ -s ATK ]; then
            (
              run_curl_exec "${URL}$(cat ATK)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
          fi
        fi
        _last_atk=`date +%s`; echo "$_last_atk" > last_atk

      else
        (
          run_curl_exec "${URL}/king" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        sleep 1s
      fi

    # ── MODO ESPERA: 1% < HP <= 10% ────────────────────────────────────────
    elif awk -v p="$KPCT" 'BEGIN { exit !(p > 1) }'; then
      printf "King sniper — modo espera: %s%%\n" "$KPCT"

      if [ -s KINGATK ]; then
        (
          run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        _last_atk=`date +%s`; echo "$_last_atk" > last_atk
      else
        (
          run_curl_exec "${URL}/king" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        sleep 0.5s
      fi

    # ── MODO FINALIZACAO: HP <= 1% ─────────────────────────────────────────
    else
      printf "King sniper — FINALIZACAO: %s%%\n" "$KPCT"

      if [ $(( _agora - _last_atk )) -gt "$LA" ]; then
        if [ -s KINGATK ]; then
          (
            run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
          if [ -s STONE ]; then
            (
              run_curl_exec "${URL}$(cat STONE)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
          fi
        elif [ -s ATK ]; then
          (
            run_curl_exec "${URL}$(cat ATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
        fi
        
        _last_atk=`date +%s`; echo "$_last_atk" > last_atk
      else
        (
          run_curl_exec "${URL}/king" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        sleep 0.5s
      fi
    fi

  done

  # ── POS-MORTE DO EVENTO ──────────────────────────────────────────────────
  if [ -s DODGE ]; then
    printf "Encerrando arena — executando dodge final\n"
    (
      run_curl_exec "${URL}$(cat DODGE)" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
  fi

  unset cl_access FIRST_DODGE FIRST_HEAL
  func_unset
  apply_event king
  printf "King ok\n"
  sleep 10s
  [ -t 1 ] && clear
}

king_start() {
  case `date +%H:%M` in
  (12:2[5-9]|16:2[5-9]|22:2[5-9])
    (
      run_curl_exec "$URL/king/enterGame" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf "King of the Immortals will be started...\n"
    until (case `date +%M` in (2[5-9]) exit 1;; esac); do
      sleep 3
    done
    (
      run_curl_exec "$URL/king/enterGame" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf "\nKing\n%s\n" "$URL"
    link_acao "$TMP/SRC" king > "$TMP/ACCESS" 2>/dev/null
    printf " Entering...\n%s\n" "`cat "$TMP/ACCESS"`"
    printf " Waiting...\n"
    cat "$TMP/SRC" | grep -o 'king/kingatk/' > "$TMP/EXIT" 2>/dev/null
    BREAK=$(($(date +%s) + 30))
    until [ -s "$TMP/EXIT" ] || [ "$(date +%s)" -gt "$BREAK" ]; do
      printf " ...\n%s\n" "`cat "$TMP/ACCESS"`"
      (
        run_curl_exec "${URL}$(cat "$TMP/ACCESS")" > "$TMP/SRC"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cat "$TMP/SRC" | sed 's/href=/\n/g' | grep '/king/' | head -n 1 | awk -F"[']" '{ print $2 }' > "$TMP/ACCESS" 2>/dev/null
      cat "$TMP/SRC" | grep -o 'king/kingatk/' > "$TMP/EXIT" 2>/dev/null
      sleep 2
    done
    king_fight
    ;;
  esac
}
