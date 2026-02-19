import sys

def build_firmware(target):
    # Exemple minimal : build pour chaque cible
    if target == 'esp':
        print('Build ESP...')
        # Appel PlatformIO ou script ESP
    elif target == 'stm':
        print('Build STM...')
        # Appel PlatformIO ou script STM
    elif target == 'linux':
        print('Build Linux...')
        # Appel QEMU ou make Linux
    else:
        print('Cible inconnue')
        sys.exit(1)
    print(f'Build terminé pour {target}')

if __name__ == '__main__':
    build_firmware(sys.argv[1])
