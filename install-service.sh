#!/bin/sh
# install-service.sh - Instala o TWM como servico do systemd
#
# Para servidores Linux (VPS) e qualquer sistema com systemd. Faz o bot
# iniciar sozinho no boot e reiniciar caso o processo caia.
#
# Uso:  ./install-service.sh
# Requer: sudo

set -e

SERVICE_NAME="twm"

if ! command -v systemctl > /dev/null 2>&1; then
    printf "Este sistema nao usa systemd. No Termux, use ./play.sh direto.\n"
    exit 1
fi

if [ "$(id -u)" = "0" ]; then
    printf "Nao rode este script como root.\n"
    printf "Rode como o usuario que vai executar o bot; ele pede sudo quando precisar.\n"
    exit 1
fi

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
RUNUSER=$(id -un)
RUNGROUP=$(id -gn)
RUNHOME="$HOME"

if [ ! -x "$TWMDIR/play.sh" ]; then
    printf "play.sh nao encontrado ou sem permissao de execucao em %s\n" "$TWMDIR"
    printf "Rode: chmod +x play.sh setup.sh stop.sh worker.sh twm.sh\n"
    exit 1
fi

if [ ! -s "$TWMDIR/accounts.conf" ]; then
    printf "Nenhuma conta cadastrada ainda.\n"
    printf "Rode ./setup.sh primeiro, depois volte aqui.\n"
    exit 1
fi

case "$TWMDIR" in
    /mnt/*|/media/*)
        printf "AVISO: %s parece ser um disco montado (Windows/externo).\n" "$TWMDIR"
        printf "Permissoes POSIX podem nao ser aplicadas, deixando o accounts.conf exposto.\n"
        printf "Continuar mesmo assim? (y/n): "
        read -r _c
        case "$_c" in y|Y) ;; *) exit 1 ;; esac
        ;;
esac

UNIT="/etc/systemd/system/${SERVICE_NAME}.service"

printf "Instalando servico:\n"
printf "  usuario:   %s\n" "$RUNUSER"
printf "  diretorio: %s\n" "$TWMDIR"
printf "  unidade:   %s\n" "$UNIT"
printf "\nContinuar? (y/n): "
read -r _ok
case "$_ok" in y|Y) ;; *) printf "Cancelado.\n"; exit 1 ;; esac

sudo tee "$UNIT" > /dev/null <<UNITEOF
[Unit]
Description=TWM - Titans War Macro (multi-contas)
Documentation=https://github.com/Theoswd/Furia-de-titas
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUNUSER}
Group=${RUNGROUP}
Environment=HOME=${RUNHOME}
WorkingDirectory=${TWMDIR}

ExecStart=/bin/sh ${TWMDIR}/play.sh
ExecStop=/bin/sh ${TWMDIR}/stop.sh

# Se o play.sh cair, sobe de novo. Os workers ficam no mesmo cgroup,
# entao parar o servico encerra tudo — sem processos orfaos.
Restart=always
RestartSec=30

# Endurecimento. ProtectHome fica DESLIGADO de proposito: o bot precisa
# gravar em ~/.twm (cookie, config e log de cada conta).
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=twm

[Install]
WantedBy=multi-user.target
UNITEOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME" > /dev/null 2>&1

printf "\nServico instalado.\n\n"
printf "Iniciar agora:      sudo systemctl start %s\n" "$SERVICE_NAME"
printf "Ver estado:         systemctl status %s\n" "$SERVICE_NAME"
printf "Ver log ao vivo:    journalctl -u %s -f\n" "$SERVICE_NAME"
printf "Parar:              sudo systemctl stop %s\n" "$SERVICE_NAME"
printf "Desativar no boot:  sudo systemctl disable %s\n" "$SERVICE_NAME"
printf "\nLog de uma conta:   tail -f ~/.twm/BR_NomeConta/twm.log\n"
