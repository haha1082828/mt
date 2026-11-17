#!/bin/sh
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
