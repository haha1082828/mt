#!/bin/sh
# resource_guard.sh - politica central de gasto automatico.

resource_log() {
    printf '%s|%s|%s|%s|%s\n' "$(date +%s)" "$1" "$2" "$3" "$4" \
        >> "$TMP/resource_ledger" 2>/dev/null
}

# resource_allow <recurso> <quantidade> <motivo>
resource_allow() {
    _rr="$1"; _ra="${2:-0}"; _rw="$3"
    case "$_ra" in ''|*[!0-9]*) _ra=0 ;; esac

    # Barreira de ouro: bloqueia qualquer gasto de ouro
    if [ "$_rr" = "gold" ] || [ "$_rr" = "ouro" ]; then
        resource_log "$_rr" "$_ra" "$_rw" negado-ouro
        unset _rr _ra _rw
        return 1
    fi

    case "$_rw" in
        # Permite gasto de prata na aceleracao da caverna e missoes
        cave_mission_silver|cave_silver_speedup)
            if [ "$_rr" != "silver" ]; then
                resource_log "$_rr" "$_ra" "$_rw" negado
                unset _rr _ra _rw; return 1
            fi
            resource_log "$_rr" "$_ra" "$_rw" permitido
            unset _rr _ra _rw; return 0 ;;
        *)
            resource_log "$_rr" "$_ra" "$_rw" negado
            unset _rr _ra _rw; return 1 ;;
    esac
}
