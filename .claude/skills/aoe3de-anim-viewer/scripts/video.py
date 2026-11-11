#!/usr/bin/env python
"""Videos of viewer anims (M5): the frame schedule, the burned-in timeline overlay, MP4 through ffmpeg, animated WebP.

    import video as VD
    sched = VD.schedule(D=1.5, fps=30, loops=3)     # [{index, t_global, t, loop}]: t = (i / fps) mod D, exact times
    times, of = VD.unique_times(sched)              # the distinct poses to render, and frame -> pose index
    ev = VD.tag_events(timeline)                     # the reached tags of an M4 timeline summary (job 'timelines')
    VD.hits(ev, t_prev, t, D)                        # the tags inside (t_prev, t] (wrapping at the loop end)
    img = VD.overlay(png, info)                      # clip name, time, key, tag markers, the flash of a tag frame
    VD.encode_mp4(frame_dir, 'v_%05d.png', 30, out_mp4, ffmpeg)    # H.264 yuv420p, +faststart
    VD.encode_webp(images, out_webp, 30)            # Pillow, loop forever
    VD.mp4_boxes(out_mp4)                           # top-level boxes: faststart = moov before mdat

The frames are rendered headless at exact main-clock times (deterministic, not a real-time capture: bundle fidelity
export_frame_times M). ffmpeg comes ONLY from the device config: config/tool-paths.local.json tools.ffmpeg.path (the
key is in skill-library-audit/assets/tool-paths.example.json), or an explicit --ffmpeg path; a missing one is a clear
error (FfmpegMissing), never a search or a download. The colour conversion to yuv420p (BT.709, limited range) and the
WebP millisecond durations are approximations (fidelity video_encode A).
"""
from __future__ import annotations

import io
import json
import math
import os
import struct
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import sheets as S  # noqa: E402

EPS = 1e-9
FLASH_SECONDS = 0.1
LANE_SHORT = {'Attack': 'ATK', 'FootstepLeft': 'FL', 'FootstepRight': 'FR', 'SpecificSoundSet': 'SND',
              'Particles': 'PFX', 'WindEffect': 'WND', 'CameraShake': 'SHK', 'other': '?', 'overflow': 'OVF'}


class FfmpegMissing(RuntimeError):
    pass


# ---------------------------------------------------------------------------------------------------- ffmpeg
def ffmpeg_path(explicit=None, config=None) -> str:
    """the ffmpeg executable: `explicit`, else tools.ffmpeg.path of the device config. Raises FfmpegMissing (with the
    fix) when neither names an existing file; never searches PATH or downloads."""
    p = explicit or C.local_tool_path('ffmpeg', config)
    if not p:
        raise FfmpegMissing('ffmpeg is not configured: set tools.ffmpeg.path in config/tool-paths.local.json (the key '
                            'is in .claude/skills/skill-library-audit/assets/tool-paths.example.json; python '
                            'scripts/tools/local_env.py checks it) or pass --ffmpeg PATH. The PNG frames are kept.')
    if not Path(p).is_file():
        raise FfmpegMissing('ffmpeg not found at %s (tools.ffmpeg.path or --ffmpeg). The PNG frames are kept.' % p)
    return str(p)


def ffmpeg_version(ffmpeg) -> str | None:
    try:
        out = subprocess.run([ffmpeg, '-hide_banner', '-version'], capture_output=True, text=True, timeout=30,
                             **_no_window()).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    return out.splitlines()[0].strip() if out else None


def _no_window():
    return {'creationflags': 0x08000000} if os.name == 'nt' else {}        # CREATE_NO_WINDOW: no console flash


def mp4_command(ffmpeg, frame_dir, pattern, fps, out, crf=18, preset='medium') -> list:
    """the ffmpeg argument list: PNG sequence -> H.264 (libx264) yuv420p, BT.709 tags, even size, +faststart."""
    return [str(ffmpeg), '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '%g' % fps, '-start_number', '0',
            '-i', str(Path(frame_dir) / pattern),
            '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2,scale=out_color_matrix=bt709:out_range=tv,format=yuv420p',
            '-c:v', 'libx264', '-preset', preset, '-crf', str(crf), '-pix_fmt', 'yuv420p',
            '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'iec61966-2-1', '-color_range', 'tv',
            '-movflags', '+faststart', '-an', str(out)]


def encode_mp4(frame_dir, pattern, fps, out, ffmpeg, crf=18, preset='medium', timeout=600) -> dict:
    """run ffmpeg; {cmd, returncode, stderr, out, bytes, boxes, faststart}. The output folder must not be a
    repository (av_common.refuse_repo_path)."""
    out = C.refuse_repo_path(out, 'an export video')
    cmd = mp4_command(ffmpeg, frame_dir, pattern, fps, out, crf, preset)
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **_no_window())
    rec = {'cmd': cmd, 'returncode': r.returncode, 'stderr': (r.stderr or '')[-4000:], 'out': str(out)}
    if r.returncode == 0 and Path(out).is_file():
        rec['bytes'] = Path(out).stat().st_size
        rec['boxes'] = [b[0] for b in mp4_boxes(out)]
        rec['faststart'] = is_faststart(out)
    return rec


def probe(path, ffmpeg) -> dict:
    """codec, pixel format, size, frame count and rate of the first video stream: ffprobe beside ffmpeg when it is
    there, else {}."""
    fp = Path(ffmpeg).with_name('ffprobe' + Path(ffmpeg).suffix)
    if not fp.is_file():
        return {}
    try:
        r = subprocess.run([str(fp), '-v', 'error', '-select_streams', 'v:0', '-count_frames', '-show_entries',
                            'stream=codec_name,profile,pix_fmt,width,height,nb_read_frames,r_frame_rate,color_space,'
                            'color_range:format=duration', '-of', 'json', str(path)],
                           capture_output=True, text=True, timeout=120, **_no_window())
        d = json.loads(r.stdout or '{}')
    except (OSError, subprocess.SubprocessError, ValueError):
        return {}
    s = (d.get('streams') or [{}])[0]
    s['duration'] = (d.get('format') or {}).get('duration')
    return s


def mp4_boxes(path) -> list:
    """[(type, offset, size)] of the top-level ISO-BMFF boxes."""
    out = []
    with open(path, 'rb') as f:
        f.seek(0, 2)
        end = f.tell()
        off = 0
        while off + 8 <= end:
            f.seek(off)
            size, typ = struct.unpack('>I4s', f.read(8))
            if size == 1:
                size = struct.unpack('>Q', f.read(8))[0]
            elif size == 0:
                size = end - off
            if size < 8:
                break
            out.append((typ.decode('latin-1'), off, size))
            off += size
    return out


def is_faststart(path) -> bool:
    """moov before mdat: a player can start before the whole file has arrived."""
    types = [b[0] for b in mp4_boxes(path)]
    return 'moov' in types and 'mdat' in types and types.index('moov') < types.index('mdat')


def encode_webp(images, out, fps, quality=82, lossless=False) -> dict:
    """animated WebP through Pillow, looping forever; frame duration round(1000 / fps) ms (WebP keeps whole ms)."""
    out = C.refuse_repo_path(out, 'an export video')
    ims = [im.convert('RGB') if im.mode != 'RGB' else im for im in images]
    if not ims:
        raise ValueError('no frames')
    dur = int(round(1000.0 / fps))
    b = io.BytesIO()
    ims[0].save(b, 'WEBP', save_all=True, append_images=ims[1:], duration=dur, loop=0, quality=quality,
                lossless=lossless, method=4)
    C.write_bytes(out, b.getvalue(), 'an export video')
    return {'out': str(out), 'frames': len(ims), 'duration_ms': dur, 'bytes': len(b.getvalue()),
            'timing_error_ms_per_frame': round(dur - 1000.0 / fps, 4)}


# ---------------------------------------------------------------------------------------------------- the schedule
def loop_time(tg, D) -> tuple:
    """(t, loop) of global time tg on a clip of duration D that loops: t = tg mod D (0 for D <= 0)."""
    if not D or D <= 0:
        return 0.0, 0
    k = int(math.floor(tg / D + EPS))
    t = tg - k * D
    return (0.0 if t < EPS else t), k


def schedule(D, fps, loops=1) -> list:
    """the video frames: N = max(1, round(loops * D * fps)); frame i shows main time t = (i / fps) mod D. A clip
    without duration gives N = max(1, round(loops * fps)) frames of t = 0."""
    if fps <= 0:
        raise ValueError('fps must be positive')
    D = float(D or 0)
    n = max(1, int(round(loops * (D if D > 0 else 1.0) * fps)))
    out = []
    for i in range(n):
        tg = i / fps
        t, k = loop_time(tg, D)
        out.append({'index': i, 't_global': tg, 't': t, 'loop': k})
    return out


def unique_times(frames, key='t', digits=9) -> tuple:
    """(distinct values of `key` in first-seen order, per frame the index into them)."""
    seen, times, of = {}, [], []
    for f in frames:
        v = f[key] if not isinstance(key, (tuple, list)) else tuple(f[k] for k in key)
        r = round(v, digits) if not isinstance(v, tuple) else tuple(round(x, digits) for x in v)
        if r not in seen:
            seen[r] = len(times)
            times.append(v)
        of.append(seen[r])
    return times, of


def tag_events(timeline) -> list:
    """[{time, type, lane, role, fraction, footstep, attrs}] every reached tag occurrence of an M4 timeline summary
    (export/plan.js timelineSummary) inside [0, D], sorted by time."""
    if not timeline:
        return []
    D = timeline.get('D') or 0
    out = []
    for tg in timeline.get('tags') or []:
        for m in tg.get('reached') or []:
            if -1e-6 <= m <= D + 1e-6:
                out.append({'time': min(max(m, 0.0), D), 'type': tg['type'], 'lane': tg.get('lane') or 'other',
                            'role': tg.get('role'), 'fraction': tg.get('fraction'), 'footstep': tg.get('footstep'),
                            'attrs': tg.get('attrs') or {}, 'footprintbone': tg.get('footprintbone')})
    return sorted(out, key=lambda e: e['time'])


def hits(events, t_prev, t, D, first=False) -> list:
    """the events a frame covers: time in (t_prev, t]; across a loop end (t < t_prev) that is (t_prev, D] + [0, t].
    The first frame (first=True) covers [0, t]."""
    out = []
    for e in events:
        m = e['time']
        if first:
            ok = m <= t + 1e-9
        elif t >= t_prev - 1e-12:
            ok = t_prev + 1e-9 < m <= t + 1e-9
        else:
            ok = m > t_prev + 1e-9 or m <= t + 1e-9
        if ok:
            out.append(e)
    return out


def flash_plan(sched, events, D, fps, seconds=FLASH_SECONDS) -> list:
    """per frame: {hits (the events it covers), flash (0..1), flash_events}. A hit starts a flash of
    max(1, round(seconds * fps)) frames fading linearly; the strongest active flash wins."""
    n_fl = max(1, int(round(seconds * fps)))
    plan = []
    active = []                                               # (start frame, events)
    for i, f in enumerate(sched):
        h = hits(events, sched[i - 1]['t'] if i else 0.0, f['t'], D, first=(i == 0))
        if h:
            active.append((i, h))
        best, bev = 0.0, []
        for s0, ev in active:
            age = i - s0
            if age < n_fl:
                v = 1.0 - age / n_fl
                if v > best:
                    best, bev = v, ev
        active = [(s0, ev) for s0, ev in active if i - s0 < n_fl]
        plan.append({'hits': h, 'flash': round(best, 4), 'flash_events': bev})
    return plan


# ---------------------------------------------------------------------------------------------------- the overlay
def _rgb(lane):
    return S.LANE_COLOURS.get(lane, S.LANE_COLOURS['other'])


def overlay(img, info) -> Image.Image:
    """the frame with a title band on top, a timeline strip below and, on a tag frame, the flash.
    info: {title, subtitle, t, D, key, keys_of, fps_rounded, loop, loops, frame, frames, sides [str], events (tag_events),
    hits, flash (0..1), flash_events, fidelity (bundle block), strip_h}"""
    im = Image.open(img).convert('RGB') if not isinstance(img, Image.Image) else img.convert('RGB')
    W, H = im.size
    k = W / 640.0
    f_t, f_s, f_b = S.font(max(11, round(15 * k))), S.font(max(10, round(12 * k))), S.font(max(16, round(30 * k)))
    strip_h = info.get('strip_h') or max(104, int(round(136 * k)))
    out = Image.new('RGB', (W, H + strip_h), S.BG)
    out.paste(im, (0, 0))
    d = ImageDraw.Draw(out, 'RGBA')
    # title band
    band = max(22, int(round(28 * k)))
    d.rectangle([0, 0, W, band], fill=(0, 0, 0, 150))
    d.text((8, (band - f_t.size) // 2 if hasattr(f_t, 'size') else 4), info.get('title') or '', fill=S.ACC, font=f_t)
    fs = S.fidelity_summary(info.get('fidelity'))
    badge = ' '.join('%s%d' % (x, fs['counts'][x]) for x in 'MAUH')
    bx = W - 8 - S.text_w(d, badge, f_s)
    x = bx
    for part in badge.split(' '):
        d.text((x, (band - f_s.size) // 2 if hasattr(f_s, 'size') else 5), part, fill=S.FLAG_COLOURS[part[0]], font=f_s)
        x += S.text_w(d, part + ' ', f_s)
    # the flash of a tag frame
    fl = float(info.get('flash') or 0)
    if fl > 0 and info.get('flash_events'):
        e0 = info['flash_events'][0]
        col = _rgb(e0['lane'])
        bw = max(4, int(round(8 * k)))
        a = int(round(255 * fl))
        d.rectangle([0, 0, W - 1, H - 1], outline=col + (a,), width=bw)
        names = []
        for e in info['flash_events']:
            n = (e['type'] if e.get('role') == 'main' else '%s %s' % (e.get('role'), e['type'])).upper()
            n += ' @ %.3f s' % e['time']                     # the tag's own time (the frame may sit up to 1/fps later)
            if n not in names:
                names.append(n)
        label = ' + '.join(names)
        lw = S.text_w(d, label, f_b)
        ly = band + int(round(10 * k))
        d.rectangle([(W - lw) // 2 - 10, ly - 4, (W + lw) // 2 + 10, ly + f_b.size + 10], fill=(0, 0, 0, int(150 * fl)))
        d.text(((W - lw) // 2, ly), label, fill=col + (a,), font=f_b)
    # strip: text lines
    y = H + 6
    t, D = float(info.get('t') or 0), float(info.get('D') or 0)
    line1 = 't %.3f / %.3f s   key %s/%s @ %s fps   loop %d/%d   frame %d/%d' % (
        t, D, info.get('key', '-'), max(0, (info.get('keys_of') or 1) - 1), info.get('fps_rounded', '-'),
        (info.get('loop') or 0) + 1, info.get('loops') or 1, (info.get('frame') or 0) + 1, info.get('frames') or 1)
    d.text((8, y), line1, fill=S.FG, font=f_s)
    y += int(round(16 * k)) + 2
    sub = info.get('subtitle') or ''
    if sub:
        d.text((8, y), sub, fill=S.DIM, font=f_s)
        y += int(round(15 * k)) + 2
    for s in info.get('sides') or []:
        d.text((8, y), s, fill=S.DIM, font=f_s)
        y += int(round(15 * k)) + 2
    # strip: the bar
    x0, x1 = 10, W - 10
    by0 = H + strip_h - int(round(46 * k))
    by1 = H + strip_h - int(round(22 * k))
    d.rectangle([x0, by0, x1, by1], fill=(21, 23, 26), outline=(54, 58, 66))
    if D > 0:
        X = lambda tt: x0 + (x1 - x0) * min(max(tt / D, 0.0), 1.0)  # noqa: E731
        step = 0.1 if D <= 3 else 0.5
        n = int(math.floor(D / step + 1e-9))
        for j in range(n + 1):
            xx = X(j * step)
            major = j % 5 == 0
            d.line([xx, by1 - (8 if major else 4) * k, xx, by1], fill=(90, 96, 106), width=1)
            endw = S.text_w(d, '%.3f s' % D, f_s) + 8
            if major and xx + 2 + S.text_w(d, '%g' % round(j * step, 3), f_s) < x1 - endw:
                d.text((xx + 2, by1 + 1), '%g' % round(j * step, 3), fill=(110, 116, 126), font=f_s)
        d.text((x1 - S.text_w(d, '%.3f s' % D, f_s), by1 + 1), '%.3f s' % D, fill=(110, 116, 126), font=f_s)
        mid = (by0 + by1) / 2
        for e in info.get('events') or []:
            xx = X(e['time'])
            col = _rgb(e['lane'])
            ya, yb = (by0 + 2, mid) if e.get('role') == 'main' else (mid, by1 - 2)
            d.line([xx, ya, xx, yb], fill=col, width=max(2, int(round(3 * k))))
            lab = LANE_SHORT.get(e['lane'], e['type'][:3])
            d.text((xx + 3, by0 - f_s.size - 2 if hasattr(f_s, 'size') else by0 - 14), lab, fill=col, font=f_s)
        px = X(t)
        d.line([px, by0 - 3, px, by1 + 3], fill=(255, 255, 255), width=max(2, int(round(2 * k))))
    return out


def side_by_side(images, gap=4) -> Image.Image:
    """images next to each other (heights padded to the tallest), a thin gap between."""
    ims = [im.convert('RGB') for im in images]
    W = sum(im.width for im in ims) + gap * (len(ims) - 1)
    H = max(im.height for im in ims)
    out = Image.new('RGB', (W, H), S.BG)
    x = 0
    for im in ims:
        out.paste(im, (x, 0))
        x += im.width + gap
    return out


def even(im) -> Image.Image:
    """pad to even width and height (yuv420p needs both)."""
    W, H = im.size
    if W % 2 == 0 and H % 2 == 0:
        return im
    out = Image.new('RGB', (W + W % 2, H + H % 2), S.BG)
    out.paste(im, (0, 0))
    return out
