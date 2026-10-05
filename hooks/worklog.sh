#!/bin/sh
# 세션이 끝나면 그 세션의 transcript로 $worklog 스킬을 헤드리스로 돌려 작업 일기를 남긴다.
#   - SessionEnd 훅(hooks.json)으로 자동 실행
# 원칙(반드시 지킴): 조건이 안 맞거나 에러여도 세션을 절대 막지 않음. codex exec는 백그라운드로 띄우고 바로 끝낸다.

# 이 훅이 띄운 codex exec도 끝날 때 SessionEnd를 일으키므로, 자식에서는 다시 띄우지 않는다.
if [ -n "$WORKLOG_HOOK" ]; then
    exit 0
fi

worklog_dir="$HOME/worklog"
min_prompts=3

input=$({ command -p cat 2>/dev/null || cat; } 2>/dev/null)

# JSON 문자열 안의 \\ 를 \ 로 되돌린다(Windows 경로).
transcript=$(printf '%s' "$input" | sed -n 's/.*"transcript_path":"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    echo "worklog: transcript 없음 - 통과"
    exit 0
fi

# 사용자가 직접 입력한 메시지는 event_msg의 user_message 줄이다(AGENTS.md 같은 주입 내용은 response_item으로만 남는다).
user_messages=$(grep '"type":"user_message"' "$transcript")

# 대화 중에 $worklog를 이미 불렀으면 수동으로 쓴 것이므로 건너뛴다.
if printf '%s\n' "$user_messages" | grep -q '"message":"\$worklog'; then
    echo "worklog: 이번 세션에서 이미 작성 - 통과"
    exit 0
fi

prompts=$(printf '%s\n' "$user_messages" | grep -c '"type":"user_message"')
if [ "$prompts" -lt "$min_prompts" ]; then
    echo "worklog: 사용자 메시지 ${prompts}개 - 짧은 세션이라 통과"
    exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
    echo "worklog: codex 명령 없음 - 통과"
    exit 0
fi

mkdir -p "$worklog_dir"

# 일기를 다 쓴 뒤 save-docs.sh로 worklog 저장소만 커밋/푸시한다. 다른 세션의 저장과 겹치지 않게 하는 락이 그쪽에 있다.
# 작업 폴더를 worklog로 두어 workspace-write 샌드박스가 그 안에만 쓰게 한다. transcript 읽기는 샌드박스가 막지 않는다.
WORKLOG_HOOK=1 nohup sh -c '
    codex exec "\$worklog $1" \
        --ephemeral \
        --skip-git-repo-check \
        --sandbox workspace-write \
        -c approval_policy=never \
        -C "$2" < /dev/null
    GIT_TERMINAL_PROMPT=0 sh "$3" worklog < /dev/null
' worklog "$transcript" "$worklog_dir" "$(dirname "$0")/save-docs.sh" >/dev/null 2>&1 &

echo "worklog: 백그라운드로 작성 시작"
exit 0
