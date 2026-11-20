import struct
import os
import sys

def build_icns(iconset_dir, output_icns_path):
    chunks = []
    
    mapping = [
        ("icon_16x16@2x.png", b"ic11"), # 32x32
        ("icon_32x32@2x.png", b"ic12"), # 64x64
        ("icon_128x128.png", b"ic07"),   # 128x128
        ("icon_128x128@2x.png", b"ic13"),# 256x256
        ("icon_256x256.png", b"ic08"),   # 256x256
        ("icon_256x256@2x.png", b"ic14"),# 512x512
        ("icon_512x512.png", b"ic09"),   # 512x512
        ("icon_512x512@2x.png", b"ic10") # 1024x1024
    ]
    
    for filename, chunk_type in mapping:
        path = os.path.join(iconset_dir, filename)
        if os.path.exists(path):
            with open(path, "rb") as f:
                data = f.read()
            chunk_len = len(data) + 8
            chunks.append(chunk_type + struct.pack(">I", chunk_len) + data)
    
    body = b"".join(chunks)
    header = b"icns" + struct.pack(">I", len(body) + 8)
    
    with open(output_icns_path, "wb") as f:
        f.write(header + body)
    
    print(f"Generated ICNS with {len(chunks)} resolution chunks at {output_icns_path}")

if __name__ == "__main__":
    iconset = sys.argv[1] if len(sys.argv) > 1 else "/tmp/Flow.iconset"
    out = sys.argv[2] if len(sys.argv) > 2 else "Resources/AppIcon.icns"
    build_icns(iconset, out)
