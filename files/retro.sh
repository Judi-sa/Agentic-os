#!/usr/bin/env bash
# retro.sh v1 : Boucle d'auto-amélioration Scale Aigency (L11)
# Agrège les logs de la semaine, calcule les taux d'échec,
# génère une proposition dans proposals/ pour décision humaine.
# NEVER modifie CLAUDE.md, AGENTS.md ou verify.sh. Propose, n'applique pas.

set -uo pipefail

LOG_DIR="logs"
PROP_DIR="proposals"
LESSONS="tasks/lessons.md"
DAYS="${RETRO_DAYS:-7}"
mkdir -p "$PROP_DIR" tasks

OUT="$PROP_DIR/retro-$(date +%Y%m%d).md"

# --- Collecte des rapports verify récents ---
RECENT=$(find "$LOG_DIR" -name 'verify-*.log' -mtime -"$DAYS" 2>/dev/null | sort)
TOTAL=$(printf '%s\n' "$RECENT" | grep -c . || echo 0)

if [ "$TOTAL" -eq 0 ]; then
  echo "Aucun rapport verify sur les $DAYS derniers jours. Rien à analyser."
  exit 0
fi

PASS_N=0; FAIL_N=0
for f in $RECENT; do
  if grep -q 'VERDICT: PASS' "$f"; then PASS_N=$((PASS_N+1)); else FAIL_N=$((FAIL_N+1)); fi
done
RATE=$(( TOTAL > 0 ? PASS_N * 100 / TOTAL : 0 ))

# --- Échecs récurrents (regroupés par message FAIL) ---
TOP_FAILS=$(grep -h '^FAIL:' $RECENT 2>/dev/null | sed 's/→.*//' | sort | uniq -c | sort -rn | head -5 || true)

# --- Escalades de la période ---
ESCALATIONS=$(find "$LOG_DIR" -name 'escalation-*.md' -mtime -"$DAYS" 2>/dev/null | wc -l | tr -d ' ')

# --- Blocages budget ---
BUDGET_BLOCKS=0
[ -f "$LOG_DIR/budget-blocked.md" ] && BUDGET_BLOCKS=$(grep -c "$(date +%Y-%m)" "$LOG_DIR/budget-blocked.md" 2>/dev/null || echo 0)

# --- Génération de la proposition ---
cat > "$OUT" << REPORT
# Rétro hebdo : $(date +%d/%m/%Y)

## Chiffres ($DAYS derniers jours)
- Runs verify : $TOTAL (PASS : $PASS_N / FAIL : $FAIL_N)
- Taux de réussite : $RATE%
- Escalades (L10) : $ESCALATIONS
- Blocages budget (L6) : $BUDGET_BLOCKS

## Échecs les plus fréquents
\`\`\`
${TOP_FAILS:-aucun}
\`\`\`

## Leçons de la période (extrait tasks/lessons.md)
\`\`\`
$(tail -10 "$LESSONS" 2>/dev/null || echo "lessons.md vide ou absent")
\`\`\`

## Propositions (à compléter par l'agent Retro, à valider par Judickaël)
- [ ] Proposition 1 :
- [ ] Proposition 2 :

## Décision Judickaël
- [ ] Validé, appliquer :
- [ ] Rejeté, raison :

> Rappel L11 : aucune proposition n'est appliquée sans validation écrite ci-dessus.
REPORT

# --- Alimentation automatique de lessons.md pour les échecs récurrents (3+ occurrences) ---
touch "$LESSONS"
grep -h '^FAIL:' $RECENT 2>/dev/null | sed 's/→.*//' | sort | uniq -c | sort -rn \
| while read -r count msg; do
  if [ "$count" -ge 3 ] && ! grep -qF "$msg" "$LESSONS"; then
    echo "[$(date +%Y-%m-%d)] | échec récurrent (${count}x) : ${msg#FAIL: } | à traiter en priorité dans les prochains briefs" >> "$LESSONS"
  fi
done

echo "Rétro générée : $OUT"
echo "Taux de réussite : $RATE% sur $TOTAL runs. Escalades : $ESCALATIONS."
exit 0
