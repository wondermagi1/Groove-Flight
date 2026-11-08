"""Build the small Windows x64 GDExtension with an installed MSVC toolchain."""
from pathlib import Path
import os, subprocess, shutil

root = Path(__file__).resolve().parents[1]
vswhere = Path(os.environ['ProgramFiles(x86)']) / 'Microsoft Visual Studio/Installer/vswhere.exe'
installation = subprocess.check_output([str(vswhere), '-latest', '-products', '*', '-requires',
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath'], text=True).strip()
if not installation:
    raise SystemExit('An installed MSVC x64 toolchain is required.')
vcvars = Path(installation) / 'VC/Auxiliary/Build/vcvars64.bat'
work = root / 'work/crowd-build'; work.mkdir(parents=True, exist_ok=True)
capture = work / 'capture-env.bat'
capture.write_text(f'@echo off\ncall "{vcvars}" >nul\nif errorlevel 1 exit /b 1\nset\n', encoding='utf-8')
environment = subprocess.check_output(['cmd', '/d', '/c', str(capture)], text=True)
env = {key.upper(): value for key, value in os.environ.items()}
for line in environment.splitlines():
    if '=' in line and not line.startswith('='):
        key, value = line.split('=', 1); env[key.upper()] = value
source = root / 'native/crowd/crowd.cpp'
compiler = shutil.which('cl.exe', path=env['PATH'])
if not compiler: raise SystemExit('MSVC cl.exe is missing from the configured toolchain.')
subprocess.run([compiler, '/nologo', '/std:c++17', '/O2', '/fp:precise', '/MT', '/EHsc', '/LD',
    str(source), '/Fo' + str(work / 'crowd.obj'), '/link',
    '/OUT:' + str(source.parent / 'groove_crowd.windows.x86_64.dll'),
    '/IMPLIB:' + str(work / 'groove_crowd.lib')], cwd=work, env=env, check=True)
