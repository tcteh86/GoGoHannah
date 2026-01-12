#!/usr/bin/env python3

import sys
sys.path.append('app')

from llm.client import generate_vocab_exercise

try:
    result = generate_vocab_exercise("happy")
    print("Success:", result)
except Exception as e:
    print("Error:", str(e))