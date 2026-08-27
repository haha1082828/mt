
## Aviso

Automação viola os termos de uso do jogo e pode resultar em **banimento das contas**. Você assume esse risco.

---

## Instalação — Termux (Android)

Instale o Termux **[pela F-Droid](https://f-droid.org/packages/com.termux/)**. A versão da Play Store não funciona.

**1.** Atualize os pacotes:

```bash
pkg update && pkg upgrade -y
```

**2.** Instale as dependências:

```bash
pkg install git curl wget jq util-linux -y
```

**3.** Impeça o Android de encerrar o bot:

```bash
termux-wake-lock
```

> Vá também em **Configurações → Bateria → Termux** e marque **"Sem restrições"**.

**4.** Baixe o bot:

```bash
cd ~ && git clone https://github.com/haha1082828/mt.git && cd mt
```

**5.** Verifique a integridade:

```bash
cd ~/mt && sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**6.** Cadastre as contas:

```bash
cd ~/mt && ./setup.sh
```

**7.** Inicie:

```bash
cd ~/mt && ./play.sh
```

---

## Instalação — WSL (Windows)

**1.** Instale as dependências:

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
```

**2.** Vá para a pasta pessoal do Linux:

```bash
cd ~
```

> **Nunca instale em `/mnt/c`.** Em pastas do Windows o Linux não aplica permissões, e o arquivo de credenciais fica com acesso liberado. Confira com `pwd` — deve começar com `/home/`.

**3.** Baixe o bot:

```bash
git clone https://github.com/haha1082828/mt.git && cd mt
```

**4.** Verifique a integridade:

```bash
cd ~/mt && sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**5.** Cadastre as contas:

```bash
cd ~/mt && ./setup.sh
```

**6.** Inicie:

```bash
cd ~/mt && ./play.sh
```

> Para o bot continuar rodando depois de fechar o terminal, use `tmux`:
>
> ```bash
> sudo apt install -y tmux && tmux new -s twm
> ```
>
> Rode o `./play.sh` dentro da sessão e saia com **Ctrl+B** depois **D**. Para voltar: `tmux attach -t twm`.
> **Se o `./play.sh` reclamar de diretório**, seu terminal está numa pasta que não existe mais. Rode `cd ~/mt` e tente de novo.

---

## Instalação — iSH (iPhone / iPad)

**1.** Instale as dependências:

```bash
apk update && apk add git curl jq tzdata bash
```

**2.** Baixe o bot:

```bash
cd ~ && git clone https://github.com/haha1082828/mt.git && cd mt
```

**3.** Verifique a integridade:

```bash
cd ~/mt && sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**4.** Cadastre as contas:

```bash
cd ~/mt && ./setup.sh
```

**5.** Inicie:

```bash
cd ~/mt && ./play.sh
```

> **O iOS suspende aplicativos em segundo plano.** O bot para quando você sai do iSH ou bloqueia a tela, e não há como evitar isso. A emulação também é lenta. Para uso contínuo, prefira Termux ou WSL.

---

## Comandos

> Todos os comandos incluem `cd ~/mt` porque precisam ser executados **dentro da pasta do bot**. Se você já estiver nela, o `cd` não atrapalha; se não estiver, ele evita o erro.

| O quê | Comando |
|---|---|
| Iniciar | `cd ~/mt && ./play.sh` |
| **Ver o painel** (não mexe nas contas) | `cd ~/mt && ./status.sh` |
| Reiniciar tudo do zero | `cd ~/mt && ./play.sh --restart` |
| Pausar / retomar | `cd ~/mt && ./pause.sh` |
| Ver estado | `cd ~/mt && ./pause.sh status` |
| Parar tudo | `cd ~/mt && ./stop.sh` |
| Deslogar todas as contas | `cd ~/mt && ./logout.sh` |
| Cadastrar contas | `cd ~/mt && ./setup.sh` |
| Diagnosticar login | `cd ~/mt && ./diagnose.sh` |
| Investigar `signal 9` | `cd ~/mt && ./sigkill.sh` |
| Ver log de uma conta | `tail -f ~/.twm/BR_NomeConta/twm.log` |

> **Para só olhar as contas, use o `./status.sh`, não o `./play.sh`.** O `status.sh` é somente leitura: desenha o painel e não sobe, não mata e não reinicia worker nenhum — sair com **Ctrl+C** não para nada. O `./play.sh` continua sendo o comando para *iniciar*; rodá-lo de novo agora preserva as contas que já estão rodando, e só sobe as que faltam.

> **Pausar não desloga.** Os processos continuam vivos e a sessão no jogo permanece válida — ao retomar não há novo login. A pausa entra em vigor **ao fim do ciclo em andamento**, então uma conta no meio de uma batalha pode levar alguns minutos para parar. Para encerrar de vez, use `cd ~/mt && ./stop.sh`.

---

## Atualização

**A atualização automática está desativada de propósito.** A versão anterior baixava e sobrescrevia os scripts sozinha, todo dia, a partir de um repositório de terceiro, sem verificar assinatura nem integridade — isso é execução de código arbitrário no seu aparelho. Além disso, o download não checava falhas: uma resposta de erro do servidor podia **truncar seus arquivos**.

Atualize sempre manualmente:

```bash
cd ~/mt && ./stop.sh && git pull && sha256sum -c .integrity --quiet && ./play.sh
```

Para revisar o que mudou **antes** de aplicar:

```bash
cd ~/mt && git fetch && git log --oneline HEAD..origin/main
```

---

## Integridade

O arquivo `.integrity` guarda a soma SHA-256 de cada script. Serve para confirmar que nenhum arquivo foi alterado — por atualização malfeita, edição acidental ou modificação de terceiro.

Verifique a qualquer momento:

```bash
cd ~/mt && sha256sum -c .integrity --quiet && echo "Nenhum script foi alterado"
```

Se aparecer alguma linha de erro, um script está diferente do publicado. Nesse caso, restaure:

```bash
cd ~/mt && git checkout -- . && git pull
```

Se você mesmo editar algum script, gere um novo baseline:

```bash
cd ~/mt && sha256sum -b *.sh | sort -k2 > .integrity
```

---

## Solução de problemas

<details>
<summary><b>"Unable to read current working directory" ou o play.sh não inicia</b></summary>

Seu terminal está numa pasta que foi renomeada ou removida. Volte para a pasta do bot:

```bash
cd ~/mt
```

Depois rode o comando de novo.
</details>

<details>
<summary><b>A conta não loga / fica presa em "login..."</b></summary>

Rode o diagnóstico. Ele mostra o que o servidor responde e **nunca exibe a senha**:

```bash
cd ~/mt && ./diagnose.sh
```

Depois com o número da conta:

```bash
cd ~/mt && ./diagnose.sh 1
```

| Resultado | Significa |
|---|---|
| **LOGIN FUNCIONOU** | a sessão está ativa |
| **O SERVIDOR RECUSOU** | senha errada, conta suspensa, ou o nome não é o de login |
| **Formulário sem erro** | sessão descartada — indício de bloqueio de IP |

O intervalo entre tentativas dobra a cada falha, até 15 minutos.
</details>

<details>
<summary><b>"could not create work tree dir: Permission denied"</b></summary>

Você está numa pasta do Windows. Vá para a pasta do Linux:

```bash
cd ~ && git clone https://github.com/haha1082828/mt.git && cd mt
```
</details>

<details>
<summary><b>"Your local changes would be overwritten by merge"</b></summary>

Descarte as alterações locais e atualize:

```bash
cd ~/mt && git checkout -- . && git pull
```
</details>

<details>
<summary><b>As contas estão jogando mas o painel mostra tudo em <code>[..]</code> / "0 online"</b></summary>

Os workers sobem com `nohup` + `setsid`, então **sobrevivem** quando o Termux é fechado ou morto pelo Android. O painel, não: ele vivia dentro do `./play.sh` e morria junto. As contas continuavam jogando e ficavam invisíveis.

O problema é o que vinha depois: para rever o painel, a única saída era rodar `./play.sh` de novo — e ele **derrubava as contas que estavam boas** e disparava 6 logins simultâneos do mesmo IP. O servidor recusa essa rajada com a mesma mensagem de "senha incorreta", e todas caíam no backoff de 30 s até 15 min. Daí o painel inteiro em `[..]`, tudo em `-`, "0 online". **O ato de olhar quebrava o que estava funcionando.**

Agora:

```bash
cd ~/mt && ./status.sh
```

Somente leitura — mostra as contas sem tocar em processo nenhum, quantas vezes você quiser. E o `./play.sh` ficou idempotente: rodá-lo com contas já no ar responde `já rodando (PID N) - mantida` e sobe só o que falta. Para forçar o reinício geral, `./play.sh --restart`.

> Se as contas caíram no backoff de login, elas se recuperam sozinhas — mas a espera chega a 15 min por conta. Acompanhe com `./status.sh`.
</details>

<details>
<summary><b>Manter o painel aberto depois de fechar o Termux</b></summary>

As contas não precisam do painel para funcionar. Mas se quiser voltar à mesma tela:

```bash
pkg install tmux -y && tmux new -s twm
```

Rode o `./play.sh` dentro da sessão e saia com **Ctrl+B** depois **D**. Para voltar: `tmux attach -t twm`.

Sem `tmux`, basta abrir o Termux e rodar `./status.sh` — o painel volta e as contas nunca foram interrompidas.
</details>

<details>
<summary><b>"[Process completed (signal 9)]" — o bot morre sozinho no meio do lançamento</b></summary>

`signal 9` é `SIGKILL`: **o Android matou o processo**, o bot não travou nem deu erro. Duas causas, nesta ordem:

### Primeiro, descubra a causa

`signal 9` é `SIGKILL` — o processo foi morto de fora e não consegue registrar nada sobre a própria morte. Em vez de tentar ajustes no escuro, deixe o bot rodar sob observação:

```bash
cd ~/mt && ./sigkill.sh
```

Ele inicia o bot normalmente (com o painel) e grava o estado do sistema a cada 2 s em `~/.twm/sigkill.log` — o arquivo sobrevive mesmo que o Termux inteiro morra. Quando parar, reabra o Termux e rode:

```bash
cd ~/mt && ./sigkill.sh relatorio
```

Como ler o resultado:

| No relatório | Causa provável | O que fazer |
|---|---|---|
| `mem_disp` caindo para perto de zero | Falta de memória | Rodar menos contas, fechar outros apps |
| `proc_bot` chegando perto de 32 | Limite de processos fantasma | Item 1 abaixo |
| `setsid: NAO` | Falta o `util-linux` | `pkg install util-linux -y` |
| Memória folgada e `proc_bot` baixo | Nenhuma das duas | Mande o relatório — a causa é outra |

**1. Limite de processos "fantasma" (Android 12 ou superior).** O sistema classifica como *phantom process* todo processo filho do Termux que ele não reconhece e, passando de **32 simultâneos**, mata sem avisar.

*Sem PC:* procure em **Configurações → Sistema → Opções do desenvolvedor** por uma opção de **restrições de processos filhos** (o nome varia: "Disable child process restrictions", "Suspensão de apps em segundo plano"). Nem todo aparelho a expõe.

*Com o celular ligado no PC:*

```bash
adb shell settings put global settings_enable_monitor_phantom_procs false
```

Nos dois casos o ajuste **volta ao normal quando o aparelho reinicia** — é preciso repetir.

**2. Restrição de bateria.** Em **Configurações → Bateria → Termux**, marque **"Sem restrições"**, e mantenha o `termux-wake-lock` ativo.

### Quantos processos o bot ocupa

O Android 12+ mata a sessão inteira acima de **32 processos filhos**. Num Moto E22 com Android 12, o Termux já marcava 26 processos com **duas** contas no ar — com seis não havia como caber. Por isso cada processo permanente foi eliminado:

| | antes | agora |
|---|---|---|
| `worker.sh` parado esperando o `twm.sh` | 6 | **0** — faz `exec`, vira o próprio `twm.sh` |
| `sleep` de espaçamento, um por conta | 6 | **0** — o tempo de rede já espaça |
| **Pico medido com 6 contas** | **21** | **15** |

Além disso o `./play.sh` encerra, ao iniciar, os workers órfãos de execuções anteriores — eles sobrevivem ao `SIGKILL` e vão se acumulando a cada tentativa, cada um contando para o limite.

> Mesmo assim a margem é apertada num aparelho de 4 GB: some ~12 processos do próprio Termux e você está em ~27 de 32. **Se o `signal 9` persistir com 6 contas, rode 4** — ou aplique o ajuste do item 1, que é o único jeito de remover o teto.

### Quanto o bot já foi enxugado

A conta de processos simultâneos com 6 contas, que é o que o Android mede:

| | antes | agora |
|---|---|---|
| Fixos (`play.sh` + 6 `worker.sh` + 6 `twm.sh`) | 13 | 13 |
| Por requisição, nas 6 contas | 18 | **12** |
| Rajada ao desenhar o painel, a cada 20 s | ~72 | **~0** |
| **Pico** | **~103** | **~25** |

Cada página baixada gastava até 19 processos (um subshell, o `curl` e até 17 execuções de `sleep`); hoje gasta 2. O painel lia cada arquivo com `cat` dentro de substituição de comando — 12 processos por conta a cada desenho — e agora usa `read`, que é interno ao shell.

> Com 6 contas isso deixa o pico bem abaixo do limite de 32. Acima disso, ou se o `signal 9` voltar, o ajuste do item 1 continua sendo a solução definitiva.
</details>

<details>
<summary><b>O `./setup.sh` mostra "Contas cadastradas: 0" mas o `./play.sh` encontra as contas</b></summary>

Os dois estavam lendo **arquivos diferentes**. O `accounts.conf` fica dentro da pasta do bot e não é versionado, então quem clonou o repositório mais de uma vez acaba com duas cópias — uma com as contas e outra vazia.

O menu do `./setup.sh` e o cabeçalho do `./play.sh` agora **mostram sempre o caminho do arquivo em uso**. Compare os dois; se forem diferentes, apague a pasta que não tem as contas:

```bash
ls -la ~/mt/accounts.conf
```

Se o arquivo local não existir, os dois scripts procuram nos lugares conhecidos antes de desistir — não é mais possível um enxergar as contas e o outro não.
</details>

<details>
<summary><b>A coluna "ATIVIDADE EM CONJUNTO" fica sempre em "Página Principal"</b></summary>

Corrigido. O painel lê a página atual de um arquivo que só era escrito por `fetch_page` — mas todo o código de batalha (`king.sh`, `coliseum.sh`, `clanfight.sh`, `altars.sh`, `undying.sh`, entre outros, mais de 100 pontos) chama o `curl` por outro caminho e nunca atualizava esse arquivo. O registro passou para a função central de requisição, por onde toda chamada passa de verdade.

Entre um ciclo e outro a conta descansa na página inicial de propósito, então **"Página Principal" durante a espera é o estado correto** — o que mudou é que agora a batalha em andamento aparece.
</details>

<details>
<summary><b>O bot para quando a tela desliga (Android)</b></summary>

```bash
termux-wake-lock
```

E em **Configurações → Bateria → Termux**, marque **"Sem restrições"**.
</details>

<details>
<summary><b>O painel quebra as linhas / fica embaralhado no celular</b></summary>

Corrigido. O painel era fixo em 68 colunas e a tela de um celular no Termux tem por volta de 56, então cada conta partia no meio. Agora ele mede a largura do terminal a cada atualização (inclusive ao girar o aparelho) e usa um layout de duas linhas por conta abaixo de 86 colunas, com os rótulos abreviados abaixo de 56.

Se ainda estourar — fonte muito grande, por exemplo — force a largura:

```bash
TWM_COLS=48 ./status.sh
```
</details>

<details>
<summary><b>Emoji aparecem como quadrados</b></summary>

A fonte do terminal não os suporta. Use o modo padrão, sem a variável `TWM_EMOJI`.
</details>

<details>
<summary><b>Contas duplicadas ou processos travados</b></summary>

```bash
cd ~/mt && ./stop.sh && pkill -f twm.sh && ./play.sh
```
</details>

<details>
<summary><b>Recomeçar do zero mantendo as contas cadastradas</b></summary>

```bash
cd ~/mt && ./stop.sh && rm -rf ~/.twm && ./play.sh
```
</details>

---

## Desinstalar

Remove **tudo**: processos, serviço, dados das contas e o próprio diretório. Pede confirmação digitando `REMOVER`:

```bash
cd ~/mt && ./uninstall.sh
```

Para remover na mão, sem o script — este comando apaga **todas as pastas** do bot:

```bash
pkill -f twm.sh; pkill -f worker.sh; pkill -f play.sh; sudo systemctl stop twm 2>/dev/null; sudo systemctl disable twm 2>/dev/null; sudo rm -f /etc/systemd/system/twm.service; cd ~ && rm -rf mt ~/.twm ~/twm ~/twm_ANTIGO_NAO_USAR ~/.multcf
```

> Isso apaga as contas cadastradas. As contas **no jogo** não são afetadas.

---

 
