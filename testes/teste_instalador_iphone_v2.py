"""Confere instalacao, bloqueios e restauracao usando uma VPS inteiramente simulada."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]

class InstaladorV2(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.kit=self.root/'kit';self.base=self.root/'vps';self.bin=self.root/'bin';self.bin.mkdir()
        (self.kit/'web').mkdir(parents=True);(self.base/'web/www/jogar').mkdir(parents=True)
        for name in ['versao-base.env','shell.html','otclientrc-extra.lua']:
            shutil.copy(ROOT/'web'/name,self.kit/'web'/name)
        shutil.copytree(ROOT/'web/patches-final',self.kit/'web/patches-final')
        shutil.copytree(self.kit/'web/patches-final',self.base/'web/patches-final')
        (self.base/'web/patches-final/0008-offscreen-e-proporcao.patch').unlink()
        shutil.copy(self.kit/'web/versao-base.env',self.base/'web/versao-base.env')
        old=subprocess.check_output(['git','-C',str(ROOT),'show','HEAD:web/shell.html'])
        (self.base/'web/shell.html').write_bytes(old)
        shutil.copy(self.kit/'web/otclientrc-extra.lua',self.base/'web/otclientrc-extra.lua')
        self.old=old
        (self.base/'.env').write_text('NOME_SERVIDOR=JV Baiak\n')
        (self.base/'mapa.otbm').write_text('mapa preservado')
        (self.base/'web/www/jogar/index.html').write_text('cliente anterior')
        (self.base/'web/www/jogar/otclient.wasm').write_text('wasm anterior')
        script=(ROOT/'web/instalar-correcao-iphone-v2.sh').read_text().replace('/run/jvbaiak-correcao-iphone.lock',str(self.root/'lock'))
        self.script=self.kit/'web/instalar-correcao-iphone-v2.sh';self.script.write_text(script)
        mocks={'id':'echo 0','docker':'exit 0','git':'echo revisao-de-teste','systemctl':'exit 3','curl':'exit 0',
               'df':"printf 'Filesystem 1024-blocks Used Available Capacity Mounted\\nfixture 99999999 0 99999999 0%% /\\n'"}
        for name,body in mocks.items():
            p=self.bin/name;p.write_text('#!/bin/bash\n'+body+'\n');p.chmod(0o755)
        self.env=dict(os.environ,BASE=str(self.base),PATH=str(self.bin)+':'+os.environ['PATH'])
        self.compiler=self.base/'web/compilar-web.sh'
        self.compiler.write_text('''set -eu
printf 'wasm novo' > "$BASE/web/www/jogar/otclient.wasm"
printf '<meta content="toque-v2-offscreen"><script src=otclient.js></script>' > "$BASE/web/www/jogar/index.html"
printf 'const x=($0-r.left)/r.width;' > "$BASE/web/www/jogar/otclient.js"
''')

    def run_script(self):
        return subprocess.run(['bash',str(self.script)],env=self.env,text=True,capture_output=True,timeout=15)

    def test_success_and_cache_version(self):
        r=self.run_script();self.assertEqual(r.returncode,0,r.stderr)
        self.assertTrue((self.base/'web/patches-final/0008-offscreen-e-proporcao.patch').exists())
        self.assertEqual((self.base/'web/shell.html').read_bytes(),(self.kit/'web/shell.html').read_bytes())
        self.assertIn('otclient.js?v=toque-v2-offscreen',(self.base/'web/www/jogar/index.html').read_text())
        self.assertEqual((self.base/'mapa.otbm').read_text(),'mapa preservado')
        self.assertEqual(len(list((self.base/'backups').glob('iphone-v2-*'))),1)

    def test_compile_failure_restores_files_and_client(self):
        self.compiler.write_text('echo quebrado > "$BASE/web/www/jogar/index.html"\nexit 1\n')
        r=self.run_script();self.assertNotEqual(r.returncode,0)
        self.assertEqual((self.base/'web/www/jogar/index.html').read_text(),'cliente anterior')
        self.assertEqual((self.base/'web/shell.html').read_bytes(),self.old)
        self.assertFalse((self.base/'web/patches-final/0008-offscreen-e-proporcao.patch').exists())
        self.assertIn('Restaurando cliente anterior',r.stderr)

    def test_different_installed_shell_stops_before_backup(self):
        (self.base/'web/shell.html').write_text('outra alteracao em andamento')
        r=self.run_script();self.assertNotEqual(r.returncode,0)
        self.assertFalse((self.base/'backups').exists())
        self.assertIn('pagina instalada mudou',r.stderr)

    def test_old_coordinate_formula_rejected_and_rolled_back(self):
        with self.compiler.open('a') as f:f.write("printf 'const x=c.width/r.width;' > \"$BASE/web/www/jogar/otclient.js\"\n")
        r=self.run_script();self.assertNotEqual(r.returncode,0)
        self.assertEqual((self.base/'web/www/jogar/index.html').read_text(),'cliente anterior')
        self.assertFalse((self.base/'web/patches-final/0008-offscreen-e-proporcao.patch').exists())

if __name__=='__main__':unittest.main()
