#!/bin/sh
# resource_guard.sh - politica central de gasto automatico.
#
# REGRA PRINCIPAL: o bot NUNCA gasta ouro. Nenhuma excecao.
#
# O motivo e operacional, nao economico: isto roda por horas sem ninguem
# olhando. Um gasto de ouro errado se repete a cada ciclo e so aparece
# quando o saldo ja foi embora. Prata e recurso renovavel e so e gasta
# quando ligada a uma missao do cla.
#
# Todo gasto pede autorizacao aqui e fica registrado em
# $TMP/resource_ledger, com carimbo de tempo, para auditoria depois.

resource_log() {
    printf '%s|%s|%s|%s|%s\n' "$(date +%s)" "$1" "$2" "$3" "$4" \
        >> "$TMP/resource_ledger" 2>/dev/null
}

# resource_allow <recurso> <quantidade> <motivo>
# Retorna 0 (autorizado) somente para prata ligada a missao do cla.
resource_allow() {
    _rr="$1"; _ra="${2:-0}"; _rw="$3"
    case "$_ra" in ''|*[!0-9]*) _ra=0 ;; esac

    # Barreira de ouro: vale para qualquer motivo, conhecido ou novo.
    # Se amanha alguem acrescentar um gasto de ouro sem lembrar desta
    # politica, ele ja nasce negado.
    if [ "$_rr" = "gold" ] || [ "$_rr" = "ouro" ]; then
        resource_log "$_rr" "$_ra" "$_rw" negado-ouro
        unset _rr _ra _rw
        return 1
    fi

    case "$_rw" in
        # Unica autorizacao: acelerar a caverna com PRATA quando a
        # atividade esta cumprindo missao do cla (secao 9 do prompt).
        cave_mission_silver)
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
