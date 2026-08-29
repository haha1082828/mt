## Aviso

O uso de automação pode contrariar os termos de serviço do jogo e levar ao **banimento das contas**. A utilização fica por sua própria responsabilidade.

---

## Instalação — Termux (Android)

Baixe o Termux **[pela F-Droid](https://f-droid.org/packages/com.termux/)**, pois a versão disponibilizada na Play Store não é compatível.

```bash
pkg update && pkg upgrade -y
```

```bash
pkg install git curl wget jq util-linux -y
```

```bash
termux-wake-lock
```

```bash
cd ~ && git clone https://github.com/haha1082828/mt.git && cd mt
```

```bash
chmod +x ./*.sh
```

```bash
./setup.sh
```

```bash
./play.sh
```

> Vá também em **Configurações → Bateria → Termux** e marque **"Sem restrições"**.
---

## Instalação — WSL no Windows

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
```

```bash
cd ~
```

```bash
git clone https://github.com/haha1082828/mt.git && cd mt
```

```bash
chmod +x ./*.sh
```

```bash
./setup.sh
```

```bash
./play.sh
```

> **Evite instalar em `/mnt/c`.** Diretórios do Windows podem impedir que o Linux aplique as permissões corretamente, deixando o arquivo de credenciais exposto. Use `pwd` para conferir o caminho; ele deve começar por `/home/`.

> Se quiser manter o processo ativo após fechar o terminal, utilize `tmux`. Rode o `./play.sh` dentro da sessão e saia com **Ctrl+B** depois **D**. Para voltar: `tmux attach -t twm`.
---

## Instalação — iSH (iPhone / iPad)

```bash
apk update && apk add git curl jq tzdata bash
```

```bash
cd ~ && git clone https://github.com/haha1082828/mt.git && cd mt
```

```bash
chmod +x ./*.sh
```

```bash
./setup.sh
```

```bash
./play.sh
```

> **Limitação do iOS:** os aplicativos podem ser suspensos quando ficam em segundo plano. Assim, o bot pode parar ao sair do iSH ou bloquear a tela. Para execução contínua, dê preferência ao Termux ou WSL.
---

## Comandos disponíveis

| O quê | Comando |
|---|---|
| Iniciar | `cd ~/mt && ./play.sh` |
| **Ver o painel** (não mexe nas contas) | `cd ~/mt && ./status.sh` |
| Rodar as atividades agora | `cd ~/mt && ./agora.sh` |
| Pausar / retomar | `cd ~/mt && ./pause.sh` |
| Parar tudo | `cd ~/mt && ./stop.sh` |
| Cadastrar contas | `cd ~/mt && ./setup.sh` |
| Deslogar todas as contas | `cd ~/mt && ./logout.sh` |
| Diagnosticar login | `cd ~/mt && ./diagnose.sh` |
| **Relatório de saúde** (uma tela, tudo) | `cd ~/mt && ./saude.sh` |
| Conferir os dados de uma conta | `cd ~/mt && ./lerstats.sh NomeDaConta` |
| Ver a página da Masmorra do Clã | `cd ~/mt && ./lerstats.sh NomeDaConta masmorra` |
| Ver log de uma conta | `tail -f ~/.twm/BR_NomeConta/twm.log` |
| Desinstalar | `cd ~/mt && ./uninstall.sh` |

---

## Atualizando o projeto

```bash
cd ~/mt && ./stop.sh && git pull && ./play.sh
```

As contas já cadastradas e os arquivos armazenados em `~/.twm` permanecem intactos; a atualização altera somente os scripts.

> **É necessário reiniciar após atualizar.** Cada conta carrega os scripts ao ser iniciada. Portanto, apenas executar `git pull` substitui os arquivos no disco, mas os processos existentes continuam usando a versão anterior. O comando acima já encerra e inicia novamente tudo, e o `./saude.sh` identifica a situação com (`PROC on/old`).

> **O painel precisa ser reiniciado também.** O `./status.sh` carrega o layout quando é iniciado. Se permanecer aberto durante um `git pull`, como costuma acontecer em uma sessão `tmux` no WSL, ele continuará usando o layout anterior. O `./stop.sh` também encerra o painel, que informa `codigo atualizado — feche e abra o painel` quando detectar uma versão antiga.

---

## Principais melhorias

### Multi-contas
- Cada conta possui sua própria instância, com diretório, sessão, credenciais, configuração e log independentes.
- Corrigida a situação em que a última conta de `accounts.conf` era silenciosamente ignorada quando faltava uma quebra de linha no final do arquivo.
- Os logins são organizados de forma serializada para evitar uma sequência de requisições do mesmo IP que possa ser recusada pelo servidor.
- Cada conta passa a utilizar um User-Agent individual.
- Erros de conexão durante o login não são mais confundidos com senha incorreta, evitando que a conta fique parada por até 15 minutos.

### Sessão
- A sessão é validada novamente durante os períodos de espera, além dos horários programados. Isso corrige o caso em que a conta aparecia no painel, mas permanecia desconectada do jogo.
- Nos intervalos entre ciclos, a conta permanece efetivamente na página inicial.
- As reconexões são distribuídas entre as contas para evitar uma sequência de logins pelo mesmo IP após uma queda.

### Estabilidade
- O número de processos por requisição foi reduzido: até 16 contas podem operar dentro do limite de 32 processos do Android 12+, evitando encerramentos por *signal 9*.
- O painel agora é independente do orquestrador; iniciar ou fechar o `./status.sh` não interrompe as contas.
- Cada conta possui log com rotação, e os ciclos de batalha contam com limite de execução.

### Eventos
- Horários conferidos contra o cronograma do jogo; inscrição 5 minutos antes em todos.
- Coliseu do Clã recuperou 3 dos 5 minutos de inscrição e só se inscreve quando a temporada está aberta.
- Corrigido o defeito que fazia a conta abandonar a luta no meio do evento.
- Durante os cinco eventos de prioridade nenhuma outra atividade roda.
- A agenda oficial do jogo passou a ser lida de verdade.

### Atividades
- Arena, carreira, campanha, caverna, cabana do sábio, liga, troca, missões e masmorra revisadas contra o projeto original.
- Liga, Troca, Missões do Clã e Eventos passaram a rodar também fora dos minutos da agenda.
- Missões concluídas voltaram a ser recolhidas; o mercador do clã faz as três produções.
- Masmorra do Clã deixou de depender de hora fixa: procura o golpe na própria página e insiste enquanto houver acesso livre.
- O bot nunca gasta ouro.

### Painel
- Atividade de cada conta visível, e batalha em andamento em destaque.
- No bloco **AO VIVO — BATALHAS**, o registro da luta aparece logo abaixo do nome: quem acertou a conta, com quanto, se foi crítico, e a habilidade, erva ou pedra que a conta usou.
- Larguras adaptadas à tela: o HP deixou de ser empurrado para fora do campo de visão no celular.
- Energia, HP, ouro e prata deixaram de ficar congelados; o painel avisa quando os números estão parados.
- Atualização a cada 5 segundos.

> Para definir a quantidade de linhas exibidas no registro da batalha: `PANEL_LOG_LINHAS=4 ./status.sh` — `0` desliga.

### Diagnóstico
- `./saude.sh` põe numa tela só o que costuma ser perguntado num diagnóstico remoto: memória, processos, sessão e log de cada conta.
- Ele avisa quando as contas ficaram rodando o código anterior a um `git pull` sem reinício.
- `./lerstats.sh` mostra a página crua que o bot lê, para comparar com o navegador quando um número não bate.

---
