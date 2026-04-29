#!/bin/bash
# german-vocab-daily.sh — adds 5 new B1 vocab words and pushes to GitHub
# Run via cron: openclaw cron add --name "German B1 Vocab" --schedule "cron 0 8 * * *" --workingDir /home/muhtar/german-b1-vocab --maxDuration 90 -- cd /home/muhtar/german-b1-vocab && bash scripts/daily-vocab.sh

REPO="/home/muhtar/german-b1-vocab"
TODAY=$(date +%Y-%m-%d)

cd "$REPO" || exit 1

# --- Generate 5 new vocab words via ollama ---
# Prompt for 5 German B1 vocabulary words with German sentence + English translation
PROMPT="Generate exactly 5 German B1-level vocabulary words appropriate for the TELC B1 exam.
For each word provide:
- the German word/phrase
- English translation
- a German example sentence
- English translation of the example

Format each entry as a JSON object with keys: word, translation, sentence, sentence_en
Return ONLY a valid JSON array with exactly 5 objects, nothing else. No markdown code blocks."

VOCAB_JSON=$(cd "$REPO" && ollama run llama3.2 2>/dev/null --prompt "$PROMPT" | tr -d '\r' | sed -n '/\[/{p:r /\]/!{H;d};x;s/\n//g;p;d};:']' ) || true

# Fallback vocab if LLM fails
if [ -z "$VOCAB_JSON" ] || ! echo "$VOCAB_JSON" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  echo "[vocab script] LLM response invalid, using fallback words" >&2
  VOCAB_JSON='[{"word":"bekämpfen","translation":"to fight, to combat","sentence":"Wir müssen die Korruption bekämpfen.","sentence_en":"We must fight corruption."},{"word":"der积雪","translation":"the积雪","sentence":"Der Schnee bedeckt die Straßen.","sentence_en":"Snow covers the streets."}]'
fi

# --- Check if today's section already exists ---
if grep -q "id=\"$TODAY\"" index.html; then
  echo "[vocab script] $TODAY section already exists, skipping HTML update"
else
  echo "[vocab script] Adding section for $TODAY"

  # Extract words from JSON using python3
  python3 << PYEOF
import json, sys

raw = """$VOCAB_JSON"""
# Clean any markdown code blocks
raw = raw.strip()
if raw.startswith('```'):
    lines = raw.split('\n')
    raw = '\n'.join(lines[1:-1] if lines[-1] == '```' else lines[1:])

try:
    words = json.loads(raw)
except:
    print("ERROR: failed to parse JSON", file=sys.stderr)
    sys.exit(1)

html = f"""
    <!-- {TODAY} -->
    <div id="{TODAY}" class="date-section">
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

# Insert before <footer> in index.html
with open("index.html", "r") as f:
    content = f.read()

content = content.replace("    <footer>", html + "    <footer>")

# Update dates array and currentIndex
content = content.replace(
    "const dates = [",
    f"const dates = ["
)
# Add new date to array (before the closing ]
import re
content = re.sub(
    r"(const dates = \[[\s\S]*?)\]\;",
    lambda m: m.group(1) + f"'{TODAY}', ",
    content
)

# Remove duplicate dates if any
content = re.sub(
    r"(const dates = \[[\s\S]*?)'{TODAY}',\s*'{TODAY}'",
    r"\1'{TODAY}'",
    content
)

with open("index.html", "w") as f:
    f.write(content)

print(f"[vocab script] Added 5 words for $TODAY to index.html")
PYEOF
fi

# --- Also update practice/index.html if word not already present ---
python3 << 'PYEOF2'
import json, re, sys

raw = """$VOCAB_JSON"""
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

# Extract existing words to avoid duplicates
existing_words = set(re.findall(r'\bword:\s*"([^"]+)"', content))

added = 0
for w in words:
    if w['word'] not in existing_words:
        new_entry = f"""      {{ word: "{w['word']}", translation: "{w['translation']}", example: "{w['sentence']}" }},\n"""
        # Insert before the last " ];" in vocabulary array
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
