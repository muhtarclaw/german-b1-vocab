#!/bin/bash
# german-vocab-daily.sh — adds 5 new B1 vocab words and pushes to GitHub

REPO="/home/muhtar/german-b1-vocab"
TODAY=$(date +%Y-%m-%d)

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
  VOCAB_JSON='[{"word":"bekämpfen","translation":"to fight, to combat","sentence":"Wir müssen die Korruption bekämpfen.","sentence_en":"We must fight corruption."},{"word":"die Umwelt","translation":"the environment","sentence":"Wir müssen die Umwelt schützen.","sentence_en":"We must protect the environment."},{"word":"erklären","translation":"to explain","sentence":"Können Sie das bitte erklären?","sentence_en":"Can you please explain that?"},{"word":"die Meinung","translation":"the opinion","sentence":"Ich habe eine andere Meinung.","sentence_en":"I have a different opinion."},{"word":"sowohl als auch","translation":"both ... and ...","sentence":"Er spricht sowohl Englisch als auch Deutsch.","sentence_en":"He speaks both English and German."}]'
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
html = f"""
    <!-- {today} -->
    <div id="{today}" class="date-section">
"""

for i, w in enumerate(words, 1):
    html += f"""      <div class="word-card">
        <div class="german"><span class="number">{i}.</span> {w['word']}</div>
        <div class="english">= {w['translation']}</div>
        <div class="sentence">{w['sentence']}</div>
        <div class="sentence-en">{w['sentence_en']}</div>
      </div>
"""

html += "    </div>\n"

with open("index.html", "r") as f:
    content = f.read()

content = content.replace("    <footer>", html + "    <footer>")

# Add new date to array
content = re.sub(
    r"(const dates = \[[\s\S]*?)\]\;",
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

print(f"[vocab script] Added {len(words)} words for {today} to index.html")
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
