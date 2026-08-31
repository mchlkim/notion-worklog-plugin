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

배포본은 값이 비어 있다. `bootstrap.md` 로 DB를 만든 뒤 채우거나 환경변수로 둔다.

```json
{
  "notion": {
    "workspace": "",
    "pageUrl": "",
    "databaseUrl": "",
    "databaseId": "",
    "dataSourceId": ""
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

### 프로젝트 옵션 바꾸기

`프로젝트` 속성의 선택지는 쓰는 사람의 환경에 맞춰 바꾸는 값이다.
카드를 묶어 보는 **유일한 분류 키**이므로 설치하고 가장 먼저 손볼 곳이다.
[`bootstrap.md`](skills/notion-worklog-skill/references/bootstrap.md) 의 DDL과
[`schema.md`](skills/notion-worklog-skill/references/schema.md) 의 허용값 표를 함께 고친다.
두 파일이 어긋나면 에이전트가 없는 옵션을 쓰려다 실패한다.

---

## 사용

### 슬래시 커맨드 (Claude Code)

```bash
/worklog-start API 서버 v2 마이그레이션   # 카드 생성, 상태=계획
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
API 서버 마이그레이션 관련 카드 다 보여줘
```

---

## 카드 스키마

| 속성 | 타입 | 값 |
|---|---|---|
| `작업명` | title | 한 줄 요약 — 대괄호 접두어 없이 (아래) |
| `상태` | select | `Backlog` `계획` `진행중` `검증` `완료` `중단/실패` — 칸반 레인 |
| `에이전트` | select | `Claude Code` `Codex` `Gemini CLI` `Cursor` `사람` `기타` |
| `모델` | select | `claude-opus-5` `claude-sonnet-5` `claude-haiku-4-5` `claude-fable-5` `gpt-5.6` `기타` |
| `프로젝트` | select | 고객사·프로젝트 이름. 분류/필터 키 — 사용자 정의 (설치 시 교체) |
| `유형` | multi_select | `구축` `운영` `조사/분석` `문서` `버그수정` `자동화` `리팩토링` `설정/환경` |
| `우선순위` | select | `P0`–`P3` |
| `결과` | select | `성공` `부분성공` `실패` `롤백` — 종료 시점에만 |
| `시작` `완료일` | date | |
| `작업경로` | text | repo 또는 cwd |
| `브랜치/커밋` | text | `main@0e89e71` 형식, 커밋 URL 하이퍼링크. 부연 금지 |
| `푸시` | checkbox | 원격에 올라갔는지. `git branch -r --contains` 로 판정 |
| `미해결` | checkbox | 남은 일이 있는 채 닫힌 카드. lint 가 추적 |
| `관련 작업` | relation | 선행·후속 카드 연결 (self-relation) |
| `세션ID` | text | 원본 로그 추적용 |
| `참고링크` | url | PR, 이슈, 문서 |

### 작업명 — 대괄호 접두어를 쓰지 않는다

제목에는 **한 줄 요약만** 쓴다. 분류는 `프로젝트` 속성이 담당한다.

| ❌ | ✅ |
|---|---|
| `[EDP] EKS 1.31 업그레이드 작업계획서` | `EKS 1.31 업그레이드 작업계획서` + `프로젝트` = `EDP` |
| `[개인/샌드박스] Shotta 웹사이트 배포` | `Shotta 웹사이트 배포` + `프로젝트` = `개인/샌드박스` |

같은 값을 제목과 속성에 두 번 적으면 보드 카드에서 반복되고, 프로젝트 이름이 바뀌었을 때
둘이 어긋난다. 접두어를 떼서 무슨 일인지 알 수 없어지면 접두어를 되살리는 대신
제목 자체를 구체적으로 쓴다.

### 프로젝트 — 묶어 보는 키

`프로젝트` 는 **사람이 정하는 값**이다. 에이전트는 기존 select 옵션 중에서 고르고,
맞는 게 없으면 임의로 만들지 않고 사용자에게 묻는다.
같은 `작업경로` 의 지난 카드가 있으면 그 카드의 `프로젝트` 를 재사용한다.

```
EDP 프로젝트 카드만 보여줘
```

`작업경로` 를 text로 남겨 둔 것은 절대경로가 머신·worktree마다 달라져 필터 키로
못 쓰기 때문이다 — 정확한 위치는 `작업경로`, 묶어 보기는 `프로젝트` 가 담당한다.

규칙 전문은 [`schema.md`](skills/notion-worklog-skill/references/schema.md) 의
"작업명 규칙"·"프로젝트 규칙" 절에 있다.

### 브랜치/커밋 — 커밋으로 바로 가기

`브랜치@짧은해시` 를 표시하고 실제 커밋으로 링크한다.
Notion 텍스트 속성은 마크다운을 해석하므로 `[표시](URL)` 이 하이퍼링크가 된다.

| 상황 | 기록되는 값 |
|---|---|
| 원격이 있는 git 레포 | [`main@0e89e71`](https://github.com/mchlkim/notion-worklog-plugin/commit/0e89e714e971cb3a7a181214363337195dd7a1dc) — 클릭하면 커밋으로 |
| 원격 없는 로컬 레포 | `main@0e89e71` (링크 없이) |
| git 레포가 아님 | 비워 둔다 |

원격 URL은 `git remote get-url origin` 을 웹 URL로 정규화해 만든다
(`git@host:o/r.git` → `https://host/o/r`).

카드 본문은 `0. 하네스` / `1. 계획` / `2. 실행` / `3. 결과` / `4. 개선점` / `5. 출처` / `6. 산출물` 일곱 섹션 고정이다.
`0. 하네스` 에는 그 작업에 쓴 스킬·MCP·CLI·서브에이전트를 최상단에 남긴다.
섹션은 제목1, 그 안의 이름 붙은 항목(`목표`, `범위 / 범위 밖` 등)은 제목2로 두고 내용은 다음 줄에 쓴다.
`2. 실행`·`4. 개선점`·`5. 출처`·`6. 산출물` 처럼 계속 덧붙는 목록은 불릿을 유지한다
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

**플러그인 매니페스트가 셋인 이유**: 세 클라이언트가 서로 다른 위치를 본다.
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

### 1.4.x → 1.5.0 — `태그` 폐지, 제목에서 대괄호 제거

분류 축을 `프로젝트` 하나로 합쳤다. 경로에서 파생하던 `태그` 속성을 없애고,
카드 제목의 `[프로젝트]` 접두어도 떼어 낸다.

에이전트에게 시키면 된다:

```
작업 기록 DB를 1.5.0 에 맞춰 갱신해줘 — 태그 속성 없애고 제목의 대괄호 접두어 제거
```

수동으로 하려면 순서가 있다. **`DROP COLUMN` 은 값을 되돌릴 수 없으니** 먼저
`태그` 값을 어딘가에 받아 두고, 칸반 뷰에 `태그` 필터가 걸려 있으면 그것부터 지운다.

```sql
DROP COLUMN "태그";
ALTER COLUMN "작업명" SET TITLE COMMENT '한 줄 요약. 대괄호 접두어를 붙이지 않는다 — 분류는 프로젝트 속성이 담당'
```

기존 카드 제목은 `notion-update-page` 로 하나씩 고친다.
`[개인/샌드박스] Shotta 웹사이트 배포` → `Shotta 웹사이트 배포`.
남은 게 있는지는 이렇게 확인한다:

```sql
SELECT "작업명" FROM "collection://<dataSourceId>"
WHERE "작업명" LIKE '%[%' OR "작업명" LIKE '%]%'
```

`태그` 로 나뉘어 있던 레포 구분이 필요하면 `작업경로` 로 거르거나,
그 이름을 `프로젝트` 옵션으로 추가한다.

### 1.2.x → 1.3.0 — 속성 타입 변경 및 `사람검토` 제거

> 아래 두 절은 1.4.x 이하에서 올라오는 경우의 중간 단계다.
> `태그` 관련 구문은 1.5.0 에서 폐지됐으니, 최신으로 바로 올릴 거면 건너뛰어도 된다.

에이전트에게 시키면 된다:

```
작업 기록 DB 스키마를 1.3.0 에 맞춰 갱신해줘
```

수동으로 하려면 `notion-update-data-source` 에 이렇게 넘긴다 —
**기존 옵션을 빠뜨리면 그 값들이 사라지니** 현재 값을 먼저 조회할 것:

```sql
ALTER COLUMN "태그" SET SELECT('현재 쓰는 태그들…');
ALTER COLUMN "모델" SET SELECT('claude-opus-5':orange, 'claude-sonnet-5':blue, 'gpt-5.6':gray, '기타':default);
DROP COLUMN "사람검토"
```

`ALTER ... SET SELECT` 는 옵션명이 같으면 기존 카드의 값을 유지한다.
`사람검토` 를 없애도 "`완료` 는 사람이 확인한 뒤" 원칙은 그대로다 — 체크박스가 아니라 절차로 지킨다.

### 1.1.x 이하에서 올라오는 경우

`태그` 속성 자체가 없으므로 **1.3.0 형태로 한 번에 추가**한다.
(1.2.0 에서는 text 였지만 1.3.0 에서 select 로 바뀌었으니 중간 단계를 거칠 필요가 없다.)

```sql
ADD COLUMN "태그" SELECT('내-레포-이름':blue);
ALTER COLUMN "모델" SET SELECT('claude-opus-5':orange, 'claude-sonnet-5':blue, 'gpt-5.6':gray, '기타':default);
DROP COLUMN "사람검토"
```

기존 카드의 `태그` 는 비어 있어도 무방하다 — 이후 생성분부터 채워진다.

---

## 문제 해결

| 증상 | 원인과 조치 |
|---|---|
| 카드가 안 만들어짐 | Notion MCP 미연결. 스킬이 조용히 넘어가지 않고 알리게 돼 있으니 메시지를 확인한다 |
| 칸반에 레인이 일부만 보임 | Notion은 **카드 없는 그룹을 기본 숨김** 처리한다. 보드 뷰 설정에서 "빈 그룹 표시"를 켠다 |
| 생성 직후 표 뷰가 먼저 뜸 | 기본 탭이 표 뷰다. UI에서 칸반 탭을 맨 앞으로 드래그한다 |
| select 값이 거부됨 (`프로젝트`·`모델`) | DDL의 옵션에 없는 값이다. `bootstrap.md` 와 `schema.md` 를 함께 갱신한다. 옵션을 추가할 때는 **기존 옵션을 전부 포함해서** `ALTER` 해야 한다 |
| 날짜 속성이 안 들어감 | 클라이언트에 따라 `date:완료일:start` 형태의 확장 키가 필요하다. `notion-fetch` 로 SQLite 컬럼 정의를 먼저 확인한다 |
| 이전 실행 로그가 사라짐 | `replace_content` 로 본문을 덮어썼을 때 생긴다. `update_content` 로 해당 섹션에만 append 해야 한다 |
| Codex에서 수정이 반영 안 됨 | 캐시가 버전 단위라 같은 버전에선 갱신되지 않는다. `codex plugin remove` → `add` 로 재설치한다. 로컬 마켓플레이스에 `marketplace upgrade` 는 쓸 수 없다 (Git 전용) |
| 마켓플레이스를 재등록했더니 플러그인이 사라짐 | `claude plugin marketplace remove` 는 그 마켓플레이스에서 설치한 플러그인까지 함께 지운다(`enabledPlugins` 에서 빠진다). `claude plugin install <플러그인>@<마켓플레이스>` 로 다시 설치한다. Codex는 `[plugins.*] enabled` 선언이 남아 재설치가 필요 없다 |
| 같은 레포인데 프로젝트가 갈림 | 같은 경로의 기존 카드 값을 재사용하게 돼 있으나 경로가 달랐을 수 있다(worktree, 심볼릭 링크). 한쪽 카드의 `프로젝트` 를 맞춰 준다 |

---

## 라이선스

[MIT](LICENSE) © mchlkim
