"""
💡 Quick Trick: Auto-Generate Docs with pdoc

Step 1: Install pdoc
    pip install pdoc

Step 2: Run live docs (auto opens in browser)
    pdoc myfile.py

Step 3: Export static docs (for sharing/hosting)
    pdoc --output-dir docs myfile.py
    👉 then open docs/index.html in browser

Notes:
- If you add docstrings → detailed docs
- If no docstrings → only function/class names"""


def add(a: int, b: int) -> int:
    """Adds two numbers and returns the result"""
    return a + b


def multiply(a: int, b: int) -> int:
    """Multiplies two numbers and returns the result"""
    return a * b


if __name__ == "__main__":
    print("✅ This is just a demo file.")
    print("Run:  pdoc pdoc_trick.py   (for live docs)")
    print("Or:   pdoc --output-dir docs pdoc_trick.py   (for static docs)")
