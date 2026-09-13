"""PrintWindow-based capture of the AoE3DE window (GDI screen grabs return black in fullscreen)."""
import ctypes, ctypes.wintypes as w, sys, time
from PIL import Image
u = ctypes.windll.user32; g = ctypes.windll.gdi32
class BI(ctypes.Structure):
    _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_int32),('biHeight',ctypes.c_int32),('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('a',ctypes.c_int32),('b',ctypes.c_int32),('c',ctypes.c_uint32),('d',ctypes.c_uint32)]
def shot(path, crop=None):
    h = u.FindWindowW(None, 'Age of Empires III: Definitive Edition')
    r = w.RECT(); u.GetClientRect(h, ctypes.byref(r)); W, H = r.right, r.bottom
    hdc = u.GetDC(0); mdc = g.CreateCompatibleDC(hdc); bmp = g.CreateCompatibleBitmap(hdc, W, H); g.SelectObject(mdc, bmp)
    u.PrintWindow(h, mdc, 2)
    bi = BI(ctypes.sizeof(BI), W, -H, 1, 32, 0, 0, 0,0,0,0); buf = ctypes.create_string_buffer(W*H*4)
    g.GetDIBits(mdc, bmp, 0, H, buf, ctypes.byref(bi), 0)
    g.DeleteObject(bmp); g.DeleteDC(mdc); u.ReleaseDC(0, hdc)
    im = Image.frombuffer('RGBA', (W, H), buf.raw, 'raw', 'BGRA', 0, 1).convert('RGB')
    if crop: im = im.crop(crop)
    im.save(path); return path
def px(x, y):
    h = u.FindWindowW(None, 'Age of Empires III: Definitive Edition')
    r = w.RECT(); u.GetClientRect(h, ctypes.byref(r)); W, H = r.right, r.bottom
    hdc = u.GetDC(0); mdc = g.CreateCompatibleDC(hdc); bmp = g.CreateCompatibleBitmap(hdc, W, H); g.SelectObject(mdc, bmp)
    u.PrintWindow(h, mdc, 2); c = g.GetPixel(mdc, x, y)
    g.DeleteObject(bmp); g.DeleteDC(mdc); u.ReleaseDC(0, hdc)
    return (c & 0xff, (c >> 8) & 0xff, (c >> 16) & 0xff)
if __name__ == '__main__':
    if sys.argv[1] == 'shot': print(shot(sys.argv[2]))
    elif sys.argv[1] == 'px': print(px(int(sys.argv[2]), int(sys.argv[3])))

def shot_ok(path, crop=None, tries=6, wait=2.0):
    """PrintWindow is intermittent while the game redraws: retry until the frame is not black."""
    from PIL import Image
    for i in range(tries):
        shot(path, crop)
        im = Image.open(path).convert('L').resize((128, 64)); data = list(im.get_flattened_data()) if hasattr(im, 'get_flattened_data') else list(im.getdata())
        if sum(1 for v in data if v > 10) > len(data) // 10: return path
        time.sleep(wait)
    return None
