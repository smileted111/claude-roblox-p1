"""docs/GDD.md 를 단일 HTML 파일(docs/GDD.html)로 변환한다.

사용법: pip install markdown && python3 tools/build_gdd_html.py
"""
import re
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "GDD.md"
OUT = ROOT / "docs" / "GDD.html"

CSS = """
:root{--bg:#f7f7f8;--panel:#fff;--text:#1d1d22;--muted:#5f6170;--line:#e3e4ea;
--accent:#c8323c;--accent-soft:#fbe9ea;--code:#f1f2f5;--th:#f3f4f7;--ok:#1f7a4d;--ok-soft:#e5f4ec}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#121317;--panel:#1a1b21;
--text:#e8e9ee;--muted:#9a9cab;--line:#2c2e37;--accent:#ff5d66;--accent-soft:#3a1f23;--code:#23252d;
--th:#21232b;--ok:#5fd39a;--ok-soft:#173326}}
:root[data-theme="dark"]{--bg:#121317;--panel:#1a1b21;--text:#e8e9ee;--muted:#9a9cab;--line:#2c2e37;
--accent:#ff5d66;--accent-soft:#3a1f23;--code:#23252d;--th:#21232b;--ok:#5fd39a;--ok-soft:#173326}
*{box-sizing:border-box}
html{scroll-behavior:smooth;scroll-padding-top:16px}
body{margin:0;background:var(--bg);color:var(--text);line-height:1.7;font-size:15px;
font-family:"Pretendard","Apple SD Gothic Neo","Malgun Gothic","Noto Sans KR",system-ui,sans-serif;
word-break:keep-all;overflow-wrap:anywhere}
.layout{display:grid;grid-template-columns:260px minmax(0,1fr);max-width:1240px;margin:0 auto}
nav.toc{position:sticky;top:0;height:100vh;overflow-y:auto;padding:28px 18px;border-right:1px solid var(--line)}
nav.toc .brand{font-weight:800;font-size:17px;margin-bottom:4px}
nav.toc .sub{color:var(--muted);font-size:12px;margin-bottom:18px}
nav.toc ul{list-style:none;margin:0;padding:0}
nav.toc li a{display:block;padding:5px 10px;border-radius:6px;color:var(--muted);text-decoration:none;font-size:13.5px}
nav.toc li a:hover,nav.toc li a.active{background:var(--accent-soft);color:var(--accent)}
nav.toc li li a{padding-left:24px;font-size:12.5px}
main{padding:40px 48px 80px;min-width:0}
.hero{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:28px 30px;margin-bottom:28px;
border-top:4px solid var(--accent)}
.hero .kicker{color:var(--accent);font-weight:700;font-size:12px;letter-spacing:.12em}
.hero h1{margin:6px 0 8px;font-size:32px;line-height:1.3}
.hero p{margin:0;color:var(--muted)}
section.doc h1{display:none}
h2{font-size:22px;margin:44px 0 14px;padding-bottom:8px;border-bottom:2px solid var(--line)}
h3{font-size:17px;margin:28px 0 10px}
h4{font-size:15px;margin:22px 0 8px;color:var(--accent)}
a{color:var(--accent)}
.table-wrap{overflow-x:auto;margin:12px 0 18px;border:1px solid var(--line);border-radius:10px;background:var(--panel)}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{padding:9px 12px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
th{background:var(--th);font-weight:700;white-space:nowrap}
tr:last-child td{border-bottom:0}
td:first-child{white-space:nowrap}
pre{background:var(--code);border:1px solid var(--line);border-radius:10px;padding:14px 16px;overflow-x:auto;font-size:13px;line-height:1.55}
code{font-family:ui-monospace,"SF Mono",Menlo,Consolas,monospace;font-size:.92em}
:not(pre)>code{background:var(--code);padding:1px 6px;border-radius:5px}
blockquote{margin:14px 0;padding:10px 16px;border-left:4px solid var(--accent);background:var(--accent-soft);border-radius:0 8px 8px 0}
hr{display:none}
ul,ol{padding-left:22px}
.tag{display:inline-block;padding:0 7px;border-radius:999px;font-size:12px;font-weight:700;line-height:1.7;vertical-align:1px}
.tag.rec{background:var(--accent-soft);color:var(--accent)}
.tag.fix{background:var(--ok-soft);color:var(--ok)}
.theme-btn{margin-top:18px;background:none;border:1px solid var(--line);color:var(--muted);border-radius:8px;padding:6px 10px;cursor:pointer;font:inherit;font-size:12px}
@media (max-width:900px){.layout{display:block}nav.toc{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line);padding:18px 16px}
nav.toc li li{display:none}main{padding:24px 16px 60px}.hero{padding:22px 18px}.hero h1{font-size:26px}}
@media print{nav.toc{display:none}.layout{display:block}main{padding:0}.table-wrap{overflow:visible}}
"""

JS = """
(function(){
  var root=document.documentElement,btn=document.getElementById('theme');
  try{var t=localStorage.getItem('gdd-theme');if(t)root.setAttribute('data-theme',t);}catch(e){}
  btn&&btn.addEventListener('click',function(){
    var dark=root.getAttribute('data-theme')==='dark'||(!root.getAttribute('data-theme')&&matchMedia('(prefers-color-scheme: dark)').matches);
    var n=dark?'light':'dark';root.setAttribute('data-theme',n);try{localStorage.setItem('gdd-theme',n);}catch(e){}
  });
  var links=[].slice.call(document.querySelectorAll('nav.toc a'));
  var heads=links.map(function(a){return document.getElementById(decodeURIComponent(a.hash.slice(1)));}).filter(Boolean);
  if('IntersectionObserver' in window){
    var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){
      links.forEach(function(a){a.classList.toggle('active',decodeURIComponent(a.hash.slice(1))===e.target.id);});}});},
      {rootMargin:'0px 0px -75% 0px'});
    heads.forEach(function(h){io.observe(h);});
  }
})();
"""


def slugify(value, separator):
    value = re.sub(r"[^\w\s-]", "", value).strip().lower()
    return re.sub(r"[\s]+", separator, value) or "section"


def main():
    text = SRC.read_text(encoding="utf-8")
    md = markdown.Markdown(
        extensions=["tables", "fenced_code", "toc", "sane_lists"],
        extension_configs={"toc": {"toc_depth": "2-3", "slugify": slugify}},
    )
    body = md.convert(text)
    title_m = re.search(r"^# (.+)$", text, re.M)
    title = title_m.group(1) if title_m else "게임 기획서"
    ver_m = re.search(r"\| 문서 버전 \| (.+?) \|", text)
    date_m = re.search(r"\| 작성일 \| (.+?) \|", text)
    meta = " · ".join(m.group(1) for m in (ver_m, date_m) if m)

    body = re.sub(r"<table>", '<div class="table-wrap"><table>', body)
    body = body.replace("</table>", "</table></div>")
    body = re.sub(r"<strong>\[추천\]</strong>|\[추천\]", '<span class="tag rec">추천</span>', body)
    body = re.sub(r"<strong>\[확정\]</strong>|\[확정\]", '<span class="tag fix">확정</span>', body)

    toc = re.sub(r"\s*\[(추천|확정)\]", "", md.toc)
    game, _, rest = title.partition("—")
    html = f"""<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>라스트 서바이벌 기획서</title>
<style>{CSS}</style>
</head>
<body>
<div class="layout">
<nav class="toc">
<div class="brand">{game.strip()}</div>
<div class="sub">{rest.strip() or "게임 기획서"} · {meta}</div>
{toc}
<button class="theme-btn" id="theme" type="button">밝게 / 어둡게</button>
</nav>
<main>
<header class="hero">
<div class="kicker">GAME DESIGN DOCUMENT</div>
<h1>{game.strip()}</h1>
<p>{meta} · 원본: docs/GDD.md</p>
</header>
<section class="doc">
{body}
</section>
</main>
</div>
<script>{JS}</script>
</body>
</html>
"""
    OUT.write_text(html, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({len(html):,} bytes)")


if __name__ == "__main__":
    main()
