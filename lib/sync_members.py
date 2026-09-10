#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tool cập nhật danh sách members từ file text vào quan_info.json
Hỗ trợ cả chạy trực tiếp hoặc import như một module.
"""

import os
import sys
import json
import re
import shutil
from pathlib import Path

# Đảm bảo console Windows in tiếng Việt UTF-8 không bị lỗi charmap
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


def sync_members(
    txt_path: str = None,
    json_path: str = None,
    backup: bool = True
) -> bool:
    # Tự động tìm thư mục chứa các file dữ liệu
    base_dir = Path(__file__).resolve().parent
    if (base_dir / "File Data Thanh Vien.txt").exists():
        project_lib = base_dir
    elif (base_dir / "lib" / "File Data Thanh Vien.txt").exists():
        project_lib = base_dir / "lib"
    elif (base_dir.parent / "lib" / "File Data Thanh Vien.txt").exists():
        project_lib = base_dir.parent / "lib"
    else:
        project_lib = Path(r"E:\FlutterWorkplace\MiSaigon\lib")

    if not txt_path:
        txt_path = project_lib / "File Data Thanh Vien.txt"
    else:
        txt_path = Path(txt_path)

    if not json_path:
        json_path = project_lib / "quan_info.json"
    else:
        json_path = Path(json_path)

    print(f"[1] Đang đọc file thành viên: {txt_path}")
    if not txt_path.exists():
        print(f"[-] Lỗi: Không tìm thấy file nguồn: {txt_path}")
        return False

    # Đọc nội dung file text (thử utf-8-sig rồi utf-8)
    lines = []
    for enc in ["utf-8-sig", "utf-8", "utf-16", "cp1258"]:
        try:
            with open(txt_path, "r", encoding=enc) as f:
                lines = [line.strip("\r\n") for line in f if line.strip()]
            break
        except (UnicodeDecodeError, UnicodeError):
            continue

    if not lines:
        print("[-] File thành viên rỗng hoặc không đọc được!")
        return False

    # Phát hiện delimiter: tab (\t), phẩy (,), hoặc chấm phẩy (;)
    first_line = lines[0]
    if "\t" in first_line:
        delimiter = "\t"
    elif "," in first_line:
        delimiter = ","
    elif ";" in first_line:
        delimiter = ";"
    else:
        delimiter = "\t"

    header_tokens = [h.strip() for h in first_line.split(delimiter)]

    col_khach = 0
    col_nfc = -1

    for idx, h in enumerate(header_tokens):
        h_clean = h.lower().replace("_", " ").strip()
        if "khách" in h_clean or "khach" in h_clean:
            col_khach = idx
        elif "nfc" in h_clean:
            col_nfc = idx

    print(f"    - Cột Mã khách: index {col_khach} ('{header_tokens[col_khach]}')")
    if col_nfc != -1:
        print(f"    - Cột Mã NFC:   index {col_nfc} ('{header_tokens[col_nfc]}')")
    else:
        print("    - [!] Cảnh báo: Không tìm thấy tiêu đề cột NFC trong header, mặc định lấy cột cuối.")
        col_nfc = len(header_tokens) - 1

    # Trích xuất dữ liệu members
    new_members = []
    for line_idx, line in enumerate(lines[1:], start=2):
        tokens = [t.strip() for t in line.split(delimiter)]
        if col_khach >= len(tokens):
            continue

        ma_khach = tokens[col_khach]
        if not ma_khach:
            continue

        ma_nfc_list = []
        if col_nfc < len(tokens):
            nfc_raw = tokens[col_nfc]
            if nfc_raw:
                ma_nfc_list = [c.strip() for c in re.split(r"[,;]+", nfc_raw) if c.strip()]

        new_members.append({
            "ma_khach": ma_khach,
            "ma_nfc": ma_nfc_list
        })

    print(f"[2] Đã trích xuất {len(new_members)} thành viên:")
    for m in new_members:
        print(f"    + {m['ma_khach']}: {m['ma_nfc']}")

    # Đọc và cập nhật quan_info.json
    print(f"\n[3] Đang cập nhật vào file: {json_path}")
    if not json_path.exists():
        print(f"[-] Lỗi: Không tìm thấy file đích: {json_path}")
        return False

    with open(json_path, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"[-] Lỗi cú pháp JSON trong file {json_path}: {e}")
            return False

    # Sao lưu file gốc trước khi ghi đè
    if backup:
        backup_path = json_path.with_suffix(".json.bak")
        shutil.copy2(json_path, backup_path)
        print(f"    - Đã tạo bản sao lưu an toàn: {backup_path.name}")

    # Ghi đè trường members
    data["members"] = new_members

    # Format JSON đẹp mắt
    json_text = json.dumps(data, indent=2, ensure_ascii=False)

    # Định dạng mảng ma_nfc gọn gàng trên 1 dòng
    def _format_nfc_inline(m):
        prefix = m.group(1)
        body = m.group(2)
        items = re.findall(r'"[^"]*"', body)
        if not items:
            return f"{prefix}[]"
        return f'{prefix}[ ' + ", ".join(items) + " ]"

    json_text = re.sub(r'("ma_nfc":\s*)\[([\s\S]*?)\]', _format_nfc_inline, json_text)

    with open(json_path, "w", encoding="utf-8") as f:
        f.write(json_text + "\n")

    print("[4] Cập nhật hoàn tất thành công!\n")
    return True


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Tool đồng bộ thành viên từ file TXT vào quan_info.json")
    parser.add_argument("--txt", default=None, help="Đường dẫn file text thành viên")
    parser.add_argument("--json", default=None, help="Đường dẫn file quan_info.json")
    parser.add_argument("--no-backup", action="store_true", help="Không tạo file backup .bak")

    args = parser.parse_args()
    success = sync_members(
        txt_path=args.txt,
        json_path=args.json,
        backup=not args.no_backup
    )
    if not success:
        sys.exit(1)
