members_allies() {
    cd "$TMP" || return 1

    echo "" >> allies.txt
    clan_id
    echo "" > callies.txt

    if [ -n "$CLD" ]; then
        printf "Updating clan members into allies\n"

        for num in `seq 5 -1 1`; do
            printf "/clan/%s/%s\n" "$CLD" "$num"
            (
                run_curl_exec "${URL}/clan/${CLD}/${num}" | grep -o -E "[/]>([[:upper:]][[:lower:]]{0,15}[[:space:]]{0,1}[[:upper:]]{0,1}[[:lower:]]{0,14},[[:space:]])<s" | awk -F"[>]" '{print $2}' | awk -F"[,]" '{print $1}' | sed 's,\ ,_,' >> allies.txt
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
        done

        sort -u allies.txt -o allies.txt
    fi

    printf "Allies for Coliseum and King of the Immortals:\n"
    cat allies.txt
    printf "Wait to continue.\n"
    sleep 2
}

id_allies() {
    printf "Looking for allies on friends list\n"
    cd "$TMP" || return 1
    : > "$TMP/tmp.txt"
    printf "/mail/friends\n"

    (
        run_curl_exec "${URL}/mail/friends" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17

    NPG=`cat "$TMP/SRC" | grep -o -E '/mail/friends/([0-9]{0,4})[^[:alnum:]]{4}62[^[:alnum:]]{3}62[^[:alnum:]]' | sed 's/\/mail\/friends\/\([0-9]\{0,4\}\).*/\1/'`

    if [ -z "$NPG" ]; then
        printf "/mail/friends\n"
        (
            run_curl_exec "${URL}/mail/friends" | sed 's,/user/,\n/user/,g' | grep '/user/' | grep '/mail/' | cut -d\< -f1 >> tmp.txt
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
    fi

    NPG=`cat "$TMP/SRC" | grep -o -E '/mail/friends/([0-9]{0,4})[^[:alnum:]]{4}62[^[:alnum:]]{3}62[^[:alnum:]]' | sed 's/\/mail\/friends\/\([0-9]\{0,4\}\).*/\1/'`

    if [ -z "$NPG" ]; then
        printf "/mail/friends\n"
        (
            run_curl_exec "${URL}/mail/friends" | sed 's,/user/,\n/user/,g' | grep '/user/' | grep '/mail/' | cut -d\< -f1 >> tmp.txt
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
    else
        for num in `seq "$NPG" -1 1`; do
            printf "Friends list page %s\n" "$num"
            (
                run_curl_exec "${URL}/mail/friends/${num}" | sed 's,/user/,\n/user/,g' | grep '/user/' | grep '/mail/' | cut -d\< -f1 >> tmp.txt
            ) </dev/null > /dev/null 2>&1 &
            time_exit 17
        done
    fi

    sort -u tmp.txt -o tmp.txt
    cat tmp.txt | cut -d\> -f2 | sed 's,\ ,_,' > allies.txt
}

clan_allies() {
    clan_id

    if [ -n "$CLD" ]; then
        cd "$TMP" || return 1
        echo "" > callies.txt
        cut -d/ -f3 tmp.txt > ids.txt

        printf "Clan allies by Leader on friends list\n"
        Lnl=`wc -l < ids.txt`
        ts=0

        for num in `seq "$Lnl" -1 1`; do
            IDN=`sed -n "${num}p" ids.txt`
            if [ -n "$IDN" ]; then
                printf "/user/%s\n" "$IDN"
                (
                    run_curl_exec "${URL}/user/${IDN}" > "$TMP/SRC"
                ) </dev/null > /dev/null 2>&1 &
                time_exit 17

                LEADPU=`sed 's,/clan/,\n/clan/,g' "$TMP/SRC" | grep -E "</a>, <span class='blue'|</a>, <span class='green'" | cut -d\< -f1 | cut -d\> -f2`
                alCLAN=`grep -E -o '/clan/[0-9]{1,3}' "$TMP/SRC" | tail -n1`

                printf "%s - %s\n" "$LEADPU" "$alCLAN"

                if [ -n "$LEADPU" ]; then
                    ts=$((ts + 1))
                    echo "$LEADPU" | sed 's,\ ,_,' >> callies.txt
                    printf "%s. Ally %s %s added.\n" "$ts" "$LEADPU" "$alCLAN"
                    sort -u callies.txt -o callies.txt
                fi

                sleep 1s
            fi
        done
    fi
}

conf_allies() {
    cd "$TMP" || return 1
    [ -t 1 ] && clear

    printf "The script will consider users on your friends list and Clan as allies.\n"
    printf "1) Add/Update alliances (All Battles)\n"
    printf "2) Add/Update just Herois alliances (Coliseum/King of immortals)\n"
    printf "3) Add/Update just Clan alliances (Altars, Clan Coliseum and Clan Fight)\n"
    printf "4) Do nothing\n"

    AL=`get_config "ALLIES"`
    printf "Current alliance configuration: %s\n" "$AL"

    if [ -z "$AL" ]; then
        printf "Set up alliances [1 to 4]: "
        while true; do
            read -r AL
            echo
            case "$AL" in
                [1-4])
                    set_config "ALLIES" "$AL"
                    break
                    ;;
                *)
                    printf "Invalid input. Please enter a value between 1 and 4:\n"
                    ;;
            esac
        done
    else
        printf "Using existing alliance configuration: %s\n" "$AL"
    fi

    case "$AL" in
        1)
            id_allies
            members_allies
            clan_allies
            printf "Alliances on all battles active\n"
            ;;
        2)
            id_allies
            if [ -e "$TMP/callies.txt" ]; then
                : > "$TMP/callies.txt"
            fi
            printf "Just Herois alliances now.\n"
            ;;
        3)
            id_allies
            clan_allies
            if [ -e "$TMP/allies.txt" ]; then
                : > "$TMP/allies.txt"
            fi
            printf "Just Clan alliances now.\n"
            ;;
        4)
            printf "Nothing changed.\n"
            : >> "$TMP/allies.txt"
            : >> "$TMP/callies.txt"
            ;;
        *)
            [ -t 1 ] && clear
            if [ -n "$AL" ]; then
                # CORRECAO: aqui era "kill -9 $$" — SIGKILL no proprio
                # shell por causa de uma opcao de menu invalida. Num worker
                # isso derruba a conta sem deixar rastro, e $$ e o PID do
                # shell PRINCIPAL mesmo quando avaliado dentro de subshell,
                # entao o estrago ia muito alem da funcao. Uma opcao
                # invalida e para ser recusada, nao para matar o processo.
                printf "Opcao invalida: %s — configuracao de aliados ignorada\n" "$AL"
                printf "conf_allies: opcao invalida (%s)\n" "$AL" >> "$TMP/ERROR_DEBUG"
                return 1
            else
                printf "Time exceeded!\n" >> "$TMP/ERROR_DEBUG"
            fi
            ;;
    esac
}
altars_fight() {
  cd "$TMP" || return 1
  apply_event altars
  LA=4
  echo "25" > HPER
  echo "15" > RPER
  rm -f FULL

  cf_access() {
    local html="$TMP/src.html"
    [ -f "$html" ] || return 1
    
    # Extrações consolidadas mantendo os mesmos destinos originais
    grep -o -E '(/[a-z]+/[a-z]{0,4}at[a-z]{0,3}k/?[?]r[=][0-9]+)' "$html" | sed -n 1p > ATK 2>/dev/null
    grep -o -E '(/[a-z]+/at[a-z]{0,3}k[a-z]{3,6}/?[?]r[=][0-9]+)' "$html" | sed -n 1p > ATKRND 2>/dev/null
    grep -o -E '(/altars/dodge/?[?]r[=][0-9]+)' "$html" | sed -n 1p > DODGE 2>/dev/null
    grep -o -E '(/altars/heal/?[?]r[=][0-9]+)' "$html" | sed -n 1p > HEAL 2>/dev/null
    grep -o -E '([[:upper:]][[:lower:]]{0,20}( [[:upper:]][[:lower:]]{0,17})?)[[:space:]]\(' "$html" | sed -n 's,\ [(],,;s,\ ,_,;2p' > CLAN 2>/dev/null
    grep -o -E "(hp)[^A-Za-z0-9]{1,4}[0-9]{1,6}" "$html" | grep -o -E '[0-9]+' | head -n 1 > HP 2>/dev/null
    grep -o -E "(nbsp)[^A-Za-z0-9]{1,2}[0-9]{1,6}" "$html" | grep -o -E '[0-9]+' | head -n 1 > HP2 2>/dev/null
    
    if [ ! -s FULL ]; then
      cat HP > FULL 2>/dev/null
    fi

    read -r ush < HP 2>/dev/null
    read -r rper < RPER 2>/dev/null
    read -r full < FULL 2>/dev/null
    read -r hper < HPER 2>/dev/null

    awk -v ush="${ush:-0}" -v rper="${rper:-0}" 'BEGIN { printf "%.0f", ush * rper / 100 + ush }' > RHP
    awk -v ush="${full:-0}" -v hper="${hper:-0}" 'BEGIN { printf "%.0f", ush * hper / 100 }' > HLHP

    if grep -q -o '/dodge/' "$html"; then
      sessao_marcar
      printf "Em batalha - HP: %s\n" "${ush:-0}"
    else
      echo 1 > BREAK_LOOP
      printf "Battle over!\n"
      sleep 2s
    fi
  }

  cf_access
  : > BREAK_LOOP; cat HP > old_HP
  FIRST_DODGE=1
  FIRST_HEAL=1
  echo $(($(date +%s) - 20)) > last_dodge
  echo $(($(date +%s) - 90)) > last_heal
  echo $(($(date +%s) - LA)) > last_atk

  FIGHT_BREAK=$(($(date +%s) + 600))
  until [ -s "BREAK_LOOP" ] || [ "$(date +%s)" -gt "$FIGHT_BREAK" ]; do
    cf_access
    if ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
       ([ "$FIRST_DODGE" -eq 1 ] || { [ "$(($(date +%s) - $(cat last_dodge)))" -gt 20 ] && [ "$(($(date +%s) - $(cat last_dodge)))" -lt 300 ]; }) && \
       awk -v ush="$(cat HP)" -v oldhp="$(cat old_HP)" 'BEGIN { exit !(ush < oldhp) }'; then
      (
        run_curl_exec "${URL}$(cat DODGE)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat HP > old_HP; date +%s > last_dodge
      FIRST_DODGE=0

    elif awk -v ush="$(cat HP)" -v hlhp="$(cat HLHP)" 'BEGIN { exit !(ush < hlhp) }' && \
         ([ "$FIRST_HEAL" -eq 1 ] || { [ "$(($(date +%s) - $(cat last_heal)))" -gt 90 ] && [ "$(($(date +%s) - $(cat last_heal)))" -lt 300 ]; }); then
      (
        run_curl_exec "${URL}$(cat HEAL)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      cat HP > old_HP
      date +%s > last_heal
      FIRST_HEAL=0

    elif awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
         awk -v rhp="$(cat RHP)" -v enh="$(cat HP2)" 'BEGIN { exit !(rhp < enh) }' || \
         awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }' && \
         ! grep -q -o 'txt smpl grey' "$TMP/src.html" && \
         grep -q -o "$(cat CLAN)" "$TMP/callies.txt"; then
      (
        run_curl_exec "${URL}$(cat ATKRND)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      date +%s > last_atk

    elif awk -v latk="$(($(date +%s) - $(cat last_atk)))" -v atktime="$LA" 'BEGIN { exit !(latk >= atktime) }'; then
      (
        run_curl_exec "${URL}$(cat ATK)" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      date +%s > last_atk
    else
      (
        run_curl_exec "${URL}/altars" > "$TMP/src.html"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cf_access
      sleep 1s
    fi
  done

  unset cf_access _random FIRST_DODGE FIRST_HEAL
  func_unset
  apply_event altars
  printf "Altars ok\n"
  sleep 10s
  [ -t 1 ] && clear
}

altars_start() {
  case `date +%H:%M` in
  (13:5[5-9]|20:5[5-9])
    fetch_page "/altars/?close=reward" "$TMP/src.html"
    fetch_page "/altars/enterFight" "$TMP/src.html"
    printf "Ancient Altars will be started...\n"

    until (case `date +%M` in (55|56|57|58|59) exit 1;; esac); do
      sleep 2
    done

    fetch_page "/altars/enterFight" "$TMP/src.html"
    printf "Altars will be started...\n"
    link_acao "$TMP/src.html" altars > "$TMP/ACCESS" 2>/dev/null
    printf " Entering...\n"
    printf " Waiting...\n"
    BREAK=$(($(date +%s) + 30))
    until grep -q -o 'altars/dodge/' "$TMP/ACCESS" || [ "$(date +%s)" -gt "$BREAK" ]; do
      printf "%s\n ...\n%s\n" "$URL" "`cat "$TMP/ACCESS"`"
      fetch_page "/altars" "$TMP/src.html"
      link_acao "$TMP/src.html" altars > "$TMP/ACCESS" 2>/dev/null
      sleep 3
    done
    altars_fight
    ;;
  esac
}
# shellcheck disable=SC2148
arena_fault() {
    (
        run_curl_exec "${URL}/fault" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    BREAK=$(($(date +%s) + 10))
    while grep -q -o '/fault/attack' "$TMP/SRC" || [ "$(date +%s)" -lt "$BREAK" ]; do
        ACCESS=`grep -o -E '(/fault/attack/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+)' "$TMP/SRC" | sed -n '1p'`
        (
            run_curl_exec "${URL}${ACCESS}" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        printf "%s\n" "$ACCESS"
        sleep 1s
    done
    printf "fault (ok)\n"
}

arena_collFight() {
    (
        run_curl_exec "${URL}/collfight/enterFight" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    if grep -q -o '/collfight/' "$TMP/SRC"; then
        printf "collfight ...\n"
        printf "/collfight/enterFight\n"
        ACCESS=`cat "$TMP/SRC" | sed 's/href=/\n/g' | grep 'collfight/take' | head -n1 | awk -F\' '{ print $2 }'`
        (
            run_curl_exec "${URL}${ACCESS}" > /dev/null
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        printf "%s\n" "$ACCESS"
        (
            run_curl_exec "${URL}/collfight/enterFight" > /dev/null
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        printf "/collfight/enterFight\n"
        printf "collfight (ok)\n"
    fi
}

arena_duel() {
    printf "Arena\n"

    checkQuest 3 apply
    checkQuest 4 apply

    fetch_page "/arena/"

    BREAK=$(($(date +%s) + 60))
    count=0

    # CORRECAO: o laco era "until grep 'lab/wizard' ...". Em alguns estados a
    # pagina da arena ja traz o link do Laboratorio do Mago e o laco terminava
    # ANTES de atacar — a conta "ia na arena" mas nao golpeava (energia nao
    # caia). Agora quem manda e a PRESENCA do link de ataque real (com nonce),
    # slot generico [0-9]+ (nao fixo em /1/), dentro do teto de 60s.
    while [ "$(date +%s)" -lt "$BREAK" ]; do
        # ALINHADO AO ORIGINAL: o alvo e o slot 1 (/arena/attack/1/), que e o
        # que o original ataca sempre. O generico [0-9]+ fica so de reserva,
        # para a pagina que por algum motivo nao ofereca o slot 1 — assim o
        # comportamento e identico ao do original no caso normal, sem parar de
        # golpear no caso incomum.
        ACCESS=`grep -o -E '/arena/attack/1/[?]r[=][0-9]+' "$TMP/SRC" | sed -n '1p'`
        [ -n "$ACCESS" ] || \
            ACCESS=`grep -o -E '/arena/attack/[0-9]+/[?]r[=][0-9]+' "$TMP/SRC" | sed -n '1p'`
        if [ -z "$ACCESS" ]; then
            printf "  Arena: sem ataque disponivel agora\n"
            break
        fi
        fetch_page "$ACCESS"
        count=$((count + 1))
        printf "  Attack %s\n" "$count"
        sleep 0.6s
    done

    fetch_page "/inv/bag/"
    SELL=`grep -o -E '(/inv/bag/sellAll/1/[?]r[=][0-9]+)' "$TMP/SRC" | sed -n '1p'`
    # CORRECAO: sem nada a vender o SELL fica vazio e o fetch_page ""
    # requisitava a HOME — um pedido a toa por passagem na arena que ainda
    # sobrescrevia $TMP/pagina, fazendo o painel (e a atividade que os outros
    # jogadores veem) piscar "Pagina Principal" no meio da arena.
    if [ -n "$SELL" ]; then
        fetch_page "$SELL"
        printf "Sell all items ok\n"
    else
        printf "Nada a vender na mochila\n"
    fi

    checkQuest 3 end
    checkQuest 4 end

    printf "Arena ok\n"
}

arena_fullmana() {
    printf "energy arena ...\n"
    (
        run_curl_exec "${URL}/arena/quit" | sed "s/href='/\n/g" | grep 'attack/1' | head -n1 | awk -F/ '{ print $5 }' | tr -cd '[:digit:]' > "$TMP/ARENA"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf " - 1 Attack...\n"
    (
        run_curl_exec "${URL}/arena/attack/1/?r=`cat "$TMP/ARENA"`" | sed "s/href='/\n/g" | grep 'arena/lastPlayer' | head -n1 | awk -F\' '{ print $1 }' | tr -cd '[:digit:]' > "$TMP/ATK1"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf " - Full Attack...\n"
    (
        run_curl_exec "${URL}/arena/lastPlayer/?r=`cat "$TMP/ATK1"`&fullmana=true" > /dev/null
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf "Energy arena ok\n"
}

# ---------------------------------------------------------------------------
# Aliados por lista (configurada no setup.sh, aplicada pela propria conta)
#   ALLIES=5  so o cla da conta (membros)
#   ALLIES=6  so os cla(s) dos lideres da lista
#   ALLIES=7  os dois
# Lista de IDs de CLAS aliados: $TWM_ACC_DIR/allies_clas.txt (um ID por linha)
# Estado: $TWM_ACC_DIR/allies_state = "MODO|AAAAMMDD" (1x por dia)
# Marcador por sessao: $TMP/allies_ok (TMP e RAM: some no reinicio e reaplica)
# ---------------------------------------------------------------------------

# al_members_clan <cid>: anexa os membros do cla em $TMP/allies_tmp.txt
# Nomes de membros a partir do HTML de uma pagina de cla (stdin). MESMA leitura
# usada pelo setup.sh: texto do link de cada jogador, mais o padrao antigo.
al_so_membros() {
    # Mantem so os blocos <li> de membro: tem /user/ID e NAO tem /chat/ (o chat do cla
    # tambem traz links /user/ID, mas fora de <li>, e nao sao membros).
    tr '\n\r' '  ' | sed 's,<li[^>]*>,\n&,g; s,</li>,&\n,g' | grep '^<li' | grep '/user/' | grep -v '/chat/'
}

al_extrai_nomes() {
    # Achata quebras de linha: um nome que quebra de linha tambem e lido.
    _en_t=`cat | tr '\n\r' '  '`
    {
        # Padrao antigo (lia 41 de 50): "/>Nome, <s" com nome em maiuscula.
        printf '%s\n' "$_en_t" | grep -o -E "[/]>([[:upper:]][[:lower:]]{0,15}[[:space:]]{0,1}[[:upper:]]{0,1}[[:lower:]]{0,14},[[:space:]])<s" | awk -F"[>]" '{print $2}' | awk -F"[,]" '{print $1}'
        if [ "$1" != antigo ]; then
            # Ampliado: nome entre um ">" e ", <tag", aceitando ate 2 marcadores curtos
            # <span ...>'</span> entre o nome e a virgula (ex.: class='not_here'), acento,
            # numero, minuscula, "_" e quebras de linha.
            printf '%s\n' "$_en_t" | grep -o -E "[>][^<>,/]{2,40}(<span[^>]*>[^<]{0,3}</span>){0,2},[[:space:]]*<" | sed -E 's/^[>]//; s/[<,].*$//'
        fi
    } | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      | awk 'length($0) > 1 && $0 !~ /[\/=<>]/ && $0 !~ /^[0-9]+$/ { gsub(/ /, "_"); print }' \
      | sort -u
}

al_members_clan() {
    [ -n "$1" ] || return 1
    _amc_out="${2:-$TMP/allies_tmp.txt}"
    _amc_seen="$TMP/al_seen.$$"
    : > "$_amc_seen"; : > "$_amc_out.raw"; : > "$_amc_out.raw_antigo"
    _aln=1
    while [ "$_aln" -le 8 ]; do
        _amc_pg=`run_curl_exec "${URL}/clan/$1/${_aln}"`
        _amc_mem=`printf '%s\n' "$_amc_pg" | al_so_membros`
        _amc_novo=0
        for _amc_x in `printf '%s\n' "$_amc_mem" | grep -o -E '/user/[0-9]+' | sort -u`; do
            if ! grep -q -x -F "$_amc_x" "$_amc_seen"; then
                printf '%s\n' "$_amc_x" >> "$_amc_seen"
                _amc_novo=1
            fi
        done
        [ "$_amc_novo" -eq 1 ] || break
        printf '%s\n' "$_amc_mem" | al_extrai_nomes >> "$_amc_out.raw"
        printf '%s\n' "$_amc_mem" | al_extrai_nomes antigo >> "$_amc_out.raw_antigo"
        _aln=$((_aln + 1))
        sleep 1
    done
    _amc_np=`grep -c . "$_amc_seen"`
    _amc_nn=`sort -u "$_amc_out.raw" | grep -c .`
    if [ "$_amc_np" -gt 0 ] && [ "$_amc_nn" -gt "$_amc_np" ]; then
        sort -u "$_amc_out.raw_antigo" | grep -v '^$' >> "$_amc_out"
    else
        sort -u "$_amc_out.raw" | grep -v '^$' >> "$_amc_out"
    fi
    rm -f "$_amc_out.raw" "$_amc_out.raw_antigo" "$_amc_seen"
    unset _aln _amc_out _amc_pg _amc_mem _amc_novo _amc_x _amc_np _amc_nn _amc_seen
}

# al_lider <uid>: imprime "cid|nome_do_lider" lendo a pagina do usuario
al_lider() {
    run_curl_exec "${URL}/user/$1" > "$TMP/al_user.html" 2>/dev/null
    # A pagina do lider traz varios links /clan/ID (menu, perfil...). O menu costuma
    # apontar para o cla de quem esta logado (o meu). Entao: pega o primeiro ID que
    # NAO seja o meu cla. Se so existir o meu, o lider e do meu cla.
    _al_ids=`grep -E -o '/clan/[0-9]{1,3}' "$TMP/al_user.html" | cut -d/ -f3`
    _alc=""
    for _al_c in $_al_ids; do
        if [ -n "$CLD" ] && [ "$_al_c" = "$CLD" ]; then continue; fi
        _alc="$_al_c"; break
    done
    if [ -z "$_alc" ] && [ -n "$CLD" ] && printf '%s\n' "$_al_ids" | grep -q -x "$CLD"; then
        _alc="$CLD"
    fi
    _aln=`sed 's,/clan/,\n/clan/,g' "$TMP/al_user.html" | grep -E "</a>, <span class='blue'|</a>, <span class='green'" | cut -d\< -f1 | cut -d\> -f2 | sed 's,\ ,_,' | head -n1`
    printf '%s|%s\n' "$_alc" "$_aln"
    unset _alc _aln _al_ids _al_c
}

# al_apply <modo>: monta allies.txt e callies.txt. Nao sobrescreve se vier vazio.
al_apply() {
    _am="$1"
    : > "$TMP/allies_tmp.txt"
    : > "$TMP/callies_new.txt"

    if [ "$_am" = 5 ] || [ "$_am" = 7 ]; then
        [ -n "$CLD" ] || clan_id 2>/dev/null
        if [ -n "$CLD" ]; then
            al_members_clan "$CLD"
        else
            # Sem identificar o meu cla: NAO aplica (evita lista sem os meus membros)
            printf "Aliados: nao consegui identificar o meu cla - tento de novo em 30 min\n"
            return 1
        fi
    fi

    if [ "$_am" = 6 ] || [ "$_am" = 7 ]; then
        [ -n "$CLD" ] || clan_id 2>/dev/null
        _falhas=0
        _nclas=0
        while IFS= read -r _cid; do
            case "$_cid" in ''|*[!0-9]*) continue ;; esac
            if [ -n "$CLD" ] && [ "$_cid" = "$CLD" ]; then
                printf "Aliados: cla %s e o meu - ignorado\n" "$_cid"
                continue
            fi
            _nclas=$((_nclas + 1))
            : > "$TMP/al_cla_$_cid.txt"
            al_members_clan "$_cid" "$TMP/al_cla_$_cid.txt"
            if [ -s "$TMP/al_cla_$_cid.txt" ]; then
                cat "$TMP/al_cla_$_cid.txt" >> "$TMP/allies_tmp.txt"
                printf "Aliados: cla %s - %s membros\n" "$_cid" "`grep -c . "$TMP/al_cla_$_cid.txt"`"
            else
                _falhas=$((_falhas + 1))
                printf "Aliados: cla %s sem membros lidos (falha?)\n" "$_cid"
            fi
        done < "$TWM_ACC_DIR/allies_clas.txt"
        unset _nclas
    fi

    _novos=`sort -u "$TMP/allies_tmp.txt" | grep -v '^$'`
    # Modo 6 sem nenhum cla aliado valido (lista vazia ou so o meu cla): zera.
    # e resultado legitimo: zera. Se alguma pagina falhou (_falhas>0), mantem.
    # Nos demais casos, lista vazia pode ser falha de rede: nao sobrescreve.
    if [ -z "$_novos" ]; then
        if [ "$_am" = 6 ] && [ "${_falhas:-0}" -eq 0 ] && [ "${_nclas:-0}" -eq 0 ]; then
            : > "$TMP/allies.txt"
            : > "$TMP/callies.txt"
            return 0
        fi
        return 1
    fi
    printf '%s\n' "$_novos" > "$TMP/allies.txt"
    sort -u "$TMP/callies_new.txt" | grep -v '^$' > "$TMP/callies.txt"
    unset _novos _uid _r _cid _nome
    return 0
}

# al_apply_saved: chamada pelo loop (tarefas_livres). Nao faz nada se nao houver
# modo 5/6/7 configurado, ou se ja aplicou hoje nesta sessao.
al_apply_saved() {
    [ -n "$TWM_ACC_DIR" ] && [ -d "$TWM_ACC_DIR" ] && [ -n "$TMP" ] || return 0
    _as_mode=`grep -E '^ALLIES=' "$TWM_ACC_DIR/config.cfg" 2>/dev/null | tail -n1 | cut -d= -f2`
    case "$_as_mode" in 5|6|7) ;; *) return 0 ;; esac

    _as_hoje=`date +%Y%m%d`
    _as_est=`cat "$TWM_ACC_DIR/allies_state" 2>/dev/null`
    if [ "$_as_est" = "$_as_mode|$_as_hoje" ] && [ -f "$TMP/allies_ok" ]; then
        unset _as_mode _as_hoje _as_est
        return 0
    fi

    _as_agora=`date +%s`
    _as_try=`cat "$TWM_ACC_DIR/allies_try" 2>/dev/null`
    case "$_as_try" in ''|*[!0-9]*) _as_try=0 ;; esac
    if [ $((_as_agora - _as_try)) -lt 1800 ]; then
        unset _as_mode _as_hoje _as_est _as_agora _as_try
        return 0
    fi
    printf '%s' "$_as_agora" > "$TWM_ACC_DIR/allies_try" 2>/dev/null

    printf "Aliados: aplicando modo %s\n" "$_as_mode"
    if al_apply "$_as_mode"; then
        _as_n=`wc -l < "$TMP/allies.txt" | tr -d ' '`
        printf '%s|%s' "$_as_mode" "$_as_hoje" > "$TWM_ACC_DIR/allies_state" 2>/dev/null
        : > "$TMP/allies_ok"
        printf "Aliados ok: %s nomes\n" "$_as_n"
        cp "$TMP/allies.txt" "$TWM_ACC_DIR/allies_lista.txt" 2>/dev/null
        unset _as_n
    else
        printf "Aliados: lista veio vazia - mantive a anterior, tento em 30 min\n"
    fi
    unset _as_mode _as_hoje _as_est _as_agora _as_try
    return 0
}
