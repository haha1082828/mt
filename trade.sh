# Troca PRATA -> OURO.
#
# A implementacao anterior procurava /trade/exchange/silver/N, que e o
# sentido contrario (comprar prata com ouro). A pagina do jogo oferece:
#   /trade/exchange/gold/1?r=N     1800 prata  ->   1 ouro
#   /trade/exchange/gold/10?r=N   18000 prata  ->  10 ouro
#   /trade/exchange/gold/100?r=N 180000 prata  -> 100 ouro
# Compra sempre pelo maior lote disponivel, que e a taxa mais eficiente.
# Troca PRATA -> OURO, com o lote escolhido pelo saldo da conta.
#
# A pagina oferece tres lotes:
#   /trade/exchange/gold/1?r=N       1800 prata ->   1 ouro
#   /trade/exchange/gold/10?r=N     18000 prata ->  10 ouro
#   /trade/exchange/gold/100?r=N   180000 prata -> 100 ouro
#
# Criterio: so usa um lote se a prata em caixa sustentar essa troca todo
# dia por um ano (365 vezes). Assim a troca nunca compromete a economia
# da conta — quem tem pouca prata cai para o lote menor em vez de parar.
#
#   lote 100 -> precisa de  65.700.000 de prata
#   lote  10 -> precisa de   6.570.000
#   lote   1 -> precisa de     657.000
#   abaixo disso nao troca
# Troca PRATA -> OURO, UMA VEZ POR DIA.
#
# A pagina oferece tres lotes:
#   /trade/exchange/gold/1?r=N       1800 prata ->   1 ouro
#   /trade/exchange/gold/10?r=N     18000 prata ->  10 ouro
#   /trade/exchange/gold/100?r=N   180000 prata -> 100 ouro
#
# O lote e escolhido pela reserva de prata: so usa um lote se o saldo
# aguentar essa mesma troca, uma por dia, durante um ano inteiro. Isso
# mantem a economia estavel — quem tem pouca prata cai para o lote menor
# em vez de drenar o caixa.
#
#   lote 100 -> reserva de 65.700.000 de prata (365 x 180.000)
#   lote  10 -> reserva de  6.570.000
#   lote   1 -> reserva de    657.000
#   abaixo disso nao troca
#
# A troca ocorre UMA VEZ por dia. O marcador fica em $TMP/last_trade e
# guarda a data, entao reiniciar o bot no mesmo dia nao repete a troca.
func_trade() {
    [ "${FUNC_trade:-y}" = "y" ] || return 1

    _hoje=`date +%Y%m%d`
    _ult=`cat "$TMP/last_trade" 2>/dev/null`
    if [ "$_ult" = "$_hoje" ]; then
        unset _hoje _ult
        return 0
    fi

    printf "Trade\n"

    _dias=${FUNC_trade_dias:-365}
    case "$_dias" in ''|*[!0-9]*) _dias=365 ;; esac

    fetch_page "/trade/exchange"
    # Saldo da conta e sempre alt='s'; alt='' e taxa de cambio da propria loja.
    _pr=`grep -o -E "silver\.png' alt='s'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/SRC" | sed -E "s@.*/> ?@@" | head -n1`
    _prata=`valor_num "$_pr"`
    case "$_prata" in ''|*[!0-9]*) _prata=0 ;; esac

    if   [ "$_prata" -ge $((180000 * _dias)) ]; then _lote=100
    elif [ "$_prata" -ge $((18000  * _dias)) ]; then _lote=10
    elif [ "$_prata" -ge $((1800   * _dias)) ]; then _lote=1
    else
        printf "Trade: prata insuficiente para trocar com seguranca (%s)\n" "$_pr"
        printf "Trade ok\n"
        unset _hoje _ult _dias _pr _prata _lote
        return 0
    fi

    _cl=`grep -o -E "/trade/exchange/gold/${_lote}[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
    if [ -z "$_cl" ]; then
        printf "Trade: lote de %s indisponivel agora\n" "$_lote"
        printf "Trade ok\n"
        unset _hoje _ult _dias _pr _prata _lote _cl
        return 0
    fi

    fetch_page "$_cl"
    printf '%s' "$_hoje" > "$TMP/last_trade" 2>/dev/null
    printf "Trade: prata %s — trocou por %s de ouro (1x hoje)\n" "$_pr" "$_lote"
    printf "Trade ok\n"
    unset _hoje _ult _dias _pr _prata _lote _cl
}

# Compra a Bencao em /effshop/ (+200 em todas as estatisticas, +25%% de
# experiencia, 100 ouro, dura 3 dias). Se ja estiver ativa o link nao
# aparece na pagina, entao basta agir sobre o que existir.
use_blessing() {
    [ "${FUNC_use_blessing:-y}" = "y" ] || return 1

    fetch_page "/effshop/" "$TMP/EFFSHOP"
    [ -s "$TMP/EFFSHOP" ] || return 1

    _cl=`grep -o -E "/effshop/blessing/[?]r=[0-9]+" "$TMP/EFFSHOP" | sed -n 1p`
    if [ -z "$_cl" ]; then
        unset _cl
        return 1
    fi

    # So compra se houver ouro suficiente (custa 100).
    # Saldo da conta e sempre alt='g'; alt='' sao os precos dos itens.
    _ouro=`grep -o -E "gold\.png' alt='g'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/EFFSHOP" | sed -E "s@.*/> ?@@" | head -n1`
    _ouro=`valor_num "$_ouro"`
    case "$_ouro" in ''|*[!0-9]*) _ouro=0 ;; esac
    if [ "$_ouro" -lt "${FUNC_blessing_gold_min:-100}" ]; then
        printf "Bencao: ouro insuficiente (%s)\n" "$_ouro"
        unset _cl _ouro
        return 1
    fi

    fetch_page "$_cl"
    printf "Bencao comprada (%s ouro disponiveis)\n" "$_ouro"
    unset _cl _ouro
    return 0
}

clan_money() {
    clan_id
    if [ -n "$CLD" ]; then
        printf "Clan money ...\n"

        fetch_page "/arena/quit"
        awk_code=`sed "s/href='/\n/g" "$TMP/SRC" | grep "attack/1" | head -n 1 | awk -F\/ '{ print $5 }' | tr -cd '[:digit:]'`
        echo "$awk_code" > "$TMP/CODE"

        printf "/clan/%s/money/?r=%s&silver=1000&gold=0&confirm=true&type=limit\n" "$CLD" "`cat "$TMP/CODE"`"
        fetch_page "/clan/${CLD}/money/?r=$(cat "$TMP/CODE")&silver=1000&gold=0&confirm=true&type=limit"

        fetch_page "/arena/quit"
        awk_code=`sed "s/href='/\n/g" "$TMP/SRC" | grep "attack/1" | head -n 1 | awk -F\/ '{ print $5 }' | tr -cd '[:digit:]'`
        echo "$awk_code" > "$TMP/CODE"

        printf "/clan/%s/money/?r=%s&silver=1000&gold=0&confirm=true&type=limit\n" "$CLD" "`cat "$TMP/CODE"`"
        fetch_page "/clan/${CLD}/money/?r=$(cat "$TMP/CODE")&silver=1000&gold=0&confirm=true&type=limit"

        printf "Clan money ok\n"
    fi
}
