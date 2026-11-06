"""A migracao de pocoes nao altera outras configuracoes e roda uma vez."""
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class PocoesInfinitas(unittest.TestCase):
    def test_migracao_idempotente(self):
        script = (ROOT / 'instalar.sh').read_text()
        define = re.search(r'\tlua_define\(\).*?\n\t}', script, re.S)[0]
        migracao = re.search(r"\tif ! grep -qx 'pocoes-infinitas-v1'.*?\n\tfi", script, re.S)[0]
        for config in ['removeChargesFromPotions = true\n', 'removeChargesFromPotions = false\n', '']:
            with self.subTest(config=config), tempfile.TemporaryDirectory() as tmp:
                p = Path(tmp)
                arquivo = p / 'config.lua'
                arquivo.write_text(config + 'removeChargesFromRunes = true\nrateExp = 800\n')
                (p / 'ajustes').touch()
                base = 'set -e\nSRV="$1"\nAJUSTES="$SRV/ajustes"\nREINICIAR_SERVIDOR=0\nok(){ :; }\n'
                cmd = base + define + '\n' + migracao + '\nprintf "%s" "$REINICIAR_SERVIDOR"\n'
                primeira = subprocess.run(['bash', '-c', cmd, 'teste', tmp], check=True, capture_output=True, text=True)
                self.assertEqual(primeira.stdout, '1')
                texto = arquivo.read_text()
                self.assertEqual(texto.count('removeChargesFromPotions = false'), 1)
                self.assertIn('removeChargesFromRunes = true\nrateExp = 800\n', texto)
                segunda = subprocess.run(['bash', '-c', cmd, 'teste', tmp], check=True, capture_output=True, text=True)
                self.assertEqual(segunda.stdout, '0')
                self.assertEqual(arquivo.read_text(), texto)


if __name__ == '__main__':
    unittest.main()
