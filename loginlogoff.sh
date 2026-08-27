# shellcheck disable=SC2148
# loginlogoff.sh - relogin automatico quando sessao expira

login_logoff() {
    PAGE=`run_curl "${URL}/user"`

    if is_logged_in "$PAGE"; then
        _acc=`extract_username "$PAGE"`
        [ -n "$_acc" ] && ACC=`echo "$_acc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'`
        # A pagina /user ja esta em maos: aproveita para atualizar HP/MP
        # antes de descarta-la. Antes o PAGE era descartado aqui e o
        # messages_info imprimia campos vazios.
        # Energia e HP maximo so existem em /train: uma requisicao por
        # ciclo de start(), nao por minuto.
        fetch_train_stats 2>/dev/null
        parse_status "$PAGE"
        unset _acc PAGE
        messages_info
        clan_id
        return 0
    fi

    printf "[%s] %s — sessao expirada, reconectando...\n" "$TWM_TAG" "$TWM_USER"
    rm -f "$TMP_COOKIE"

    # Mesmo motivo do do_login: a sessao precisa passar pela pagina de
    # login antes do POST, senao o servidor recusa a credencial correta.
    run_curl "${URL}/?sign_in=1" > /dev/null 2>&1

    cript_file="$TMP/cript_file"
    [ ! -f "$cript_file" ] && return 1

    creds=`base64 -d "$cript_file" 2>/dev/null`
    luser=`echo "$creds" | sed 's/login=//;s/&pass=.*//'`
    lpass=`echo "$creds" | sed 's/.*&pass=//'`
    unset creds

    run_curl \
        --data-urlencode "login=${luser}" \
        --data-urlencode "pass=${lpass}" \
        "${URL}/?sign_in=1" > /dev/null

    sleep 1

    run_curl \
        "${URL}/user" > /dev/null

    unset luser lpass

    PAGE=`run_curl "${URL}/user"`

    if is_logged_in "$PAGE"; then
        printf "[%s] %s — reconectado\n" "$TWM_TAG" "$TWM_USER"
        _acc=`extract_username "$PAGE"`
        [ -n "$_acc" ] && ACC=`echo "$_acc" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'`
        # Energia e HP maximo so existem em /train: uma requisicao por
        # ciclo de start(), nao por minuto.
        fetch_train_stats 2>/dev/null
        parse_status "$PAGE"
        unset _acc
        messages_info
        clan_id
        return 0
    fi

    printf "[%s] %s — falha ao reconectar\n" "$TWM_TAG" "$TWM_USER"
    [ -n "$TWM_STATUS_FILE" ] && echo "login_retry" > "$TWM_STATUS_FILE"
    return 1
}
