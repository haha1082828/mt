# clanquest.sh - Missoes do Cla e combinacao com as atividades
#
# A pagina /clan/<CLD>/quest/ lista 8 missoes, cada uma ligada a uma
# atividade. Mapeamento confirmado no jogo:
#
#   1 Gladiador                    Lute na Arena 20x na Liga     -> liga
#   2 Gladiador Lendario           Vença 15x na Liga             -> liga
#   3 Guerreiro da Arena           Lute 75x na Arena             -> arena
#   4 Guerreiro Lendario da Arena  Vença 50x na Arena            -> arena
#   5 Procura por Recursos         Faça 8 pesquisas na Caverna   -> caverna
#   6 Mestre dos torneios          Participe de 6 torneios       -> carreira
#   7 Alquimista                   Faça 2 Elixires               -> elixir
#   8 Velho Lojista                Obtenha 3 pedras ou ervas     -> loja
#
# A ideia e sempre TOMAR a missao antes de executar a atividade, para que
# o progresso conte. Fazer a atividade sem a missao ativa desperdiça a
# tentativa.

# IDs de missao por tipo de atividade
cq_ids() {
    case "$1" in
        liga)     echo "1 2" ;;
        arena)    echo "3 4" ;;
        caverna)  echo "5" ;;
        carreira) echo "6" ;;
        elixir)   echo "7" ;;
        mercador) echo "8" ;;
        *)        echo "" ;;
    esac
}

# Baixa a pagina de missoes do cla em $TMP/CQUEST.
cq_pagina() {
    [ -n "$CLD" ] || clan_id
    [ -n "$CLD" ] || return 1
    fetch_page "/clan/${CLD}/quest/" "$TMP/CQUEST"
    [ -s "$TMP/CQUEST" ]
}

# cq_tomar <tipo>
# Toma a missao do cla correspondente aquela atividade, se houver.
# Devolve 0 se tomou alguma (a atividade vale a pena agora).
cq_tomar() {
    _tipo="$1"
    [ "${FUNC_clan_quests:-y}" = "y" ] || return 1
    cq_pagina || return 1

    _tomou=1
    for _id in `cq_ids "$_tipo"`; do
        _cl=`grep -o -E "/clan/${CLD}/quest/take/${_id}/[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl"
            printf "Missao do cla tomada (%s #%s)\n" "$_tipo" "$_id"
            _tomou=0
        fi
    done
    unset _tipo _id _cl
    return $_tomou
}

# cq_concluir
# Recolhe as missoes ja concluidas.
cq_concluir() {
    [ "${FUNC_clan_quests:-y}" = "y" ] || return 1
    cq_pagina || return 1
    _n=0
    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/end/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl"
            printf "Missao do cla concluida (#%s)\n" "$_id"
            _n=$((_n + 1))
        fi
    done
    unset _id _cl
    [ "$_n" -gt 0 ]
}

# cq_ajudar
# Apoia missoes de companheiros que estejam perto de concluir.
# O gasto de ouro em ajuda e limitado a UMA vez por ciclo.
cq_ajudar() {
    [ "${FUNC_clan_help:-y}" = "y" ] || return 1
    cq_pagina || return 1

    _usou_ouro=0
    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/help/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        [ -n "$_cl" ] || continue

        # Links de ajuda que cobram ouro trazem confirmacao de custo.
        if printf '%s' "$_cl" | grep -q 'gold\|pay'; then
            [ "$_usou_ouro" -eq 1 ] && continue
            _usou_ouro=1
        fi
        fetch_page "$_cl"
        printf "Ajuda em missao do cla (#%s)\n" "$_id"
    done
    unset _id _cl _usou_ouro
    return 0
}

# cq_forcar_ouro
# Missao parada com ouro suficiente: conclui pagando.
# O limite vem de FUNC_quest_gold_min (padrao 1200).
cq_forcar_ouro() {
    # Concluir missao do cla pagando ouro e gasto de OURO, e a politica
    # nega qualquer gasto de ouro. A funcao continua existindo para nao
    # quebrar quem a chama, mas a tentativa para aqui e fica no ledger.
    resource_allow gold "${FUNC_quest_gold_min:-1200}" quest_force_gold || return 1

    [ "${FUNC_quest_force_gold:-y}" = "y" ] || return 1
    _min=${FUNC_quest_gold_min:-1200}
    case "$_min" in ''|*[!0-9]*) _min=1200 ;; esac

    # Ouro atual, lido da propria pagina
    cq_pagina || return 1
    # Saldo da conta e sempre alt='g'; alt='Ouro' e a recompensa da missao.
    _ouro=`grep -o -E "gold\.png' alt='g'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/CQUEST" | sed -E "s@.*/> ?@@" | head -n1`
    _ouro=`valor_num "$_ouro"`
    case "$_ouro" in ''|*[!0-9]*) return 1 ;; esac
    [ "$_ouro" -gt "$_min" ] || return 1

    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/(finish|complete|endGold|forGold)/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl"
            printf "Missao do cla concluida com ouro (#%s, ouro %s)\n" "$_id" "$_ouro"
            unset _id _cl _ouro _min
            return 0
        fi
    done
    unset _id _cl _ouro _min
    return 1
}

# cq_antes <tipo>
# Chamada antes de cada atividade: recolhe concluidas, toma a do tipo,
# e devolve 0 se a atividade esta combinada com alguma missao.
cq_antes() {
    [ -n "$CLD" ] || return 1
    cq_concluir > /dev/null 2>&1
    cq_tomar "$1"
}

# Sorteio portatil de 1..N. Nao usa shuf (ausente em ash/toybox enxutos)
# nem $RANDOM (nao existe em dash). Semeia com o PID para que contas
# diferentes no mesmo segundo nao escolham sempre a mesma opcao.
cq_sorteia() {
    _sn="$1"
    _sc=`cat "$TMP/rnd_seq" 2>/dev/null`
    case "$_sc" in ''|*[!0-9]*) _sc=0 ;; esac
    _sc=$((_sc + 1))
    printf '%s' "$_sc" > "$TMP/rnd_seq" 2>/dev/null
    awk -v n="$_sn" -v s="$$" -v c="$_sc" \
        'BEGIN{ srand(s * 7919 + c * 104729 + systime()); printf "%d", int(rand()*n)+1 }'
    unset _sn _sc
}

# Missao 7 do cla: produzir elixir no laboratorio (secao 17 do prompt).
# So produz o necessario para a missao: toma a missao, faz a pocao e
# encerra. Sem missao ativa nao produz nada.
cq_elixir() {
    [ -n "$CLD" ] || return 1
    cq_tomar elixir || return 1

    fetch_page "/lab/alchemy/" || return 1
    _i=`cq_sorteia 4`
    fetch_page "/lab/alchemy/${_i}/" || return 1

    _cl=`grep -o -E "/lab/alchemy/${_i}/makePotion[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
    [ -n "$_cl" ] || { unset _i _cl; return 1; }

    case "$_i" in
        1) printf "Elixir de forca\n" ;;
        2) printf "Elixir de vida\n" ;;
        3) printf "Elixir de agilidade\n" ;;
        4) printf "Elixir de protecao\n" ;;
    esac

    fetch_page "$_cl"
    _cl=`grep -o -E "/lab/alchemy/${_i}/makePotion[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
    [ -n "$_cl" ] && fetch_page "$_cl"

    cq_concluir 2>/dev/null
    unset _i _cl
    return 0
}

# Missao 8 do cla: obter pedras ou ervas com o mercador do Coliseu
# (secao 18). A missao chama "Velho Lojista", mas a loja dela NAO e a
# troca de prata: e /coliseum/merchant/.
cq_mercador() {
    [ -n "$CLD" ] || return 1
    cq_tomar mercador || return 1

    fetch_page "/coliseum/merchant/" || return 1
    _i=`cq_sorteia 2`
    _cl=`grep -o -E "/coliseum/merchant/${_i}/startMaking[?]r=[0-9]+&ref=lab" "$TMP/SRC" | sed -n 1p`
    [ -n "$_cl" ] || { unset _i _cl; return 1; }

    case "$_i" in
        1) printf "Produzindo pedras\n" ;;
        2) printf "Produzindo ervas\n" ;;
    esac

    fetch_page "$_cl"
    _cl=`grep -o -E "/coliseum/merchant/${_i}/startMaking[?]r=[0-9]+&ref=lab" "$TMP/SRC" | sed -n 1p`
    [ -n "$_cl" ] && fetch_page "$_cl"

    cq_concluir 2>/dev/null
    unset _i _cl
    return 0
}
