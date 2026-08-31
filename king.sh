# shellcheck disable=SC2148
king_fight() {
  cd "$TMP" || return 1
  LA=4
  HPER="38"
  RPER=5

  cl_access() {
    set -- `combate_ler king "$HPER" "$RPER" "$TMP/SRC"`
    _emluta="$1"; RHP="$2"; HLHP="$3"; _hpat="$4"; _hp2at="$5"
    grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:][:space:]]' "$TMP/SRC" | sed -n 's,\ [<]s,,;s,\ ,_,;2p' > USER 2>/dev/null
    if [ "$_emluta" = "1" ]; then
      sessao_marcar
      printf "Em batalha - HP: %s\n" "$_hpat"
    else
      (
        run_curl_exec "${URL}/king" > "$TMP/SRC"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      grep -o -E '(/king/unrip/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC" | sed -n 1p > UNRIP 2>/dev/null
      if grep -q -o -E '(/king/unrip/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
        (
          run_curl_exec "${URL}$(cat UNRIP)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
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
  cat HP > old_HP
  _agora=`date +%s`
  _last_dodge=$(( _agora - 20 ))
  _last_heal=$(( _agora - 90 ))
  _last_atk=$(( _agora - LA ))
  _fullat=`cat FULL 2>/dev/null`
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

      if awk -v ush="$_hpat" -v hlhp="$HLHP" 'BEGIN { exit !(ush < hlhp) }' && \
         [ $(( _agora - _last_heal )) -gt 90 ] && \
         [ $(( _agora - _last_heal )) -lt 300 ]; then
        (
          run_curl_exec "${URL}$(cat HEAL)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        cat HP > FULL; _fullat="$_hpat"
        _last_heal=`date +%s`; echo "$_last_heal" > last_heal
        sleep 0.3s

      elif [ $(( _agora - _last_atk )) -gt "$LA" ]; then
        if grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
          (
            run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
          if awk -v ush="$_hp2at" 'BEGIN { exit !(ush < 25) }'; then
            (
              run_curl_exec "${URL}$(cat STONE)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
          fi
        else
          if [ $(( _agora - _last_atk )) -ne "$LA" ] && \
             ! grep -q -o 'txt smpl grey' "$TMP/SRC" && \
             awk -v rhp="$RHP" -v enh="$_hp2at" 'BEGIN { exit !(rhp < enh) }' || \
             [ $(( _agora - _last_atk )) -ne "$LA" ] && \
             ! grep -q -o 'txt smpl grey' "$TMP/SRC" && \
             grep -q -o "`cat USER`" allies.txt; then
            (
              run_curl_exec "${URL}$(cat ATKRND)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
            _last_atk=`date +%s`; echo "$_last_atk" > last_atk
          fi
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
        sleep 1s
      fi

    # ── MODO ESPERA: 1% < HP <= 10% ────────────────────────────────────────
    elif awk -v p="$KPCT" 'BEGIN { exit !(p > 1) }'; then
      printf "King sniper — modo espera: %s%%\n" "$KPCT"

      if grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
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

      # Agora o ataque focado respeita o tempo (LA) rigorosamente
      if [ $(( _agora - _last_atk )) -gt "$LA" ]; then
        if grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
          # 1. kingatk — prioridade absoluta
          (
            run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
          # 2. stone imediatamente apos kingatk se disponivel
          if [ -s STONE ]; then
            (
              run_curl_exec "${URL}$(cat STONE)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
          fi
        else
          # 3. Ataque normal
          (
            run_curl_exec "${URL}$(cat ATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
        fi
        
        # Marca que o tempo do ataque foi utilizado
        _last_atk=`date +%s`; echo "$_last_atk" > last_atk
      else
        # Aguarda o cooldown passar atualizando o alvo rapidamente
        (
          run_curl_exec "${URL}/king" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        sleep 0.5s
      fi
    fi

  done

  # ── POS-MORTE DO REI ───────────────────────────────────────────────────────
  if [ -s DODGE ]; then
    printf "King morto — executando dodge pos-morte\n"
    (
      run_curl_exec "${URL}$(cat DODGE)" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
  fi

  unset cl_access
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
      run_curl_exec "$URL/train" | grep -o -E '\(([0-9]+)\)' | sed 's/[()]//g' > "$TMP/FULL"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
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
