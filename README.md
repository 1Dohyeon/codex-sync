# codex-sync

[claude-sync](https://github.com/1Dohyeon/claude-sync)를 Codex의 디렉터리 위치와 파일명에 맞춰 옮긴 저장소입니다. 내용은 claude-sync와 같고, 형식이 다른 항목만 Codex 형식으로 바꿨습니다.

`~/.codex/`는 실제 폴더로 두고, 관리 대상 항목만 그 안으로 **심링크**합니다. Codex는 항상 `~/.codex/`와 `~/.agents/` 아래 고정 경로에서 읽으므로, 저장소를 어디에 clone하든 심링크가 위치 차이를 흡수합니다. CLI, 데스크톱 앱, IDE 확장은 모두 같은 경로를 읽습니다. Codex 클라우드(웹)는 원격 컨테이너에서 실행되므로 이 설정이 적용되지 않습니다.

## SETTINGS(Clone)

1. Codex를 설치하고 로그인합니다.
2. private 저장소이므로 `gh auth login`으로 GitHub에 로그인해 둡니다.
3. Codex에게 아래 한 줄을 그대로 전달합니다.

```
https://github.com/1Dohyeon/codex-sync 읽고 설치해줘
```

이후는 Codex가 [SETTING_GUIDE.md](SETTING_GUIDE.md)를 따라 처리합니다. 저장소를 둘 위치와 기존 설정을 옮겨도 되는지만 답해 주면 됩니다.

- 연결 상태는 `ls -l ~/.codex`와 `ls -l ~/.agents`로 확인합니다. `->` 뒤가 저장소 경로면 연결된 것입니다.
- **기존 설정은 지우지 않습니다.** 실제 파일은 `~/codex-backup/`으로 옮긴 뒤 링크합니다. 다른 도구가 관리하던 심링크는 덮어쓰기 전에 원래 경로를 알려주고 승인을 받습니다.
- 절차는 `git`·`ln`·`mv`·`mkdir`·`ls`·`find` 명령을 씁니다. 기존 `~/.codex/rules/`의 `forbidden` 규칙에 걸려 있으면 중간에 멈춥니다.

## GLOBAL CODEX `~/.codex/`

```s
~/.codex/                                         # 실제 폴더
├── agents/ hooks/ prompts/ rules/                # → codex-sync로 심링크
├── AGENTS.md                                     # → codex-sync로 심링크
└── config.toml auth.json sessions/ log/ ...      # Codex 설정·런타임, git이 모름

~/.agents/
└── skills/                                       # → codex-sync/skills로 심링크
```

skills만 `~/.agents/` 아래에 연결합니다. Codex가 사용자 skills를 이 위치에서 읽기 때문입니다.

`config.toml`은 이 저장소가 관리하지 않습니다. 모델, 샌드박스, MCP 서버, hooks 등록은 기기마다 직접 설정합니다.

`~/plans/`는 계획 문서를 둘 수 있는 곳 가운데 하나입니다. 경로는 [`AGENTS.md`](AGENTS.md)의 ENVIRONMENTS 절에 있는 `PLANS_PATH`로 바꿀 수 있습니다. `~/.codex/`와 codex-sync 밖의 별개 위치이며, 여기에 남길지와 이를 git 저장소로 둘지는 모두 선택입니다.

> `~/plans/`를 git 저장소로 관리하면 어느 기기에서든 똑같은 기록을 이어서 쓸 수 있습니다.

## codex

```s
codex-sync/                # 설정 저장소
├── AGENTS.md              # Codex 응답·행동 규칙 (세션 시작 시 자동 로드)
├── rules/                 # 명령 실행 허용·확인·금지 정책 (default.rules)
├── skills/                # 상황별 절차 (필요할 때만 로드)
├── agents/                # 커스텀 서브에이전트 정의 (*.toml)
├── prompts/               # 커스텀 프롬프트 (슬래시 커맨드)
├── hooks/                 # 훅 스크립트 (hooks.json 등록은 하지 않음)
├── templates/             # 문서 작성 시 참고할 템플릿 (심링크 대상 아님)
├── output-styles/         # claude-sync의 출력 스타일 원본 (심링크 대상 아님)
├── SETTING_GUIDE.md       # Codex가 읽고 실행하는 세팅 절차 (심링크 대상 아님)
└── README.md              # 이 문서 (심링크 대상 아님)
```

### claude-sync와 다른 점

| claude-sync                               | codex-sync               | 달라진 점                                                                          |
| ----------------------------------------- | ------------------------ | ---------------------------------------------------------------------------------- |
| `CLAUDE.md` `CLAUDE.local.md` `rules/*.md` | `AGENTS.md`              | Codex는 지침 폴더를 자동으로 읽지 않아서 원문을 순서대로 이어 붙였습니다.          |
| `agents/*.md`                             | `agents/*.toml`          | `name`·`description`·`developer_instructions` 필드로 옮겼습니다. `tools`·`model`은 대응 필드가 없어 뺐습니다. |
| `commands/`                               | `prompts/`               | 내용은 같습니다. Codex에서 prompts는 skills로 대체되는 중인 기능입니다.           |
| `settings.json`의 `permissions` (Bash)    | `rules/default.rules`    | `allow`는 `"allow"`, `deny`는 `"forbidden"`, `ask`는 `"prompt"`로 옮겼습니다.      |
| `settings.json`의 나머지, `settings.local.json` | 없음               | `config.toml`에 해당하며 이 저장소가 관리하지 않습니다.                            |

`CLAUDE.local.md`는 claude-sync에서 gitignore 대상이지만, codex-sync에서는 `AGENTS.md`에 합쳐져 **커밋됩니다.** Codex에는 `AGENTS.md`에 내용을 덧붙이는 로컬 전용 파일이 없기 때문입니다. `AGENTS.override.md`는 덧붙이는 파일이 아니라 `AGENTS.md`를 대체하는 파일입니다.

Codex의 `rules/`는 claude-sync의 `rules/`와 이름만 같습니다. claude-sync의 rules는 모델이 읽는 지침이고, codex-sync의 rules는 셸 명령을 실행하기 전에 실행기가 거르는 정책입니다. Codex에서 `"allow"`는 묻지 않고 **샌드박스 밖에서** 실행한다는 뜻이라, Claude Code의 `allow`보다 의미가 강합니다. TUI에서 명령을 허용 목록에 추가하면 Codex가 `~/.codex/rules/default.rules`에 규칙을 덧붙이므로, 링크를 타고 이 저장소 파일이 바뀔 수 있습니다.

## 라우팅

Codex는 세션을 시작할 때 [`AGENTS.md`](AGENTS.md)를 컨텍스트에 주입합니다. 따라서 어떤 작업에서든 공통으로 지켜야 하는 규칙은 `AGENTS.md`에 담습니다.

그 외에 작업 종류가 갈리는 경우(개발이면 개발, 리서치면 리서치 등)에는 [`skills/`](skills/)를 활용하도록 `AGENTS.md`에서 라우팅합니다.

| 요청 유형                         | 호출되는 skill                                    |
| --------------------------------- | ------------------------------------------------- |
| 코드 작성·수정                    | [`development`](skills/development/SKILL.md)      |
| 요청사항 분석·설계                | [`planning-dev`](skills/planning-dev/SKILL.md)    |
| 커밋 전 변경 리뷰                 | [`diff-review`](skills/diff-review/SKILL.md)      |
| 브랜치 전체 리뷰(PR 전)           | [`branch-review`](skills/branch-review/SKILL.md)  |
| PR 리뷰                           | [`pr-review`](skills/pr-review/SKILL.md)          |
| git 작업(worktree·commit·push 등) | [`git-workflow`](skills/git-workflow/SKILL.md)    |
| 조사·리서치·자료 종합             | [`research`](skills/research/SKILL.md)            |
| 논문·긴 기술 문서 정독            | [`paper-reading`](skills/paper-reading/SKILL.md)  |

## 알려진 한계

`AGENTS.md`와 skills는 claude-sync 원문을 그대로 옮겼기 때문에, Claude Code를 전제로 한 표현이 남아 있습니다.

- `/development` 같은 Claude Code의 스킬 호출 방식과 `Read`·`Grep`·`Agent` 같은 Claude Code 도구 이름이 본문에 있습니다.
- 스킬과 규칙이 가리키는 경로 가운데 `~/.claude/`로 시작하는 것이 있습니다. `rules/default.rules`의 `planning-dev` 훅 스크립트 규칙도 `~/.claude/skills/...` 경로를 씁니다.
- 리뷰 스킬(`diff-review`·`branch-review`·`pr-review`)은 축마다 서브에이전트를 병렬로 띄우고 모델을 따로 지정하는 구조입니다. codex-sync의 `agents/*.toml`에는 모델 지정이 없으므로, 축별 모델 배분은 적용되지 않습니다.

세션 흐름과 리뷰 축 설계는 [claude-sync README](https://github.com/1Dohyeon/claude-sync#세션-흐름)를 참고합니다.
