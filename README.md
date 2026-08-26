# notion-worklog-plugin

에이전트가 한 일을 **Notion 칸반 하나에 모으는** 플러그인.

Claude Code에서 시작한 작업을 Codex가 이어받아도, 며칠 뒤 다른 세션에서 다시 열어도
**같은 보드 · 같은 스키마 · 같은 절차**로 계획 → 실행 → 결과가 쌓인다.
"그때 왜 그렇게 했지"를 사람도 에이전트도 추적할 수 있게 하는 것이 목적이다.

- 규격: [Agent Plugins 1.0.0](https://agent-plugins.org/specification) + [Agent Skills](https://agentskills.io/specification)
- 지원: Claude Code · Codex · Agent Plugins 규격을 읽는 모든 클라이언트
- 필요: Notion 계정 + [Notion 원격 MCP](https://mcp.notion.com/mcp) (OAuth, 토큰 발급 불필요)

---

## 무엇을 해결하나

에이전트와 하는 작업은 대화창 안에서만 살아 있다. 세션을 닫으면 판단 근거가 사라지고,
다른 도구로 옮기면 맥락이 끊긴다. 그렇다고 매번 사람이 회고를 옮겨 적기도 어렵다.

이 플러그인은 그 기록을 **에이전트 본인이** 남기게 한다.

| | 없을 때 | 있을 때 |
|---|---|---|
| 작업 이력 | 세션 로그에 흩어짐 | 칸반 카드 한 장 |
| 도구 전환 | 맥락 유실 | 같은 보드에 이어 기록 |
| 실패 기록 | 사라짐 | `중단/실패` 레인에 사유까지 남음 |
| 회고 | 사람이 수동 정리 | 카드 본문에 이미 있음 |

---

## 동작 방식

에이전트가 작업을 시작·진행·종료할 때 카드 한 장이 상태를 따라 움직인다.

```text
  ┌─────────┐   착수    ┌─────────┐   진행    ┌─────────┐
  │  계획   │ ────────▶ │ 진행중  │ ────────▶ │  검증   │
  └─────────┘  카드 생성 └─────────┘ 실행로그  └─────────┘
       │                     │       append        │
       │                     │                     │ 사람 확인
       │                     ▼                     ▼
       │               ┌───────────┐         ┌─────────┐
       └──────────────▶│ 중단/실패 │         │  완료   │
           막히면       └───────────┘         └─────────┘
```

핵심 규칙 세 가지:

1. **`완료` 로 올리는 건 사람만 한다.** 에이전트는 `검증` 까지만. 자화자찬 방지.
2. **실행 로그는 append.** 본문을 통째로 덮어쓰면 이전 기록이 날아간다.
3. **실패해도 카드를 지우지 않는다.** 실패 기록이 다음 작업에 더 유용하다.

### 언제 기록하나

| 기록한다 | 기록하지 않는다 |
|---|---|
| 파일·인프라를 실제로 변경 | 단순 질문 답변 |
| 여러 단계에 걸치는 작업 | 한 줄 조회, 읽기 전용 탐색 |
| 결론이 산출물인 조사/분석 | 사용자가 "기록하지 마"라고 한 경우 |

판단 기준 전문은 [`SKILL.md`](skills/notion-worklog-skill/SKILL.md) 의 "언제 쓰나" 절에 있다.

---

## 설치

### 1. 마켓플레이스 등록

```bash
# Claude Code
claude plugin marketplace add mchlkim/notion-worklog-plugin
claude plugin install notion-worklog-plugin@mchlkim-agent-tools

# Codex
codex plugin marketplace add mchlkim/notion-worklog-plugin
codex plugin add notion-worklog-plugin@mchlkim-agent-tools
```

로컬 클론이나 개발 중인 사본을 쓰려면 레포 자리에 **플러그인 디렉토리 경로**를 넣는다.
루트에 마켓플레이스 매니페스트가 있으므로 그대로 인식된다.

```bash
claude plugin marketplace add ~/dev/notion-worklog-plugin
```

> **Codex는 설치 시 `~/.codex/plugins/cache/<마켓플레이스>/<플러그인>/<버전>/` 로 사본을 복사한다.**
> 캐시는 **버전으로 키가 잡히므로** 같은 버전에서 소스만 고쳐도 반영되지 않는다. 재설치해야 한다:
>
> ```bash
> codex plugin remove notion-worklog-plugin@mchlkim-agent-tools
> codex plugin add    notion-worklog-plugin@mchlkim-agent-tools
> ```
>
> `codex plugin marketplace upgrade` 는 **Git 마켓플레이스 전용**이다.
> 로컬 경로로 등록했다면 `is not configured as a Git marketplace` 오류가 난다.
> Claude Code는 소스 경로를 그대로 참조하므로 이 과정이 필요 없다.

Agent Plugins 규격을 지원하는 다른 클라이언트는 이 디렉토리를 그대로 등록하면
루트 `plugin.json` · `skills/` · `mcp.json` 을 읽는다.

### 2. Notion MCP 연결

Notion 공식 원격 MCP를 쓴다. 별도 인티그레이션 토큰을 만들 필요가 없다.

| 클라이언트 | 설정 |
|---|---|
| Claude Code | 플러그인의 `.mcp.json` 이 자동 적용된다. 이미 Notion 커넥터를 연결했다면 중복이므로 하나만 남긴다 |
| Codex | `codex mcp login notion` 으로 OAuth 로그인 |
| 기타 | `https://mcp.notion.com/mcp` 를 streamable-http MCP로 등록 |

연결 확인:

```
Notion 워크스페이스 연결됐는지 확인해줘
```

### 3. 기록용 DB 만들기 — **최초 1회 필수**

이 플러그인은 **DB를 자동으로 만들지 않는다.** 처음 설치하면 자기 워크스페이스에
보드를 하나 만들고 그 ID를 설정에 넣어야 한다.

에이전트에게 이렇게 시키면 된다:

```
references/bootstrap.md 대로 작업 기록용 Notion DB를 만들고
worklog.config.json 을 갱신해줘
```

[`references/bootstrap.md`](skills/notion-worklog-skill/references/bootstrap.md) 에
부모 페이지 생성 → DB DDL → 칸반 뷰 구성 → config 갱신까지의 절차가 들어 있다.
수동으로 하려면 그 문서의 DDL을 Notion에 직접 적용해도 된다.

---

## 설정

[`skills/notion-worklog-skill/assets/worklog.config.json`](skills/notion-worklog-skill/assets/worklog.config.json)

```json
{
  "notion": {
    "workspace": "<워크스페이스 이름>",
    "pageUrl": "<부모 페이지 URL>",
    "databaseUrl": "<DB URL>",
    "databaseId": "<database id>",
    "dataSourceId": "<data source id>"
  },
  "defaults": {
    "priority": "P2",
    "project": "개인/샌드박스"
  }
}
```

기록 대상을 찾는 순서:

1. 환경변수 `NOTION_WORKLOG_DATA_SOURCE_ID`
2. `worklog.config.json` 의 `notion.dataSourceId`
3. 둘 다 없으면 → `bootstrap.md` 절차로 새로 생성

배포본의 `worklog.config.json` 은 **빈 템플릿**이다. 파일을 고치는 대신 환경변수로 두면
플러그인을 업데이트해도 설정이 덮이지 않는다. 에이전트별로 이렇게 넣는다:

| 위치 | 설정 |
|---|---|
| 셸 전역 | `~/.zshrc` 에 `export NOTION_WORKLOG_DATA_SOURCE_ID="..."` |
| Claude Code | `~/.claude/settings.json` 의 `env` 블록 |
| Codex | `~/.codex/config.toml` 의 `[shell_environment_policy.set]` |

`dataSourceId` 는 `databaseId` 와 **다른 값**이다. Notion DB 하나에 여러 데이터소스가
달릴 수 있어서, 카드를 만들 때는 데이터소스 ID가 필요하다.
`notion-fetch` 로 DB를 조회하면 `collection://<data_source_id>` 형태로 나온다.

### 프로젝트 태그 바꾸기

`프로젝트` 속성의 선택지는 쓰는 사람의 환경에 맞춰 바꾸는 값이다.
[`bootstrap.md`](skills/notion-worklog-skill/references/bootstrap.md) 의 DDL과
[`schema.md`](skills/notion-worklog-skill/references/schema.md) 의 허용값 표를 함께 고친다.
두 파일이 어긋나면 에이전트가 없는 옵션을 쓰려다 실패한다.

---

## 사용

### 슬래시 커맨드 (Claude Code)

```bash
/worklog-start [프로젝트] EKS 1.31 업그레이드      # 카드 생성, 상태=계획
/worklog-finish 성공                                # 결과 채우고 상태=검증
```

인자를 생략하면 지금까지의 대화 맥락에서 작업명·프로젝트·유형·결과를 추론한다.

### 자동 트리거

스킬 `description` 이 걸려 있어 별도 호출 없이도 붙는다.
`작업 기록`, `작업 이력`, `worklog`, `칸반`, `무슨 작업 했었지` 같은 표현이 트리거다.

항상 켜 두려면 `CLAUDE.md`(또는 `AGENTS.md`)에 한 줄 넣는다:

```markdown
코드·인프라를 변경하거나 여러 단계에 걸치는 작업을 하면
`notion-worklog-skill` 스킬을 반드시 사용해 계획 → 실행 → 결과를 남긴다.
```

### 이력 조회

```
지난주에 무슨 작업 했었는지 보드에서 찾아줘
EKS 업그레이드 관련 카드 다 보여줘
```

---

## 카드 스키마

| 속성 | 타입 | 값 |
|---|---|---|
| `작업명` | title | `[프로젝트] 한 줄 요약` |
| `상태` | select | `Backlog` `계획` `진행중` `검증` `완료` `중단/실패` — 칸반 레인 |
| `에이전트` | select | `Claude Code` `Codex` `Gemini CLI` `Cursor` `사람` `기타` |
| `모델` | text | 실제 모델명 |
| `프로젝트` | select | 사용자 정의 (설치 시 교체) |
| `유형` | multi_select | `구축` `운영` `조사/분석` `문서` `버그수정` `자동화` `리팩토링` `설정/환경` |
| `우선순위` | select | `P0`–`P3` |
| `결과` | select | `성공` `부분성공` `실패` `롤백` — 종료 시점에만 |
| `사람검토` | checkbox | 사람이 확인했는지 |
| `시작` `완료일` | date | |
| `작업경로` | text | repo 또는 cwd |
| `태그` | text | `작업경로` 에서 파생한 슬러그 — 필터 키 (아래) |
| `브랜치/커밋` | text | |
| `세션ID` | text | 원본 로그 추적용 |
| `참고링크` | url | PR, 이슈, 문서 |

### 태그 — 경로 단위로 묶어 보기

`태그` 는 사람이 정하는 값이 아니라 **작업 디렉토리에서 기계적으로 파생**한다.
같은 레포에서 나온 작업은 언제 어느 에이전트가 기록하든 같은 태그가 붙는다.

| `작업경로` | `태그` |
|---|---|
| `/Users/me/dev/api-server` | `api-server` |
| `/Users/me/dev/My Project` | `my-project` |
| `/Users/me/work/Data_Pipeline.v2` | `data-pipeline-v2` |

git 레포면 최상위 경로, 아니면 cwd의 basename을 소문자·하이픈으로 정규화한다.
`작업경로` 는 절대경로라 머신·worktree마다 달라지지만 `태그` 는 안정적이라
Notion 보드에서 필터·그룹 키로 쓸 수 있다.

```
notion-worklog-plugin 태그 붙은 카드만 보여줘
```

규칙 전문은 [`schema.md`](skills/notion-worklog-skill/references/schema.md) 의 "태그 규칙" 절에 있다.

카드 본문은 `1. 계획` / `2. 실행` / `3. 결과` / `4. 배운 점` 네 섹션 고정이다
([`card-template.md`](skills/notion-worklog-skill/assets/card-template.md)).

전체 속성 정의와 MCP 호출 예시는
[`references/schema.md`](skills/notion-worklog-skill/references/schema.md) 에 있다.

### 본문에 쓰지 않는 것

스킬이 명시적으로 금지한다 — **고객 데이터, 자격증명, 내부 IP·계정 정보**.
경로와 리소스명 수준까지만 기록한다.

---

## 구조

```text
notion-worklog-plugin/
├── plugin.json                  # Agent Plugins 1.0.0 (표준)
├── mcp.json                     # 표준 MCP (streamable-http)
├── .claude-plugin/
│   ├── plugin.json              # Claude Code 플러그인 매니페스트
│   └── marketplace.json         # 이 레포를 마켓플레이스로 등록 (source: ".")
├── .agents/plugins/
│   └── marketplace.json         # Codex / 표준 규격용 동일 선언
├── .codex-plugin/plugin.json    # Codex
├── .mcp.json                    # Claude Code + Codex 공용 MCP
├── skills/
│   └── notion-worklog-skill/    # 세 규격이 모두 이 경로를 본다
│       ├── SKILL.md             # 기록 절차 — 단일 진실 소스
│       ├── references/
│       │   ├── schema.md        # 속성 스키마 + MCP 호출 예시
│       │   └── bootstrap.md     # 새 워크스페이스에 DB 만들기 (DDL)
│       └── assets/
│           ├── card-template.md
│           └── worklog.config.json
├── commands/                    # Claude Code 슬래시커맨드
│   ├── worklog-start.md
│   └── worklog-finish.md
├── LICENSE
└── README.md
```

**매니페스트가 셋인 이유**: 세 클라이언트가 서로 다른 위치를 본다.
표준은 루트 `plugin.json`, Claude Code는 `.claude-plugin/plugin.json`,
Codex는 `.codex-plugin/plugin.json`.
반면 **`skills/` 는 셋 다 같은 경로**를 쓰므로 스킬 본문은 하나만 유지된다.
`.mcp.json` 도 Claude Code와 Codex가 같은 형식이라 한 파일을 공유한다.

MCP 설정이 `mcp.json` / `.mcp.json` 둘로 나뉜 것도 같은 이유다 —
표준 규격은 `streamable-http`, Claude Code·Codex는 `http` 타입명을 쓴다.

**`plugin.json` 과 `marketplace.json` 의 역할은 다르다.**
앞쪽은 "이 플러그인이 무엇인가", 뒤쪽은 "이 레포에 어떤 플러그인이 있는가"를 답한다.
이 레포는 플러그인 하나짜리라 `marketplace.json` 이 `"source": "."` 로 자기 자신을 가리킨다.
`marketplace add` 는 **레포 루트에서** 마켓플레이스 매니페스트를 찾으므로 이 파일이 없으면
설치 명령이 아무것도 찾지 못한다.

---

## 릴리스

버전은 매니페스트 5곳에 적혀 있다 — 루트 `plugin.json`, `.claude-plugin/plugin.json`,
`.codex-plugin/plugin.json`, 그리고 마켓플레이스 매니페스트 2곳의 `plugins[0].version`.
어긋난 채로 배포하면 클라이언트마다 다른 버전을 보고한다.

배포 전 검증:

```bash
claude plugin validate . --strict   # 마켓플레이스 + 플러그인 매니페스트
claude plugin tag                   # plugin.json 과 마켓플레이스 항목의 일치를 검증하고 git 태그 생성
```

`claude plugin tag` 는 `{name}--v{version}` 태그를 만들면서 두 매니페스트가 같은 버전을
말하는지 확인해 준다. 릴리스 커밋 전에 돌리는 것이 가장 싸게 막는 방법이다.

---

## 업그레이드

### 1.1.x → 1.2.0 — `태그` 속성 추가

이미 DB를 만들어 쓰고 있다면 속성을 하나 추가해야 한다. 에이전트에게 시키면 된다:

```
작업 기록 DB에 "태그" 텍스트 속성을 추가해줘
```

추가하지 않으면 카드 생성 시 해당 속성만 무시되거나 거부된다.
기존 카드의 태그는 비어 있어도 무방하다 — 이후 생성분부터 채워진다.

---

## 문제 해결

| 증상 | 원인과 조치 |
|---|---|
| 카드가 안 만들어짐 | Notion MCP 미연결. 스킬이 조용히 넘어가지 않고 알리게 돼 있으니 메시지를 확인한다 |
| 칸반에 레인이 일부만 보임 | Notion은 **카드 없는 그룹을 기본 숨김** 처리한다. 보드 뷰 설정에서 "빈 그룹 표시"를 켠다 |
| 생성 직후 표 뷰가 먼저 뜸 | 기본 탭이 표 뷰다. UI에서 칸반 탭을 맨 앞으로 드래그한다 |
| `프로젝트` 값이 거부됨 | DDL의 select 옵션에 없는 값. `bootstrap.md` 와 `schema.md` 를 함께 갱신한다 |
| 날짜 속성이 안 들어감 | 클라이언트에 따라 `date:완료일:start` 형태의 확장 키가 필요하다. `notion-fetch` 로 SQLite 컬럼 정의를 먼저 확인한다 |
| 이전 실행 로그가 사라짐 | `replace_content` 로 본문을 덮어썼을 때 생긴다. `update_content` 로 해당 섹션에만 append 해야 한다 |
| Codex에서 수정이 반영 안 됨 | 캐시가 버전 단위라 같은 버전에선 갱신되지 않는다. `codex plugin remove` → `add` 로 재설치한다. 로컬 마켓플레이스에 `marketplace upgrade` 는 쓸 수 없다 (Git 전용) |
| 마켓플레이스를 재등록했더니 플러그인이 사라짐 | `claude plugin marketplace remove` 는 그 마켓플레이스에서 설치한 플러그인까지 함께 지운다(`enabledPlugins` 에서 빠진다). `claude plugin install <플러그인>@<마켓플레이스>` 로 다시 설치한다. Codex는 `[plugins.*] enabled` 선언이 남아 재설치가 필요 없다 |
| 같은 레포인데 태그가 갈림 | 절대경로가 달랐을 가능성(worktree, 심볼릭 링크). 같은 경로의 기존 카드 태그를 재사용하게 돼 있으니 한쪽 카드의 태그를 맞춰 준다 |

---

## 라이선스

[MIT](LICENSE) © mchlkim
