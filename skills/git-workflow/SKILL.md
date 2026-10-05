---
description: git worktree를 만들거나 정리할 때, 커밋 메시지를 쓸 때, 푸시·PR을 다룰 때 따르는 절차. 베이스 브랜치(develop·release/*·main) 선택, 원격 브랜치 선점 방식의 worktree 생성과 메인 클론 브랜치 생성, 유실 확인 후 worktree·로컬 브랜치 삭제, 커밋 메시지 작성 규칙, 푸시 승인 규칙을 담는다.
---

# Git 워크플로 규칙

## 베이스 브랜치 고르기

새 브랜치를 어디서 딸지(베이스)는 고정하지 않고 사용자가 고른다. worktree 생성, [`planning-dev`](../planning-dev/SKILL.md)의 계획 문서, [`branch-review`](../branch-review/SKILL.md)의 범위가 이 규칙을 쓴다.

1. 이번 대화에서 이미 확정한 베이스가 있거나, 계획 문서의 `requirements.md`에 `브랜치: <브랜치> (베이스: <베이스>)` 줄이 있으면 그 베이스를 쓰고 묻지 않는다. 계획 문서는 `planning-dev`의 "계획 문서 찾기" 순서로 찾는다.
2. 없으면 원격에 실제로 있는 후보를 모은다. 후보는 `origin/develop`, `origin/release/*`, `origin/main`이다.

```sh
git fetch origin
```

```sh
git branch -r
```

3. 모은 후보를 `AskUserQuestion`의 선택지로 묻는다.
   - `release/*`가 없으면 `develop`과 `main` 두 가지만 묻는다.
   - `release/*`가 여럿이면 최근 것 두 개까지만 선택지로 두고, 나머지는 사용자가 "Other"로 적게 한다.
   - 후보가 하나뿐이면 묻지 않고 그것을 쓰며, 무엇을 썼는지 알린다. 하나도 없으면 멈추고 베이스를 묻는다.
4. 브랜치 이름으로 베이스를 짐작해 자동으로 고르지 않는다. 추천 표시만 한다. `hotfix/*`는 `main`, 그 밖은 `develop`을 추천으로 둔다.

## worktree 생성

작업 브랜치는 새 worktree로 만들거나, 아래 "메인 클론에서 브랜치 만들기"대로 메인 클론에서 만든다. 어느 쪽으로 할지는 사용자가 고른다. worktree로 정했으면 아래 순서로 만든다. `<base>`는 위 "베이스 브랜치 고르기"로 정한 베이스다. `planning-dev`에서 작업 브랜치와 베이스를 이미 확정했으면 그 값을 쓴다. 계획 문서의 `requirements.md` 브랜치 줄에 있다.

### worktree 위치 정하기

원격 브랜치를 만들기 전에 worktree를 둘 위치 `<dir>`을 **꼭** `AskUserQuestion`으로 묻는다. 묻지 않고 정하지 않는다. 선택지는 아래 순위대로 두고, 선택지마다 실제로 만들어질 전체 경로를 보여 준다.

| 순위 | 선택지                         | 위치                                                                                                                                  |
| ---- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | 앱의 훅이 안내하는 위치        | 세션을 연 앱이 훅(세션 시작 안내)으로 안내하는 경로. 안내가 없으면 이 선택지를 빼고, 있으면 추천으로 표시한다                          |
| 2    | 메인 작업 폴더와 형제 위치     | 메인 클론(`<main-dir>`)과 같은 부모 폴더 아래. 1순위 선택지가 없으면 이것을 추천으로 표시한다                                         |

두 선택지에 없는 경로는 사용자가 `AskUserQuestion`의 직접 입력으로 적는다.

### 만드는 순서

0. worktree를 둘 위치 `<dir>`을 위 "worktree 위치 정하기"대로 정한다.

1. 베이스 브랜치에서 새 브랜치를 원격에 먼저 만든다(로컬엔 아직 없는 빈 브랜치):

```sh
git fetch origin
git push origin origin/<base>:refs/heads/<branch>
```

2. 방금 만든 원격 브랜치를 추적하는 worktree를 `<dir>`에 만든다:

```sh
git fetch origin
git worktree add -b <branch> <dir> origin/<branch>
```

`--track`은 붙이지 않는다. 시작점이 `origin/<branch>`라 upstream은 어차피 자동으로 잡히고, git 2.18 미만에서는 `unknown option 'track'`으로 실패한다.

3. upstream이 베이스 브랜치가 아니라 `<branch>` 자신인지 확인한다. (`git worktree add -b <branch> <dir> origin/<base>`처럼 만들면 upstream이 베이스가 되어버려서, 이후 평범한 `git push` 한 번에 커밋이 바로 베이스로 들어간다.)

```sh
git -C <dir> status -sb
```

`## <branch>...origin/<branch>`로 나와야 한다. 그렇지 않으면 아래로 고친다.

| status 출력                     | 상태                                          | 조치                                                    |
| ------------------------------- | --------------------------------------------- | ------------------------------------------------------- |
| `## <branch>...origin/<branch>` | 정상                                          | 다음 단계로                                             |
| `## <branch>...origin/<base>`   | 베이스 브랜치를 추적                          | `git -C <dir> branch --set-upstream-to=origin/<branch>` |
| `## <branch>`                   | upstream 없음 (`branch.autoSetupMerge=false`) | 위와 동일                                               |

고친 뒤 `status -sb`로 다시 확인한다.

4. 의존성을 설치한다. 새 worktree엔 `node_modules`가 없어서 이 단계까지 끝내야 바로 쓸 수 있다. 저장소 자체의 패키지 매니저를 쓴다(`bun.lock` → `bun install`, `pnpm-lock.yaml` → `pnpm install` 등).

5. 설치 과정에서 생긴 lockfile 변경은 되돌린다.

```sh
git -C <dir> checkout -- <lockfile>
```

새 worktree는 원래 clean한 상태로 시작하므로, 여기서 생긴 lockfile 변경은 의도된 변경이 아니라 환경 노이즈다(예: 더 최신 패키지 매니저가 메타데이터를 다시 씀). 실제 의존성 버전이 바뀐 경우라면 그대로 되돌리되 보고에서 언급한다.

6. env 파일을 연결한다. `.env`는 gitignore 대상이라 새 worktree엔 없다. 메인 클론(`<main-dir>`)에 실제로 존재하는 `apps/*/.env`, `apps/*/.env.local`을 찾아 새 worktree의 같은 상대경로로 **복사**한다.

```sh
cd <main-dir> && find apps -maxdepth 2 \( -name '.env' -o -name '.env.local' \) | while read -r f; do
  cp "<main-dir>/$f" "<dir>/$f"
done
```

복사가 실패하면(권한 등) 메인 클론 파일을 가리키는 심링크로 대신한다.

```sh
ln -sf "<main-dir>/$f" "<dir>/$f"
```

Windows에서 심링크를 쓰려면 개발자 모드가 켜져 있어야 한다. 꺼져 있으면 에러 없이 복사본이 생겨 겉보기엔 성공한 것처럼 보이므로, 심링크 경로로 갔다면 `ls -l <dir>/$f`로 `->` 화살표가 뜨는지 반드시 확인한다.

이 단계는 값을 그 시점에 한 번 복제하는 것이라, 이후 메인 클론이나 다른 worktree에서 값을 바꾸면 이 worktree엔 반영되지 않는다. 바뀐 걸 알게 되면 그때 다시 복사한다.

7. 마지막으로 확인하고 보고한다.

```sh
git -C <dir> status -sb
```

작업 트리가 clean해야 한다.

## 메인 클론에서 브랜치 만들기

worktree 없이 메인 클론에서 작업 브랜치를 따는 경우다. `<branch>`와 `<base>`는 worktree 생성과 같은 방식으로 정한다.

1. 메인 클론의 작업 트리가 clean한지 확인한다. 커밋하지 않은 변경이 있으면 중단하고 보고한다. 브랜치를 옮기면 그 변경이 새 브랜치로 따라온다.

```sh
git status --porcelain
```

2. worktree 생성 1단계와 같이 베이스에서 새 브랜치를 원격에 먼저 만든다.

```sh
git fetch origin
git push origin origin/<base>:refs/heads/<branch>
```

3. 방금 만든 원격 브랜치를 시작점으로 로컬 브랜치를 만들고 옮긴다. 시작점이 `origin/<branch>`라 upstream이 베이스가 아니라 `<branch>` 자신으로 잡힌다.

```sh
git fetch origin
git switch -c <branch> origin/<branch>
```

4. `git status -sb`가 `## <branch>...origin/<branch>`로 나오는지 확인한다. 다르면 worktree 생성 3단계의 표대로 고친다.

## worktree 정리

**"워크트리 삭제해줘" = 워크트리 폴더 + 로컬 브랜치를 지우고, 원격은 그대로 둔다.** 둘은 한 묶음이라 로컬 브랜치를 남길지 따로 묻지 않는다.

worktree로 만든 브랜치는 그 worktree에서만 작업한다. 그래서 worktree가 사라지면 그 로컬 브랜치는 쓸 곳이 없어 정리 대상이다. 반대로 원격 브랜치는 PR과 사본을 들고 있는 쪽이므로 손대지 않는다(삭제는 사용자가 직접 웹에서 진행).

지울 것과 두는 것을 혼동하지 않는다.

|                                   | 실체                                | 이 절차에서                  |
| --------------------------------- | ----------------------------------- | ---------------------------- |
| ① 로컬 브랜치 `<branch>`          | `.git/refs/heads/<branch>`          | **지운다** (`git branch -D`) |
| ② 원격 추적 ref `origin/<branch>` | `.git/refs/remotes/origin/<branch>` | 두고, 건드리지 않는다        |
| ③ GitHub의 원격 브랜치            | GitHub 서버                         | 두고, 건드리지 않는다        |

②③은 `git branch -D`로 지워지지 않는다. ③ 삭제(`git push origin --delete`, `git push origin :<branch>`)는 푸시가 끼는 동작이라 "푸시 · PR · 머지" 규칙에 걸리므로 하지 않는다.

worktree 제거만으로는 ①이 남는다. worktree 제거는 작업 디렉터리와 `.git/worktrees/<name>/` 메타데이터만 없애고 브랜치 ref는 건드리지 않는다(브랜치의 점유만 풀린다). 그래서 아래 2·3단계를 둘 다 해야 정리가 끝난다.

### 1. 유실 확인

**로컬에만 있는 것이 없는지 먼저 본다.** 원격에 사본이 있다는 것이 ①을 지워도 되는 근거다. 아래 중 하나라도 걸리면 중단하고 보고한다. 조용히 우회하거나 `-D`로 밀지 않는다.

```sh
git -C <dir> status -sb
```

| status 출력                             | 판정                                                     |
| --------------------------------------- | -------------------------------------------------------- |
| `## <branch>...origin/<branch>` + clean | 통과. 원격과 동일하다                                    |
| `[ahead N]`                             | 미푸시 커밋이 있다 → 푸시 승인이 필요하므로 중단·보고    |
| 변경·스테이징된 파일                    | 중단·보고                                                |
| `[behind N]`만                          | 통과. 원격이 앞서 있을 뿐 잃을 것은 없다                 |
| `origin/<branch>: gone`                 | 원격 사본이 없다 → 아래 "원격이 이미 삭제된 경우"로 간다 |

```sh
git -C <dir> stash list
```

비어 있어야 한다. stash는 브랜치를 지워도 남지만 되찾을 실마리가 사라지므로 중단·보고한다.

### 2. worktree 제거

```sh
git worktree remove <dir>
```

`git worktree remove`는 git 2.17부터다. 그 미만에서는 `usage: git worktree add ...`(exit 129)로 실패하므로 디렉터리를 지우고 prune한다.

```sh
rm -rf <dir>
```

```sh
git -C <main-dir> worktree prune
```

오류에 `Filename too long`이 있으면 경로가 긴 파일(`node_modules` 등) 때문에 폴더를 다 지우지 못한 것이다. git은 이때 이미 `.git` 파일과 등록 정보를 지웠을 수 있다. **다른 우회(`core.longpaths`, `\\?\` 경로, robocopy, 다른 삭제 명령 등)를 시도하지 않는다.** 아래 두 명령으로 연결만 끊고 다음 단계로 간다. 남은 폴더와 빈 부모 폴더는 지우지 않고, 남은 폴더 경로를 보고에 적는다.

```sh
rm -f <dir>/.git
```

```sh
git -C <main-dir> worktree prune
```

### 3. 로컬 브랜치 삭제

```sh
git -C <main-dir> branch -D <branch>
```

`-d`가 아니라 `-D`다. 이 브랜치는 develop에 머지되지 않았거나 머지 전에 리베이스돼 조상이 아니어서 `-d`는 거부된다. `-D`를 쓰는 근거는 1단계에서 원격 사본을 확인한 것이며, 확인 없이 `-D`를 쓰지 않는다.

2단계보다 먼저 실행하면 `checked out at ...`으로 거부된다. 순서를 지킨다.

### 4. 검증

```sh
git -C <main-dir> worktree list
```

```sh
git -C <main-dir> branch -vv
```

```sh
git -C <main-dir> branch -r
```

worktree 목록과 로컬 브랜치 목록에서 `<branch>`가 사라지고, `origin/<branch>`는 **그대로 남아 있어야** 한다. 마지막 항목이 "로컬만 지웠다"의 증거이므로 보고에 함께 적는다.

### 원격이 이미 삭제된 경우 (`: gone`)

선임이 원격 브랜치를 지운 뒤라 ②③이 없다. 원격 사본이 없으니 1단계의 근거가 사라지므로, **develop에 반영됐는지를 대신 확인**하고 나서 지운다.

| 확인       | 명령                                 | 판정                   |
| ---------- | ------------------------------------ | ---------------------- |
| 조상 여부  | `git branch --merged origin/develop` | 목록에 있으면 반영됨   |
| patch 단위 | `git cherry origin/develop <branch>` | 모든 줄이 `-`면 반영됨 |

`--merged`만 믿지 않는다. 머지 전에 리베이스(force-push)하는 저장소에서는 로컬 tip이 develop의 조상이 아니라 거의 아무것도 걸리지 않는다. `git cherry`의 `-`는 patch-id 동일본이 upstream에 있다는 뜻이라 리베이스를 통과한다.

`git cherry`에 `+`가 남으면 곧바로 미반영으로 결론내지 않는다. 리베이스로 **주변 문맥**이 바뀌면 같은 변경도 patch-id가 달라진다. 그 커밋 제목으로 develop 히스토리를 찾아본다.

```sh
git log origin/develop --oneline --grep=<제목 일부>
```

같은 제목이 있으면 `git show --stat`으로 양쪽 stat을 비교하고, 파일 단위로 `git diff <로컬커밋> <develop커밋> -- <파일>`이 비는지 본다. 여기까지 확인되면 반영된 것으로 보고 지운다. 어느 것도 확인되지 않으면 중단하고 보고한다.

### 정리를 빠뜨렸을 때

이 절차의 3단계를 생략하면 로컬 브랜치가 계속 쌓인다. 자동으로 없어지는 경로가 없다.

- 선임이 원격 브랜치를 지우고 `git fetch --prune`을 해도 ②만 사라진다. ①은 upstream이 `: gone`으로 표시만 되고 남는다. git은 로컬 브랜치를 자동 삭제하지 않는다.
- GitHub Desktop의 BranchPruner는 **기본 브랜치(`main`)에 머지된** 브랜치만 정리한다(로그: `Pruning 0 branches that have been merged into the default branch, main`). PR을 `develop`으로 머지하는 저장소에서는 한 번도 걸리지 않는다.

`git branch -vv`에서 `: gone`이 붙은 것들이 밀린 정리 후보다. 위 "원격이 이미 삭제된 경우"로 확인한 뒤 한 번에 지운다.

## 커밋 메시지

**커밋 메시지를 작성하기 전에 [`~/.claude/CLAUDE.local.md`](../../CLAUDE.local.md)를 무조건 Read한다.** 거기 적힌 추가 커밋 규칙도 꼭 따른다.

그 다음 저장소 자체 규칙을 아래 순서로 파악한다.

1. commit/git 관련 문서(`CONTRIBUTING.md`, `.github/` 안의 문서, 저장소 `CLAUDE.md` 등)가 있으면 Read한다.
2. `git log`로 기존 커밋 히스토리를 보고 실제 쓰이는 패턴을 파악한다.

**제목**: 저장소에 규칙 문서가 없으면 1번에서 파악한 히스토리 패턴을 따른다.

**본문(description)**: 저장소에 규칙이 있으면 그 규칙을 따른다. 없으면(대체로 없다) 다음을 따른다.

- 1레벨 불릿 리스트로 구성한다.
- why(이유)는 적지 않는다. what(무엇을 했는지)만 적는다.

## 푸시 · PR · 머지

- 머지(`git merge`, `gh pr merge`)는 사용자가 요청할 때만 한다. 실행 전 확인은 [`settings.json`](../../settings.json)의 `permissions.ask`가 받으므로, auto mode여도 확인 창이 뜬다.
- PR 생성·수정은 필요하면 한다.
