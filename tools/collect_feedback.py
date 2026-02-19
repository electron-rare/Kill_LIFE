import datetime
import os

def collect_feedback(target):
    log_file = f"docs/evidence/{target}/feedback.log"
    feedback = input(f"Feedback pour {target} (bug, usage, suggestion) : ")
    with open(log_file, "a") as f:
        f.write(f"[{datetime.datetime.now()}] {feedback}\n")
    print(f"Feedback enregistré dans {log_file}")

if __name__ == '__main__':
    import sys
    collect_feedback(sys.argv[1])
