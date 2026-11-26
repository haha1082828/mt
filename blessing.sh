#!/bin/sh
# blessing.sh - Bencao
#
# A Bencao nao deve ser comprada automaticamente.
# Este modulo e carregado POR ULTIMO pelo run.sh e protege o ponto real de
# requisicao. Assim, mesmo que algum codigo legado volte a chamar
# /effshop/blessing/, a requisicao e bloqueada antes do curl sair.

blessing_url_bloqueada() {
    # Liberada so durante a compra controlada por use_blessing (1x a cada 72h).
    [ "${BLESSING_ALLOW:-0}" = "1" ] && return 1
    for _bl_arg in "$@"; do
        case "$_bl_arg" in
            *'/effshop/blessing/'*|*'/effshop/blessing?'*|*'/effshop/blessing')
                unset _bl_arg
                return 0
                ;;
        esac
    done
    unset _bl_arg
    return 1
}

blessing_registrar_bloqueio() {
    [ -n "${TMP:-}" ] || return 0
    printf '%s|Bencao|bloqueada|%s\n' "$(date +%s)" "$1" >> "$TMP/blessing_blocked.log" 2>/dev/null
}

# Bencao: no maximo UMA compra a cada 72 horas (259200 s).
# Respeita FUNC_use_blessing e FUNC_blessing_gold_min do function.sh.
use_blessing() {
    load_config
    [ "${FUNC_use_blessing:-n}" = "y" ] || return 3

    _bl_agora=`date +%s`
    _bl_ult=`cat "$TMP/last_blessing" 2>/dev/null`
    case "$_bl_ult" in ''|*[!0-9]*) _bl_ult=0 ;; esac
    [ $((_bl_agora - _bl_ult)) -ge 259200 ] || { unset _bl_agora _bl_ult; return 3; }

    # Falhou ou nao havia link: so tenta de novo em 30 min.
    _bl_try=`cat "$TMP/last_blessing_try" 2>/dev/null`
    case "$_bl_try" in ''|*[!0-9]*) _bl_try=0 ;; esac
    [ $((_bl_agora - _bl_try)) -ge 1800 ] || { unset _bl_agora _bl_ult _bl_try; return 3; }
    printf '%s' "$_bl_agora" > "$TMP/last_blessing_try" 2>/dev/null

    fetch_page "/effshop/" "$TMP/EFFSHOP"
    [ -s "$TMP/EFFSHOP" ] || { unset _bl_agora _bl_ult _bl_try; return 1; }

    _bl_cl=`grep -o -E "/effshop/blessing/[?]r=[0-9]+" "$TMP/EFFSHOP" | sed -n 1p`
    if [ -z "$_bl_cl" ]; then
        unset _bl_agora _bl_ult _bl_try _bl_cl
        return 1
    fi

    _bl_ouro=`grep -o -E "gold\.png' alt='g'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/EFFSHOP" | sed -E "s@.*/> ?@@" | head -n1`
    _bl_ouro=`valor_num "$_bl_ouro"`
    case "$_bl_ouro" in ''|*[!0-9]*) _bl_ouro=0 ;; esac
    if [ "$_bl_ouro" -lt "${FUNC_blessing_gold_min:-0}" ]; then
        printf "Bencao: ouro insuficiente (%s)\n" "$_bl_ouro"
        unset _bl_agora _bl_ult _bl_try _bl_cl _bl_ouro
        return 1
    fi

    resource_allow gold "${FUNC_blessing_gold_min:-0}" blessing || { unset _bl_agora _bl_ult _bl_try _bl_cl _bl_ouro; return 1; }

    # Marca ANTES de comprar: mesmo que a requisicao demore, caia ou o bot
    # seja reiniciado no meio, nao existe segunda compra dentro de 72h.
    printf '%s' "$_bl_agora" > "$TMP/last_blessing" 2>/dev/null
    BLESSING_ALLOW=1
    fetch_page "$_bl_cl"
    BLESSING_ALLOW=0
    printf "Bencao comprada (proxima em 72h)\n"
    unset _bl_agora _bl_ult _bl_try _bl_cl _bl_ouro
    return 0
}

# info.sh define _rc_run(), run_curl() e run_curl_exec(). Reutilizamos o
# mesmo motor HTTP e so acrescentamos a trava especifica da Bencao.
run_curl() {
    if blessing_url_bloqueada "$@"; then
        blessing_registrar_bloqueio "$*"
        return 1
    fi
    _rc_run "" "$@"
}

run_curl_exec() {
    if blessing_url_bloqueada "$@"; then
        blessing_registrar_bloqueio "$*"
        return 1
    fi
    _rc_run "exec" "$@"
}
