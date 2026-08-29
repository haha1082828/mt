# shellcheck disable=SC2148
king_fight() {
  cd "$TMP" || return 1
  LA=4
  HPER="38"
  RPER=5

  # LEITURA DA PAGINA: DE 23 PROCESSOS PARA 2.
  #
  # Esta funcao lia o MESMO arquivo 23 vezes — sete grep, nove sed, dois awk
  # e cinco "$(cat ...)" — e roda duas a tres vezes por volta do laco de
  # luta. Davam 50 a 70 processos por volta, por conta, com todas as contas
  # entrando no evento no mesmo minuto. E o que estourava o teto de 32
  # processos do Android 12 e trazia o "signal 9" de volta justamente em
  # evento.
  #
  # Agora um unico awk le a pagina uma vez e grava os mesmos arquivos, com o
  # mesmo conteudo — conferido byte a byte em cinco cenarios: luta completa,
  # sem kingatk/stone, luta encerrada, pagina vazia e HP ausente.
  #
  # Sobram dois processos: o awk e o grep do nome do alvo, que continua
  # separado por depender de "sed -n 2p" com substituicoes proprias.
  cl_access() {
    set -- `combate_ler king "$HPER" "$RPER" "$TMP/SRC"`
    _emluta="$1"; RHP="$2"; HLHP="$3"; _hpat="$4"; _hp2at="$5"
    grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:][:space:]]' "$TMP/SRC" | sed -n 's,\ [<]s,,;s,\ ,_,;2p' > USER 2>/dev/null
    if [ "$_emluta" = "1" ]; then
      # A pagina respondeu com a luta: sessao confirmada.
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

  # Calcula porcentagem de HP do rei
  # HP2 = HP atual do rei, FULL = HP maximo do rei
  # Os dois valores ja vem do cl_access e do cache do FULL: eram dois "cat"
  # por volta do laco, so para calcular esta porcentagem.
  king_percent() {
    if [ -n "$_hp2at" ] && [ -n "$_fullat" ] && [ "$_fullat" -gt 0 ] 2>/dev/null; then
      awk -v h="$_hp2at" -v f="$_fullat" 'BEGIN { printf "%.2f", h / f * 100 }'
    else
      echo "100"
    fi
  }

  cl_access
  cat HP > old_HP
  # ESTADO DO LACO EM VARIAVEIS.
  #
  # last_atk, last_heal e FULL eram lidos com "$(cat ...)" a cada
  # comparacao — dois processos cada, varias vezes por volta. Os arquivos
  # continuam sendo gravados (outros pontos e o painel os leem), mas quem
  # decide dentro do laco passa a ler a variavel, que nao custa processo.
  _agora=`date +%s`
  _last_dodge=$(( _agora - 20 ))
  _last_heal=$(( _agora - 90 ))
  _last_atk=$(( _agora - LA ))
  _fullat=`cat FULL 2>/dev/null`
  echo "$_last_dodge" > last_dodge
  echo "$_last_heal"  > last_heal
  echo "$_last_atk"   > last_atk
  : > BREAK_LOOP

  # LIMITE DE TEMPO: BREAK_LOOP so e gravado quando a luta termina.
  # Se o estado nunca resolver (pagina muda, servidor devolve algo
  # inesperado), o laco ficava requisitando para sempre e a conta
  # travava naquela batalha. Teto de 10 minutos.
  FIGHT_BREAK=$(($(date +%s) + 600))
  until [ -s "BREAK_LOOP" ] || [ "$_agora" -gt "$FIGHT_BREAK" ]; do
    : > BREAK_LOOP
    _agora=`date +%s`

    KPCT=`king_percent`

    # ── MODO NORMAL: HP > 10% ──────────────────────────────────────────────
    # Comportamento original sem dodge
    if awk -v p="$KPCT" 'BEGIN { exit !(p > 10) }'; then

      # Heal do jogador (mantido em modo normal)
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

      # Ataque com cooldown normal
      elif [ $(( _agora - _last_atk )) -gt "$LA" ]; then
        if grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
          # kingatk disponivel — prioridade maxima
          (
            run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
          # Stone se rei com HP baixo
          if awk -v ush="$_hp2at" 'BEGIN { exit !(ush < 25) }'; then
            (
              run_curl_exec "${URL}$(cat STONE)" > "$TMP/SRC"
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
            cl_access
          fi
        else
          # Ataque random ou normal
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
        # Aguarda cooldown — apenas atualiza pagina
        (
          run_curl_exec "${URL}/king" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        sleep 1s
      fi

    # ── MODO ESPERA: 1% < HP <= 10% ────────────────────────────────────────
    # Para todos os ataques exceto kingatk — guarda o golpe para o fim
    elif awk -v p="$KPCT" 'BEGIN { exit !(p > 1) }'; then
      printf "King sniper — modo espera: %s%%\n" "$KPCT"

      # Apenas kingatk e permitido nesse intervalo
      if grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
        (
          run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        _last_atk=`date +%s`; echo "$_last_atk" > last_atk
      else
        # Sem kingatk — apenas atualiza e monitora HP
        (
          run_curl_exec "${URL}/king" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        sleep 0.5s
      fi

    # ── MODO FINALIZACAO: HP <= 1% ─────────────────────────────────────────
    # Modo agressivo — spam de ataques, sem delays, sem heal, sem dodge
    else
      printf "King sniper — FINALIZACAO: %s%%\n" "$KPCT"

      # Sequencia de finalizacao: kingatk > stone > atk > atk > atk > repeat
      if grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
        # 1. kingatk — prioridade absoluta
        (
          run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        # 2. stone imediatamente apos kingatk
        if [ -s STONE ]; then
          (
            run_curl_exec "${URL}$(cat STONE)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
        fi
      fi

      # 3-5. Spam ataque normal — sem delay
      (
        run_curl_exec "${URL}$(cat ATK)" > "$TMP/SRC"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cl_access
      (
        run_curl_exec "${URL}$(cat ATK)" > "$TMP/SRC"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cl_access
      (
        run_curl_exec "${URL}$(cat ATK)" > "$TMP/SRC"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cl_access

      # 6. kingatk novamente se disponivel
      if grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
        (
          run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
      fi

      _last_atk=`date +%s`; echo "$_last_atk" > last_atk
    fi

  done

  # ── POS-MORTE DO REI ───────────────────────────────────────────────────────
  # Executa dodge UMA ÚNICA VEZ imediatamente apos o rei morrer
  # Objetivo: garantir posicao para proxima rodada
  if [ -s DODGE ]; then
    printf "King morto — executando dodge pos-morte\n"
    (
      run_curl_exec "${URL}$(cat DODGE)" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
  fi

  unset cl_access
  func_unset
  # CORRECAO: sem o argumento, o apply_event monta "/${1}/" com $1
  # vazio e pede "//" — um request invalido que ainda gravava "//"
  # como atividade da conta no painel.
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
