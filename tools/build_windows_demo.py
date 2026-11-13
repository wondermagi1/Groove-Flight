"""Build a Windows release from an isolated allowlisted runtime tree."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,time,zipfile

ROOT=Path(__file__).resolve().parents[1]
VERSION=re.search(r'config/version="(\d+\.\d+\.\d+)',(ROOT/'project.godot').read_text(encoding='utf-8')).group(1)
NAME=f'GrooveFlight_Demo_v{VERSION}_Windows_x64'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def archive_demo(out):
 archive=out.parent/(out.name+'.zip')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
  for source in sorted(out.rglob('*')):
   if source.is_file():bundle.write(source,source.relative_to(out.parent).as_posix())
 with zipfile.ZipFile(archive) as bundle:assert bundle.testzip() is None,'ZIP checksum failure'
 info={'path':archive.name,'bytes':archive.stat().st_size,'sha256':digest(archive)}
 (archive.with_suffix('.sha256')).write_text(info['sha256']+'  '+archive.name+'\n',encoding='ascii')
 print(json.dumps(info),flush=True)
 return info

def build():
 parser=argparse.ArgumentParser()
 parser.add_argument('--engine',default='D:/Tool/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
 parser.add_argument('--template',type=Path)
 parser.add_argument('--skip-import',action='store_true')
 parser.add_argument('--archive-only',action='store_true')
 args=parser.parse_args()
 if args.archive_only:archive_demo(ROOT/'dist'/NAME);return
 assert args.template is not None,'Provide --template <official windows_release_x86_64.exe>'
 template=args.template.resolve()
 assert template.is_file() and template.read_bytes()[:2]==b'MZ','Windows release template missing'
 stage=ROOT/'work'/('demo-stage-'+VERSION);stage.mkdir(parents=True,exist_ok=True)
 out=ROOT/'dist'/NAME;out.mkdir(parents=True,exist_ok=True)
 logdir=ROOT/'work/demo-build';logdir.mkdir(exist_ok=True)
 inputs=[]
 def copy(source):
  rel=source.relative_to(ROOT);dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
  inputs.append(rel.as_posix())
  imp=Path(str(source)+'.import')
  if imp.is_file():
   shutil.copy2(imp,Path(str(dest)+'.import'))
   text=imp.read_text(encoding='utf-8')
   for relative in set(re.findall(r'res://(\.godot/imported/[^"\n]+)',text)):
    cached=ROOT/relative
    if cached.is_file():
     target=stage/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(cached,target)
   imported=stage/'.godot/imported'
   for md5 in (ROOT/'.godot/imported').glob(source.name+'-*.md5'):
    imported.mkdir(parents=True,exist_ok=True);shutil.copy2(md5,imported/md5.name)
 for folder in ['scenes','scripts','shaders','assets']:
  for source in (ROOT/folder).rglob('*'):
   if source.is_file() and source.suffix not in ['.import','.tmp'] and not source.name.startswith('~'):copy(source)
 for source in (ROOT/'audio').iterdir():
  if source.is_file() and source.suffix in ['.wav','.ogg','.json','.md']:copy(source)
 for folder in ['audio/arsenal','audio/authorized','audio/legacy','audio/charts']:
  for source in (ROOT/folder).rglob('*'):
   if source.is_file() and source.suffix in ['.wav','.ogg','.json','.txt','.md']:copy(source)
 for filename in ['WEAPON_DYNAMICS.json','GeneralUser-LICENSE.txt','TinySoundFont-LICENSE.txt']:
  copy(ROOT/'audio/instruments'/filename)
 for filename in ['crowd.gdextension','groove_crowd.windows.x86_64.dll']:copy(ROOT/'native/crowd'/filename)
 for filename in ['project.godot','icon.svg','CREDITS.md']:copy(ROOT/filename)
 project=(stage/'project.godot').read_text(encoding='utf-8').replace('config/name="Groove Flight"','config/name="Groove Flight Demo"').replace('config/custom_user_dir_name="BeatDriftPrototype"','config/custom_user_dir_name="GrooveFlightDemo"')
 (stage/'project.godot').write_text(project,encoding='utf-8')
 preset=(ROOT/'export_presets.cfg').read_text(encoding='utf-8').replace('custom_template/release=""','custom_template/release='+json.dumps(template.as_posix()))
 (stage/'export_presets.cfg').write_text(preset,encoding='utf-8')
 env=os.environ.copy();env['APPDATA']=str(ROOT/'tests/profile-demo-export')
 def run_engine(arguments,name):
  print(name,flush=True)
  with (logdir/(name+'.log')).open('w',encoding='utf-8') as log:
   p=subprocess.run([args.engine,'--headless','--path',str(stage),*arguments],cwd=stage,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=360)
  text=(logdir/(name+'.log')).read_text(encoding='utf-8',errors='replace')
  assert p.returncode==0 and 'SCRIPT ERROR' not in text and 'Parse Error' not in text,text[-6000:]
 if not args.skip_import:run_engine(['--editor','--import','--quit'],'import')
 # Raw composer PCM is decoded directly by Godot code. Editor builds use the
 # source WAV, while exported resources use import settings: never let a new
 # WAV's default QOA compression change its format in the standalone demo.
 changed=0
 for imported in (stage/'audio').rglob('*.wav.import'):
  text=imported.read_text(encoding='utf-8')
  fixed=re.sub(r'compress/mode=\d+','compress/mode=0',text)
  if fixed!=text:imported.write_text(fixed,encoding='utf-8');changed+=1
 if changed:run_engine(['--editor','--import','--quit'],'import-pcm')
 exe=out/'GrooveFlightDemo.exe';run_engine(['--export-release','Windows Demo',str(exe)],'export-release')
 assert exe.is_file() and exe.stat().st_size>1000000 and exe.with_suffix('.pck').is_file()
 # Direct PCM feedback loaders and the offline recognizer require OS files.
 for source in (ROOT/'audio/authorized/feedback').glob('*.wav'):
  dest=out/source.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
 native=out/'native/crowd';native.mkdir(parents=True,exist_ok=True)
 for filename in ['crowd.gdextension','groove_crowd.windows.x86_64.dll']:shutil.copy2(ROOT/'native/crowd'/filename,native/filename)
 helper=ROOT/'tools/audio_recognizer/BeatDriftTranscribe'
 assert (helper/'BeatDriftTranscribe.exe').is_file()
 shutil.copytree(helper,out/'tools/audio_recognizer/BeatDriftTranscribe',dirs_exist_ok=True)
 credits=out/'Credits';credits.mkdir(exist_ok=True)
 for source,name in [(ROOT/'CREDITS.md','MUSIC_AND_ASSETS.md'),(ROOT/'audio/CREDITS.md','AUDIO_PROVENANCE.md'),(ROOT/'assets/planets/CREDITS.md','PLANET_TEXTURES.md'),(ROOT/'audio/authorized/scott_buckley/LICENSE.md','FILAMENTS_LICENSE.md'),(ROOT/'audio/authorized/scott_buckley/planets/LICENSE.md','PLANET_MUSIC_LICENSE.md'),(ROOT/'audio/instruments/GeneralUser-LICENSE.txt','GENERALUSER_LICENSE.txt'),(ROOT/'audio/instruments/TinySoundFont-LICENSE.txt','TINYSOUNDFONT_LICENSE.txt')]:shutil.copy2(source,credits/name)
 for folder in ['third_party/audio-recognizer','third_party/basic-pitch','third_party/godot']:
  if (ROOT/folder).is_dir():shutil.copytree(ROOT/folder,credits/Path(folder).name,dirs_exist_ok=True)
 (out/'LaunchCompatibility.bat').write_text('@echo off\r\ncd /d "%~dp0"\r\nstart "" "%~dp0GrooveFlightDemo.exe" --rendering-method gl_compatibility\r\n',encoding='utf-8')
 (out/'README_中文.txt').write_text(f'Groove Flight 节拍飞行 · Windows Demo\n版本{VERSION} / 2026-11-11\n\n完整解压此文件夹，双击 GrooveFlightDemo.exe。无需安装Godot或Python。\n如默认模式无法启动，可双击 LaunchCompatibility.bat 使用兼容模式。请保留同目录的.pck、DLL及附带文件夹。\n\n快速体验：主菜单 → 星球航图 → 选择星球 → 选择流派 → 确认出击。\nWASD／方向键移动，空格冲刺，E超载，Tab打开音序编排，Esc暂停，F11切换全屏。\nJ/K/L对应A/B/C武器轨，每6秒三轨合计成绩统一决定下一段全武器弹量，开场100%。武器按原充能与音乐点自动齐射。波间购买、合成和调整音轨；完成星球任务且击败Boss后通关。\n\n本版包括24种武器、三种流派、八颗星球的独立歌曲/任务、音色图鉴与自由作曲，星球按游玩进度解锁。实弹流开局10点；敌人持续推进；第二波可刷史诗武器、第三波起可刷传奇；Boss攻势与特效已增强。\n设置中可分别调整背景音乐、武器、拾取、受击等音量。\n\n存档与音量保存在当前Windows用户的 %APPDATA%/GrooveFlightDemo 中，与开发项目分开。\n音乐、纹理和组件署名见Credits文件夹。\n',encoding='utf-8-sig')
 game_commit=subprocess.check_output(['git','log','-1','--format=%H','--','scripts','project.godot'],cwd=ROOT,text=True).strip()
 manifest={'version':VERSION,'platform':'Windows x86_64','game_commit':game_commit,'source_inputs':sorted(inputs),'template_sha256':digest(template),'native_kernel_sha256':digest(ROOT/'native/crowd/groove_crowd.windows.x86_64.dll'),'separate_demo_user_directory':'GrooveFlightDemo'}
 (out/'BUILD_INFO.json').write_text(json.dumps({k:manifest[k] for k in ['version','platform','game_commit','native_kernel_sha256','separate_demo_user_directory']},indent=2),encoding='utf-8')
 files=[p for p in out.rglob('*') if p.is_file()]
 manifest['package_files']=[{'path':p.relative_to(out).as_posix(),'bytes':p.stat().st_size,'sha256':digest(p)} for p in sorted(files)]
 (logdir/'BUILD.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'folder':str(out),'files':len(files),'MB':round(sum(p.stat().st_size for p in files)/1024**2,1)}),flush=True)
 archive_demo(out)

if __name__=='__main__':build()
