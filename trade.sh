#!/bin/sh
# trade.sh - Troca PRATA -> OURO, Bencao e Doacao de Cla
#
# REVISAO 2 (feita a partir da pagina REAL /trade/exchange).

# CORRECAO CRITICA (UBUNTU / MULTI-CONTAS):
# Garante que $TMP esta definida. No Ubuntu VPS ela vem vazia,
# o que fazia o script tentar gravar na raiz (ex: /TRADE_PAGE).
: "${TMP:=${TWMDIR:-/tmp}/tmp}"
mkdir -p "$TMP" 2>/dev/null

# ---------------------------------------------------------------------------
# Auxiliares (prefixo trd_ para nao colidir com nenhuma outra funcao)
# ---------------------------------------------------------------------------

trd_log() {
    [ -n "${TMP:-}" ] || return 0
    printf '%s %s\n' "`date '+%d/%m %H:%M:%S'`" "$*" >> "$TMP/trade_debug.log" 2>/dev/null
    _tl_n=`wc -l < "$TMP/trade_debug.log" 2>/dev/null | tr -d ' '`
    case "$_tl_n" in ''|*[!0-9]*) _tl_n=0 ;; esac
    if [ "$_tl_n" -gt 400 ]; then
        tail -n 200 "$TMP/trade_debug.log" > "$TMP/trade_debug.log.tmp" 2>/dev/null \
            && mv "$TMP/trade_debug.log.tmp" "$TMP/trade_debug.log" 2>/dev/null
    fi
    unset _tl_n
}

# trd_num <texto> -> inteiro. Entende "1800", "5'881", "54.300", "1,234,567",
# "2.5K", "94,3M".
trd_num() {
    _tn_v=`printf '%s' "$1" | tr -d ' '`
    case "$_tn_v" in
        *[Kk]) _tn_mu=1000 ;;
        *[Mm]) _tn_mu=1000000 ;;
        *[Bb]) _tn_mu=1000000000 ;;
        *)     _tn_mu=1 ;;
    esac
    _tn_d=`printf '%s' "$_tn_v" | tr -cd '0-9.,'`
    if [ -z "$_tn_d" ]; then
        unset _tn_v _tn_mu _tn_d
        echo 0
        return 0
    fi
    awk -v s="$_tn_d" -v m="$_tn_mu" 'BEGIN {
        n = gsub(/[.,]/, "&", s)
        if (n == 0) {
            v = s + 0
        } else if (n >= 2) {
            gsub(/[.,]/, "", s); v = s + 0
        } else {
            p = match(s, /[.,]/)
            tail = length(s) - p
            if (m == 1 && tail == 3) { gsub(/[.,]/, "", s); v = s + 0 }
            else                     { sub(/,/, ".", s);    v = s + 0 }
        }
        printf "%.0f", v * m
    }'
    unset _tn_v _tn_mu _tn_d
}

# trd_exato <texto>: sucesso se o valor NAO vem abreviado (K/M/B).
trd_exato() {
    case "$1" in
        *[KkMmBb]) return 1 ;;
        '')        return 1 ;;
    esac
    return 0
}

# Prata e ouro no cabecalho (alt='s' / alt='g'), exatamente como aparecem.
trd_prata_raw() {
    [ -r "$1" ] || return 1
    _tp=`grep -o -E "silver\.png' alt='s'/>[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" "$1" 2>/dev/null \
        | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1`
    printf '%s' "$_tp"
    unset _tp
}

trd_ouro_raw() {
    [ -r "$1" ] || return 1
    _to=`grep -o -E "gold\.png' alt='g'/>[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" "$1" 2>/dev/null \
        | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1`
    printf '%s' "$_to"
    unset _to
}

# Mesma leitura, mas na pagina /user (quando o cabecalho da troca nao traz).
trd_prata_user() {
    fetch_page "/user" "$TMP/TRADE_USER" 2>/dev/null || return 1
    trd_prata_raw "$TMP/TRADE_USER"
}
trd_ouro_user() {
    fetch_page "/user" "$TMP/TRADE_USER" 2>/dev/null || return 1
    trd_ouro_raw "$TMP/TRADE_USER"
}

# "Ouro disponivel para troca: N de M"  ->  N
trd_disp() {
    [ -r "$1" ] || return 1
    sed 's/<[^>]*>/ /g' "$1" 2>/dev/null | tr '\n\r\t' '   ' \
        | grep -o -E "para troca: *[0-9]+" | head -n1 | grep -o -E "[0-9]+$"
}

# trd_opcoes <arquivo> <prata_disponivel> <max_ouro|0>
trd_opcoes() {
    tr '\n\r\t' '   ' < "$1" 2>/dev/null | awk -v disp="$2" -v maxg="$3" '
    function num(s,   m, n, p, tail, v) {
        sub(/[- ]+$/, "", s)
        gsub(/\047/, "", s)
        m = 1
        if (s ~ /[Kk]$/) m = 1000
        else if (s ~ /[Mm]$/) m = 1000000
        else if (s ~ /[Bb]$/) m = 1000000000
        gsub(/[^0-9.,]/, "", s)
        if (s == "") return 0
        n = gsub(/[.,]/, "&", s)
        if (n == 0) v = s + 0
        else if (n >= 2) { gsub(/[.,]/, "", s); v = s + 0 }
        else {
            p = match(s, /[.,]/); tail = length(s) - p
            if (m == 1 && tail == 3) { gsub(/[.,]/, "", s); v = s + 0 }
            else { sub(/,/, ".", s); v = s + 0 }
        }
        return v * m
    }
    function limpa(t) {
        gsub(/<[^>]*>/, " ", t)
        gsub(/&#62;|&gt;/, ">", t)
        gsub(/&nbsp;/, " ", t)
        gsub(/&amp;/, "\\&", t)
        gsub(/[ ]+/, " ", t)
        sub(/^ /, "", t); sub(/ $/, "", t)
        return t
    }
    {
        s = $0
        best = 0
        pat = "[0-9][0-9\047.,]*[KkMmBb]? ?-?> ?[0-9][0-9\047.,]*"
        while (match(s, /<[Aa] [^>]*>/)) {
            tag = substr(s, RSTART, RLENGTH)
            rest = substr(s, RSTART + RLENGTH)
            e = index(rest, "</a>"); if (e == 0) e = index(rest, "</A>")
            if (e == 0) break
            inner = substr(rest, 1, e - 1)
            after = substr(rest, e + 4)
            s = after
            if (!match(tag, /href=["\047][^"\047]*["\047]/)) continue
            href = substr(tag, RSTART + 6, RLENGTH - 7)
            gsub(/&amp;/, "\\&", href)
            txt = limpa(inner)
            if (txt ~ /[Cc]omprar|[Bb]uy/) continue
            ok = match(txt, pat)
            if (!ok) {
                nx = after
                p = index(nx, "<a "); q = index(nx, "<A ")
                if (p == 0 || (q > 0 && q < p)) p = q
                if (p > 0) nx = substr(nx, 1, p - 1)
                nx = substr(limpa(substr(nx, 1, 300)), 1, 25)
                txt = txt " " nx
                if (txt ~ /[Cc]omprar|[Bb]uy|para/) continue
                ok = match(txt, pat)
            } else if (txt ~ /para/) continue
            if (!ok) continue
            m = substr(txt, RSTART, RLENGTH)
            split(m, parts, />/)
            custo = num(parts[1]); ouro = num(parts[2])
            if (ouro <= 0) continue
            paga = (custo <= disp) ? 1 : 0
            if (maxg > 0 && ouro > maxg) paga = 0
            printf "C|%s|%.0f|%.0f|%d\n", href, ouro, custo, paga
            if (paga && ouro > best) { best = ouro; bh = href; bc = custo }
        }
        if (best > 0) printf "S|%s|%.0f|%.0f\n", bh, best, bc
    }'
}

trd_desligar() {
    if type set_config > /dev/null 2>&1; then
        set_config FUNC_trade n 2>/dev/null
    elif [ -f "$TMP/config.cfg" ]; then
        grep -v '^FUNC_trade=' "$TMP/config.cfg" > "$TMP/config.cfg.tmp" 2>/dev/null
        echo "FUNC_trade=n" >> "$TMP/config.cfg.tmp"
        mv "$TMP/config.cfg.tmp" "$TMP/config.cfg" 2>/dev/null
    fi
    FUNC_trade=n
}

# ---------------------------------------------------------------------------
# Troca de prata por ouro
# ---------------------------------------------------------------------------
func_trade() {
    [ "${FUNC_trade:-y}" = "y" ] || return 1

    _tr_hoje=`date +%Y%m%d`
    _tr_ult=`cat "$TMP/last_trade" 2>/dev/null`
    if [ "$_tr_ult" = "$_tr_hoje" ]; then
        unset _tr_hoje _tr_ult
        return 0
    fi

    _tr_agora=`date +%s`
    _tr_try=`cat "$TMP/last_trade_try" 2>/dev/null`
    case "$_tr_try" in ''|*[!0-9]*) _tr_try=0 ;; esac
    if [ $((_tr_agora - _tr_try)) -lt 1800 ]; then
        unset _tr_hoje _tr_ult _tr_agora _tr_try
        return 0
    fi
    printf '%s' "$_tr_agora" > "$TMP/last_trade_try" 2>/dev/null

    printf "Trade\n"

    _tr_res=${FUNC_trade_reserva:-0}
    case "$_tr_res" in ''|*[!0-9]*) _tr_res=0 ;; esac

    _tr_cliques=0
    _tr_fim=""

    while [ "$_tr_cliques" -lt 4 ]; do
        if ! fetch_page "/trade/exchange" "$TMP/TRADE_PAGE"; then
            printf "Trade: falha ao abrir /trade/exchange\n"
            trd_log "TRADE falha de rede em /trade/exchange"
            _tr_fim=erro
            break
        fi

        _tr_pr=`trd_prata_raw "$TMP/TRADE_PAGE"`
        [ -n "$_tr_pr" ] || _tr_pr=`trd_prata_user`
        _tr_og=`trd_ouro_raw "$TMP/TRADE_PAGE"`
        [ -n "$_tr_og" ] || _tr_og=`trd_ouro_user`
        if [ -z "$_tr_pr" ] || [ -z "$_tr_og" ]; then
            printf "Trade: nao consegui ler prata/ouro - nao vou clicar\n"
            trd_log "TRADE prata='$_tr_pr' ouro='$_tr_og' ilegiveis; pagina salva em trade_page.html"
            cp "$TMP/TRADE_PAGE" "$TMP/trade_page.html" 2>/dev/null
            _tr_fim=erro
            break
        fi
        _tr_prn=`trd_num "$_tr_pr"`
        _tr_ogn=`trd_num "$_tr_og"`
        _tr_disp=`trd_disp "$TMP/TRADE_PAGE"`

        if [ "$_tr_disp" = "0" ]; then
            printf "Trade: limite diario de troca ja usado\n"
            _tr_fim=feito
            break
        fi

        _tr_av=$((_tr_prn - _tr_res))
        [ "$_tr_av" -ge 0 ] || _tr_av=0
        _tr_mx=${_tr_disp:-0}
        case "$_tr_mx" in ''|*[!0-9]*) _tr_mx=0 ;; esac

        _tr_out=`trd_opcoes "$TMP/TRADE_PAGE" "$_tr_av" "$_tr_mx"`
        _tr_sel=`printf '%s\n' "$_tr_out" | grep '^S|' | head -n1`

        if [ -z "$_tr_sel" ]; then
            _tr_nc=`printf '%s\n' "$_tr_out" | grep -c '^C|'`
            if [ "$_tr_cliques" -gt 0 ]; then
                _tr_fim=feito
            elif [ "$_tr_nc" -gt 0 ]; then
                printf "Trade: prata insuficiente para a menor troca (%s)\n" "$_tr_pr"
                _tr_fim=espera
            else
                printf "Trade: nenhuma opcao de troca encontrada na pagina\n"
                trd_log "TRADE nenhuma opcao 'X -> Y' achada; pagina salva em trade_page.html"
                cp "$TMP/TRADE_PAGE" "$TMP/trade_page.html" 2>/dev/null
                _tr_fim=erro
            fi
            break
        fi

        _tr_href=`printf '%s' "$_tr_sel" | cut -d'|' -f2 | sed -E 's#^https?://[^/]+##'`
        _tr_gain=`printf '%s' "$_tr_sel" | cut -d'|' -f3`
        _tr_cost=`printf '%s' "$_tr_sel" | cut -d'|' -f4`

        fetch_page "$_tr_href" "$TMP/TRADE_RESP"
        _tr_cliques=$((_tr_cliques + 1))

        fetch_page "/trade/exchange" "$TMP/TRADE_AFTER" 2>/dev/null
        _tr_og2=`trd_ouro_raw "$TMP/TRADE_AFTER"`
        [ -n "$_tr_og2" ] || _tr_og2=`trd_ouro_user`
        _tr_ogn2=`trd_num "$_tr_og2"`
        _tr_disp2=`trd_disp "$TMP/TRADE_AFTER"`

        _tr_ver=nao
        if trd_exato "$_tr_og" && trd_exato "$_tr_og2"; then
            if   [ "$_tr_ogn2" -lt "$_tr_ogn" ]; then _tr_ver=perdeu
            elif [ "$_tr_ogn2" -gt "$_tr_ogn" ]; then _tr_ver=ganhou
            else _tr_ver=igual
            fi
        fi
        if [ "$_tr_ver" = "igual" ] || [ "$_tr_ver" = "nao" ]; then
            if [ -n "$_tr_disp" ] && [ -n "$_tr_disp2" ]; then
                if [ "$_tr_disp2" -lt "$_tr_disp" ]; then _tr_ver=ganhou
                elif [ "$_tr_ver" = "nao" ]; then _tr_ver=igual
                fi
            fi
        fi

        case "$_tr_ver" in
            perdeu)
                printf "Trade: ATENCAO - o ouro CAIU (%s -> %s). Troca desligada nesta conta.\n" "$_tr_og" "$_tr_og2"
                trd_log "TRADE OURO CAIU apos clicar em $_tr_href (opcao $_tr_gain de ouro por $_tr_cost de prata): $_tr_og -> $_tr_og2. FUNC_trade=n gravado."
                cp "$TMP/TRADE_RESP" "$TMP/trade_resp.html" 2>/dev/null
                cp "$TMP/TRADE_PAGE" "$TMP/trade_page.html" 2>/dev/null
                trd_desligar
                _tr_fim=erro
                break
                ;;
            ganhou)
                printf "Trade: trocou %s de prata por %s de ouro (ouro %s -> %s)\n" "$_tr_cost" "$_tr_gain" "$_tr_og" "$_tr_og2"
                rm -f "$TMP/trade_fail" 2>/dev/null
                ;;
            igual)
                _tr_f=`cat "$TMP/trade_fail" 2>/dev/null`
                case "$_tr_f" in "$_tr_hoje":*) _tr_fn=${_tr_f#*:} ;; *) _tr_fn=0 ;; esac
                case "$_tr_fn" in ''|*[!0-9]*) _tr_fn=0 ;; esac
                _tr_fn=$((_tr_fn + 1))
                printf '%s:%s' "$_tr_hoje" "$_tr_fn" > "$TMP/trade_fail" 2>/dev/null
                printf "Trade: clique feito mas nada mudou - tentativa %s de 3\n" "$_tr_fn"
                trd_log "TRADE sem efeito: $_tr_href ($_tr_gain de ouro por $_tr_cost). Resposta em trade_resp.html"
                cp "$TMP/TRADE_RESP" "$TMP/trade_resp.html" 2>/dev/null
                cp "$TMP/TRADE_PAGE" "$TMP/trade_page.html" 2>/dev/null
                if [ "$_tr_fn" -ge 3 ]; then
                    printf '%s' "$_tr_hoje" > "$TMP/last_trade" 2>/dev/null
                    printf "Trade: 3 tentativas sem efeito - volto amanha\n"
                fi
                _tr_fim=erro
                break
                ;;
            *)
                printf "Trade: clique feito (nao deu para confirmar o resultado)\n"
                trd_log "TRADE clicou $_tr_href ($_tr_gain por $_tr_cost) sem como confirmar; ouro $_tr_og -> $_tr_og2"
                _tr_fim=feito
                break
                ;;
        esac
    done

    if [ "$_tr_fim" = "feito" ] || { [ -z "$_tr_fim" ] && [ "$_tr_cliques" -gt 0 ] && false; }; then
        printf '%s' "$_tr_hoje" > "$TMP/last_trade" 2>/dev/null
    fi

    printf "Trade ok\n"
    unset _tr_hoje _tr_ult _tr_agora _tr_try _tr_res _tr_cliques _tr_fim _tr_pr _tr_og _tr_prn _tr_ogn \
          _tr_disp _tr_av _tr_mx _tr_out _tr_sel _tr_nc _tr_href _tr_gain _tr_cost _tr_og2 _tr_ogn2 \
          _tr_disp2 _tr_ver _tr_f _tr_fn
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

# ---------------------------------------------------------------------------
# Doacao de prata ao cla (a cada 120 min)
# ---------------------------------------------------------------------------
clan_money() {
    [ "${FUNC_clan_money:-y}" = "y" ] || return 0

    [ -n "$CLD" ] || clan_id 2>/dev/null
    [ -n "$CLD" ] || return 0

    _cm_agora=`date +%s`
    _cm_ultimo=`cat "$TMP/last_clan_money" 2>/dev/null`

    case "$_cm_ultimo" in
        ''|*[!0-9]*) _cm_ultimo=0 ;;
    esac

    if [ $((_cm_agora - _cm_ultimo)) -lt 7200 ]; then
        unset _cm_agora _cm_ultimo
        return 0
    fi

    printf "Clan money ...\n"

    _cm_valor=${FUNC_clan_money_silver:-100000}
    case "$_cm_valor" in ''|*[!0-9]*) _cm_valor=100000 ;; esac
    [ "$_cm_valor" -gt 0 ] || _cm_valor=100000

    _cm_code=""
    _cm_base="$TMP/CMONEY_PAGE"
    if fetch_page "/clan/${CLD}/money/" "$TMP/CMONEY_PAGE"; then
        _cm_code=`grep -o -E "name=['\"]r['\"][^>]*value=['\"][0-9]+|value=['\"][0-9]+['\"][^>]*name=['\"]r['\"]" "$TMP/CMONEY_PAGE" 2>/dev/null \
            | grep -o -E '[0-9]+' | head -n 1`
        [ -n "$_cm_code" ] || _cm_code=`grep -o -E '[?&]r=[0-9]+' "$TMP/CMONEY_PAGE" 2>/dev/null | head -n 1 | cut -d= -f2`
    fi
    if [ -z "$_cm_code" ]; then
        fetch_page "/clan/${CLD}/" "$TMP/CMONEY_MAIN"
        _cm_code=`grep -o -E '[?]r=[0-9]+' "$TMP/CMONEY_MAIN" 2>/dev/null | head -n 1 | cut -d= -f2`
        _cm_base="$TMP/CMONEY_MAIN"
        trd_log "CLANMONEY r= nao veio de /clan/${CLD}/money/; usei a pagina principal do cla"
    fi

    if [ -n "$_cm_code" ]; then
        _cm_antes=`trd_prata_raw "$_cm_base"`

        _cm_url="/clan/${CLD}/money/?r=${_cm_code}&silver=${_cm_valor}&gold=0&confirm=true&type=limit"

        printf '%s\n' "$_cm_url"

        fetch_page "$_cm_url" "$TMP/CMONEY_RESP"

        printf '%s' "$_cm_agora" > "$TMP/last_clan_money" 2>/dev/null

        _cm_depois=`trd_prata_raw "$TMP/CMONEY_RESP"`
        [ -n "$_cm_depois" ] || _cm_depois=`trd_prata_user`
        if trd_exato "$_cm_antes" && trd_exato "$_cm_depois" \
           && [ "`trd_num "$_cm_depois"`" -ge "`trd_num "$_cm_antes"`" ]; then
            printf "Clan money: doacao nao confirmada (prata %s -> %s)\n" "$_cm_antes" "$_cm_depois"
            trd_log "CLANMONEY url=$_cm_url prata $_cm_antes -> $_cm_depois (sem queda)"
            cp "$TMP/CMONEY_PAGE" "$TMP/clan_money_page.html" 2>/dev/null
            cp "$TMP/CMONEY_RESP" "$TMP/clan_money_resp.html" 2>/dev/null
        fi

        printf "Clan money ok\n"

        unset _cm_url _cm_antes _cm_depois
    else
        printf "Clan money: falha ao obter chave r=\n"
        trd_log "CLANMONEY sem r= em /clan/${CLD}/money/ nem em /clan/${CLD}/"
        cp "$TMP/CMONEY_PAGE" "$TMP/clan_money_page.html" 2>/dev/null
        cp "$TMP/CMONEY_MAIN" "$TMP/clan_main_page.html" 2>/dev/null
    fi

    unset _cm_code _cm_base _cm_valor _cm_agora _cm_ultimo
}
