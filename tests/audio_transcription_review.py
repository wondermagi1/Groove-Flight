"""Original harmonic tones encoded as actual MP3, then recognized by the model."""
from pathlib import Path
import importlib.util
import json
import subprocess
import sys
import wave
import numpy as np
import lameenc

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work' / 'transcription-tests'
WORK.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('transcribe', ROOT/'tools/transcribe_audio.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
checks, failures, facts = [], [], {}
def check(value, message):
    checks.append(message)
    if not value:
        failures.append(message)
        print('FAIL', message, flush=True)

def fixture(path, chords=False):
    rate = 44100
    data = np.zeros(rate*6, dtype=np.float64)
    for index, pitch in enumerate([60,64,67,72,67,64,62,60]):
        start = round((.25+index*.5)*rate)
        time = np.arange(round(.38*rate))/rate
        gate = np.minimum(1,time/.008)*np.minimum(1,(.38-time)/.04)
        pitches = [pitch,48,55] if chords else [pitch]
        for midi in pitches:
            frequency = 440*2**((midi-69)/12)
            tone = sum(np.sin(2*np.pi*frequency*h*time)*(.5/h**1.7) for h in range(1,6))
            tone *= gate*np.exp(-time*1.8)/len(pitches)
            data[start:start+len(time)] += tone
    pcm = (data*30000).astype('<i2').tobytes()
    encoder = lameenc.Encoder()
    encoder.set_bit_rate(192); encoder.set_in_sample_rate(rate); encoder.set_channels(1); encoder.set_quality(2)
    path.write_bytes(encoder.encode(pcm)+encoder.flush())
    return data

def run_helper(request, name):
    path = WORK / (name+'.request.json')
    result = WORK / (name+'.result.json')
    status = WORK / (name+'.status.json')
    path.write_text(json.dumps(request), encoding='utf-8')
    command = [sys.executable, str(ROOT/'tools/transcribe_audio.py')]
    command += ['--request',str(path),'--output',str(result),'--status',str(status)]
    subprocess.run(command, timeout=100, check=False)
    return json.loads(result.read_text(encoding='utf-8'))

audio = fixture(WORK/'原创旋律 空格.mp3')
request = {'path':str(WORK/'原创旋律 空格.mp3'),'bpm':120,'mode':'melody','start':0,'length':0,'sensitivity':.5}
result = run_helper(request, 'melody')
check(result['ok'], 'actual compressed MP3 decodes and passes the neural model')
if result['ok']:
    score = result['score']
    pitches = [note['pitch'] for track in score['tracks'] for note in track['notes']]
    check({60,62,64,67,72}.issubset(set(pitches)), 'the known original melody pitches are recognized')
    check(len(pitches)<40, 'melody extraction rejects most spurious harmonic notes')
    check(score['bpm']==120 and len(score['tracks'])==1, 'manual BPM and monophonic mode survive conversion')
    check(all(note['beat']*4==round(note['beat']*4) and note['duration']>=.25 for t in score['tracks'] for note in t['notes']), 'recognized notes obey editor grid and minimum length')
    facts['melody_pitches'] = pitches
    facts['recognition_seconds'] = result['facts']['elapsed']
    facts['score_notes'] = result['facts']['notes']
fixture(WORK/'chords.mp3', True)
result = run_helper(dict(request,path=str(WORK/'chords.mp3'),mode='poly'), 'chords')
check(result['ok'] and len(result.get('score',{}).get('tracks',[]))==2, 'polyphonic MP3 creates editable high and low register tracks')
if result['ok']:
    notes = [n for track in result['score']['tracks'] for n in track['notes']]
    check({48,55}.issubset({n['pitch'] for n in notes}), 'real simultaneous bass and harmony tones are recovered')
    facts['chord_notes'] = len(notes)
cropped = module.decode(WORK/'原创旋律 空格.mp3', 1., 2.)
check(abs(len(cropped)/22050-2)<.01, 'decoder seeks and bounds the requested two-second excerpt')
check(module.estimate_tempo(audio.astype(np.float32)[::2])[0] >= 40, 'automatic tempo estimator returns a bounded usable suggestion')
for name, change in [('outside',{'start':99}),('bad-bpm',{'bpm':2}),('missing',{'path':str(WORK/'none.mp3')})]:
    result = run_helper(dict(request,**change), name)
    check(not result['ok'] and bool(result.get('error')), 'invalid source/options return an explicit error / '+name)
(WORK/'broken.mp3').write_bytes(b'not a music file')
check(not run_helper(dict(request,path=str(WORK/'broken.mp3')), 'broken')['ok'], 'corrupt MP3 fails without fabricating notes')
with wave.open(str(WORK/'silence.wav'),'wb') as file:
    file.setnchannels(1); file.setsampwidth(2); file.setframerate(22050); file.writeframes(bytes(44100))
check(not run_helper(dict(request,path=str(WORK/'silence.wav')), 'silence')['ok'], 'silence produces a readable no-sound failure')
report = {'checks':len(checks),'failures':failures,'facts':facts,'scope':'Original synthesized melodies/chords encoded to real MP3; actual CPU ONNX inference, excerpt bounds, quantization and corrupt/invalid/silent audio. No commercial-song accuracy claim.'}
(ROOT/'tests/results-audio-transcription.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False),flush=True)
sys.exit(bool(failures))
