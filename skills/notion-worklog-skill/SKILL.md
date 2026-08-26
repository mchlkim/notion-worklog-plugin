---
name: notion-worklog-skill
description: Use when starting, progressing, or finishing a multi-step task that should leave a trace — code changes, infrastructure work, investigations, document authoring — or when the user asks what work was done before. Records the plan, execution, and result as a card in a shared Notion kanban database so work done by Claude Code, Codex, Cursor, or any other agent lands on one auditable board. Trigger for 작업 기록, 작업 이력, worklog, work log, 칸반, kanban, Notion 기록, 무슨 작업 했었지.
compatibility: Requires a connected Notion MCP server (https://mcp.notion.com/mcp) with write access to the target database.
metadata:
  author: mchlkim
  version: "1.0"
---

# Notion Worklog Skill

어떤 에이전트가 작업하든 **같은 Notion 보드**에 계획 → 실행 → 결과를 남긴다.
나중에 사람이나 다른 에이전트가 "그때 왜 그렇게 했지"를 추적할 수 있게 하는 것이 목적이다.

## 언제 쓰나

**기록한다**
- 파일·인프라를 실제로 변경하는 작업
- 여러 단계에 걸치거나 한 세션에 안 끝날 작업
- 조사/분석처럼 결론이 산출물인 작업
- 사용자가 과거 이력을 물을 때 (이때는 조회만)

**기록하지 않는다**
- 단순 질문 답변, 한 줄 조회, 읽기 전용 탐색
- 사용자가 명시적으로 "기록하지 마"라고 한 경우

## 기록 대상 찾기

1. 환경변수 `NOTION_WORKLOG_DATA_SOURCE_ID` 가 있으면 그 값을 쓴다.
2. 없으면 `assets/worklog.config.json` 의 `notion.dataSourceId` 를 읽는다.
3. 둘 다 없거나 접근이 안 되면 `references/bootstrap.md` 를 따라 DB를 새로 만들고,
   만든 ID를 `assets/worklog.config.json` 에 써 넣는다.

## 필요한 도구

Notion MCP 서버(`https://mcp.notion.com/mcp`)의 도구를 쓴다.
**클라이언트마다 도구 이름 접두어가 다르므로** 이름 끝부분으로 찾을 것:

| 하는 일 | 도구 (접두어 제외) |
|---|---|
| 스키마·기존 카드 확인 | `notion-fetch`, `notion-search` |
| 카드 생성 | `notion-create-pages` |
| 카드 수정 | `notion-update-page` |

예: Claude Code는 `mcp__claude_ai_Notion__notion-create-pages`, 다른 클라이언트는 `notion.create_pages` 형태일 수 있다.

> Notion MCP를 못 찾으면 **조용히 넘어가지 말고** 사용자에게 알린다:
> "Notion MCP가 연결돼 있지 않아 작업 기록을 남기지 못합니다. `https://mcp.notion.com/mcp` 를 연결해 주세요."

## 절차

### 1) 착수 — 카드 생성

`notion-create-pages` 로 `data_source_id` 를 부모로 하는 페이지를 만든다.

- `작업명`: `[프로젝트] 한 줄 요약` (예: `[프로젝트A] API 서버 v2 마이그레이션`)
- `상태`: `계획`
- `에이전트` / `모델`: 지금 돌고 있는 에이전트와 모델명
- `프로젝트` `유형` `우선순위` `시작` `작업경로` 채움
- `태그`(select): `작업경로` 에서 파생한 슬러그. **같은 경로면 항상 같은 값**이어야 한다 —
  git 최상위(없으면 cwd)의 basename을 소문자·하이픈으로 정규화한다.
  `/Users/me/dev/api-server` → `api-server`.
  **select 이므로 기존 옵션에 있으면 그대로 쓰고, 없으면 옵션을 먼저 추가**한다
  (기존 옵션을 전부 포함해서 `ALTER`). 규칙 전문은 [references/schema.md](references/schema.md).
- 본문: `assets/card-template.md` 의 `1. 계획` 섹션을 채워서 넣는다

카드 URL을 기억해 뒀다가 이후 수정에 쓴다. 사용자에게 URL을 한 줄로 알린다.

### 2) 진행 — 상태만 옮기고 로그는 append

착수하면 `상태` = `진행중`.

의미 있는 결정과 시행착오가 생길 때만 본문 `2. 실행` 에 **덧붙인다**.
`notion-update-page` 의 `update_content` (search/replace) 를 써서 해당 섹션에만 추가한다.
`replace_content` 로 본문 전체를 다시 쓰지 말 것 — 이전 기록이 날아간다.

기록 가치가 있는 것: 방향을 바꾼 판단, 막혔던 지점과 원인, 버린 대안과 이유.
기록하지 말 것: 명령어 나열, 성공한 단순 반복 작업.

### 3) 종료 — 결과 채우고 `검증` 으로

`결과`(`성공`/`부분성공`/`실패`/`롤백`) · `완료일` · `브랜치/커밋` 을 채우고
본문 `3. 결과`, `4. 배운 점` 을 작성한 뒤 `상태` = `검증`.

`브랜치/커밋` 은 **`브랜치@짧은해시` 를 커밋 URL로 하이퍼링크**한다.
텍스트 속성이 마크다운을 해석하므로 `[main@0e89e71](<원격URL>/commit/<전체해시>)` 로 쓴다.
원격이 없으면 링크 없이 `main@0e89e71`, git 레포가 아니면 비워 둔다.

**`완료` 로 옮기는 것은 사람이 확인한 뒤**다. 에이전트가 스스로 `완료` 로 올리지 않는다.
사용자가 확인했다고 하면 `상태` = `완료` 로 옮긴다.

### 4) 실패해도 카드를 남긴다

`상태` = `중단/실패`, `결과` = `실패` 또는 `롤백`, 사유를 본문에 적는다.
실패 기록이 다음 작업에 더 유용하다. 카드를 지우지 않는다.

## 규칙

- **작업 단위로 카드를 나눈다.** 한 대화에서 세 가지 일을 했으면 카드도 세 개다.
- 이미 진행 중인 카드가 있는지 먼저 확인한다 (`notion-search` 또는 `상태` 필터). 같은 작업을 중복 생성하지 않는다.
- 속성 값은 **정해진 옵션 안에서만** 쓴다. 새 값이 필요하면 사용자에게 확인하고 옵션을 추가한다.
- `태그` 는 예외다. 경로에서 기계적으로 파생하는 값이므로 사용자에게 묻지 않고 옵션을 추가해도 된다.
  대신 **같은 경로에 이미 카드가 있으면 그 카드의 태그를 그대로 재사용한다.** 새로 만들어 내지 않는다.
- 고객 데이터, 자격증명, 내부 IP·계정 정보는 본문에 쓰지 않는다. 경로와 리소스명 수준까지만.

## 참고 파일

- [references/schema.md](references/schema.md) — 전체 속성과 허용값, MCP 호출 예시
- [references/bootstrap.md](references/bootstrap.md) — 새 워크스페이스에 DB 만들기 (DDL 포함)
- [assets/card-template.md](assets/card-template.md) — 카드 본문 형식
- [assets/worklog.config.json](assets/worklog.config.json) — 대상 DB / 데이터소스 ID
