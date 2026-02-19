import subprocess

def check_all_targets(targets):
    results = {}
    for target in targets:
        print(f"\n--- Vérification {target} ---")
        try:
            subprocess.run(["python", "tools/build_firmware.py", target], check=True)
            subprocess.run(["python", "tools/test_firmware.py", target], check=True)
            subprocess.run(["python", "tools/collect_evidence.py", target], check=True)
            evidence = subprocess.run(["python", "tools/verify_evidence.py", target], capture_output=True, text=True)
            results[target] = evidence.stdout.strip()
        except subprocess.CalledProcessError as e:
            results[target] = f"Erreur: {e}"
    return results

if __name__ == '__main__':
    targets = ["esp", "stm", "linux"]
    report = check_all_targets(targets)
    print("\n=== Rapport de vérification ===")
    for tgt, res in report.items():
        print(f"{tgt}: {res}")
