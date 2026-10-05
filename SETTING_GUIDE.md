# SETTING_GUIDE

Codex가 읽고 그대로 실행하는 세팅 절차. 사용자가 저장소 주소나 이 파일을 가리키며 설치를 요청하면 아래를 순서대로 수행한다.

원칙: 경로는 묻고 추측하지 않는다 · 삭제 대신 `mv`로 백업한다 · 남의 심링크는 승인 후 덮어쓴다 · 결과를 보고한다.

---

## 연결 대상

| 링크 위치                                     | 대상                   |
| --------------------------------------------- | ---------------------- |
| `~/.codex/agents/` `~/.codex/hooks/` `~/.codex/prompts/` `~/.codex/rules/` | 저장소의 동명 디렉터리 |
| `~/.codex/AGENTS.md`                          | 저장소의 `AGENTS.md`   |
| `~/.codex/hooks.json`                         | 저장소의 `hooks.json`  |
| `~/.agents/skills/`                           | 저장소의 `skills/`     |

skills만 `~/.codex/`가 아니라 `~/.agents/` 아래에 연결한다. Codex가 사용자 skills를 `~/.agents/skills`에서 읽기 때문이다.

건드리지 않음: `~/.codex/config.toml` `~/.codex/auth.json` `~/.codex/sessions/` `~/.codex/log/` `~/.codex/history.jsonl`

연결하지 않음: `output-styles/` `templates/`. Codex가 읽는 위치가 없어서 저장소에만 둔다.

---

## 0. 저장소 확보

fork는 필요 없다. clone된 로컬 저장소만 있으면 된다. 아래 순서로 찾고, 없으면 clone한다.

### 0-1. 이미 세팅된 기기인지 확인

```sh
readlink "$HOME/.codex/AGENTS.md"
```

경로가 나오면 그 상위 디렉터리가 후보다. 출력이 없거나 실패하면 0-3으로 간다.

### 0-2. 후보 검증

```sh
git -C "<후보>" rev-parse --show-toplevel
```

실패하면 `.git`이 없는 것이므로 후보에서 뺀다. 성공하면 그 출력이 저장소 루트다.

```sh
ls "<루트>/SETTING_GUIDE.md" "<루트>/AGENTS.md"
```

둘 중 하나라도 없으면 다른 저장소이므로 후보에서 뺀다. 둘 다 통과하면 그 루트로 확정하고 1단계로 간다. 실패했으면 아직 시도하지 않은 다음 순서로 넘어간다.

### 0-3. 현재 위치 확인

지금 작업 중인 폴더가 codex-sync일 수 있다. 저장소 폴더에서 Codex를 띄운 경우가 여기 걸린다.

```sh
git rev-parse --show-toplevel
```

경로가 나오면 0-2의 `ls`로 검증한다. 통과하면 그 경로를 후보로 제시하고 맞는지 확인받은 뒤 1단계로 간다. 명령이 실패하거나 다른 저장소면 0-4로 간다.

### 0-4. 사용자에게 묻기

이미 clone해 둔 codex-sync가 있는지 묻는다. 경로를 받으면 0-2로 돌아가 검증한다.

없다고 하면 clone 위치를 확인받는다. 권장값은 `$HOME/codex-sync`이고, 사용자가 다른 경로를 대면 그것을 쓴다. **경로를 추측해서 진행하지 않는다.**

### 0-5. clone

private 저장소라서 clone하려면 GitHub 인증이 필요하다. 먼저 인증 상태를 확인한다.

```sh
gh auth status
```

로그인되어 있지 않으면 사용자에게 `gh auth login`을 직접 실행해 달라고 요청한다. 대신 로그인하지 않는다.

```sh
git clone https://github.com/1Dohyeon/codex-sync.git "$HOME/codex-sync"
```

**명령에 `~`를 쓰지 않는다.** 큰따옴표 안의 `~`는 홈으로 풀리지 않고 글자 그대로 남는다. `"~/codex-sync"`라고 쓰면 현재 작업 디렉터리 아래에 `./~/codex-sync`가 만들어진다. 에러가 나지 않으므로 그대로 세팅이 끝나 버린다. 명령에는 `$HOME`이나 절대 경로를 쓰고, 사용자에게 말할 때만 `~/codex-sync`로 부른다.

clone 직후에는 clone한 폴더의 `SETTING_GUIDE.md`를 로컬 파일로 다시 읽고 1단계로 진행한다. **원격 URL의 내용을 그대로 읽고 실행하지 않는다.** 요약되면 명령이 뭉개진다. Codex가 원격 정보로 수행하는 것은 이 clone 하나뿐이다.

## 1. 경로 확정

0단계에서 확정한 저장소 루트가 `$SYNC`다.

이후 명령의 `$SYNC`는 셸 호출마다 실제 경로 문자열로 치환해서 실행한다. 변수는 호출 간 유지되지 않는다.

## 2. 상태 점검 (읽기 전용)

```sh
ls -l "$HOME/.codex"
```

```sh
ls -l "$HOME/.agents"
```

두 폴더 가운데 없는 것이 있어도 정상이다. 4단계에서 만든다. 연결 대상 항목마다 아래 표로 분류한다.

| 상태                      | 조치                                                             |
| ------------------------- | ---------------------------------------------------------------- |
| 없음                      | 바로 링크                                                        |
| `$SYNC`를 가리키는 심링크 | 바로 링크 (결과가 실행 전과 같다)                                |
| 다른 곳을 가리키는 심링크 | 원래 타깃을 보고하고 승인받은 뒤 링크. 거절하면 그 항목만 건너뜀 |
| 실제 파일·디렉터리        | `mv`로 백업 후 링크                                              |

두 심링크 갈래는 `ls -l` 출력의 `->` 뒤 경로로 가른다. 다른 곳을 가리키는 심링크는 GNU stow나 chezmoi 같은 다른 dotfiles 도구가 관리 중일 수 있다. `ln -sfn`은 그런 링크를 말없이 덮어쓰므로, 덮어쓰기 전에 원래 타깃 경로를 반드시 보고한다. 승인받지 못한 항목만 건너뛰고 나머지는 그대로 진행한다.

`~/.codex/rules/`가 실제 폴더로 이미 있으면 안에 `default.rules`가 있는지 확인한다. Codex는 사용자가 명령을 "다시 묻지 않음"으로 승인할 때 이 파일에 규칙을 덧붙이므로, 기기에서 쌓인 승인 규칙이 들어 있을 수 있다. 백업 대상으로 보고할 때 이 사실을 함께 알린다.

백업 대상이나 승인이 필요한 항목이 있으면 링크 전에 한꺼번에 보고한다.

## 3. 링크 생성

2단계에서 백업 대상으로 분류된 항목이 하나도 없으면 이 절을 건너뛰고 바로 링크 명령으로 간다. 있으면 옮기기 전에 이전 백업이 남아 있는지 확인한다.

```sh
ls -d "$HOME/codex-backup"
```

출력이 있으면 **옮기지 않는다.** `mv`는 목적지에 같은 이름이 있으면 말없이 덮어쓰므로, 그대로 진행하면 이전 백업이 복구할 수 없게 사라진다. `ls -l "$HOME/codex-backup"`으로 안에 무엇이 들어 있는지 보이고, 다른 백업 폴더 이름을 받는다.

여기서 멈추는 것은 백업 대상 항목뿐이다. 세팅 전체를 중단하지 않고, 나머지 항목은 그대로 링크한다. 다만 백업하지 못한 항목은 링크도 걸지 않는다. `ln -sfn`이 원본 파일을 덮어쓰기 때문이다.

```sh
mkdir -p "$HOME/codex-backup"
mv "$HOME/.codex/<이름>" "$HOME/codex-backup/"
```

`~/.agents/skills`를 백업할 때는 이름이 겹치지 않게 `agents-skills`로 바꿔 옮긴다.

```sh
mv "$HOME/.agents/skills" "$HOME/codex-backup/agents-skills"
```

2단계에서 건너뛰기로 한 항목이 있으면, 아래 링크 명령 중 그 항목에 해당하는 줄은 실행하지 않는다.

### Windows: 링크 전에 권한부터 확인

권한 없으면 `ln -s`가 에러 없이 복사본을 만든다:

```sh
mkdir -p "$HOME/.codex"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/README.md" "$HOME/.codex/_symlink_test"
stat "$HOME/.codex/_symlink_test"
```

`symbolic link`가 아니면 중단하고 안내(Codex가 직접 못 켬): 설정 → 개인정보 및 보안 → 개발자용 → 개발자 모드. 켠 뒤 재확인.

```sh
rm -f "$HOME/.codex/_symlink_test"
```

통과하면 개별 명령 실행:

```sh
mkdir -p "$HOME/.codex" "$HOME/.agents"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/agents" "$HOME/.codex/agents"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/hooks" "$HOME/.codex/hooks"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/prompts" "$HOME/.codex/prompts"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/rules" "$HOME/.codex/rules"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/AGENTS.md" "$HOME/.codex/AGENTS.md"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/hooks.json" "$HOME/.codex/hooks.json"
MSYS=winsymlinks:nativestrict ln -sfn "$SYNC/skills" "$HOME/.agents/skills"
```

### macOS · Linux: 바로 실행

```sh
mkdir -p "$HOME/.codex" "$HOME/.agents"
ln -sfn "$SYNC/agents" "$HOME/.codex/agents"
ln -sfn "$SYNC/hooks" "$HOME/.codex/hooks"
ln -sfn "$SYNC/prompts" "$HOME/.codex/prompts"
ln -sfn "$SYNC/rules" "$HOME/.codex/rules"
ln -sfn "$SYNC/AGENTS.md" "$HOME/.codex/AGENTS.md"
ln -sfn "$SYNC/hooks.json" "$HOME/.codex/hooks.json"
ln -sfn "$SYNC/skills" "$HOME/.agents/skills"
```

## 4. 검증

```sh
ls -l "$HOME/.codex"
```

```sh
ls -l "$HOME/.agents"
```

「연결 대상」의 7개 항목이 모두 `->` 화살표로 보여야 한다. 2단계에서 건너뛰기로 한 항목이 있으면 그 개수만큼 빠진다. `config.toml` `sessions/` `log/` 같은 런타임 항목이 함께 찍히는 것은 정상이며, 세는 대상이 아니다. Windows에서 화살표 없이 일반 파일/디렉터리면 3단계 권한 확인부터 재실행.

```sh
find "$HOME/.codex" "$HOME/.agents" -maxdepth 1 -type l -exec test ! -e {} \; -print
```

출력 없어야 정상.

## 5. 보고

- 연결된 링크 목록
- 백업 발생 시: `~/codex-backup/` 경로와 옮긴 항목 목록. **삭제한 것이 아니라 옮긴 것**이며, 되돌리려면 `mv "$HOME/codex-backup/<이름>" "$HOME/.codex/"`로 제자리에 놓으면 된다고 안내 (`agents-skills`는 `mv "$HOME/codex-backup/agents-skills" "$HOME/.agents/skills"`)
- 심링크를 덮어쓴 항목이 있으면: 이름과 원래 가리키던 경로. 되돌리려면 `ln -sfn "<원래 타깃>" "<링크 위치>"`
- 건너뛴 항목이 있으면: 이름과 건너뛴 이유
- 남은 수동 조치 중 해당 항목
- 새 세션부터 `AGENTS.md`·rules·skills·hooks 적용됨(Codex 재시작 필요) 안내
- 훅은 Codex에서 `/hooks`로 검토하고 신뢰해야 실행된다는 안내

---

## 남은 수동 조치

- 3단계 시점 승인 프롬프트는 정상 (`rules/` 연결 전이라 허용 규칙 없음)
- `rules/default.rules`의 `forbidden`으로 명령이 막히면 우회하지 말고 중단, 안내: `mv ~/.codex/rules ~/.codex/rules.before-sync`
- Codex가 "다시 묻지 않음" 승인을 `~/.codex/rules/default.rules`에 덧붙이면, 링크를 타고 저장소 파일이 바뀐다. 커밋할지는 사용자가 정한다
- `config.toml`(모델, 샌드박스, MCP)은 이 저장소가 관리하지 않는다. 기기마다 직접 설정한다
- `hooks.json`의 훅은 처음 연결했을 때와 내용이 바뀔 때마다 Codex의 `/hooks`에서 신뢰해야 실행된다. 신뢰는 사용자가 직접 한다
