"""Shade's one spoken line in the ending (scripts/cutscenes/cs_last_page.gd):
"Every page you won was a page he didn't get."

It is the team's own recording (assets/voice/src/shade_every_page_recording.mp3,
kept out of Godot by a .gdignore), with the quiet trimmed off both ends and
its level evened out; nothing else is done to the voice. Needs ffmpeg.
Re-running overwrites assets/voice/shade_every_page.wav.

    python3 tools/voice/build_shade_voice.py
"""
import os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "assets", "voice", "src", "shade_every_page_recording.mp3")
DST = os.path.join(HERE, "..", "..", "assets", "voice", "shade_every_page.wav")

def main():
    trim = "silenceremove=start_periods=1:start_threshold=-42dB:start_duration=0.05"
    chain = ",".join([
        "aresample=44100",
        trim, "areverse", trim, "areverse",          # the quiet before and after it
        "highpass=f=60",                              # (rumble under the voice)
        "loudnorm=I=-15:TP=-1.5:LRA=9",
        "afade=t=in:d=0.02", "areverse", "afade=t=in:d=0.12", "areverse",  # no clicks at either end
    ])
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", SRC, "-af", chain, "-ac", "1", "-ar", "44100",
                    "-c:a", "pcm_s16le", DST], check=True)
    print("wrote", os.path.normpath(DST))

if __name__ == "__main__":
    main()
