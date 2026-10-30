"""Offline audio -> editable BeatDrift score.

Uses Spotify Basic Pitch's Apache-2.0 ONNX model. Window padding/overlap follows
its published inference protocol (Spotify AB, 2022); note grouping, tempo
estimation, editor quantization and process protocol below are BeatDrift code.
No song recognition service, network calls or copyrighted fixture is used.
"""
from pathlib import Path
import argparse
import json
import math
import os
import sys
import time
import numpy as np
import miniaudio
import onnxruntime as ort

RATE = 22050
WINDOW = 43844
OVERLAP = 7680
HOP = WINDOW - OVERLAP

def atomic_json(path, value):
    path = Path(path)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, allow_nan=False), encoding='utf-8')
    os.replace(temporary, path)

def progress(path, amount, text):
    atomic_json(path, {'progress': amount, 'message': text})

def decode(path, start, length):
    path = Path(path)
    if not path.is_file() or path.stat().st_size > 128 * 1024 * 1024:
        raise ValueError('请选择不超过128MB的本地音频文件。')
    info = miniaudio.get_file_info(str(path))
    remaining = info.duration - start
    if remaining < .15:
        raise ValueError('起点已超出音频，或剩余片段太短。')
    length = remaining if length == 0 else min(length, remaining)
    if length > 600.01:
        raise ValueError('一次最多识别10分钟，请设置起点与片段长度。')
    stream = miniaudio.stream_file(str(path), output_format=miniaudio.SampleFormat.FLOAT32,
                                  nchannels=1, sample_rate=RATE, frames_to_read=16384,
                                  seek_frame=round(start * RATE))
    blocks = []
    count = 0
    maximum = round(length * RATE)
    try:
        for samples in stream:
            block = np.frombuffer(samples, dtype=np.float32)[:maximum-count].copy()
            blocks.append(block)
            count += len(block)
            if count >= maximum:
                break
    finally:
        stream.close()
    if not blocks or count < RATE * .15:
        raise ValueError('音频无法解码或片段太短。')
    audio = np.concatenate(blocks)
    if not np.isfinite(audio).all() or float(np.max(np.abs(audio))) < .0001:
        raise ValueError('片段中没有可识别的声音。')
    return audio

def estimate_tempo(audio):
    # Spectral-flux autocorrelation is a suggestion, not an original tempo map.
    hop = 256
    sample = audio[:RATE * 90:2]
    sr = RATE / 2
    width = 1024
    if len(sample) < width * 4:
        return 120., 0.
    windows = np.lib.stride_tricks.sliding_window_view(sample, width)[::hop]
    spectrum = np.abs(np.fft.rfft(windows * np.hanning(width), axis=1))
    envelope = np.maximum(np.diff(np.log1p(spectrum * 20), axis=0), 0).sum(axis=1)
    envelope -= envelope.mean()
    n = len(envelope)
    fft = np.fft.rfft(envelope, n=2 ** (2*n-1).bit_length())
    correlation = np.fft.irfft(np.abs(fft)**2)[:n]
    if correlation[0] <= 1e-8:
        return 120., 0.
    minimum = max(1, round(sr / hop * 60 / 180))
    maximum = min(n-1, round(sr / hop * 60 / 65))
    candidates = np.arange(minimum, maximum+1)
    score = correlation[candidates] / correlation[0]
    bpms = sr / hop * 60 / candidates
    score *= np.exp(-.5 * (np.log2(bpms / 115) / .8)**2)
    best = int(np.argmax(score))
    bpm = round(float(bpms[best]), 1)
    return bpm, float(score[best])

def infer(audio, model, status):
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    options.log_severity_level = 3
    session = ort.InferenceSession(str(model), sess_options=options, providers=['CPUExecutionProvider'])
    audio = np.pad(audio, (OVERLAP//2, 0))
    starts = range(0, len(audio), HOP)
    notes, onsets = [], []
    for index, start in enumerate(starts):
        window = audio[start:start+WINDOW]
        window = np.pad(window, (0, WINDOW-len(window))).astype(np.float32)
        note, onset = session.run(['StatefulPartitionedCall:1', 'StatefulPartitionedCall:2'],
                                 {'serving_default_input_2:0': window[None, :, None]})
        notes.append(note[0, 15:-15, :])
        onsets.append(onset[0, 15:-15, :])
        progress(status, .12 + .70*(index+1)/len(starts), f'分析音高与起音 {index+1}/{len(starts)}')
    frames = int((len(audio)-OVERLAP//2) / HOP * 142)
    return np.concatenate(notes)[:frames], np.concatenate(onsets)[:frames]

def extract_notes(frames, onsets, mode, sensitivity):
    threshold = .55 - .25*sensitivity
    frame_threshold = .32 - .12*sensitivity
    seconds_per_frame = HOP / 142 / RATE
    if mode == 'melody':
        # A monophonic, continuity-biased dominant line, not vocal separation.
        weighted = frames.copy()
        weighted[:, :27] *= .25  # below C3: prefer an audible melodic register
        weighted[:, 70:] *= .6
        chosen = np.full(len(frames), -1, dtype=np.int16)
        previous = -1
        for index, row in enumerate(weighted):
            current = int(np.argmax(row))
            if previous >= 0 and row[previous] > frame_threshold and row[previous] >= row[current]*.8:
                current = previous
            if row[current] >= frame_threshold:
                chosen[index] = current
                previous = current
            else:
                previous = -1
        mask = np.zeros_like(frames)
        valid = np.flatnonzero(chosen >= 0)
        mask[valid, chosen[valid]] = 1
        frames = frames * mask
        onsets = onsets * mask
    events = []
    for pitch in range(3, 88):  # Basic Pitch A0=21; editor starts C1=24
        values = frames[:, pitch]
        onset = onsets[:, pitch]
        active = -1
        gap = 0
        for index in range(len(values)):
            attack = (onset[index] >= threshold and
                      (index == 0 or onset[index] >= onset[index-1]) and
                      (index+1 == len(values) or onset[index] > onset[index+1]))
            voiced = values[index] >= frame_threshold
            if active >= 0 and attack and index-active >= 10:
                events.append((active, index, pitch+21, float(np.mean(values[active:index]))))
                active = index
                gap = 0
            elif active < 0 and (attack or voiced):
                active = index
                gap = 0
            elif active >= 0:
                gap = 0 if voiced else gap+1
                if gap >= 5:
                    end = index-gap+1
                    if end-active >= 7:
                        events.append((active, end, pitch+21, float(np.mean(values[active:end]))))
                    active = -1
        if active >= 0 and len(values)-gap-active >= 7:
            end = len(values)-gap
            events.append((active, end, pitch+21, float(np.mean(values[active:end]))))
    events = [(max(0., start*seconds_per_frame-.0018), end*seconds_per_frame,
               pitch, strength) for start,end,pitch,strength in events]
    return sorted(events)

def to_score(events, bpm, duration, title, mode):
    if not events:
        raise ValueError('没有识别出稳定音符。可尝试纯音乐、独奏、哼唱或提高灵敏度。')
    bars = max(1, math.ceil(duration*bpm/240 - 1e-7))
    if bars > 256 or bars*240/bpm > 600.0001:
        raise ValueError('按此速度转谱超过256小节或10分钟，请缩短片段。')
    tracks = [{'id': 1, 'name': '旋律估计' if mode == 'melody' else '高音 / 和声估计',
               'weapon': 'pulse', 'volume': .8, 'pan': 0., 'mute': False, 'solo': False, 'notes': []}]
    if mode == 'poly':
        tracks.append({'id': 2, 'name': '低音估计', 'weapon': 'nova', 'volume': .65,
                       'pan': 0., 'mute': False, 'solo': False, 'notes': []})
    seen = set()
    for start, end, pitch, strength in events:
        beat = round(start*bpm/60*4)/4
        length = max(.25, round((end-start)*bpm/60*4)/4)
        length = min(length, bars*4-beat)
        track = 1 if mode == 'poly' and pitch < 60 else 0
        key = (track, beat, pitch)
        if key in seen or length < .25 or not 24 <= pitch <= 108:
            continue
        seen.add(key)
        tracks[track]['notes'].append({'id': len(seen), 'beat': beat, 'duration': length,
                                      'pitch': pitch, 'velocity': max(25, min(120, round(35+85*strength)))})
    if len(seen) > 8192:
        raise ValueError('识别音符超过8192个，请缩短片段或使用旋律优先模式。')
    if not seen:
        raise ValueError('没有位于编辑器音域内的有效音符。')
    return {'format': 'beatdrift-score', 'version': 1, 'title': title[:150], 'bpm': bpm,
            'bars': bars, 'tracks': tracks}

ROLE_SETUP = {
    'lead': ('主旋律估计', 'boomerang', .78, 0.),
    'bass': ('低音估计', 'rail', .65, 0.),
    'harmony': ('和弦估计', 'nova', .48, -.28),
    'pad': ('长音铺底估计', 'orbit', .36, .25),
    'accent': ('装饰音估计', 'chain', .60, .20),
    'kick': ('低频鼓点估计', 'missile', .63, 0.),
    'snare': ('中频鼓点估计', 'scatter', .38, -.08),
    'hat': ('高频鼓点估计', 'pulse_needle', .22, .28),
}

def detect_percussion(audio, sensitivity=.5):
    """Band-limited transient estimates, not isolated original drum stems.

    FFT batches bound memory for ten-minute files. Stable sustained tones produce
    no repeated triggers. Detection stays on source transients, not a fake loop.
    """
    width, hop = 1024, 256
    if len(audio) < width * 2:
        return []
    windows = np.lib.stride_tricks.sliding_window_view(audio, width)[::hop]
    freqs = np.fft.rfftfreq(width, 1/RATE)
    bands = [(45, 200, 'kick'), (220, 2400, 'snare'), (4000, 10000, 'hat')]
    envelopes = np.empty((len(windows), 3))
    for offset in range(0, len(windows), 1024):
        spectrum = np.abs(np.fft.rfft(windows[offset:offset+1024] * np.hanning(width), axis=1))
        for band, (lo, hi, _) in enumerate(bands):
            envelopes[offset:offset+len(spectrum), band] = np.log1p(spectrum[:, (freqs >= lo) & (freqs < hi)].mean(axis=1)*20)
    flux = np.maximum(np.diff(envelopes, axis=0, prepend=envelopes[:1]), 0.)
    events = []
    for band, (_, _, role) in enumerate(bands):
        values = flux[:, band]
        threshold = max(.045, float(np.percentile(values, 75)) * (2.5-sensitivity), float(values.max()) * .13)
        last = -1000
        for index in range(1, len(values)-1):
            if (values[index] < threshold or values[index] < values[index-1] or values[index] <= values[index+1]
                or (index-last)*hop/RATE < (.14 if role == 'kick' else .09)):
                continue
            # Nearby FFT windows see one source onset; quantization merges them.
            when = max(0., (index*hop+width*.5)/RATE-.018)
            strength = min(1., float(values[index]/max(threshold*3, 1e-9)))
            events.append((when, role, round(55+55*strength)))
            last = index
    return sorted(events)

def orchestrate(score, percussion=()):
    """Revoice recognized notes, preserving pitches/gates/velocities and IDs."""
    result = dict(score)
    source = [dict(n) for t in score['tracks'] for n in t['notes']]
    onsets = {}
    for note in source:
        onsets.setdefault(note['beat'], []).append(note['pitch'])
    buckets = {role: [] for role in ROLE_SETUP}
    for note in source:
        pitches = onsets[note['beat']]
        if note['pitch'] < 55:
            role = 'bass'
        elif note['duration'] >= 3:
            role = 'pad'
        elif len(pitches) >= 3 and note['pitch'] < max(pitches):
            role = 'harmony'
        elif note['duration'] <= .5 and note['pitch'] >= 77:
            role = 'accent'
        else:
            role = 'lead'
        buckets[role].append(note)
    if len(buckets['lead']) >= 8 and not buckets['accent']:
        pitches = sorted(n['pitch'] for n in buckets['lead'])
        split = pitches[len(pitches)//2]
        colors = [n for n in buckets['lead'] if n['pitch'] > split]
        if 0 < len(colors) < len(buckets['lead']):
            buckets['lead'] = [n for n in buckets['lead'] if n['pitch'] <= split]
            buckets['accent'] = colors
    seen = set()
    next_id = max((n['id'] for n in source), default=0)+1
    for seconds, role, velocity in percussion:
        beat = round(seconds*score['bpm']/60*4)/4
        if beat >= score['bars']*4 or (beat, role) in seen or next_id > 8192:
            continue
        seen.add((beat, role))
        buckets[role].append({'id': next_id, 'beat': beat, 'duration': .25,
                             'pitch': {'kick':36, 'snare':38, 'hat':42}[role], 'velocity': velocity})
        next_id += 1
    result['tracks'] = []
    for role, (name, weapon, gain, pan) in ROLE_SETUP.items():
        if buckets[role]:
            result['tracks'].append({'id': len(result['tracks'])+1, 'name': name, 'weapon': weapon,
                                     'role': role, 'volume': gain, 'pan': pan, 'mute': False, 'solo': False,
                                     'notes': buckets[role]})
    return result

def run(request, output, status):
    started = time.monotonic()
    data = json.loads(Path(request).read_text(encoding='utf-8-sig'))
    path = Path(data['path'])
    start, length = float(data.get('start', 0)), float(data.get('length', 0))
    bpm = float(data.get('bpm', 0))
    mode = data.get('mode', 'arrange')
    sensitivity = float(data.get('sensitivity', .5))
    if (not all(math.isfinite(x) for x in (start,length,bpm,sensitivity)) or
        start < 0 or length < 0 or length > 600 or not (bpm == 0 or 40 <= bpm <= 240) or
        mode not in ('melody','poly','arrange') or not 0 <= sensitivity <= 1):
        raise ValueError('识别参数超出有效范围。')
    progress(status, .02, '解码音频片段')
    audio = decode(path, start, length)
    progress(status, .08, '估计速度')
    suggested_bpm, confidence = estimate_tempo(audio)
    automatic = bpm == 0
    if automatic:
        bpm = suggested_bpm if confidence > .05 else 120.
    progress(status, .1, '加载本地音高模型')
    base = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parent))
    model = base / 'models' / 'basic_pitch.onnx'
    frames, onsets = infer(audio, model, status)
    progress(status, .87, '整理音符与量化')
    events = extract_notes(frames, onsets, mode, sensitivity)
    score = to_score(events, bpm, len(audio)/RATE, path.stem+' · 音频识谱', 'poly' if mode == 'arrange' else mode)
    if mode == 'arrange':
        progress(status, .93, '分配旋律、低音、和弦与鼓组')
        score = orchestrate(score, detect_percussion(audio, sensitivity))
    count = sum(len(track['notes']) for track in score['tracks'])
    warnings = ['这是机器估计的草稿；成品歌曲的人声、鼓点和伴奏可能产生误音、漏音及八度偏差。',
                '已量化到十六分网格；声部依据音域、时值与同时起音编配，不代表原曲乐器分离。']
    if mode == 'arrange':
        warnings.append('低/中/高频瞬态估计为鼓组，可能将钢琴、拨弦误识为打击声，可逐轨静音调整。')
    if automatic:
        warnings.append(f'自动速度约{bpm:g} BPM，可能存在半速/倍速误差；请试听并校准。')
    atomic_json(output, {'ok': True, 'score': score, 'warnings': warnings,
                         'facts': {'notes': count, 'seconds': len(audio)/RATE, 'bpm': bpm,
                                   'parts': len(score['tracks']), 'mode': mode, 'auto_bpm': automatic, 'tempo_confidence': confidence,
                                   'elapsed': time.monotonic()-started, 'engine': 'Basic Pitch ONNX CPU'}})
    progress(status, 1., f'识别完成：{count}个音符，{bpm:g} BPM')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--request', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--status', required=True)
    args = parser.parse_args()
    try:
        run(args.request, args.output, args.status)
        return 0
    except Exception as error:
        atomic_json(args.output, {'ok': False, 'error': str(error) or type(error).__name__})
        progress(args.status, 1., '识别失败，原曲谱未更改')
        return 1

if __name__ == '__main__':
    sys.exit(main())
