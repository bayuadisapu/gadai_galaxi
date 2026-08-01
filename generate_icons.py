"""
generate_icons.py
Generate semua ukuran app icon Android dari logofix.jpeg
"""
from PIL import Image
import os

src = "logofix.jpeg"
img = Image.open(src).convert("RGBA")

# --- App Icon sizes (mipmap) ---
mipmap_sizes = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

base = r"android\app\src\main\res"

for folder, size in mipmap_sizes.items():
    out_dir = os.path.join(base, folder)
    os.makedirs(out_dir, exist_ok=True)
    resized = img.resize((size, size), Image.LANCZOS)
    # ic_launcher - full color (app icon di launcher)
    resized.save(os.path.join(out_dir, "ic_launcher.png"))
    print(f"[OK] {folder}/ic_launcher.png ({size}x{size})")

# --- Notification icon: harus putih + transparan (drawable) ---
# Android notification icon harus monochrome putih
drawable_dir = os.path.join(base, "drawable")
os.makedirs(drawable_dir, exist_ok=True)

# Resize ke 96x96 untuk drawable
notif_size = 96
notif_img = img.resize((notif_size, notif_size), Image.LANCZOS)

# Konversi ke monochrome: alpha channel dari brightness gambar asli, warna putih
r, g, b, a = notif_img.split()
import PIL.ImageOps
# Buat grayscale lalu threshold jadi mask
gray = notif_img.convert("L")
# Buat canvas putih dengan alpha = grayscale (bagian gelap jadi transparan, terang jadi putih)
notif_out = Image.new("RGBA", (notif_size, notif_size), (0, 0, 0, 0))
white_layer = Image.new("RGBA", (notif_size, notif_size), (255, 255, 255, 255))
# Gunakan grayscale sebagai alpha mask (invert karena logo gelap di background putih)
from PIL import ImageOps
mask = ImageOps.invert(gray)
notif_out.paste(white_layer, mask=mask)
notif_out.save(os.path.join(drawable_dir, "ic_notification.png"))
print(f"[OK] drawable/ic_notification.png ({notif_size}x{notif_size})")

# Juga copy ke drawable-v21
drawable_v21 = os.path.join(base, "drawable-v21")
os.makedirs(drawable_v21, exist_ok=True)
notif_out.save(os.path.join(drawable_v21, "ic_notification.png"))
print(f"[OK] drawable-v21/ic_notification.png")

# Juga simpan ic_launcher.png di drawable untuk referensi FCM
launcher_192 = img.resize((192, 192), Image.LANCZOS)
launcher_192.save(os.path.join(drawable_dir, "ic_launcher.png"))
print(f"[OK] drawable/ic_launcher.png (192x192)")

print("\n=== Semua icon berhasil di-generate! ===")
