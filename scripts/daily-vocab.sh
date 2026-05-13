#!/bin/bash
# german-vocab-daily.sh — adds 5 new B1 vocab words and pushes to GitHub

REPO="/home/muhtar/german-b1-vocab"
TODAY=$(date +%Y-%m-%d)

# Use local Git token from environment if available, otherwise use stored value
GIT_TOKEN="${GIT_TOKEN:-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}"

cd "$REPO" || exit 1

# --- Check if model is cached ---
MODEL="gemma4:e2b"
if ! ollama list 2>/dev/null | grep -q "^$MODEL "; then
  echo "[vocab script] Model $MODEL not cached, pulling..."
  ollama pull "$MODEL"
fi

# --- Generate 5 new vocab words via Ollama API ---
VOCAB_JSON=$(python3 "$REPO/scripts/fetch-vocab.py" 2>&1) || true

# Fallback vocab if LLM fails
if [ -z "$VOCAB_JSON" ] || ! echo "$VOCAB_JSON" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  echo "[vocab script] LLM response invalid, using fallback words" >&2
  VOCAB_JSON='[{"word":"die Versicherung","translation":"the insurance","sentence":"Ich habe eine Haftpflichtversicherung abgeschlossen.","sentence_en":"I have taken out liability insurance."},{"word":"verhandeln","translation":"to negotiate","sentence":"Wir müssen über den Preis verhandeln.","sentence_en":"We need to negotiate the price."},{"word":"die Genehmigung","translation":"the permission","sentence":"Wir brauchen eine Baugenehmigung.","sentence_en":"We need a building permit."},{"word":"der Einfluss","translation":"the influence","sentence":"Er hat großen Einfluss auf die Entscheidung.","sentence_en":"He has great influence on the decision."},{"word":"unverzichtbar","translation":"indispensable","sentence":"Diese Ausrüstung ist unverzichtbar.","sentence_en":"This equipment is indispensable."}]'
fi

echo "[vocab script] Generated vocab: $VOCAB_JSON" >&2

export VOCAB_JSON
export TODAY

# --- Check if today's section already exists ---
if grep -q "id=\"$TODAY\"" index.html; then
  echo "[vocab script] $TODAY section already exists, skipping HTML update"
else
  echo "[vocab script] Adding section for $TODAY"

  python3 << 'PYEOF'
import json, re, sys, os

raw = os.environ.get('VOCAB_JSON', '')
raw = raw.strip()
if raw.startswith('```'):
    lines = raw.split('\n')
    raw = '\n'.join(lines[1:-1] if lines[-1] == '```' else lines[1:])

try:
    words = json.loads(raw)
except:
    print("ERROR: failed to parse JSON", file=sys.stderr)
    sys.exit(1)

today = os.environ.get('TODAY', '')

# Get existing words to avoid duplicates (only for today's date section)
with open("index.html", "r") as f:
    existing_content = f.read()

# Check if today's section already has all words by looking for the date section
# Only check words within today's section if it exists partially
existing_words_today = set()
today_section_match = re.search(r'<div id="' + re.escape(today) + r'"[^>]*>(.*?)</div>\s*</div>', existing_content, re.DOTALL)
if today_section_match:
    section_content = today_section_match.group(1)
    existing_words_today = set(re.findall(r'<div class="german">\s*<span class="number">.*?</span>\s*([^<]+)', section_content))

# Filter out words that already exist in today's section
today_words = []
for w in words:
    if w['word'] in existing_words_today:
        print(f"[vocab script] Skipping duplicate (already in today's section): {w['word']}", file=sys.stderr)
    else:
        today_words.append(w)

if len(today_words) == 0:
    print("[vocab script] All words already in today's section, aborting update", file=sys.stderr)
    sys.exit(0)

html = f"""
    <!-- {today} -->
    <div id="{today}" class="date-section">
"""

for i, w in enumerate(today_words, 1):
    html += f"""      <div class="word-card">
        <div class="german"><span class="number">{i}.</span> {w['word']}</div>
        <div class="english">= {w['translation']}</div>
        <div class="sentence">{w['sentence']}</div>
        <div class="sentence-en">{w['sentence_en']}</div>
      </div>
"""

html += "    </div>\n"

content = existing_content
content = content.replace("    <footer>", html + "    <footer>")

# Add new date to array
content = re.sub(
    r"(const dates = \[[\s\S]*?)\];",
    lambda m: m.group(1) + f"'{today}', ",
    content
)

# Remove duplicate dates if any
content = re.sub(
    r"(const dates = \[[\s\S]*?)'{today}',\s*'{today}'",
    r"\1'{today}'",
    content
)

with open("index.html", "w") as f:
    f.write(content)

print(f"[vocab script] Added {len(today_words)} new words for {today} to index.html")
PYEOF
fi

# --- Also update practice/index.html ---
python3 << 'PYEOF2'
import json, re, sys, os

raw = os.environ.get('VOCAB_JSON', '')
raw = raw.strip()
if raw.startswith('```'):
    lines = raw.split('\n')
    raw = '\n'.join(lines[1:-1] if lines[-1] == '```' else lines[1:])

try:
    words = json.loads(raw)
except:
    print("ERROR: failed to parse JSON for practice", file=sys.stderr)
    sys.exit(1)

with open("practice/index.html", "r") as f:
    content = f.read()

existing_words = set(re.findall(r'\bword:\s*"([^"]+)"', content))

added = 0
for w in words:
    if w['word'] not in existing_words:
        new_entry = f"""      {{ word: "{w['word']}", translation: "{w['translation']}", example: "{w['sentence']}" }},\n"""
        content = content.rstrip()
        if content.endswith("];"):
            content = content[:-3] + new_entry + "    ];"
        added += 1

if added > 0:
    with open("practice/index.html", "w") as f:
        f.write(content)
    print(f"[vocab script] Added {added} new words to practice/index.html")
else:
    print("[vocab script] All words already in practice, skipping")
PYEOF2

# --- Commit and push ---
git add -A
if git diff --cached --quiet; then
  echo "[vocab script] No changes to commit"
else
  git commit -m "Add German B1 vocab for $TODAY" --allow-empty
  git push https://muhtarclaw:$GIT_TOKEN@github.com/muhtarclaw/german-b1-vocab.git main
  echo "[vocab script] Pushed to GitHub"
fi
