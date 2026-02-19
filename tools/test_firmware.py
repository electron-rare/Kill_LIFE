import sys

def test_firmware(target):
    # Exemple minimal : tests pour chaque cible
    if target == 'esp':
        print('Tests ESP...')
        # Appel tests unitaires ESP
    elif target == 'stm':
        print('Tests STM...')
        # Appel tests unitaires STM
    elif target == 'linux':
        print('Tests Linux...')
        # Appel tests unitaires Linux
    else:
        print('Cible inconnue')
        sys.exit(1)
    print(f'Tests terminés pour {target}')

if __name__ == '__main__':
    test_firmware(sys.argv[1])
