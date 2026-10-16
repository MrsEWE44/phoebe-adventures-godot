"""Map supplied audio filenames to battle states and author inspectable Godot profiles.

Keeps original recordings intact. Run after adding named audio files; the first
matching semantic group wins, and numbered variants are retained for randomness.
"""
from pathlib import Path
import json
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
EVENTS = {
    'idle': ('待机', '开心', '快乐', '笑声', '对话'),
    'battle': ('战斗', '挑衅', '开心', '笑声'),
    'hurt': ('受伤', '挨打', '哭声', '委屈'),
    'death': ('被击败', '死亡', '难过至极', '哭声', '受伤'),
    'angry': ('生气', '愤怒', '哭声', '受伤'),
    'afraid': ('害怕', '委屈', '哭声', '受伤'),
    'terrified': ('惊吓', '难过', '哭声', '受伤'),
    'proud': ('得意', '嘲笑', '开心', '快乐', '笑声'),
    'skill': ('技能', '挑衅', '开心', '笑声'),
    'ultimate': ('大招', '非常生气', '开心', '笑声'),
    'victory': ('胜利', '快乐', '开心', '笑声'),
    'exhausted': ('疲惫', '委屈', '哭声', '受伤'),
    'dialogue': ('对话', '挑衅', '开心', '笑声'),
    'interaction': ('对话', '挑衅', '开心', '笑声'),
}
FAMILIES = {'penguin': '凑企鹅', 'anon': '千早爱音', 'tensura': '天素罗', 'mutsumi': '睦子米'}
COOLDOWNS = {'idle':12.0, 'battle':8.0, 'hurt':2.0, 'death':0.0, 'angry':7.0,
             'afraid':9.0, 'terrified':10.0, 'proud':8.0, 'skill':4.0,
             'ultimate':6.0, 'victory':6.0, 'exhausted':7.0, 'dialogue':3.0, 'taunt':12.0}

def build():
    gains_path = ROOT/'Audio/voice_gains.json'
    gains = json.loads(gains_path.read_text(encoding='utf-8'))
    manifest = {'families': {}, 'clips': {}, 'shared': {'soyo': 'tensura', 'soyo_full': 'tensura', 'weiro': 'tensura'}}
    for family, folder in FAMILIES.items():
        files = sorted(p for p in (ROOT/'Audio'/folder).iterdir() if p.suffix.lower() in ('.mp3', '.wav', '.ogg'))
        assert files, f'No recordings for {folder}'
        captions = {}
        if family == 'mutsumi':
            captions = {line['file']: line['text'] for line in json.loads((ROOT/'Audio/睦子米/lines.json').read_text(encoding='utf-8-sig'))}
        picks = {}
        rules = dict(EVENTS)
        if family == 'penguin': rules['taunt'] = ('嘲笑', '挑衅')
        for event, keywords in rules.items():
            for keyword in keywords:
                matched = [p for p in files if keyword in p.stem]
                if matched:
                    picks[event] = matched
                    break
            assert event in picks, f'No {event} recording for {folder}'
        references = {p: f'clip_{i}' for i, p in enumerate(files)}
        lines = ['[gd_resource type="Resource" format=3]', '[ext_resource type="Script" path="res://Characters/voice_profile.gd" id="script"]']
        for path, ident in references.items():
            relative = path.relative_to(ROOT).as_posix()
            lines.append(f'[ext_resource type="AudioStream" path="res://{relative}" id="{ident}"]')
            samples, rate = sf.read(path, always_2d=True)
            assert len(samples) and np.isfinite(samples).all(), relative
            peak = float(np.abs(samples).max())
            active = samples[np.abs(samples).max(axis=1) > max(.003, peak*.08)]
            rms = float(np.sqrt(np.mean(active**2))) if active.size else 0.0
            assert peak > .01 and rms > .001, f'Silent recording: {relative}'
            gain = min(10**(-17/20)/rms, .85/peak)
            gains['res://'+relative] = round(float(20*np.log10(gain)), 3)
            manifest['clips'][relative] = {'seconds':round(len(samples)/rate,3), 'gain_db':gains['res://'+relative], 'adjusted_peak':round(peak*gain,4)}
        lines += ['[resource]', 'script = ExtResource("script")', 'volume_db = 0.0', 'shared_cooldown = 1.8', 'max_duration = 0.0', 'event_cooldowns = '+json.dumps(COOLDOWNS)]
        for event, paths in picks.items():
            lines.append(event+' = Array[AudioStream](['+', '.join(f'ExtResource("{references[p]}")' for p in paths)+'])')
        lines.append('event_text = '+json.dumps({e:[captions.get(p.stem, '（'+p.stem+'）') for p in paths] for e,paths in picks.items()}, ensure_ascii=False))
        resource = '\n'.join(lines)+'\n'
        (ROOT/f'Characters/Voices/{family}.tres').write_text(resource, encoding='utf-8')
        if family == 'penguin':
            (ROOT/'Characters/Voices/penguin_full.tres').write_text(resource, encoding='utf-8')
        manifest['families'][family] = {e:[p.relative_to(ROOT).as_posix() for p in paths] for e,paths in picks.items()}
    for name, voice in [('mutsumi', 'mutsumi'), ('soyo', 'tensura'), ('soyo_full', 'tensura')]:
        path = ROOT/f'Characters/Definitions/{name}.tres'
        text = path.read_text(encoding='utf-8').replace('Voices/instrument.tres', f'Voices/{voice}.tres')
        path.write_text(text, encoding='utf-8')
    gains_path.write_text(json.dumps(gains, ensure_ascii=False, indent=2), encoding='utf-8')
    (ROOT/'Audio/named_voice_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Updated {len(FAMILIES)} voice families, {len(manifest["clips"])} full recordings; peak <= 0.85.')

if __name__ == '__main__':
    build()
