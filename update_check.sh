# update_check.sh - Atualizacao MANUAL e verificavel
#
# A atualizacao automatica foi desativada de proposito. Baixar e sobrescrever
# scripts sozinho, sem assinatura nem verificacao de integridade, e execucao
# de codigo arbitrario no aparelho. Agora usa git (integridade por hash de
# conteudo), exige arvore limpa, so aceita fast-forward e nunca roda sozinha.

update() {
    if [ ! -t 0 ]; then
        printf "Atualizacao automatica desativada por seguranca.\n"
        printf "Para atualizar: pare o bot (./stop.sh), rode 'git pull' e revise o diff.\n"
        return 1
    fi

    if [ -z "$TWMDIR" ] || [ ! -d "$TWMDIR" ]; then
        printf "TWMDIR nao definido.\n"
        return 1
    fi

    if ! command -v git > /dev/null 2>&1; then
        printf "git nao instalado. Rode: pkg install git\n"
        return 1
    fi

    if [ ! -d "$TWMDIR/.git" ]; then
        printf "Este diretorio nao e um repositorio git.\n"
        printf "Atualize manualmente clonando a versao nova.\n"
        return 1
    fi

    printf "AVISO: atualizar substitui os scripts. Pare o bot antes (./stop.sh).\n"
    printf "Continuar? (y/n): "
    read -r _u
    case "$_u" in y|Y) ;; *) printf "Cancelado.\n"; return 1 ;; esac

    ( cd "$TWMDIR" || exit 1

      if [ -n "$(git status --porcelain)" ]; then
          printf "Ha alteracoes locais nao commitadas. Update abortado para nao perde-las.\n"
          printf "Revise com: git status\n"
          exit 1
      fi

      printf "Buscando atualizacoes...\n"
      git fetch --quiet origin || { printf "Falha ao buscar.\n"; exit 1; }

      _branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      [ -z "$_branch" ] && _branch="master"

      printf "Alteracoes pendentes:\n"
      git --no-pager log --oneline "HEAD..origin/${_branch}" 2>/dev/null | head -20

      # --ff-only: recusa merge inesperado. O git ja garante integridade do
      # conteudo por hash, ao contrario da comparacao por tamanho anterior.
      if git merge --ff-only "origin/${_branch}" 2>/dev/null; then
          printf "Atualizado. Reinicie com ./play.sh\n"
      else
          printf "Nao foi possivel atualizar por fast-forward. Resolva manualmente.\n"
          exit 1
      fi
    )
}
