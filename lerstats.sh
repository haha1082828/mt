#!/bin/sh
# lerstats.sh - Mostra o que o bot LE da conta, e de onde
#
# Serve para comparar com o que o jogo mostra no navegador. Quando um numero
# do painel nao bate com o jogo, o problema esta quase sempre no seletor: a
# pagina mudou de formato e a expressao passa a casar outro numero. Este
# script exibe o TRECHO CRU da pagina ao redor de cada valor, para que a
# diferenca fique visivel sem adivinhacao.
#
# Usa o cookie que a conta ja tem em ~/.twm/BR_<conta>/cookie.txt, entao nao
# faz login novo e NAO precisa de senha.
#
# Uso:  ./lerstats.sh            lista as contas
#       ./lerstats.sh Grimlock   mostra os dados dessa conta
#       ./lerstats.sh Grimlock masmorra   mostra a pagina da Masmorra do Cla

umask 077

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
TWMHOME="$HOME/.twm"
URL="https://furiadetitas.net"

G='\033[1;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[1;36m'; D='\033[2m'; N='\033[0m'

[ -d "$TWMHOME" ] || { printf "${R}Bot nunca executado neste aparelho.${N}\n"; exit 1; }

if [ -z "$1" ]; then
    printf "${C}Contas disponiveis:${N}\n"
    for _d in "$TWMHOME"/BR_*/; do
        [ -d "$_d" ] && printf "  %s\n" "$(basename "${_d%/}" | sed 's/^BR_//')"
    done
    printf "\n${D}Uso: ./lerstats.sh NomeDaConta${N}\n"
    exit 0
fi

ACC_DIR=""
for _d in "$TWMHOME"/BR_*/; do
    [ -d "$_d" ] || continue
    case "$(basename "${_d%/}")" in *"$1"*) ACC_DIR="${_d%/}"; break ;; esac
done
[ -n "$ACC_DIR" ] || { printf "${R}Conta nao encontrada: %s${N}\n" "$1"; exit 1; }

CK="$ACC_DIR/cookie.txt"
[ -s "$CK" ] || { printf "${R}Sem sessao salva. Rode ./play.sh antes.${N}\n"; exit 1; }

UA="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"
[ -s "$TWMDIR/userAgent.txt" ] && UA=$(head -n1 "$TWMDIR/userAgent.txt")

baixa() {
    curl -sS -L --compressed --max-redirs 5 --connect-timeout 15 --max-time 30 \
         -A "$UA" -c "$CK" -b "$CK" "$1" 2>/dev/null
}

printf "${C}Conta:${N} %s\n\n" "$(basename "$ACC_DIR")"

# ---------- modo masmorra: ./lerstats.sh Conta masmorra ----------
#
# Mostra a pagina da Masmorra do Cla como o bot a ve. E o unico jeito de
# saber, sem estar com o aparelho, por que a masmorra nao acha o golpe:
# o endereco esta errado, o painel de recompensa esta na frente, ou os
# acessos gratis realmente acabaram.
case "$2" in
    masmorra|-m|dungeon)
        printf "${C}== pagina /clandungeon/?close ==${N}\n"
        DUN=$(baixa "$URL/clandungeon/?close")
        printf "  tamanho: %s bytes\n" "$(printf '%s' "$DUN" | wc -c)"
        if [ -z "$DUN" ]; then
            printf "  ${R}pagina vazia (sessao caida, sem rede ou endereco inexistente)${N}\n"
            exit 1
        fi

        printf "\n${D}  Titulo da pagina:${N}\n"
        printf '%s' "$DUN" | grep -o -E "<title>[^<]{0,60}" | sed 's/<title>/    /'

        printf "\n${D}  Trechos com golpe / acesso / masmorra (texto, sem tags):${N}\n"
        printf '%s' "$DUN" | sed 's/<[^>]*>/ /g' | tr -s ' \t' ' ' \
            | grep -o -i -E ".{0,40}(golpe|acesso|masmorra|dungeon).{0,40}" | head -n 8 | sed 's/^/    /'

        printf "\n${D}  TODOS os links acionaveis (com nonce ?r=):${N}\n"
        printf '%s' "$DUN" | grep -o -E "/[a-z0-9_-]{3,24}/[a-z0-9_-]{0,24}/?[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+" \
            | sort -u | head -n 15 | sed 's/^/    /'

        printf "\n${Y}  O que o bot procura hoje:${N}\n"
        _gp=$(printf '%s' "$DUN" | grep -o -E "/clandungeon/at[a-z]{0,3}k/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+" | sed -n 1p)
        [ -n "$_gp" ] || _gp=$(printf '%s' "$DUN" | grep -o -E "/[a-z]{4,20}/at[a-z]{0,3}k/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+" | sed -n 1p)
        if [ -n "$_gp" ]; then
            printf "    ${G}link de golpe encontrado: %s${N}\n" "$_gp"
        else
            printf "    ${R}nenhum link de golpe nesta pagina${N}\n"
            printf "    ${D}Compare com a lista de links acima: se houver um golpe ali${N}\n"
            printf "    ${D}com outro formato, e ele que o bot precisa aprender.${N}\n"
        fi
        exit 0
        ;;
esac

# ---------- /train : energia e HP maximo ----------
printf "${C}== pagina /train ==${N}\n"
TRAIN=$(baixa "$URL/train")
if [ -z "$TRAIN" ]; then
    printf "  ${R}pagina vazia (sessao caida ou sem rede)${N}\n\n"
else
    printf "${D}  Todo trecho com a palavra 'Energia' (texto, sem tags):${N}\n"
    printf '%s' "$TRAIN" | sed 's/<[^>]*>/ /g' | tr -s ' ' \
        | grep -o -i -E ".{0,45}Energia.{0,45}" | head -n 6 \
        | sed 's/^/    /' || printf "    ${R}nenhuma ocorrencia de 'Energia'${N}\n"

    printf "\n${D}  Todos os numeros entre parenteses (HP maximo sai daqui):${N}\n"
    printf '%s' "$TRAIN" | grep -o -E '\([0-9]{1,9}\)' | head -n 5 | sed 's/^/    /'

    printf "\n${D}  Contexto de cada icone (qual valor acompanha qual icone):${N}\n"
    printf '%s' "$TRAIN" | grep -o -E "icon/[a-z]+\.png.{0,60}" | head -n 8 | sed 's/^/    /'


    printf "\n${D}  Pares 'N / M' ou 'N de M' (energia atual e teto, se existirem):${N}\n"
    printf '%s' "$TRAIN" | sed 's/<[^>]*>/ /g' | tr -s ' ' \
        | grep -o -E "[0-9][0-9.,']{0,9} ?(/|de) ?[0-9][0-9.,']{0,9}" | head -n 6 | sed 's/^/    /'

    printf "\n${Y}  O que o bot extrai hoje:${N}\n"
    _ene=$(printf '%s' "$TRAIN" | grep -o -E "Energia:?[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" \
           | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1)
    _fix=$(printf '%s' "$TRAIN" | grep -o -E '\([0-9]{1,9}\)' | head -n1 | tr -d '()')
    printf "    Energia (teto) = %s\n" "${_ene:-<vazio>}"
    printf "    HP max  = %s\n\n" "${_fix:-<vazio>}"
fi

# ---------- /user : HP, MP, nivel, ouro, prata ----------
printf "${C}== pagina /user ==${N}\n"
USERPG=$(baixa "$URL/user")
if [ -z "$USERPG" ]; then
    printf "  ${R}pagina vazia (sessao caida ou sem rede)${N}\n"
else
    printf "${D}  Todo trecho com a palavra 'Energia' (texto, sem tags):${N}\n"
    printf '%s' "$USERPG" | sed 's/<[^>]*>/ /g' | tr -s ' ' \
        | grep -o -i -E ".{0,45}Energia.{0,45}" | head -n 4 | sed 's/^/    /'

    printf "\n${D}  Contexto de cada icone (qual valor acompanha qual icone):${N}\n"
    printf '%s' "$USERPG" | grep -o -E "icon/[a-z]+\.png.{0,60}" | head -n 8 | sed 's/^/    /'


    printf "\n${Y}  O que o bot extrai hoje:${N}\n"
    printf "    HP    = %s\n" "$(printf '%s' "$USERPG" | grep -o -E "health\.png' alt='hp'/>[^0-9]{0,40}[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1)"
    printf "    Energia (atual) = %s\n" "$(printf '%s' "$USERPG" | grep -o -E "mana\.png' alt='mp'/>[^0-9]{0,40}[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1)"
    printf "    Nivel = %s\n" "$(printf '%s' "$USERPG" | grep -o -E "level\.png' alt='[^']*'/>[^0-9]{0,40}[0-9]{1,4}" | grep -o -E '[0-9]{1,4}$' | head -n1)"
    printf "    Ouro  = %s\n" "$(printf '%s' "$USERPG" | grep -o -E "gold\.png' alt='g'/>[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1)"
    printf "    Prata = %s\n" "$(printf '%s' "$USERPG" | grep -o -E "silver\.png' alt='s'/>[^0-9]{0,40}[0-9][0-9.,']{0,14}[KMBkmb]?" | grep -o -E "[0-9][0-9.,']{0,14}[KMBkmb]?$" | head -n1)"
fi

printf "\n${C}== o que esta gravado para o painel ==${N}\n"
if [ -s "$ACC_DIR/stats" ]; then
    IFS='|' read -r _n _hp _mp _en _lv _ou _pr _ts < "$ACC_DIR/stats"
    printf "    nome=%s HP=%s MP=%s Energia=%s LV=%s Ouro=%s Prata=%s\n" \
        "$_n" "$_hp" "$_mp" "$_en" "$_lv" "$_ou" "$_pr"
    case "$_ts" in
        ''|*[!0-9]*) ;;
        *) printf "    ${D}gravado ha %s minuto(s)${N}\n" "$(( ( $(date +%s) - _ts ) / 60 ))" ;;
    esac
else
    printf "    ${R}arquivo stats ausente${N}\n"
fi

printf "\n${D}Compare a Energia acima com a do navegador. Se o bot extrai um\n"
printf "numero diferente do que o jogo mostra, o trecho cru de /train diz por que.${N}\n"
