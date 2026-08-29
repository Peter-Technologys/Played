#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
import io, json, shutil
import cairosvg

ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / "assets/branding/otya_logo_master.svg"
NAVY = (3, 5, 22, 255)
WHITE = (255, 255, 255, 255)


def font(size: int, bold: bool = True):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def render_svg(size: int = 1024) -> Image.Image:
    png = cairosvg.svg2png(url=str(SVG), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def contain(img: Image.Image, size: tuple[int, int], scale: float = .82, bg=(0,0,0,0)) -> Image.Image:
    w, h = size
    canvas = Image.new("RGBA", size, bg)
    cp = img.copy()
    cp.thumbnail((int(w*scale), int(h*scale)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(cp, ((w-cp.width)//2, (h-cp.height)//2))
    return canvas


def save_png(img: Image.Image, path: Path, rgb: bool = False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if rgb:
        img = img.convert("RGB")
    img.save(path, "PNG", optimize=True)


def mono_logo(master: Image.Image, size=512):
    m = contain(master, (size,size), .84)
    a = m.getchannel("A")
    out = Image.new("RGBA", (size,size), (255,255,255,0))
    out.putalpha(a)
    return out


def launcher(master: Image.Image, size: int, scale=.76):
    return contain(master, (size,size), scale, NAVY)


def draw_gradient_text(canvas, xy, text, fnt, start=(67,133,255), end=(255,77,170)):
    mask = Image.new("L", canvas.size, 0)
    d = ImageDraw.Draw(mask)
    d.text(xy, text, font=fnt, fill=255)
    grad = Image.new("RGBA", canvas.size, (0,0,0,0))
    pix = grad.load()
    x0, y0 = xy
    bbox = d.textbbox(xy, text, font=fnt)
    width = max(1, bbox[2]-bbox[0])
    for x in range(max(0,bbox[0]), min(canvas.width,bbox[2]+1)):
        t = min(1,max(0,(x-bbox[0])/width))
        c = tuple(int(start[i]*(1-t)+end[i]*t) for i in range(3))
        ImageDraw.Draw(grad).line((x,bbox[1],x,bbox[3]), fill=c+(255,))
    grad.putalpha(mask)
    canvas.alpha_composite(grad)


def make_wordmark(master: Image.Image, width=1536, height=512):
    out = Image.new("RGBA", (width,height), (0,0,0,0))
    logo = contain(master, (height,height), .72)
    out.alpha_composite(logo, (0,0))
    d = ImageDraw.Draw(out)
    f = font(250, True)
    text = "TYA"  # Brand rule: symbol IS the O on the same line.
    bbox = d.textbbox((0,0), text, font=f)
    x = 465
    y = (height-(bbox[3]-bbox[1]))//2 - bbox[1]
    draw_gradient_text(out, (x,y), text, f, (43,178,255), (255,116,73))
    return out


def make_stacked(master: Image.Image, width=1024, height=1280):
    out = Image.new("RGBA", (width,height), (0,0,0,0))
    logo = contain(master, (900,900), .86)
    out.alpha_composite(logo, ((width-900)//2,30))
    d = ImageDraw.Draw(out)
    f = font(150, False)
    text="OTYA"
    box=d.textbbox((0,0),text,font=f)
    x=(width-(box[2]-box[0]))//2
    y=970
    d.text((x,y), text, font=f, fill=WHITE)
    return out


def make_splash(master: Image.Image, width=1080, height=1920):
    out=Image.new("RGBA",(width,height),NAVY)
    # ambient glow
    glow=Image.new("RGBA",out.size,(0,0,0,0))
    gd=ImageDraw.Draw(glow)
    gd.ellipse((170,380,910,1120),fill=(48,42,255,80))
    glow=glow.filter(ImageFilter.GaussianBlur(120))
    out=Image.alpha_composite(out,glow)
    logo=contain(master,(760,760),.86)
    out.alpha_composite(logo,((width-760)//2,420))
    d=ImageDraw.Draw(out)
    f=font(118,False)
    text="OTYA"
    box=d.textbbox((0,0),text,font=f)
    d.text(((width-(box[2]-box[0]))//2,1240),text,font=f,fill=(236,237,255,255))
    # floor glow
    floor=Image.new("RGBA",out.size,(0,0,0,0)); fd=ImageDraw.Draw(floor)
    fd.ellipse((240,1500,840,1585),fill=(115,35,255,95)); floor=floor.filter(ImageFilter.GaussianBlur(45))
    return Image.alpha_composite(out,floor)


def ai_frames(master: Image.Image):
    frames=[]
    for i,blur in enumerate((8,13,18,26),1):
        base=contain(master,(512,512),.72)
        a=base.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
        g=Image.new("RGBA",base.size,(95,45,255,0)); g.putalpha(a.point(lambda p:int(p*.55)))
        frame=Image.alpha_composite(g,base)
        if i==3:
            d=ImageDraw.Draw(frame)
            for ang,c in [(0,(48,213,255,255)),(70,(219,30,255,255)),(145,(255,98,55,255)),(225,(114,66,255,255)),(310,(255,197,47,255))]:
                import math
                r=210; x=256+int(math.cos(math.radians(ang))*r); y=256+int(math.sin(math.radians(ang))*r)
                d.ellipse((x-6,y-6,x+6,y+6),fill=c)
        frames.append(frame)
    return frames


def make_feature(master: Image.Image):
    w,h=1024,500
    out=Image.new("RGBA",(w,h),NAVY)
    # subtle colored arcs/background glow
    bg=Image.new("RGBA",(w,h),(0,0,0,0)); d=ImageDraw.Draw(bg)
    d.arc((-180,80,650,720),200,345,fill=(32,119,255,120),width=5)
    d.arc((400,-180,1250,660),15,155,fill=(255,48,155,100),width=5)
    bg=bg.filter(ImageFilter.GaussianBlur(4)); out=Image.alpha_composite(out,bg)
    logo=contain(master,(380,380),.82); out.alpha_composite(logo,(65,60))
    d=ImageDraw.Draw(out); f=font(185,True); sub=font(46,False)
    d.text((430,115),"TYA",font=f,fill=(245,246,255,255))
    d.text((432,320),"Your world. Your way.",font=sub,fill=(205,210,236,255))
    return out


def main():
    master=render_svg(1024)
    mono=mono_logo(master,512)
    wordmark=make_wordmark(master)
    stacked=make_stacked(master)

    # Flutter assets
    save_png(master, ROOT/"assets/icons/otya_logo_master.png")
    save_png(mono, ROOT/"assets/icons/otya_logo_white.png")
    save_png(wordmark, ROOT/"assets/icons/otya_wordmark.png")
    save_png(stacked, ROOT/"assets/icons/otya_logo_stacked.png")
    for i,frame in enumerate(ai_frames(master),1):
        save_png(frame, ROOT/f"assets/animations/otya_ai_thinking_{i:02d}.png")

    # Android drawables
    draw=ROOT/"android/app/src/main/res/drawable"
    save_png(contain(master,(512,512),.84), draw/"otya_logo.png")
    save_png(mono, draw/"otya_logo_white.png")
    save_png(wordmark, draw/"otya_wordmark.png")
    save_png(contain(master,(432,432),.64), draw/"ic_launcher_foreground.png")
    save_png(contain(master,(512,512),.72), draw/"otya_splash_logo.png")
    (draw/"otya_splash_background.xml").write_text('<?xml version="1.0" encoding="utf-8"?>\n<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="@color/otya_launcher_background"/></shape>\n')

    notif_sizes={"mdpi":24,"hdpi":36,"xhdpi":48,"xxhdpi":72,"xxxhdpi":96}
    for den,sz in notif_sizes.items():
        save_png(mono.resize((sz,sz),Image.Resampling.LANCZOS), ROOT/f"android/app/src/main/res/drawable-{den}/ic_notification.png")

    mip={"mdpi":48,"hdpi":72,"xhdpi":96,"xxhdpi":144,"xxxhdpi":192}
    for den,sz in mip.items():
        base=ROOT/f"android/app/src/main/res/mipmap-{den}"
        save_png(launcher(master,sz,.76),base/"ic_launcher.png",True)
        save_png(launcher(master,sz,.76),base/"ic_launcher_round.png",True)
        save_png(launcher(master,sz,.68),base/"ic_launcher_foreground.png",True)

    anydpi=ROOT/"android/app/src/main/res/mipmap-anydpi-v26"; anydpi.mkdir(parents=True,exist_ok=True)
    adaptive='''<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n  <background android:drawable="@color/otya_launcher_background"/>\n  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n</adaptive-icon>\n'''
    (anydpi/"ic_launcher.xml").write_text(adaptive); (anydpi/"ic_launcher_round.xml").write_text(adaptive)
    values=ROOT/"android/app/src/main/res/values"; values.mkdir(parents=True,exist_ok=True)
    (values/"otya_brand_colors.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>\n<resources>\n <color name="otya_launcher_background">#030516</color>\n <color name="otya_brand_navy">#030516</color>\n <color name="otya_brand_blue">#146BFF</color>\n <color name="otya_brand_violet">#6A19FF</color>\n <color name="otya_brand_magenta">#E81CFF</color>\n <color name="otya_brand_orange">#FF8A00</color>\n</resources>\n''')

    # Web/favicon/PWA
    web=ROOT/"web"; (web/"icons").mkdir(parents=True,exist_ok=True)
    for sz,name in [(16,"favicon-16x16.png"),(32,"favicon-32x32.png"),(48,"favicon-48x48.png"),(180,"apple-touch-icon.png")]:
        save_png(launcher(master,sz,.76),web/name,True)
    ico=launcher(master,48,.76).convert("RGB"); ico.save(web/"favicon.ico",format="ICO",sizes=[(16,16),(32,32),(48,48)])
    for sz in (192,512):
        save_png(launcher(master,sz,.76),web/"icons"/f"Icon-{sz}.png",True)
        save_png(launcher(master,sz,.64),web/"icons"/f"Icon-maskable-{sz}.png",True)

    # iOS AppIcon
    ios=ROOT/"ios/Runner/Assets.xcassets/AppIcon.appiconset"; ios.mkdir(parents=True,exist_ok=True)
    specs=[
      ("Icon-App-20x20@1x.png",20,1,"iphone"),("Icon-App-20x20@2x.png",20,2,"iphone"),("Icon-App-20x20@3x.png",20,3,"iphone"),
      ("Icon-App-29x29@1x.png",29,1,"iphone"),("Icon-App-29x29@2x.png",29,2,"iphone"),("Icon-App-29x29@3x.png",29,3,"iphone"),
      ("Icon-App-40x40@1x.png",40,1,"iphone"),("Icon-App-40x40@2x.png",40,2,"iphone"),("Icon-App-40x40@3x.png",40,3,"iphone"),
      ("Icon-App-60x60@2x.png",60,2,"iphone"),("Icon-App-60x60@3x.png",60,3,"iphone"),
      ("Icon-App-76x76@1x.png",76,1,"ipad"),("Icon-App-76x76@2x.png",76,2,"ipad"),("Icon-App-83.5x83.5@2x.png",83.5,2,"ipad"),
      ("Icon-App-1024x1024@1x.png",1024,1,"ios-marketing")]
    images=[]
    for fn,pt,sc,idiom in specs:
        px=int(round(pt*sc)); save_png(launcher(master,px,.76),ios/fn,True)
        images.append({"size":f"{pt}x{pt}","idiom":idiom,"filename":fn,"scale":f"{sc}x"})
    (ios/"Contents.json").write_text(json.dumps({"images":images,"info":{"version":1,"author":"xcode"}},indent=2))

    # Store assets
    store=ROOT/"store_assets"; store.mkdir(exist_ok=True)
    save_png(launcher(master,512,.76),store/"google_play_icon_512.png",True)
    save_png(launcher(master,1024,.76),store/"app_icon_master_1024.png",True)
    save_png(make_feature(master),store/"feature_graphic_1024x500.png",True)

    # Splash reference for design/testing
    save_png(make_splash(master),ROOT/"assets/branding/otya_splash_reference.png",True)
    print("OTYA brand assets generated successfully")


if __name__ == "__main__":
    main()
