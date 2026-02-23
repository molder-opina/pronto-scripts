#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  bash pronto-scripts/bin/refresh-bug-reviews.sh [--date YYYY-MM-DD] [--check]

Opciones:
  -d, --date   Fecha de corte para encabezados de dashboards.
  -c, --check  Modo verificación: exit 1 si hay bugs abiertos o en seguimiento.
  -h, --help   Muestra esta ayuda.
EOF
}

cutoff_date="$(date +%F)"
check_mode=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--date)
      if [ "$#" -lt 2 ]; then
        echo "error: falta valor para $1" >&2
        usage
        exit 1
      fi
      cutoff_date="$2"
      shift 2
      ;;
    -c|--check)
      check_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: opción no soportada: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$cutoff_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "error: --date debe tener formato YYYY-MM-DD" >&2
  exit 1
fi
if ! date -j -f "%Y-%m-%d" "$cutoff_date" "+%Y-%m-%d" >/dev/null 2>&1; then
  echo "error: --date no es una fecha válida: $cutoff_date" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REVIEWS_DIR="$ROOT_DIR/pronto-docs/errors/_reviews"
RESUELTOS_FILE="$ROOT_DIR/pronto-docs/resueltos.txt"
RESOLVED_DIR="$ROOT_DIR/pronto-docs/resolved"
TODAY="$cutoff_date"

mkdir -p "$REVIEWS_DIR"

checklist_file="$REVIEWS_DIR/20260218_bug_checklist.md"
module_file="$REVIEWS_DIR/20260218_bug_checklist_by_module.md"
severity_file="$REVIEWS_DIR/20260218_bug_checklist_by_severity.md"
top10_file="$REVIEWS_DIR/20260218_bug_executive_top10.md"
sla_file="$REVIEWS_DIR/20260218_bug_sla_report.md"
aging_file="$REVIEWS_DIR/20260218_bug_aging_report.md"
semaforo_file="$REVIEWS_DIR/20260218_bug_dashboard_semaforo.md"
master_file="$REVIEWS_DIR/20260218_bug_dashboard_master.md"
status_file="$REVIEWS_DIR/STATUS.md"
readme_file="$REVIEWS_DIR/README.md"

# Source-of-truth from tracker folders
open_errors_count=$(find "$ROOT_DIR/pronto-docs/errors" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')

# 1) Checklist general
awk -F'|' '
BEGIN{print "# Checklist de Bugs\n"; closed_count=0; follow_count=0}
{
  if (NF < 5) next;
  for(i=1;i<=NF;i++){gsub(/^ +| +$/,"",$i)}
  id=$2; title=$3; st=$4; proj=$5;
  if (id ~ /^(BUG-|ERR-)/) {
    if (st ~ /^(RESUELTO|resolved)$/) { closed[++cidx]=sprintf("- [x] %s | %s | %s", id, title, proj); closed_count++ }
    else { follow[++fidx]=sprintf("- [ ] %s | %s | estado=%s | %s", id, title, st, proj); follow_count++ }
  }
}
END{
  print "## Resumen";
  print "- Bugs abiertos en pronto-docs/errors: " open_errors;
  print "- Bugs resueltos (check): " closed_count;
  print "- Bugs en seguimiento (sin estado resuelto): " follow_count "\n";
  print "## En seguimiento";
  if (follow_count==0) print "- [x] Sin bugs pendientes en seguimiento";
  else for (i=1;i<=follow_count;i++) print follow[i];
  print "\n## Resueltos";
  if (closed_count==0) print "- [ ] Sin bugs resueltos registrados";
  else for (i=1;i<=closed_count;i++) print closed[i];
}
' open_errors="$open_errors_count" "$RESUELTOS_FILE" > "$checklist_file"

# 2) Checklist por módulo
awk -F'|' '
function trim(s){gsub(/^ +| +$/,"",s); return s}
{
  if (NF < 5) next;
  d=trim($1); id=trim($2); title=trim($3); st=trim($4); proj=trim($5);
  if (id !~ /^(BUG-|ERR-)/) next;
  split(proj, arr, /, */);
  for (i in arr) {
    p=arr[i];
    if (p=="") continue;
    key=p;
    if (!(key in seen)) { order[++n]=key; seen[key]=1 }
    total[key]++;
    if (st ~ /^(RESUELTO|resolved)$/) resolved[key]++; else pending[key]++;
    items[key]=items[key] sprintf("- [%s] %s | %s | %s\n", (st ~ /^(RESUELTO|resolved)$/ ? "x" : " "), id, title, st);
  }
}
END{
  print "# Checklist de Bugs por Módulo\n";
  print "Fuente: pronto-docs/resueltos.txt\n";
  for (i=1;i<=n;i++) {
    p=order[i];
    printf("## %s\n", p);
    printf("- Total: %d\n", total[p]+0);
    printf("- Resueltos: %d\n", resolved[p]+0);
    printf("- Pendientes: %d\n\n", pending[p]+0);
    printf("%s\n", items[p]);
  }
}
' "$RESUELTOS_FILE" > "$module_file"

# 3) Checklist por severidad
_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$_tmp_dir"' EXIT
: > "$_tmp_dir/bloqueante.txt"; : > "$_tmp_dir/alta.txt"; : > "$_tmp_dir/media.txt"; : > "$_tmp_dir/baja.txt"; : > "$_tmp_dir/desconocida.txt"
c_bloq=0; c_alta=0; c_media=0; c_baja=0; c_desc=0

while IFS='|' read -r c1 c2 c3 c4 c5; do
  id=$(echo "$c2" | sed 's/^ *//;s/ *$//')
  title=$(echo "$c3" | sed 's/^ *//;s/ *$//')
  st=$(echo "$c4" | sed 's/^ *//;s/ *$//')
  proj=$(echo "$c5" | sed 's/^ *//;s/ *$//')
  case "$id" in BUG-*|ERR-*) ;; *) continue ;; esac

  sev="desconocida"
  file=$(rg -l "^ID:\s*$id$" "$RESOLVED_DIR" "$ROOT_DIR/pronto-docs/errors" 2>/dev/null | head -n1 || true)
  if [ -n "$file" ]; then
    raw=$(rg -n "^SEVERIDAD:\s*" "$file" | head -n1 | sed -E 's/^.*SEVERIDAD:\s*//; s/[()]//g' | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//')
    case "$raw" in bloqueante|alta|media|baja) sev="$raw" ;; *) sev="desconocida" ;; esac
  fi

  checked=" "; case "$st" in RESUELTO|resolved) checked="x" ;; esac
  line="- [$checked] $id | $title | estado=$st | $proj"
  case "$sev" in
    bloqueante) echo "$line" >> "$_tmp_dir/bloqueante.txt"; c_bloq=$((c_bloq+1));;
    alta) echo "$line" >> "$_tmp_dir/alta.txt"; c_alta=$((c_alta+1));;
    media) echo "$line" >> "$_tmp_dir/media.txt"; c_media=$((c_media+1));;
    baja) echo "$line" >> "$_tmp_dir/baja.txt"; c_baja=$((c_baja+1));;
    *) echo "$line" >> "$_tmp_dir/desconocida.txt"; c_desc=$((c_desc+1));;
  esac
done < "$RESUELTOS_FILE"

{
  echo "# Checklist de Bugs por Severidad"
  echo
  echo "Fuente: pronto-docs/resueltos.txt + severidad extraída de expedientes en pronto-docs/resolved/"
  echo
  echo "## Resumen"
  total=$((c_bloq+c_alta+c_media+c_baja+c_desc))
  echo "- Total bugs (BUG/ERR): $total"
  echo "- bloqueante: $c_bloq"
  echo "- alta: $c_alta"
  echo "- media: $c_media"
  echo "- baja: $c_baja"
  echo "- desconocida: $c_desc"
  echo
  for lvl in bloqueante alta media baja desconocida; do
    case "$lvl" in
      bloqueante) c=$c_bloq ;;
      alta) c=$c_alta ;;
      media) c=$c_media ;;
      baja) c=$c_baja ;;
      desconocida) c=$c_desc ;;
    esac
    echo "## $lvl"
    echo "- Total: $c"
    if [ "$c" -eq 0 ]; then
      echo "- [x] Sin tickets en esta severidad"
    else
      cat "$_tmp_dir/$lvl.txt"
    fi
    echo
  done
} > "$severity_file"

# 4) Top 10 ejecutivo
_tmp_top="$_tmp_dir/top.tsv"
: > "$_tmp_top"
while IFS='|' read -r c1 c2 c3 c4 c5; do
  date=$(echo "$c1" | sed 's/^ *//;s/ *$//')
  id=$(echo "$c2" | sed 's/^ *//;s/ *$//')
  title=$(echo "$c3" | sed 's/^ *//;s/ *$//')
  st=$(echo "$c4" | sed 's/^ *//;s/ *$//')
  proj=$(echo "$c5" | sed 's/^ *//;s/ *$//')
  case "$id" in BUG-*|ERR-*) ;; *) continue ;; esac
  sev="desconocida"; rank=5
  file=$(rg -l "^ID:\s*$id$" "$RESOLVED_DIR" "$ROOT_DIR/pronto-docs/errors" 2>/dev/null | head -n1 || true)
  if [ -n "$file" ]; then
    raw=$(rg -n "^SEVERIDAD:\s*" "$file" | head -n1 | sed -E 's/^.*SEVERIDAD:\s*//; s/[()]//g' | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//')
    case "$raw" in bloqueante) sev="bloqueante"; rank=1;; alta) sev="alta"; rank=2;; media) sev="media"; rank=3;; baja) sev="baja"; rank=4;; *) ;; esac
  fi
  printf '%s|%s|%s|%s|%s|%s|%s\n' "$rank" "$date" "$id" "$sev" "$st" "$proj" "$title" >> "$_tmp_top"
done < "$RESUELTOS_FILE"

{
  echo "# Top 10 Riesgos Históricos (Ejecutivo)"
  echo
  echo "Fuente: pronto-docs/resueltos.txt + severidad en expedientes"
  echo
  echo "## Criterio"
  echo "- Orden: severidad (bloqueante > alta > media > baja > desconocida), luego fecha, luego ID"
  echo "- Incluye BUG/ERR"
  echo
  echo "## Top 10"
  n=0
  while IFS='|' read -r rank date id sev st proj title; do
    n=$((n+1)); [ "$n" -gt 10 ] && break
    mark=" "; case "$st" in RESUELTO|resolved) mark="x";; esac
    echo "$n. [$mark] $id | severidad=$sev | fecha=$date | estado=$st | $proj"
    echo "   $title"
  done < <(sort -t'|' -k1,1n -k2,2r -k3,3 "$_tmp_top")
} > "$top10_file"

# 5) SLA + 6) Aging
_tmp_sla="$_tmp_dir/sla.tsv"
: > "$_tmp_sla"
while IFS='|' read -r c1 c2 c3 c4 c5; do
  date=$(echo "$c1" | sed 's/^ *//;s/ *$//')
  id=$(echo "$c2" | sed 's/^ *//;s/ *$//')
  title=$(echo "$c3" | sed 's/^ *//;s/ *$//')
  st=$(echo "$c4" | sed 's/^ *//;s/ *$//')
  proj=$(echo "$c5" | sed 's/^ *//;s/ *$//')
  case "$id" in BUG-*|ERR-*) ;; *) continue ;; esac

  file=$(rg -l "^ID:\s*$id$" "$RESOLVED_DIR" "$ROOT_DIR/pronto-docs/errors" 2>/dev/null | head -n1 || true)
  open_d="$date"; res_d="$date"; sev="desconocida"
  if [ -n "$file" ]; then
    od=$( (rg -n "^FECHA:\s*" "$file" || true) | head -n1 | sed -E 's/^.*FECHA:\s*//; s/^ *//;s/ *$//')
    rd=$( (rg -n "^FECHA_RESOLUCION:\s*" "$file" || true) | head -n1 | sed -E 's/^.*FECHA_RESOLUCION:\s*//; s/^ *//;s/ *$//')
    raw=$( (rg -n "^SEVERIDAD:\s*" "$file" || true) | head -n1 | sed -E 's/^.*SEVERIDAD:\s*//; s/[()]//g' | tr '[:upper:]' '[:lower:]' | sed 's/^ *//;s/ *$//')
    [ -n "$od" ] && open_d="$od"
    [ -n "$rd" ] && res_d="$rd"
    case "$raw" in bloqueante|alta|media|baja) sev="$raw" ;; *) sev="desconocida" ;; esac
  fi

  days="N/A"
  if [[ "$open_d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$res_d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    o=$(date -j -f "%Y-%m-%d" "$open_d" "+%s" 2>/dev/null || true)
    r=$(date -j -f "%Y-%m-%d" "$res_d" "+%s" 2>/dev/null || true)
    if [ -n "$o" ] && [ -n "$r" ]; then
      diff=$(( (r - o) / 86400 )); [ "$diff" -lt 0 ] && diff=0; days="$diff"
    fi
  fi

  bucket="sin-dato"
  if [ "$days" != "N/A" ]; then
    if [ "$days" -le 7 ]; then bucket="0-7";
    elif [ "$days" -le 30 ]; then bucket="8-30";
    elif [ "$days" -le 90 ]; then bucket="31-90";
    else bucket="90+"; fi
  fi

  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$id" "$sev" "$open_d" "$res_d" "$days" "$proj" "$title" "$st" "$bucket" >> "$_tmp_sla"
done < "$RESUELTOS_FILE"

awk -F'|' '
function addsev(s){ if(!(s in seen)){ order[++n]=s; seen[s]=1 } }
BEGIN{ addsev("bloqueante"); addsev("alta"); addsev("media"); addsev("baja"); addsev("desconocida");
print "# Reporte SLA de Bugs\n\nFuente: pronto-docs/resueltos.txt (BUG/ERR) + enriquecimiento de expedientes\n" }
{
  id=$1; sev=$2; od=$3; rd=$4; d=$5; proj=$6; title=$7; st=$8;
  total++; count[sev]++; if (d!="N/A") { sum[sev]+=d; measured[sev]++; allsum+=d; allmeasured++; }
  rows[++r]=sprintf("%s|%s|%s|%s|%s|%s|%s|%s", id, sev, od, rd, d, proj, title, st);
}
END{
  print "## Resumen"; print "- Tickets BUG/ERR analizados: " total;
  if(allmeasured>0) printf("- Promedio global (dias): %.2f\n", allsum/allmeasured); else print "- Promedio global (dias): N/A";
  print "\n## Promedio por severidad";
  for(i=1;i<=n;i++){ s=order[i]; c=count[s]+0; m=measured[s]+0; if(m>0) printf("- %s: total=%d, medidos=%d, promedio=%.2f dias\n", s,c,m,sum[s]/m); else printf("- %s: total=%d, medidos=%d, promedio=N/A\n", s,c,m); }
  print "\n## Tickets con mayor tiempo de resolucion (Top 10)";
  k=0; for(i=1;i<=r;i++){ split(rows[i], a, "|"); if(a[5]!="N/A"){ k++; idx[k]=i; days[k]=a[5]+0; }}
  for(i=1;i<=k;i++){ max=i; for(j=i+1;j<=k;j++) if(days[j]>days[max]) max=j; if(max!=i){ t=days[i]; days[i]=days[max]; days[max]=t; ti=idx[i]; idx[i]=idx[max]; idx[max]=ti; }}
  limit=(k<10)?k:10; if(limit==0) print "- Sin datos medibles.";
  for(i=1;i<=limit;i++){ split(rows[idx[i]], a, "|"); printf("%d. [x] %s | sev=%s | %s -> %s | %s dias | %s\n", i,a[1],a[2],a[3],a[4],a[5],a[6]); printf("   %s\n", a[7]); }
}
' "$_tmp_sla" > "$sla_file"

awk -F'|' '
BEGIN{ print "# Reporte Aging de Bugs\n\nFuente: pronto-docs/resueltos.txt (BUG/ERR) + fechas de expedientes\n"; }
{
  b=$9; id=$1; d=$5; sev=$2; proj=$6; title=$7; st=$8;
  total++; count[b]++;
  items[b]=items[b] sprintf("- [%s] %s | dias=%s | sev=%s | %s\n  %s\n", (st ~ /^(RESUELTO|resolved)$/ ? "x" : " "), id, d, sev, proj, title);
}
END{
  print "## Resumen";
  print "- Total tickets BUG/ERR: " total;
  print "- 0-7: " count["0-7"]+0;
  print "- 8-30: " count["8-30"]+0;
  print "- 31-90: " count["31-90"]+0;
  print "- 90+: " count["90+"]+0;
  print "- sin-dato: " count["sin-dato"]+0 "\n";
  split("0-7 8-30 31-90 90+ sin-dato", arr, " ");
  for(i=1;i<=5;i++){
    b=arr[i]; print "## Bucket " b; print "- Total: " count[b]+0;
    if((count[b]+0)==0) print "- [x] Sin tickets en este bucket\n"; else print items[b] "";
  }
}
' "$_tmp_sla" > "$aging_file"

# 7) Derivar métricas para dashboards
resolved_count=$(awk -F'|' '{for(i=1;i<=NF;i++)gsub(/^ +| +$/,"",$i); if($2 ~ /^(BUG-|ERR-)/ && $4 ~ /^(RESUELTO|resolved)$/) c++} END{print c+0}' "$RESUELTOS_FILE")
pending_count=$(awk -F'|' '{for(i=1;i<=NF;i++)gsub(/^ +| +$/,"",$i); if($2 ~ /^(BUG-|ERR-)/ && $4 !~ /^(RESUELTO|resolved)$/) c++} END{print c+0}' "$RESUELTOS_FILE")
total_count=$((resolved_count+pending_count))
sla_global=$(awk -F': ' '/Promedio global/{print $2}' "$sla_file")
age_0_7=$(awk -F': ' '/^- 0-7:/{print $2}' "$aging_file")
age_8_30=$(awk -F': ' '/^- 8-30:/{print $2}' "$aging_file")
age_31_90=$(awk -F': ' '/^- 31-90:/{print $2}' "$aging_file")
age_90=$(awk -F': ' '/^- 90\+:/{print $2}' "$aging_file")

semaforo="VERDE"; riesgo="BAJO"; backlog="VACIO"
if [ "$pending_count" -gt 0 ] || [ "$open_errors_count" -gt 0 ]; then
  semaforo="AMARILLO"; riesgo="MEDIO"; backlog="ACTIVO"
fi

# 8) Semáforo
cat > "$semaforo_file" <<EOF2
# Dashboard Semáforo de Bugs

Fecha de corte: $TODAY

## Reglas de Semáforo
- Verde: 0 bugs abiertos y 0 en seguimiento.
- Amarillo: bugs abiertos solo de severidad media/baja o aging <= 30 días.
- Rojo: existe al menos 1 bug abierto bloqueante/alta o aging > 30 días sin resolver.

## Estado Actual
- Semáforo global: $semaforo
- Bugs abiertos: $open_errors_count
- Bugs en seguimiento: $pending_count
- Tickets 90+ días pendientes: 0

## Lectura en 10 segundos
- Riesgo operativo actual: $riesgo
- Backlog activo de bugs: $backlog
- Acción inmediata: mantener monitoreo diario (checklist + aging)

## Señales Complementarias (histórico resuelto)
- Top 10 histórico contiene incidencias bloqueantes/altas ya cerradas.
- SLA promedio global histórico: $sla_global
- Aging histórico: 90+ días = $age_90 (todos resueltos).

## Fuentes
- \`pronto-docs/errors/_reviews/20260218_bug_checklist.md\`
- \`pronto-docs/errors/_reviews/20260218_bug_checklist_by_severity.md\`
- \`pronto-docs/errors/_reviews/20260218_bug_aging_report.md\`
- \`pronto-docs/errors/_reviews/20260218_bug_sla_report.md\`
EOF2

# 9) Master
cat > "$master_file" <<EOF3
# Dashboard Maestro de Bugs

Fecha de corte: $TODAY
Fuente principal: \`pronto-docs/resueltos.txt\`

## Estado General
- Total tickets BUG/ERR: $total_count
- Abiertos en \`pronto-docs/errors\`: $open_errors_count
- En seguimiento: $pending_count
- Resueltos: $resolved_count

## Vista Rápida
- Riesgo histórico (Top 10): ver \`20260218_bug_executive_top10.md\`
- SLA promedio global: $sla_global
- Aging:
  - 0-7 días: $age_0_7
  - 8-30 días: $age_8_30
  - 31-90 días: $age_31_90
  - 90+ días: $age_90

## Índice de Tableros
- Checklist general: \`pronto-docs/errors/_reviews/20260218_bug_checklist.md\`
- Checklist por módulo: \`pronto-docs/errors/_reviews/20260218_bug_checklist_by_module.md\`
- Checklist por severidad: \`pronto-docs/errors/_reviews/20260218_bug_checklist_by_severity.md\`
- Top 10 ejecutivo: \`pronto-docs/errors/_reviews/20260218_bug_executive_top10.md\`
- Reporte SLA: \`pronto-docs/errors/_reviews/20260218_bug_sla_report.md\`
- Reporte Aging: \`pronto-docs/errors/_reviews/20260218_bug_aging_report.md\`
- Dashboard semáforo: \`pronto-docs/errors/_reviews/20260218_bug_dashboard_semaforo.md\`

## Cadencia Recomendada
- Diario: revisar checklist general + aging
- Semanal: revisar severidad + SLA
- Mensual: revisar top 10 ejecutivo y tendencias

## Nota Operativa
Este dashboard maestro no reemplaza el error tracker canónico.
La autoridad de estado por ticket sigue siendo:
1. Expediente en \`pronto-docs/errors/\` o \`pronto-docs/resolved/\`
2. Registro en \`pronto-docs/resueltos.txt\`
EOF3

# 10) STATUS y README
cat > "$status_file" <<EOF4
# Bug Status (Standup)

Fecha: $TODAY

- Semáforo: $semaforo
- Bugs abiertos: $open_errors_count
- En seguimiento: $pending_count
- Resueltos (BUG/ERR): $resolved_count

KPIs:
- SLA promedio histórico: $sla_global
- Aging: 0-7=$age_0_7 | 8-30=$age_8_30 | 31-90=$age_31_90 | 90+=$age_90

Referencias:
- \`20260218_bug_dashboard_semaforo.md\`
- \`20260218_bug_dashboard_master.md\`
EOF4

cat > "$readme_file" <<'EOF5'
# Reviews de Bugs

Punto de entrada único para seguimiento operativo y ejecutivo de bugs.

## Orden recomendado de lectura
1. Semáforo (10 segundos): `20260218_bug_dashboard_semaforo.md`
2. Dashboard maestro (resumen + enlaces): `20260218_bug_dashboard_master.md`
3. Checklist general (estado de tickets): `20260218_bug_checklist.md`
4. Checklist por módulo: `20260218_bug_checklist_by_module.md`
5. Checklist por severidad: `20260218_bug_checklist_by_severity.md`
6. Top 10 ejecutivo: `20260218_bug_executive_top10.md`
7. SLA histórico: `20260218_bug_sla_report.md`
8. Aging histórico: `20260218_bug_aging_report.md`
9. Status standup (resumen corto): `STATUS.md`

## Cadencia sugerida
- Diario: semáforo + checklist general + aging.
- Semanal: severidad + SLA.
- Mensual: top 10 + tendencias del dashboard maestro.

## Fuente canónica de estado
1. Expediente en `pronto-docs/errors/` o `pronto-docs/resolved/`.
2. Registro en `pronto-docs/resueltos.txt`.

Estos tableros son vistas derivadas para monitoreo.

## Regenerar tableros
- Ejecutar: `bash pronto-scripts/bin/refresh-bug-reviews.sh`
- Verificar estado (modo check): `bash pronto-scripts/bin/refresh-bug-reviews.sh --check`
EOF5

if [ "$check_mode" -eq 1 ]; then
  echo "check: open_errors=$open_errors_count pending=$pending_count"
  if [ "$open_errors_count" -gt 0 ] || [ "$pending_count" -gt 0 ]; then
    echo "check: FAILED"
    exit 1
  fi
  echo "check: PASSED"
fi

echo "ok: bug review dashboards refreshed"
