#!/usr/bin/env python3
"""
Passage 기획 프로토타입(Claude 아티팩트 "Bundled Page" HTML) 디코더.

기획은 앞으로도 Claude 아티팩트를 번들한 단일 HTML(~280KB, <title>Bundled Page</title>)로
전달된다. 이 형식을 분석하는 절차를 자동화한다.

구조:
  - 한 줄에 JSON 리소스 맵 {uuid: {mime, compressed, data(base64)}}.
    · text/javascript 3개 = React·ReactDOM·아티팩트 로더(런타임) → 앱 로직 아님(무시).
    · font/woff2 = 폰트.
  - 실제 앱 UI는 그 다음 긴 줄의 "JSON 문자열로 인코딩된 렌더링 HTML"(raw 한글)에 있다.
    단, 인터랙티브(Vue) 앱이라 이 정적 HTML에는 초기 화면 1개만 들어있다.

전체 화면·네비게이션은 브라우저로 확인해야 한다(이 스크립트가 뽑은 HTML을 로컬 서버로 서빙):
    cd <out_dir> && python3 -m http.server 8777
    # 브라우저에서 http://127.0.0.1:8777/<원본 html 파일명>
    # (file:// 은 차단되므로 반드시 http 서버로. iPhone 크기로 보고, 탭·버튼을 눌러 화면 전환)

사용법:
    python3 scripts/decode-prototype.py "~/Downloads/Passage App.html" [out_dir]
"""
import sys
import os
import re
import json
import base64
import gzip
import html as htmllib


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    src_path = os.path.expanduser(sys.argv[1])
    out = sys.argv[2] if len(sys.argv) > 2 else "prototype_decoded"
    os.makedirs(out, exist_ok=True)

    with open(src_path, encoding="utf-8") as f:
        raw = f.read()

    # 1) 리소스 맵: {"uuid": {"mime":..,"compressed":..,"data":..}} 형태의 긴 줄.
    for line in raw.splitlines():
        s = line.strip()
        if s.startswith('{"') and '"mime"' in s and '"data"' in s:
            try:
                obj = json.loads(s)
            except json.JSONDecodeError:
                continue
            for key, v in obj.items():
                data = base64.b64decode(v["data"])
                if v.get("compressed"):
                    try:
                        data = gzip.decompress(data)
                    except OSError:
                        pass  # 압축 표기와 달리 평문일 수 있음
                ext = {"text/javascript": "js", "font/woff2": "woff2"}.get(v.get("mime"), "bin")
                path = os.path.join(out, f"{key[:8]}.{ext}")
                with open(path, "wb") as fp:
                    fp.write(data)
                print(f"resource {key[:8]}  mime={v.get('mime'):20s} -> {path} ({len(data)} bytes)")
            break

    # 2) 렌더링된 앱 HTML: JSON 문자열로 인코딩된 "<!DOCTYPE html>..." 줄.
    for line in raw.splitlines():
        s = line.strip()
        if s.startswith('"<!DOCTYPE') or s.startswith('"<!doctype'):
            try:
                app_html = json.loads(s)
            except json.JSONDecodeError:
                app_html = json.loads(s[: s.rindex('"') + 1])
            html_path = os.path.join(out, "rendered_app.html")
            with open(html_path, "w", encoding="utf-8") as fp:
                fp.write(app_html)
            print(f"rendered app HTML -> {html_path} ({len(app_html)} chars)")

            # 3) 텍스트 콘텐츠(화면 문구) — 인접 중복 제거.
            body = re.sub(r"<(script|style)[\s\S]*?</\1>", " ", app_html)
            fragments = [htmllib.unescape(t).strip() for t in re.findall(r">([^<>]+)<", body)]
            clean, prev = [], None
            for t in fragments:
                if t and t != prev:
                    clean.append(t)
                    prev = t
            txt_path = os.path.join(out, "screen_text.txt")
            with open(txt_path, "w", encoding="utf-8") as fp:
                fp.write("\n".join(clean))
            print(f"screen text -> {txt_path} ({len(clean)} fragments)")
            break

    # 4) 인터랙티브 확인 안내 — 원본 HTML을 out에 복사해두면 바로 서빙 가능.
    basename = os.path.basename(src_path)
    dst = os.path.join(out, basename)
    if os.path.abspath(src_path) != os.path.abspath(dst):
        with open(src_path, "rb") as a, open(dst, "wb") as b:
            b.write(a.read())
    print("\n인터랙티브 화면·네비게이션 확인:")
    print(f"  cd {out} && python3 -m http.server 8777")
    print(f"  브라우저: http://127.0.0.1:8777/{basename}")
    print("  (file:// 차단 → http 서버 필수. 정적 HTML엔 초기 화면만, 나머지는 클릭으로 전환)")


if __name__ == "__main__":
    main()
