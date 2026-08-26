# 속성 스키마와 호출 예시

## 속성

| 속성 | 타입 | 허용값 / 규칙 |
|---|---|---|
| `작업명` | title | `[프로젝트] 한 줄 요약` |
| `상태` | select | `Backlog` `계획` `진행중` `검증` `완료` `중단/실패` — 칸반 레인 |
| `에이전트` | select | `Claude Code` `Codex` `Gemini CLI` `Cursor` `사람` `기타` |
| `모델` | text | `claude-opus-5`, `gpt-5.6` 등 |
| `프로젝트` | select | `프로젝트A` `프로젝트B` `프로젝트C` `사내` `개인/샌드박스` — **설치 후 자기 환경에 맞게 교체** |
| `유형` | multi_select | `구축` `운영` `조사/분석` `문서` `버그수정` `자동화` `리팩토링` `설정/환경` |
| `우선순위` | select | `P0` `P1` `P2` `P3` |
| `결과` | select | `성공` `부분성공` `실패` `롤백` — 종료 시점에만 |
| `사람검토` | checkbox | `__YES__` / `__NO__` |
| `시작` `완료일` | date | `YYYY-MM-DD` |
| `작업경로` | text | repo 또는 cwd 절대경로 |
| `태그` | text | `작업경로` 에서 파생한 슬러그 — 같은 경로면 항상 같은 값 (아래 규칙) |
| `브랜치/커밋` | text | 브랜치명 + 커밋 해시 |
| `세션ID` | text | 에이전트 세션/스레드 ID |
| `참고링크` | url | PR, Jira, Confluence |
| `ID` `생성일시` `수정일시` | 자동 | 쓰지 말 것 |

## 태그 규칙

`태그` 는 사람이 정하는 값이 아니라 **`작업경로` 에서 기계적으로 파생**한다.
같은 디렉토리에서 나온 작업은 언제 누가 기록하든 같은 태그가 나와야 하기 때문이다.

1. **기준 경로를 고른다** — git 레포면 최상위(`git rev-parse --show-toplevel`),
   아니면 cwd. 이 값이 곧 `작업경로` 에 들어간다.
2. **basename 을 뽑는다** — `/Users/me/dev/api-server` → `api-server`
3. **정규화한다**
   - 소문자화
   - 공백 · `_` · `.` → `-`
   - 한글 · 영숫자 · `-` 외 문자 제거
   - 연속 하이픈은 하나로, 앞뒤 하이픈은 제거
   - 40자 초과 시 자름

| `작업경로` | `태그` |
|---|---|
| `/Users/me/dev/api-server` | `api-server` |
| `/Users/me/dev/My Project` | `my-project` |
| `/Users/me/work/Data_Pipeline.v2` | `data-pipeline-v2` |
| `/Users/me/dev/사내포털` | `사내포털` |

**basename 이 겹칠 때만** 부모 디렉토리명을 앞에 붙여 구분한다.
`/a/infra/api` 와 `/b/web/api` 가 둘 다 있으면 `infra-api` · `web-api`.
겹치는지는 기존 카드의 `태그` 를 조회해 같은 태그가 **다른 `작업경로`** 로 이미 쓰였는지로 판단한다.

> 절대경로를 그대로 필터 키로 쓰지 않는 이유: 머신·사용자·worktree 마다 달라진다.
> `작업경로` 는 정확한 위치를 남기고, `태그` 는 묶어 보기 위한 안정적인 키다.

## 카드 생성

```json
{
  "parent": { "type": "data_source_id", "data_source_id": "<dataSourceId>" },
  "pages": [{
    "properties": {
      "작업명": "[프로젝트A] API 서버 v2 마이그레이션",
      "상태": "계획",
      "에이전트": "Codex",
      "모델": "gpt-5.6",
      "프로젝트": "프로젝트A",
      "유형": ["운영", "문서"],
      "우선순위": "P1",
      "시작": "2026-08-26",
      "작업경로": "/path/to/your-repo",
      "태그": "your-repo"
    },
    "content": "## 1. 계획\n- 목표: ..."
  }]
}
```

## 상태만 변경

```json
{
  "page_id": "<카드 page id>",
  "command": "update_properties",
  "properties": { "상태": "진행중" }
}
```

## 본문 append (기존 내용 보존)

```json
{
  "page_id": "<카드 page id>",
  "command": "update_content",
  "content_updates": [{
    "old_str": "## 3. 결과",
    "new_str": "- (14:20) 의존 라이브러리 버전 충돌로 스키마 마이그레이션을 먼저 적용\n\n## 3. 결과"
  }]
}
```

`2. 실행` 섹션 끝에 붙이려면 그 다음 헤딩(`## 3. 결과`) 을 앵커로 잡고 앞에 끼워 넣는 것이 안전하다.

## 종료 처리

```json
{
  "page_id": "<카드 page id>",
  "command": "update_properties",
  "properties": {
    "상태": "검증",
    "결과": "성공",
    "완료일": "2026-08-26",
    "브랜치/커밋": "feat/api-v2 @ a1b2c3d"
  }
}
```

> 날짜 속성은 클라이언트에 따라 `"date:완료일:start"` 형태의 확장 키를 요구할 수 있다.
> `notion-fetch` 로 데이터소스를 먼저 조회해 SQLite 컬럼 정의를 확인하면 확실하다.

## 이력 조회

```json
{ "query": "API 서버 마이그레이션", "data_source_url": "collection://<dataSourceId>" }
```

특정 레포의 작업만 보려면 `태그` 로 거른다.

```sql
SELECT "작업명", "상태", "결과", "date:시작:start"
FROM "collection://<dataSourceId>"
WHERE "태그" = 'api-server'
ORDER BY "생성일시" DESC
```
