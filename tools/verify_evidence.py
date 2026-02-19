import os
import sys

def verify_evidence(target):
    evidence_dir = f"docs/evidence/{target}"
    if os.path.exists(evidence_dir):
        files = os.listdir(evidence_dir)
        if files:
            print(f"Evidence pack trouvé pour {target} : {files}")
            return True
        else:
            print(f"Evidence pack vide pour {target}")
            return False
    else:
        print(f"Evidence pack absent pour {target}")
        return False

if __name__ == '__main__':
    verify_evidence(sys.argv[1])
