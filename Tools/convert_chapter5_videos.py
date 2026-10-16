"""Convert Chapter5 videos while retaining their original audio; skip existing outputs."""
from pathlib import Path
import subprocess, sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.tools/python'))
import imageio_ffmpeg
for source,dest in [('badapple视频.mp4','chapter5_badapple.ogv'),('菲比卖萌.mp4','chapter5_phoebe.ogv')]:
    target=root/'Videos'/dest
    if target.exists(): continue
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-i',str(root/'Videos'/source),'-map','0:v:0','-map','0:a:0','-vf','scale=960:-2','-c:v','libtheora','-q:v','6','-c:a','libvorbis','-q:a','4','-y',str(target)],check=True)
    print(dest,'converted with original audio',flush=True)
