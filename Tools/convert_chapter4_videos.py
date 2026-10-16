"""Convert supplied MP4 movies to Godot's built-in Theora/Vorbis format, keeping audio."""
from pathlib import Path
import subprocess, sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.tools/python'))
import imageio_ffmpeg
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
for source,dest in [('天素罗的开始.mp4','chapter4_reveal.ogv'),('天素罗伪罗.mp4','chapter4_impostor.ogv'),('第四关最终BOSS战胜利视频.mp4','chapter4_victory.ogv'),('第四关最终BOSS回忆视频.mp4','chapter4_memory.ogv')]:
    target=root/'Videos'/dest
    if target.exists(): continue
    subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-i',str(root/'Videos'/source),'-map','0:v:0','-map','0:a:0','-vf','scale=960:-2','-c:v','libtheora','-q:v','6','-c:a','libvorbis','-q:a','4','-y',str(target)],check=True)
    print(dest, 'converted with original audio',flush=True)
