#!/usr/bin/env python3
# 요구사항 원문과 "비슷한 과거 태스크"를 ~/plans에서 찾는다.
# 태스크를 분석하기 전에 예전에 비슷한 걸 어떻게 풀었는지 참고하는 용도다.
#
#   python3 tasksim.py <repo> <쿼리 텍스트...>
#
# ~/plans/{owner}/<repo>/ 와 ~/plans/done/{owner}/<repo>/ 아래에서
# requirements.md나 tasks.md가 있는 폴더 하나를 문서 하나로 본다.
# requirements.md가 있으면 requirements.md + design.md를, 없으면 tasks.md를 비교한다.
# 여기서는 문서를 모으기만 하고, 순위 계산은 tasksim_core.py가 맡는다.
# git 커밋·PR은 보지 않는다(비슷한 PR·커밋은 prsim.py, 파일 동반 관계는 cochange.js의 몫).

import sys
from pathlib import Path

from tasksim_core import fail, rank

args = sys.argv[1:]
if len(args) < 2:
    fail("사용법: python3 tasksim.py <repo> <쿼리 텍스트...>")

repo, *query_parts = args
query = " ".join(query_parts)

plans_dir = Path.home() / "plans"


def plan_repo_dirs() -> list[Path]:
    dirs = []
    for base in (plans_dir, plans_dir / "done"):
        if not base.is_dir():
            continue
        for owner in sorted(base.iterdir()):
            if base == plans_dir and owner.name == "done":
                continue
            if (owner / repo).is_dir():
                dirs.append(owner / repo)
    return dirs


repo_dirs = plan_repo_dirs()
if not repo_dirs:
    fail(f"~/plans에 {repo} 저장소가 없다 — 유사 태스크 검색을 건너뛴다.")

docs: list[str] = []
names: list[str] = []

for repo_dir in repo_dirs:
    folders = sorted({p.parent for name in ("requirements.md", "tasks.md") for p in repo_dir.rglob(name)})
    for folder in folders:
        req = folder / "requirements.md"
        if req.is_file():
            text = req.read_text(encoding="utf-8")
            design = folder / "design.md"
            if design.is_file():
                text += "\n" + design.read_text(encoding="utf-8")
        else:
            text = (folder / "tasks.md").read_text(encoding="utf-8")
        docs.append(text)
        names.append(str(folder.relative_to(plans_dir)))

if not docs:
    fail(f"{repo}에 비교할 문서가 없다 — 유사 태스크 검색을 건너뛴다.")

print(f"{repo} · 문서 {len(docs)}개 · 쿼리 \"{query}\"")
for i, sim in rank(docs, query):
    print(f"  {sim:.3f}  {names[i]}")
