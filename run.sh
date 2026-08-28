twm_play() {
    echo "$RUN" > "$TMP/runmode_file" 2>/dev/null

    if [ ! -s "$TMP/CLD" ]; then
        clan_id
    fi

    # ORDEM DE PRIORIDADE DOS EVENTOS
    #
    # O "case" para no primeiro padrao que casa, entao a ordem dos ramos
    # E a prioridade. De cima para baixo:
    #
    #   1. Torneio dos Clas      10:55  18:55
    #   2. Altares dos Deuses    13:55  20:55
    #   3. Vale dos Imortais     09:55  15:55  21:55
    #   4. Rei dos Imortais      12:25  16:25  22:25
    #   5. Coliseu do Cla        10:28  14:58
    #
    # O Coliseu comum roda das 00:30 as 04:30 em todas as contas.
    case `date +%H:%M` in

        # --- 1. Torneio dos Clas
        (10:5[5-9]|18:5[5-9])
            evento_dedicar
            if [ -n "$CLD" ]; then
                clanfight_start
            fi
            evento_espera
            start
            ;;

        # --- 2. Altares dos Deuses
        (13:5[5-9]|20:5[5-9])
            evento_dedicar
            if [ -n "$CLD" ]; then
                altars_start
            fi
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
        #
        # CORRECAO (evento perdido): este ramo chamava so em 10:2[8-9] e
        # 14:5[8-9] — DOIS minutos —, mas o proprio clancoliseum_start aceita
        # 10:2[5-9]|14:5[5-9], ou seja foi escrito para CINCO minutos de
        # antecedencia, como os demais eventos. Os tres primeiros minutos da
        # inscricao eram descartados pelo agendador.
        #
        # Isso importa porque a inscricao (/clancoliseum/enterFight) acontece
        # DENTRO do modulo: perder a janela nao e chegar atrasado, e nao
        # participar. Com o worker preso numa atividade longa (campanha ate
        # 90s, coliseu ate 600s) ou dormindo, dois minutos se perdem com
        # facilidade — e o Coliseu do Cla passava em branco no dia.
        (10:2[5-9]|14:5[5-9])
            evento_dedicar
            if [ -n "$CLD" ]; then
                clancoliseum_start
            fi
            evento_espera
            start
            ;;

        # --- Coliseu comum: 00:30 as 04:30, pulsado de 10 em 10 minutos
        #
        # Antes esta janela casava TODO minuto. A coliseum_fight faz tres
        # requisicoes de preparacao (/train, /settings/graphics/0,
        # /coliseum) antes de lutar, entao eram ~720 requisicoes por conta
        # por noite so de preparo. Com 10 contas, ~7.200; com 20, ~14.400.
        #
        # A TitansWarPro pulsa nos minutos terminados em 5 e roda sem
        # problema. Mesma ideia aqui, dentro da janela 00:30-04:30: 24
        # entradas por noite em vez de 241. Os minutos que sobram caem no
        # ramo (*), que ja chama tarefas_livres, entao a checagem das
        # missoes do cla e da arena continua na mesma frequencia.
        (00:[345]5|0[123]:[0-5]5|04:[012]5)
            coliseum_fight
              # PAUSA PARA CHECAR MISSOES. O Coliseu comum nao esta entre os
              # cinco eventos de prioridade, entao entre as lutas o bot
              # confere o checklist do cla e roda a arena no intervalo dela.
              # Antes, as quatro horas da janela passavam sem nada disso.
            tarefas_livres
            # Este ramo nao passa pelo func_cat/start(), entao sem isto a
            # sessao ficava presa na ultima pagina de luta/missao. Descansa na
            # Home no servidor entre os pulsos (o func_cat ja faz isso nos
            # demais ramos).
            descansar
            # Quando NAO ha luta, o coliseum_fight retorna na hora e este ramo
            # (sem func_sleep) reentraria em rajada dentro do mesmo minuto.
            # Uma pausa curta limita isso sem atrasar o pulso de forma sensivel;
            # quando HA luta, o coliseum_fight ja consome o tempo.
            sleep 5
            ;;

        # --- Batalha de Bandeiras
        (10:1[0-4]|16:1[0-4])
            flagfight_start
            # Sai da pagina da batalha e descansa na Home no servidor: este
            # ramo tambem nao passa pelo func_cat/start().
            descansar
            ;;

        # --- Eventos especiais
        (09:2[5-9]|21:2[5-9])
            specialEvent
            start
            ;;

        # --- Rotina comum
        #
        # Madrugada alinhada com a TitansWarPro: rotina completa a cada
        # :00 e :30. Antes so havia :00 das 00 as 03, porque a janela do
        # Coliseu casava todo minuto e nao sobrava espaco. Com o Coliseu
        # pulsado nos minutos terminados em 5, :00 e :30 ficam livres.
        # CORRECAO: faltavam 10:00, 10:30, 12:30, 16:00, 16:30, 21:00 e 21:30.
        # Nesses vaos o start() nunca rodava, e as atividades que so existiam
        # nele (Liga, Troca, Eventos, Missoes do Cla) ficavam de fora — em
        # 16:00-16:30, por exemplo, havia mais de uma hora sem varredura
        # completa. Nenhum dos minutos adicionados colide com os ramos de
        # evento acima (que usam :10, :25, :28, :55, :58).
        (00:00|00:30|01:00|01:30|02:00|02:30|03:00|03:30|04:00|04:30|05:00|05:30|06:00|06:30|07:00|07:30|08:00|08:30|09:00|10:00|10:30|11:00|11:30|12:00|12:30|13:00|13:30|14:00|14:30|15:00|15:30|16:00|16:30|17:00|17:30|18:00|18:30|19:00|19:30|20:00|20:30|21:00|21:30|22:00|23:00|23:30)
            start
            ;;

        (*)
            if echo "$RUN" | grep -q -E '[-]cl'; then
                printf "Running in coliseum mode: %s\n" "$RUN"
                sleep 5
                arena_duel
                coliseum_start
                messages_info
            fi
            # Arena a cada 30 min, mesmo fora dos minutos da agenda.
            tarefas_livres
            func_sleep
            func_crono
            ;;
    esac
}

# Reinicia APENAS esta conta.
#
# CORRECAO (multi-contas): a versao anterior fazia
#     pgrep -f "sh.*twm/twm.sh"  +  kill -9
# O padrao nao casava com o diretorio real do repositorio, entao nao matava
# nada; mas quem instalasse numa pasta chamada "twm" mataria TODAS as contas
# de uma vez. Em seguida chamava "$HOME/twm/twm.sh", caminho inexistente.
# Alem disso "kill -9 $pidf" com varios PIDs entre aspas e argumento invalido.
#
# Agora simplesmente encerra este processo: o worker.sh desta conta ja tem
# um laco que o reinicia em ~15s, sem tocar nas demais contas.
restart_script() {
    printf "[%s] %s — reiniciando esta conta\n" "$TWM_TAG" "${ACC:-$TWM_USER}"
    exit 0
}
