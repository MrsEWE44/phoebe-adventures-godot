"""Measure provided voice files and author runtime gains; never overwrite source audio."""
from pathlib import Path
import json, math, re, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/python'))
import imageio_ffmpeg
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
path = ROOT / 'Audio/voice_gains.json'
gains = json.loads(path.read_text(encoding='utf8'))
report = []
for folder in ['Doro', '奶蛙', '凑企鹅', 'Q币企鹅', '咕咕嘎嘎']:
    for source in sorted((ROOT / 'Audio' / folder).iterdir()):
        if source.suffix.lower() not in ['.mp3', '.wav']:
            continue
        result = subprocess.run([ffmpeg, '-hide_banner', '-i', str(source), '-af', 'volumedetect', '-f', 'null', '-'], capture_output=True, text=True, encoding='utf8', errors='replace')
        mean = re.search(r'mean_volume: ([-\d.]+) dB', result.stderr)
        peak = re.search(r'max_volume: ([-\d.]+) dB', result.stderr)
        if result.returncode or not mean or not peak:
            raise RuntimeError(f'Cannot measure {source.name}: {result.stderr[-500:]}')
        average, maximum = float(mean[1]), float(peak[1])
        gain = round(max(-16, min(12, -18-average, -3-maximum)), 2)
        key = 'res://' + source.relative_to(ROOT).as_posix()
        gains[key] = gain
        report.append({'file': key, 'mean_db': average, 'peak_db': maximum, 'gain_db': gain})
path.write_text(json.dumps(gains, ensure_ascii=False, indent=2), encoding='utf8')
(ROOT / 'Audio/Doro/level_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
print(f'Authored volume gains for {len(report)} Chapter3 voice clips')
