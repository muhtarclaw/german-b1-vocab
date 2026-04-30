#!/usr/bin/env python3
"""Fetch German B1 vocab from Ollama API and output JSON."""
import urllib.request, json, re, sys

MODEL = "gemma4:e2b"
PROMPT = """Generate exactly 5 German B1-level vocabulary words appropriate for the TELC B1 exam.
For each word provide:
- the German word/phrase
- English translation
- a German example sentence
- English translation of the example

Format each entry as a JSON object with keys: word, translation, sentence, sentence_en
Return ONLY a valid JSON array with exactly 5 objects, nothing else. No markdown code blocks."""

req = urllib.request.Request(
    "http://localhost:11434/api/generate",
    data=json.dumps({"model": MODEL, "prompt": PROMPT, "stream": False}).encode(),
    headers={"Content-Type": "application/json"}
)

try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.load(resp)
        text = data.get("response", "").strip()
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
