#!/usr/bin/env bash
# verify.sh v2 : Vérificateur indépendant Scale Aigency
# Règle d'or : aucun agent ne note son propre travail. Ce script note.
# Sortie : exit 0 = PASS (commit autorisé) / exit 1 = FAIL (tâche reste OPEN)
# Portable macOS + Linux (pas de grep -P)

set -uo pipefail

# --- Config (surchargables via .env ou variables d'environnement) ---
MAX_DIFF_LINES="${MAX_DIFF_LINES:-800}"
STATE_MAX_AGE_MIN="${STATE_MAX_AGE_MIN:-720}"   # 12h

FAILS=0
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
REPORT="$LOG_DIR/verify-$(date +%Y%m%d-%H%M%S).log"

fail() { echo "FAIL: $1" | tee -a "$REPORT"; FAILS=$((FAILS+1)); }
pass() { echo "PASS: $1" >> "$REPORT"; }
warn() { echo "WARN: $1" | tee -a "$REPORT"; }

echo "=== VERIFY Scale Aigency : $(date) ===" | tee "$REPORT"

DIFF_CACHED=$(git diff --cached 2>/dev/null || true)
ADDED_LINES=$(printf '%s\n' "$DIFF_CACHED" | grep -E '^\+' | grep -vE '^\+\+\+' || true)

# ------------------------------------------------------------
# 1. Fichiers protégés intacts (L3)
# ------------------------------------------------------------
for f in CLAUDE.md scripts/verify.sh .gitignore; do
  if git diff --name-only HEAD 2>/dev/null | grep -qx "$f"; then
    fail "fichier protégé modifié → $f (L3)"
  else
    pass "fichier protégé intact → $f"
  fi
done

# ------------------------------------------------------------
# 2. Fichiers interdits dans le staging (L4)
# ------------------------------------------------------------
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
for pattern in '^\.env' '\.pem$' '\.key$' 'current-state\.md$'; do
  if printf '%s\n' "$STAGED_FILES" | grep -qE "$pattern"; then
    fail "fichier interdit stagé → pattern $pattern (L4/L5)"
  fi
done
[ "$FAILS" -eq 0 ] && pass "aucun fichier interdit stagé"

# ------------------------------------------------------------
# 3. Données clients (L4) — emails réels + téléphones Martinique
# ------------------------------------------------------------
if [ -n "$ADDED_LINES" ]; then
  EMAILS=$(printf '%s\n' "$ADDED_LINES" \
    | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' \
    | grep -viE '@(example|test|exemple|fictif|localhost)\.' || true)
  if [ -n "$EMAILS" ]; then
    fail "email potentiellement réel détecté (L4) : $(echo "$EMAILS" | head -3 | tr '\n' ' ')"
  else
    pass "aucun email réel dans le diff"
  fi

  if printf '%s\n' "$ADDED_LINES" | grep -E '(0596|0696|\+596)[0-9 .-]{8,}' | grep -vE '00 00 00' >/dev/null; then
    fail "numéro de téléphone Martinique détecté (L4)"
  else
    pass "aucun numéro client dans le diff"
  fi
fi

# ------------------------------------------------------------
# 4. Secrets / clés API (L4) — patterns étendus au stack réel
# ------------------------------------------------------------
SECRET_PATTERNS=(
  'sk-[a-zA-Z0-9]{20,}'                      # OpenAI/Anthropic style
  'sk_live_[a-zA-Z0-9]{20,}'                 # Stripe LIVE
  'sk_test_[a-zA-Z0-9]{20,}'                 # Stripe test
  'whsec_[a-zA-Z0-9]{20,}'                   # Stripe webhook
  'eyJhbGciOi[a-zA-Z0-9._-]{20,}'            # JWT (Supabase service keys)
  'AKIA[0-9A-Z]{16}'                         # AWS
  'Bearer [a-zA-Z0-9._-]{20,}'
  'API_KEY[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']{10,}'
)
SECRET_HIT=0
for p in "${SECRET_PATTERNS[@]}"; do
  if printf '%s\n' "$ADDED_LINES" | grep -qE "$p"; then
    fail "secret en clair détecté → pattern: $p (L4)"
    SECRET_HIT=1
  fi
done
[ "$SECRET_HIT" -eq 0 ] && pass "aucun secret en clair"

# ------------------------------------------------------------
# 5. Build / lint / tests (si présents)
# ------------------------------------------------------------
if [ -f package.json ]; then
  if grep -q '"lint"' package.json; then
    npm run lint --silent >>"$REPORT" 2>&1 && pass "lint" || fail "npm run lint"
  fi
  if grep -q '"build"' package.json; then
    npm run build --silent >>"$REPORT" 2>&1 && pass "build" || fail "npm run build"
  fi
  if grep -q '"test"' package.json; then
    npm test --silent >>"$REPORT" 2>&1 && pass "tests" || fail "npm test"
  fi
else
  warn "pas de package.json : bloc build/lint/tests ignoré"
fi

# ------------------------------------------------------------
# 6. État du projet à jour (L5)
# ------------------------------------------------------------
if [ -f current-state.md ]; then
  if [ -n "$(find current-state.md -mmin +"$STATE_MAX_AGE_MIN" 2>/dev/null)" ]; then
    fail "current-state.md non mis à jour depuis +$((STATE_MAX_AGE_MIN/60))h (L5)"
  else
    pass "current-state.md récent"
  fi
else
  fail "current-state.md absent (L5)"
fi

grep -qx "current-state.md" .gitignore 2>/dev/null \
  && pass ".gitignore contient current-state.md" \
  || fail ".gitignore ne contient pas current-state.md (L5)"

# ------------------------------------------------------------
# 7. Taille du diff (garde-fou sur-ingénierie, L9)
# ------------------------------------------------------------
LINES=$(printf '%s\n' "$ADDED_LINES" | grep -c . || echo 0)
if [ "${LINES:-0}" -gt "$MAX_DIFF_LINES" ]; then
  fail "diff de $LINES lignes > $MAX_DIFF_LINES : découper la tâche (L9)"
else
  pass "taille du diff raisonnable ($LINES lignes ajoutées)"
fi

# ------------------------------------------------------------
# 8. Rotation des logs (garde 30 derniers rapports)
# ------------------------------------------------------------
ls -1t "$LOG_DIR"/verify-*.log 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true

# ------------------------------------------------------------
# Verdict (lisible humain + machine pour Build 3)
# ------------------------------------------------------------
echo "---" | tee -a "$REPORT"
if [ "$FAILS" -eq 0 ]; then
  echo "VERDICT: PASS → commit autorisé" | tee -a "$REPORT"
  echo "{\"verdict\":\"PASS\",\"fails\":0,\"report\":\"$REPORT\"}" > "$LOG_DIR/last-verdict.json"
  exit 0
else
  echo "VERDICT: FAIL ($FAILS erreurs) → tâche reste OPEN. Rapport : $REPORT" | tee -a "$REPORT"
  echo "{\"verdict\":\"FAIL\",\"fails\":$FAILS,\"report\":\"$REPORT\"}" > "$LOG_DIR/last-verdict.json"
  exit 1
fi
