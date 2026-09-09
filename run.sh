#!/bin/sh
# run.sh - Loop principal de rotinas e agendamento

twm_play() {
    if [ ! -s "$TMP/CLD" ]; then
        clan_id
    fi

    # Se a flag de modo forçado for de caverna (-cv) e o horário NÃO for de evento obrigatório,
    # executa prioritariamente a rotina da caverna.
    if [ -s "$TMP/runmode_file" ]; then
        read -r _curr_run < "$TMP/runmode_file" 2>/dev/null
        case "$_curr_run" in
            *-cv*)
                case `date +%H:%M` in
                    (10:5[5-9]|13:5[5-9]|15:5[5-9]|12:2[5-9]|16:2[5-9]|22:2[5-9]|20:5[5-9]|09:5[5-9]|21:5[5-9]|10:2[5-9]|14:5[5-9])
                        # Deixa cair no fluxo normal de relógio para os eventos obrigatórios abaixo
                        ;;
                    *)
                        if type cave_routine >/dev/null 2>&1; then
                            cave_routine
                        else
                            cave_start
                        fi
                        sleep 15
                        return 0
                        ;;
                esac
                ;;
        esac
    fi

    # ORDEM DE PRIORIDADE DOS EVENTOS FIXOS
    case `date +%H:%M` in

        # --- 1. Torneio dos Clas
        (10:5[5-9]|18:5[5-9])
            evento_dedicar
            [ -n "$CLD" ] && clanfight_start
            evento_espera
            start
            ;;

        # --- 2. Altares dos Deuses
        (13:5[5-9]|20:5[5-9])
            evento_dedicar
            [ -n "$CLD" ] && altars_start
            evento_espera
            start
            ;;

        # --- 3. Vale dos Imortais
        (09:5[5-9]|15:5[5-9]|21:5[5-9])
            evento_dedicar
            undying_start
            evento_espera
            start
            ;;

        # --- 4. Rei dos Imortais
        (12:2[5-9]|16:2[5-9]|22:2[5-9])
            evento_dedicar
            king_start
            evento_espera
            start
            ;;

        # --- 5. Coliseu do Cla
        (10:2[5-9]|14:5[5-9])
            evento_dedicar
            [ -n "$CLD" ] && clancoliseum_start
            evento_espera
            start
            ;;

        # --- Coliseu comum
        (00:[345]5|0[123]:[0-5]5|04:[012]5)
            coliseum_fight
            tarefas_livres
            descansar
            sleep 5
            ;;

        # --- Batalha de Bandeiras
        (10:1[0-4]|16:1[0-4])
            flagfight_start
            descansar
            ;;

        # --- Eventos especiais
        (09:2[5-9]|21:2[5-9])
            specialEvent
            start
            ;;

        # --- Rotina comum (Horários cheios)
        (00:00|00:30|01:00|01:30|02:00|02:30|03:00|03:30|04:00|04:30|05:00|05:30|06:00|06:30|07:00|07:30|08:00|08:30|09:00|10:00|10:30|11:00|11:30|12:00|12:30|13:00|13:30|14:00|14:30|15:00|15:30|16:00|16:30|17:00|17:30|18:00|18:30|19:00|19:30|20:00|20:30|21:00|21:30|22:00|23:00|23:30)
            start
            ;;

        (*)
            # Se a conta foi iniciada especificamente com modo Coliseu (-cl)
            if echo "$RUN" | grep -q -E '[-]cl'; then
                arena_duel
                coliseum_start
                messages_info
            fi
            tarefas_livres
            func_sleep
            func_crono
            ;;
    esac
}
