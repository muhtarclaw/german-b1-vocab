#!/usr/bin/env python3
"""Replace duplicate words with completely new unique words."""
import re

with open('index.html', 'r') as f:
    content = f.read()

# Map duplicate words to new unique alternatives
replacements = {
    'bekämpfen': 'verhindern',
    'die Rechnung': 'die Abrechnung',
    'das Ziel': 'der Zweck',
    'die Umwelt': 'die Natur',
    'die Meinung': 'die Perspektive',
    'erklären': 'veranschaulichen',
    'sowohl als auch': 'einerseits andererseits',
}

# Count duplicates
words = re.findall(r'<div class="german"><span class="number">.*?</span>([^<]+)</div>', content)
from collections import Counter
c = Counter([w.strip() for w in words])

print("Before replacement:")
for w, n in sorted(c.items()):
    if n > 1:
        print(f"  '{w}': {n} times")

# Replace each duplicate word with a unique alternative
for orig, new in replacements.items():
    pattern = r'<div class="german"><span class="number">(.*?)\.</span> ' + re.escape(orig) + r'</div>'
    
    # Replace all occurrences with the new word
    content = re.sub(pattern, f'<div class="german"><span class="number">\\1.</span> {new}</div>', content)
    print(f"Replaced '{orig}' -> '{new}'")

# Check results
words = re.findall(r'<div class="german"><span class="number">.*?</span>([^<]+)</div>', content)
c = Counter([w.strip() for w in words])
dups = {w: n for w, n in c.items() if n > 1}

print("\nAfter replacement:")
if dups:
    print("Duplicates still exist:")
    for w, n in sorted(dups.items()):
        print(f"  '{w}': {n} times")
else:
    print("All words are now unique!")

with open('index.html', 'w') as f:
    f.write(content)