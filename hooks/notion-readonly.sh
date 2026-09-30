#!/bin/sh
# Notion MCP를 읽기 전용으로 제한한다(PreToolUse). 허용 목록에 있는 읽기 툴만 통과시키고 나머지는 거부한다.
#
# 커넥터 접두사는 기기·연결 방식에 따라 달라지므로(mcp__notion__ / mcp__claude_ai_Notion__ 등)
# 접두사가 아니라 마지막 `__` 뒤의 동작 이름으로 판정한다. 접두사로 판정하던 이전 방식은
# 커넥터 이름이 바뀌면서 아무것도 걸리지 않는 상태가 됐다.
#
# 동작 이름은 접두사(get·list·query 등)로 훑지 않고 목록에 그대로 적는다. 접두사로 허용하면
# notion-get-or-create-page 같은 쓰기 툴이 읽기로 오판된다. 커넥터에 따라 이름 앞에 `notion-`이
# 붙기도 하고 안 붙기도 해서 그 부분만 떼고 대조한다. 새 읽기 툴이 생기면 거부되므로 그때 목록에 추가한다.
#
# 이 훅은 방어선이라 실패하면 닫힌다(fail-closed). node가 실행되지 않으면 아래 deny로 떨어진다.
# 편의 훅(save-docs)의 "실패해도 세션을 막지 않는다" 원칙과 반대이며,
# 막는 것이 목적인 훅은 조용히 열리는 쪽이 더 위험하기 때문에 의도적으로 다르게 둔다.
#
# JSON은 node로 처리한다: jq는 기기에 따라 없을 수 있지만
# node는 Claude Code 구동에 필요해 항상 있다고 볼 수 있다.

# 거부 응답은 셸과 node 양쪽에서 쓰므로 한 곳에만 두고 환경변수로 넘긴다(문구가 갈리지 않게).
DENY_JSON='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Notion MCP는 읽기 전용으로 제한되어 있습니다. 허용 목록에 없는 툴은 차단됩니다."}}'
export DENY_JSON

node -e '
let raw = "";
process.stdin.on("data", d => raw += d);
process.stdin.on("end", () => {
  let name = "";
  try { name = JSON.parse(raw).tool_name || ""; } catch {}

  // mcp__claude_ai_Notion__notion-update-page → update-page
  const op = name.split("__").pop().replace(/^notion-/, "");

  const READ = new Set([
    "fetch",
    "search",
    "search-agents",
    "search-sessions",
    "get-async-task",
    "get-comments",
    "get-session-status",
    "get-teams",
    "get-users",
    "list-favorite-pages",
    "list-private-pages",
    "list-recent-pages",
    "list-shared-pages",
    "list-session-events",
    "query-data-sources",
    "query-meeting-notes",
    "query-sessions",
    "read-session-event",
    "download-attachment"
  ]);

  // 목록에 있으면 출력 없이 통과. 이름을 못 읽은 경우도 여기서 걸러져 거부로 떨어진다.
  if (READ.has(op)) process.exit(0);

  process.stdout.write(process.env.DENY_JSON);
});
' 2>/dev/null || printf '%s' "$DENY_JSON"

exit 0
