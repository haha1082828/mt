#!/bin/sh
# trade.sh - Troca PRATA -> OURO, Bencao e Doacao de Cla

func_trade() {
    [ "${FUNC_trade:-y}" = "y" ] || return 1

    _hoje=`date +%Y%m%d`
    _ult=`cat "$TMP/last_trade" 2>/dev/null`
    if [ "$_ult" = "$_hoje" ]; then
        unset _hoje _ult
        return 0
    fi

    printf "Trade\n"

    # Reduzido o tempo de reserva padrao para 1 dia
    _dias=${FUNC_trade_dias:-1}
    case "$_dias" in ''|*[!0-9]*) _dias=1 ;; esac

    fetch_page "/trade/exchange"

    # Leitura tolerante a tags HTML e espacos entre o icone e o valor
    _pr=`grep -o -E "silver\.png' alt='s'/>[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/SRC" | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1`
    _prata=`valor_num "$_pr"`
    case "$_prata" in ''|*[!0-9]*) _prata=0 ;; esac

    if   [ "$_prata" -ge $((180000 * _dias)) ]; then _lote=100
    elif [ "$_prata" -ge $((18000  * _dias)) ]; then _lote=10
    elif [ "$_prata" -ge $((1800   * _dias)) ]; then _lote=1
    else
        printf "Trade: prata insuficiente (%s)\n" "$_pr"
        printf "Trade ok\n"
        unset _hoje _ult _dias _pr _prata _lote
        return 0
    fi

    # Leitura flexivel do link de troca (suporta barra opcional antes de ?r=)
    _cl=`grep -o -E "/trade/exchange/gold/${_lote}/?[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
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

use_blessing() {
    [ "${FUNC_use_blessing:-y}" = "y" ] || return 1

    fetch_page "/effshop/" "$TMP/EFFSHOP"
    [ -s "$TMP/EFFSHOP" ] || return 1

    _cl=`grep -o -E "/effshop/blessing/[?]r=[0-9]+" "$TMP/EFFSHOP" | sed -n 1p`
    if [ -z "$_cl" ]; then
        unset _cl
        return 1
    fi

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
    [ "${FUNC_clan_money:-y}" = "y" ] || return 0

    [ -n "$CLD" ] || clan_id 2>/dev/null
    [ -n "$CLD" ] || return 0

    # Controle proprio do Clan Money, separado por conta.
    # O marcador fica dentro de $TMP, que ja e exclusivo de cada conta.
    _cm_agora=`date +%s`
    _cm_ultimo=`cat "$TMP/last_clan_money" 2>/dev/null`

    case "$_cm_ultimo" in
        ''|*[!0-9]*) _cm_ultimo=0 ;;
    esac

    # Mantem o intervalo de 120 minutos usado pelo fluxo antigo.
    if [ $((_cm_agora - _cm_ultimo)) -lt 7200 ]; then
        unset _cm_agora _cm_ultimo
        return 0
    fi

    printf "Clan money ...\n"

    # Acessa a pagina principal do cla para extrair a chave r=
    fetch_page "/clan/${CLD}/"

    _code=`grep -o -E '[?]r=[0-9]+' "$TMP/SRC" | head -n 1 | cut -d= -f2`

    if [ -n "$_code" ]; then
        _cm_url="/clan/${CLD}/money/?r=${_code}&silver=1000&gold=0&confirm=true&type=limit"

        printf '%s\n' "$_cm_url"

        # Uma unica chamada: evita doar duas vezes na mesma execucao.
        fetch_page "$_cm_url"

        # Marca somente depois da chamada ter sido realizada.
        printf '%s' "$_cm_agora" > "$TMP/last_clan_money" 2>/dev/null

        printf "Clan money ok\n"

        unset _cm_url
    else
        printf "Clan money: falha ao obter chave r=\n"
    fi

    unset _code _cm_agora _cm_ultimo
}
