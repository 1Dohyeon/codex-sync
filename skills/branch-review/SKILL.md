---
description: PR을 올리기 전에 브랜치 전체를 최종 점검할 때 사용한다("브랜치 리뷰해줘", "PR 올리기 전에 봐줘"). 베이스에서 갈라진 뒤 이 브랜치에 쌓인 커밋 전부가 범위이며, 작업 규모와 유형에 따라 아키텍처·코드 레벨·영향 범위·테스트·컨벤션·요구사항 가운데 필요한 축(standard 이상이면 여섯 축 전부)을 격리된 서브에이전트로 병렬로 본다. 화면 변경이 있으면 브라우저 확인 목록을 부록으로 덧붙인다.
---

# 브랜치 전체 리뷰

베이스에서 갈라진 뒤 **이 브랜치에 쌓인 커밋 전부**가 대상이다. 판단할 것은 "남에게 보여도 되는가"다. 완성된 단위를 보는 자리이므로 구조와 테스트까지 함께 본다.

## 범위

아래 순서로 잡는다.

1. 베이스를 정한다. 이 브랜치 계획 문서의 `requirements.md`에 적힌 베이스를 쓰고, 없으면 [`git-workflow`](../git-workflow/SKILL.md)의 "베이스 브랜치 고르기"로 묻는다. 계획 문서는 [`planning-dev`의 "계획 문서 찾기"](../planning-dev/SKILL.md#계획-문서-찾기) 순서로 찾는다. 원격 ref(`origin/<base>`)를 쓰고 로컬 브랜치는 쓰지 않는다. worktree로 작업하는 동안 로컬 브랜치는 갱신되지 않아 뒤처지기 쉽고, 그러면 갈라진 지점이 과거로 밀려 남의 커밋까지 대상에 들어온다.

2. 갈라진 지점을 구한다. 출력된 SHA를 다음 명령에 리터럴로 옮겨 적는다.

```sh
git merge-base origin/<base> HEAD
```

3. **대상 커밋 목록을 사용자에게 보여주고 맞는지 확인받는다.** 낯선 커밋이 섞여 있으면 갈라진 지점을 잘못 잡은 것이므로 중단하고 보고한다. 확인 없이 다음으로 넘어가지 않는다.

```sh
git log --oneline 9a3f1c2..HEAD
```

4. 확정 명령은 아래와 같다. 끝의 `HEAD`를 빠뜨리면 커밋되지 않은 워킹트리 변경까지 섞여 들어와 [`diff-review`](../diff-review/SKILL.md)와 범위가 겹친다.

```sh
git diff 9a3f1c2 HEAD
```

5. 커밋되지 않은 변경은 이 범위에 들어가지 않는다. 아래로 확인해서 있으면 리뷰 대상에서 빠진다는 사실을 사용자에게 알린다. 그 부분을 보려면 `diff-review`가 따로 있다.

```sh
git status --porcelain
```

**셸 변수를 쓰지 않고** ref와 SHA를 명령에 리터럴로 박는다. Bash 호출 사이에는 셸 상태가 남지 않아서 `MB=$(...)` 뒤에 쓴 `$MB`는 빈 문자열이 되고, 그러면 `git diff`로 축약되어 에러 없이 전혀 다른 범위를 리뷰하게 된다. 단일 명령으로 유지한다. `&&`·`;`·`|`로 엮으면 allowlist의 접두 규칙에 걸리지 않아 매번 승인 프롬프트가 뜬다.

## 축

부를 축은 [`review-common/verify.md`](../review-common/verify.md)의 "규모 판단"이 규모와 유형으로 정한다. standard 이상이면 아래 여섯 축을 모두 부른다.

- [`architecture-reviewer`](../../agents/architecture-reviewer.md)
- [`logic-reviewer`](../../agents/logic-reviewer.md)
- [`impact-reviewer`](../../agents/impact-reviewer.md)
- [`testing-reviewer`](../../agents/testing-reviewer.md)
- [`convention-reviewer`](../../agents/convention-reviewer.md)
- [`requirement-reviewer`](../../agents/requirement-reviewer.md)

`requirement-reviewer`에게 진행 중이라고 알리지 않는다. 완성된 단위를 보는 자리이므로 누락도 그대로 지적이다.

화면에 닿는 파일이 있으면 [`qa-reviewer`](../../agents/qa-reviewer.md)를 부록으로 함께 부른다. PR을 올리기 전 사람이 직접 확인할 목록이 된다.

## 이어서

[`review-common/verify.md`](../review-common/verify.md)를 읽고 요구사항 확보부터 출력까지 그대로 진행한다. 요구사항은 사용자에게 먼저 묻지 않고 이 브랜치의 계획 문서 `requirements.md`부터 본다. 요구사항마다 적힌 확인 기준이 이번 리뷰의 판정 기준이 된다.
