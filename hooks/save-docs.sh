#!/bin/sh
# plans/(계획 문서용 별도 private repo)의 "현재 상태"를 스냅샷 커밋/푸시한다.
#   - SessionEnd 훅으로 자동 실행
#   - /save-docs 커맨드로 수동 실행
# 목적: 계획 문서 유실 방지 + 크로스머신 이어작업.
# 원칙(반드시 지킴): 변경 없으면 통과 / 오프라인·충돌·에러여도 세션을 절대 막지 않음.

# 훅 계약상 stdin으로 JSON이 올 수 있으나 여기선 쓰지 않는다(있으면 소진만).
{ command -p cat 2>/dev/null || cat; } >/dev/null 2>&1 || :

plans_dir="$HOME/plans"

git_plans() {
    git -C "$plans_dir" "$@"
}

# plans가 git 저장소가 아니면(이 기기에 plans repo 미클론 등) 조용히 통과.
# worktree면 .git이 파일이므로 -e로 검사한다.
if [ ! -e "$plans_dir/.git" ]; then
    echo "snapshot: plans가 git 저장소가 아님 — 통과"
    exit 0
fi

# 변경 확인. 없으면 통과 → 빈 커밋 방지
changes=$(git_plans status --porcelain 2>/dev/null)
if [ -z "$changes" ]; then
    echo "snapshot: 변경 없음 — 통과"
    exit 0
fi

# 현재 상태 그대로 스테이징
git_plans add -A >/dev/null 2>&1 || :

# 추적 파일의 절반 넘게 지워졌으면 체크아웃 실패 등으로 작업 트리가 빈 것으로 보고 멈춘다.
# 옮긴 파일은 -M으로 이름 변경이 되어 삭제로 세지 않는다.
tracked=$(git_plans ls-tree -r --name-only HEAD 2>/dev/null | wc -l)
deleted=$(git_plans diff --cached -M --diff-filter=D --name-only 2>/dev/null | wc -l)
if [ "$tracked" -gt 0 ] && [ $((deleted * 2)) -gt "$tracked" ]; then
    git_plans reset -q >/dev/null 2>&1 || :
    echo "snapshot: 추적 파일 $tracked개 중 $deleted개 삭제 — 비정상으로 보고 커밋 안 함"
    exit 0
fi

stamp=$(date '+%Y-%m-%d %H:%M')     # 이 기기의 로컬 시각(KST 등)
msg="chore: auto-save $stamp"

if git_plans commit -m "$msg" >/dev/null 2>&1; then
    echo "snapshot: 커밋 — $msg"
else
    echo "snapshot: 커밋 실패 — 통과(세션엔 영향 없음)"
    exit 0
fi

# push는 실패해도 무시(오프라인/non-fast-forward). 세션 종료가 매달리지 않게 15초 후 kill.
# macOS 기본 환경에는 timeout(1)이 없어 백그라운드 + kill 패턴을 쓴다.
git_plans push >/dev/null 2>&1 &
push_pid=$!
( sleep 15; kill "$push_pid" 2>/dev/null ) >/dev/null 2>&1 &
killer_pid=$!

if wait "$push_pid" 2>/dev/null; then
    echo "snapshot: push 완료"
else
    echo "snapshot: push 실패/시간초과(오프라인·충돌) — 로컬 커밋만, 다음에 수동 pull/push"
fi

kill "$killer_pid" 2>/dev/null
exit 0
