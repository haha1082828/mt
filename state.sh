#!/bin/sh
# state.sh - estado atomico por conta para scheduler, eventos e painel.
# Nao acessa a rede. Todos os arquivos ficam dentro de $TMP.

_state_atomic_write() {
    _sf="$1"
    _st="${_sf}.$$"
    cat > "$_st" || { rm -f "$_st" 2>/dev/null; return 1; }
    mv "$_st" "$_sf"
}

runtime_state_write() {
    _sa="$1"; _sp="$2"; _ss="$3"; _sd="${4:-}"
    {
        printf 'timestamp=%s\n' "$(date +%s)"
        printf 'activity=%s\n' "$_sa"
        printf 'page=%s\n' "$_sp"
        printf 'status=%s\n' "$_ss"
        [ -n "$_sd" ] && printf 'detail=%s\n' "$_sd"
    } | _state_atomic_write "$TMP/runtime_state"
    unset _sa _sp _ss _sd
}

event_lock_start() {
    _se="$1"
    _now=$(date +%s)
    {
        printf 'event=%s\n' "$_se"
        printf 'status=running\n'
        printf 'pid=%s\n' "$$"
        printf 'started=%s\n' "$_now"
        printf 'updated=%s\n' "$_now"
    } | _state_atomic_write "$TMP/event_lock"
    unset _se _now
}

event_lock_active() {
    [ -s "$TMP/event_lock" ] || return 1
    _ls=""; _lp=""; _started=0
    while IFS='=' read -r _lk _lv; do
        case "$_lk" in
            status)  _ls="$_lv" ;;
            pid)     _lp="$_lv" ;;
            started) _started="$_lv" ;;
        esac
    done < "$TMP/event_lock"

    [ "$_ls" = "running" ] || { rm -f "$TMP/event_lock" 2>/dev/null; unset _ls _lp _started _lk _lv; return 1; }
    case "$_lp" in ''|*[!0-9]*) rm -f "$TMP/event_lock" 2>/dev/null; unset _ls _lp _started _lk _lv; return 1 ;; esac
    case "$_started" in ''|*[!0-9]*) _started=0 ;; esac

    _ttl=${EVENT_LOCK_TTL:-1800}
    case "$_ttl" in ''|*[!0-9]*) _ttl=1800 ;; esac
    _age=$(( $(date +%s) - _started ))
    if [ "$_started" -gt 0 ] && [ "$_age" -gt "$_ttl" ]; then
        rm -f "$TMP/event_lock" 2>/dev/null
        unset _ls _lp _started _ttl _age _lk _lv
        return 1
    fi

    if kill -0 "$_lp" 2>/dev/null; then
        unset _ls _lp _started _ttl _age _lk _lv
        return 0
    fi

    rm -f "$TMP/event_lock" 2>/dev/null
    unset _ls _lp _started _ttl _age _lk _lv
    return 1
}

event_lock_finish() {
    _se="${1:-evento}"
    _sr="${2:-finished}"
    {
        printf 'event=%s\n' "$_se"
        printf 'status=%s\n' "$_sr"
        printf 'finished=%s\n' "$(date +%s)"
    } | _state_atomic_write "$TMP/last_event"
    rm -f "$TMP/event_lock" 2>/dev/null
    unset _se _sr
}

event_slot_seen() {
    _slot="$1"
    [ -n "$_slot" ] || return 1
    _last=""
    [ -r "$TMP/last_event_slot" ] && read -r _last < "$TMP/last_event_slot" || :
    [ "$_last" = "$_slot" ]
}

event_slot_mark() {
    _slot="$1"
    [ -n "$_slot" ] || return 1
    printf '%s\n' "$_slot" > "$TMP/last_event_slot"
    rm -f "$TMP/event_retry" 2>/dev/null
    unset _slot
}

# Falhas de entrada nao podem gerar rajada a cada poll. No maximo 3 tentativas
# por slot, com intervalo minimo de 60s entre elas.
event_retry_allowed() {
    _slot="$1"
    _now=`date +%s`
    _rs=""; _rt=0; _rc=0
    if [ -r "$TMP/event_retry" ]; then
        IFS='|' read -r _rs _rt _rc < "$TMP/event_retry" || :
    fi
    case "$_rt" in ''|*[!0-9]*) _rt=0 ;; esac
    case "$_rc" in ''|*[!0-9]*) _rc=0 ;; esac

    if [ "$_rs" != "$_slot" ]; then
        unset _slot _now _rs _rt _rc
        return 0
    fi
    [ "$_rc" -lt 3 ] || { unset _slot _now _rs _rt _rc; return 1; }
    [ $((_now - _rt)) -ge 60 ]
    _ret=$?
    unset _slot _now _rs _rt _rc
    return "$_ret"
}

event_retry_mark() {
    _slot="$1"
    _now=`date +%s`
    _rs=""; _rt=0; _rc=0
    if [ -r "$TMP/event_retry" ]; then
        IFS='|' read -r _rs _rt _rc < "$TMP/event_retry" || :
    fi
    case "$_rc" in ''|*[!0-9]*) _rc=0 ;; esac
    [ "$_rs" = "$_slot" ] || _rc=0
    _rc=$((_rc + 1))
    printf '%s|%s|%s\n' "$_slot" "$_now" "$_rc" > "$TMP/event_retry"
    EVENT_RETRY_COUNT=$_rc
    export EVENT_RETRY_COUNT
    unset _slot _now _rs _rt _rc
}

event_retry_count() {
    _slot="$1"
    _rs=""; _rt=0; _rc=0
    if [ -r "$TMP/event_retry" ]; then
        IFS='|' read -r _rs _rt _rc < "$TMP/event_retry" || :
    fi
    case "$_rc" in ''|*[!0-9]*) _rc=0 ;; esac
    if [ "$_rs" = "$_slot" ]; then printf '%s' "$_rc"; else printf '0'; fi
    unset _slot _rs _rt _rc
}

combat_state_write() {
    _ce="$1"; _cs="$2"; _ca="${3:-}"; _ch="${4:-}"
    {
        printf 'event=%s\n' "$_ce"
        printf 'status=%s\n' "$_cs"
        printf 'action=%s\n' "$_ca"
        printf 'hp=%s\n' "$_ch"
        printf 'updated=%s\n' "$(date +%s)"
    } | _state_atomic_write "$TMP/combat_state"
    unset _ce _cs _ca _ch
}

combat_state_clear() {
    rm -f "$TMP/combat_state" 2>/dev/null
}
