#!/usr/bin/env python3
"""Fetch German B1 vocab from Ollama cloud API and output JSON."""
import urllib.request, json, re, sys

MODEL = "minimax-m2.7:cloud"
API_KEY = "a20f10d761304ae2bbbfb4bb047945db.Lsya1_8ufV7z9BxIhSqcOHhq"
PROMPT = """Generate exactly 5 German B1-level vocabulary words appropriate for the TELC B1 exam.
For each word provide:
- the German word/phrase
- English translation
- a German example sentence
- English translation of the example

Format each entry as a JSON object with keys: word, translation, sentence, sentence_en
Return ONLY a valid JSON array with exactly 5 objects, nothing else. No markdown code blocks."""

req = urllib.request.Request(
    "https://ollama.com/v1/chat/completions",
    data=json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": PROMPT}],
        "stream": False
    }).encode(),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
)

try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.load(resp)
        text = data["choices"][0]["message"]["content"].strip()
except Exception as e:
    print(f"API error: {e}", file=sys.stderr)
    sys.exit(1)

# Strip markdown code fences
text = re.sub(r"^```(?:json)?\s*", "", text)
text = re.sub(r"\s*```\s*$", "", text)

# Find balanced JSON array via bracket counting
depth = 0
start = -1
for i, c in enumerate(text):
    if c == "[":
        if start == -1:
            start = i
        depth += 1
    elif c == "]":
        depth -= 1
        if depth == 0 and start != -1:
            candidate = text[start:i+1]
            try:
                arr = json.loads(candidate)
                print(json.dumps(arr, ensure_ascii=False))
            except Exception as e:
                print(f"JSON parse error: {e}", file=sys.stderr)
                sys.exit(1)
            break
else:
    print("No JSON array found in response", file=sys.stderr)
    sys.exit(1)
