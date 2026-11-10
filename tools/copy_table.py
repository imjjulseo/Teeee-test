#!/usr/bin/env python3
"""화면 문구(멘트)를 표 하나로 뽑고, 고친 표를 다시 적용한다 (말투·용어는 docs/copy_guide.md).

  python3 tools/copy_table.py export copy.csv   # 모든 문구 → CSV (file, line, text, new)
  (표 프로그램에서 new 칸만 채운다. 비워 두면 그대로)
  python3 tools/copy_table.py apply copy.csv    # new 칸을 파일에 반영

문구는 scripts(.gd 문자열) · scenes(.tscn) · resources(.tres)의 한글이 든 큰따옴표 문자열이다.
기획서 5.2장 표와 같아야 하는 ability_description, 개발용 화면(debug_panel · playtest_summary)은 뺀다.
적용 뒤에는 단위 테스트를 돌린다 (문구를 기대하는 테스트가 있다).
"""
import csv, glob, re, sys

SKIP_FILES = ("scripts/debug_panel.gd", "scripts/playtest_summary.gd", "scenes/debug_panel.tscn")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
KOREAN = re.compile("[가-힣]")


def source_files():
    files = []
    for pattern in ("resources/**/*.tres", "scenes/**/*.tscn", "scripts/**/*.gd"):
        files += glob.glob(pattern, recursive=True)
    return sorted(f for f in files if f not in SKIP_FILES)


def strings_in(path):
    """(줄 번호, 문구) 목록. 주석과 ability_description 줄은 뺀다."""
    found = []
    with open(path, encoding="utf-8", newline="") as file:
        for number, line in enumerate(file, 1):
            if line.lstrip().startswith("#") or line.startswith("ability_description"):
                continue
            if path.endswith(".gd"):
                line = re.sub(r'\s#[^"]*$', "", line)
            found += [(number, m.group(1)) for m in STRING.finditer(line) if KOREAN.search(m.group(1))]
    return found


def export(out_path):
    with open(out_path, "w", encoding="utf-8-sig", newline="") as out:
        writer = csv.writer(out)
        writer.writerow(["file", "line", "text", "new"])
        for path in source_files():
            for number, text in strings_in(path):
                writer.writerow([path, number, text, ""])


def apply(table_path):
    changed = missed = 0
    with open(table_path, encoding="utf-8-sig", newline="") as table:
        rows = [row for row in csv.DictReader(table) if row.get("new")]
    for row in rows:
        with open(row["file"], encoding="utf-8", newline="") as file:
            lines = file.readlines()
        index = int(row["line"]) - 1
        old, new = '"%s"' % row["text"], '"%s"' % row["new"].replace('"', '\\"')
        if index >= len(lines) or old not in lines[index]:
            print("못 찾음 (표를 다시 뽑으세요): %s:%s %s" % (row["file"], row["line"], row["text"]))
            missed += 1
            continue
        lines[index] = lines[index].replace(old, new, 1)
        with open(row["file"], "w", encoding="utf-8", newline="") as file:
            file.writelines(lines)
        changed += 1
    print("고침 %d, 못 찾음 %d" % (changed, missed))
    return 1 if missed else 0


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("export", "apply"):
        sys.exit(__doc__)
    sys.exit(export(sys.argv[2]) if sys.argv[1] == "export" else apply(sys.argv[2]))
