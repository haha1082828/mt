# PATCH TESTE — CLANCOLISEUM
# Substitui somente a leitura/parsing da página. Não altera timers, endpoints,
# prioridades ou arquivos de estado.
clancoliseum_access_fast() {
  awk '
    {
      if ($0 ~ /\/clancoliseum\/dodge\/?\?r=[0-9]+/) dodge=$0
      if ($0 ~ /\/clancoliseum\/heal\/?\?r=[0-9]+/) heal=$0
      if ($0 ~ /hp[^A-Za-z0-9]{1,4}[0-9]{1,6}/) hp=$0
      if ($0 ~ /\/shield\/?\?r=[0-9]+/) shield=$0
      if ($0 ~ /\/[^"'"'"' ]*attack[^"'"'"' ]*\?r=[0-9]+/) atk=$0
    }
    END {
      print dodge > "DODGE"
      print heal > "HEAL"
      print hp > "USH"
      print shield > "SHIELD"
      print atk > "ATK"
    }
  ' "$src_ram" 2>/dev/null
}
