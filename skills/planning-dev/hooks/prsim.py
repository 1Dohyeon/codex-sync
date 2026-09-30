#!/usr/bin/env python3
# 요구사항 원문과 "비슷한 과거 PR·커밋"을 저장소 히스토리에서 찾는다.
# 계획 문서에 없는 작업(동료가 한 일, 계획 문서를 쓰기 전의 일)까지 선례로 잡는 용도다.
#
#   python3 prsim.py <저장소 경로> <쿼리 텍스트...>
#
# gh로 merge된 PR을 읽을 수 있으면 PR 제목·본문·변경 파일을 비교한다.
# gh가 없거나, 인증·원격 문제로 실패하거나, PR이 하나도 없으면 커밋 메시지·변경 파일로 대신한다.
# 변경 파일 경로도 비교 대상에 넣는다. 메시지가 부실한 커밋도 경로가 겹치면 잡히게 하려는 것이다.
# 여기서는 PR·커밋을 모으기만 하고, 순위 계산은 tasksim_core.py가 맡는다.

import json
import subprocess
import sys
from pathlib import Path

from tasksim_core import fail, rank

MAX_PRS = 300
MAX_COMMITS = 1000


def run(cmd: list[str], cwd: str) -> str:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=True, timeout=120).stdout


def collect_prs(root: str) -> list[tuple[str, str, str]]:
    out = run(
        ["gh", "pr", "list", "--state", "merged", "--limit", str(MAX_PRS), "--json", "number,title,body,files"],
        root,
    )
    items = []
    for pr in json.loads(out):
        files = " ".join(f["path"] for f in pr.get("files") or [])
        text = f"{pr['title']}\n{pr.get('body') or ''}\n{files}"
        items.append((f"PR #{pr['number']}", pr["title"], text))
    return items


def collect_commits(root: str) -> list[tuple[str, str, str]]:
    # %x00: 커밋 경계, %x1f: 해시·제목·본문 구분, %x1e: 메시지와 --name-only 파일 목록의 경계
    out = run(
        ["git", "log", "--no-merges", "-n", str(MAX_COMMITS), "--format=%x00%h%x1f%s%x1f%b%x1e", "--name-only"],
        root,
    )
    items = []
    for chunk in out.split("\0"):
        if not chunk.strip():
            continue
        head, _, files = chunk.partition("\x1e")
        sha, subject, body = head.split("\x1f", 2)
        text = f"{subject}\n{body}\n{' '.join(files.split())}"
        items.append((sha, subject, text))
    return items


args = sys.argv[1:]
if len(args) < 2:
    fail("사용법: python3 prsim.py <저장소 경로> <쿼리 텍스트...>")

repo_path, *query_parts = args
query = " ".join(query_parts)

try:
    root = run(["git", "rev-parse", "--show-toplevel"], repo_path).strip()
except (OSError, subprocess.CalledProcessError):
    fail(f"{repo_path}는 git 저장소가 아니다. 유사 PR·커밋 검색을 건너뛴다.")

source = "PR"
try:
    items = collect_prs(root)
except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
    print("gh로 PR을 읽지 못했다. 커밋에서 대신 찾는다.")
    items = []
if not items:
    source = "커밋"
    try:
        items = collect_commits(root)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        items = []
if not items:
    fail(f"{Path(root).name}에 비교할 PR·커밋이 없다. 유사 PR·커밋 검색을 건너뛴다.")

print(f"{Path(root).name} · {source} {len(items)}개 · 쿼리 \"{query}\"")
for i, sim in rank([text for _, _, text in items], query):
    ref, title, _ = items[i]
    print(f"  {sim:.3f}  {ref}  {title}")
