# Genera texturas PBR procedurales (sin descargas). Ejecutar: python3 tools/gen_textures.py
import numpy as np
from PIL import Image
import os
OUT = os.path.join(os.path.dirname(__file__), '..', 'textures')
N = 512

def fbm(beta, seed, shape=(N, N)):
    r = np.random.default_rng(seed)
    w = r.standard_normal(shape)
    F = np.fft.fft2(w)
    fy = np.fft.fftfreq(shape[0])[:, None]; fx = np.fft.fftfreq(shape[1])[None, :]
    f = np.sqrt(fx**2 + fy**2); f[0, 0] = 1.0
    F = F / (f ** (beta / 2.0)); F[0, 0] = 0
    a = np.real(np.fft.ifft2(F))
    return (a - a.min()) / (a.max() - a.min())

def fbm1(beta, seed, n=N):
    r = np.random.default_rng(seed)
    F = np.fft.fft(r.standard_normal(n))
    f = np.abs(np.fft.fftfreq(n)); f[0] = 1.0
    F = F / (f ** (beta / 2.0)); F[0] = 0
    a = np.real(np.fft.ifft(F))
    return (a - a.min()) / (a.max() - a.min())

def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(h)
    l = np.sqrt(nx**2 + ny**2 + nz**2)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)

def save(name, albedo=None, normal=None, rough=None):
    if albedo is not None:
        Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).save(f'{OUT}/{name}_albedo.png', optimize=True)
    if normal is not None:
        Image.fromarray(normal).save(f'{OUT}/{name}_normal.png', optimize=True)
    if rough is not None:
        Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), 'L').save(f'{OUT}/{name}_rough.png', optimize=True)

def blur(a, k=1):
    out = a.copy()
    for _ in range(k):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out

yy, xx = np.mgrid[0:N, 0:N]

# ---------- chapa acanalada verde-azulada con óxido y tornillos ----------
ridge = np.clip(np.sin(2 * np.pi * xx / (N / 8.0)) * 1.5, -1, 1)
h = ridge * 0.5 + 0.5
rust = np.zeros((N, N))
for row in (40, 296):
    for k in range(8):
        cx, cy = 16 + 64 * k, row
        d = np.sqrt((xx - cx)**2 + (yy - cy)**2)
        h -= np.clip(1 - d / 5.0, 0, 1) * 0.5
        streak = np.exp(-((xx - cx) / 4.0)**2) * np.clip((yy - cy) / 120.0, 0, 1) * np.clip(1 - (yy - cy) / 160.0, 0, 1) * (yy > cy)
        rust += streak * 0.8
col1 = fbm1(2.2, 3); vfade = fbm1(2.2, 4)
rust += (np.clip((col1 - 0.62) * 5, 0, 1)[None, :] * np.clip(vfade * 1.4 - 0.2, 0, 1)[:, None]) * 0.7
rust = np.clip(blur(rust, 1), 0, 1)
n1, n2 = fbm(2.2, 1), fbm(3.0, 2)
base = np.array([0.15, 0.42, 0.40])
alb = base[None, None, :] * (0.78 + 0.45 * n1[..., None]) * (0.72 + 0.28 * h[..., None])
alb = alb * (1 - 0.55 * rust[..., None]) + np.array([0.36, 0.19, 0.09])[None, None, :] * 0.55 * rust[..., None]
alb *= (1 - 0.6 * np.clip(1 - np.sqrt(0) , 0, 1)) if False else 1
rough = 0.38 + 0.3 * n2 + 0.3 * rust
save('wall', alb, normal_from_height(h + 0.05 * fbm(1.2, 5), 22), rough)

# ---------- piso de concreto pulido con manchas y grietas ----------
f1 = fbm(2.0, 10); st = fbm(3.0, 11); gr = fbm(1.0, 12)
mask = np.clip((st - 0.60) * 4, 0, 1)
alb = np.array([0.70, 0.68, 0.63])[None, None, :] * (0.86 + 0.26 * f1[..., None]) * (1 - 0.35 * mask[..., None]) * (0.95 + 0.1 * gr[..., None])
crack = np.zeros((N, N)); r = np.random.default_rng(13)
for _ in range(7):
    x, y = r.integers(0, N), r.integers(0, N); a = r.uniform(0, 6.28)
    for _ in range(140):
        a += r.normal(0, 0.35); x = (x + int(round(np.cos(a) * 2))) % N; y = (y + int(round(np.sin(a) * 2))) % N
        crack[y, x] = 1
crack = np.clip(blur(crack, 1) * 3, 0, 1)
alb *= (1 - 0.45 * crack[..., None])
hh = 0.5 * fbm(1.2, 14) + 0.2 * gr - 0.5 * crack
save('floor', alb, normal_from_height(hh, 14), 0.5 + 0.35 * fbm(2.5, 15))

# ---------- concreto oscuro mojado (tanques) ----------
f1 = fbm(2.2, 20); wet = fbm1(2.0, 21); vf = fbm1(2.4, 22)
streak = blur(np.clip((wet - 0.5) * 3, 0, 1)[None, :] * np.clip(0.5 + 0.5 * vf, 0, 1)[:, None], 3)
alg = np.clip((fbm(3.0, 23) - 0.66) * 4, 0, 1)
alb = np.array([0.27, 0.285, 0.28])[None, None, :] * (0.8 + 0.4 * f1[..., None]) * (1 - 0.18 * streak[..., None])
alb += np.array([0.0, 0.035, 0.0])[None, None, :] * alg[..., None]
save('dconc', alb, normal_from_height(0.6 * fbm(1.3, 24) + 0.4 * f1, 12), 0.45 + 0.35 * (1 - streak) * fbm(2.5, 25))

# ---------- estuco beige (oficina) ----------
f1 = fbm(2.0, 30); sp = np.random.default_rng(31).random((N, N))
alb = np.array([0.72, 0.66, 0.52])[None, None, :] * (0.9 + 0.2 * f1[..., None]) * (0.96 + 0.06 * sp[..., None])
save('stucco', alb, normal_from_height(0.6 * fbm(1.5, 32) + 0.4 * sp, 10), 0.8 + 0.15 * fbm(2, 33))

# ---------- madera (tableros y escritorio) ----------
w = fbm(2.5, 40); grain = 0.5 + 0.5 * np.sin(2 * np.pi * (yy / N * 30 + 2.5 * w))
plank = (yy // 128); tone = np.random.default_rng(41).random(8)[plank]
seam = ((yy % 128) < 2).astype(float)
dark, light = np.array([0.36, 0.20, 0.08]), np.array([0.62, 0.42, 0.22])
t = np.clip(0.35 * grain + 0.65 * tone, 0, 1)[..., None]
alb = (dark[None, None, :] * (1 - t) + light[None, None, :] * t) * (1 - 0.6 * seam[..., None])
save('wood', alb, normal_from_height(grain * 0.3 - seam * 0.8, 10), 0.55 + 0.2 * fbm(2, 42))

# ---------- normal del agua ----------
hw = fbm(2.4, 50) + 0.5 * fbm(1.8, 51)
Image.fromarray(normal_from_height(hw, 40)).save(f'{OUT}/water_normal.png', optimize=True)

# ---------- fondo de follaje visto por las ventanas (emisivo) ----------
S = (256, 1024)
leaves = fbm(1.6, 60, S); sky = fbm(3.0, 61, S); g = fbm(1.4, 62, S)
mask = leaves > 0.5
green = np.stack([0.14 + 0.2 * g, 0.38 + 0.4 * g, 0.10 + 0.12 * g], -1)
skyc = np.stack([0.80 + 0 * sky, 0.90 + 0 * sky, 1.0 + 0 * sky], -1) * (0.9 + 0.2 * sky[..., None])
img = np.where(mask[..., None], green * 1.1, skyc)
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(f'{OUT}/foliage_albedo.png', optimize=True)
print('ok')
