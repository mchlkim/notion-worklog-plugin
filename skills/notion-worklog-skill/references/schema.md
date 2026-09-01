# 속성 스키마와 호출 예시

## 속성

| 속성 | 타입 | 허용값 / 규칙 |
|---|---|---|
| `작업명` | title | 한 줄 요약. **대괄호 접두어를 붙이지 않는다** (아래) |
| `상태` | select | `Backlog` `계획` `진행중` `검증` `완료` `중단/실패` — 칸반 레인 |
| `에이전트` | select | `Claude Code` `Codex` `Gemini CLI` `Cursor` `사람` `기타` |
| `모델` | select | `claude-opus-5` `claude-sonnet-5` `claude-haiku-4-5` `claude-fable-5` `gpt-5.6` `기타` |
| `프로젝트` | select | 고객사·프로젝트 이름 — 분류/필터의 유일한 키. **설치 후 자기 환경에 맞게 교체** |
| `유형` | multi_select | `구축` `운영` `조사/분석` `문서` `버그수정` `자동화` `리팩토링` `설정/환경` |
| `우선순위` | select | `P0` `P1` `P2` `P3` |
| `결과` | select | `성공` `부분성공` `실패` `롤백` — 종료 시점에만 |
| `시작` `완료일` | date | `YYYY-MM-DD` |
| `작업경로` | text | repo 또는 cwd 절대경로 |
| `브랜치/커밋` | text | `브랜치@짧은해시` + 커밋 URL 하이퍼링크 (아래 규칙). **다른 부연을 쓰지 않는다** |
| `푸시` | checkbox | 커밋이 원격에 올라갔는지. `git branch -r --contains <해시>` 가 비어 있지 않으면 체크 |
| `미해결` | checkbox | 남은 일이 있는 채로 완료·중단되면 체크. lint 와 Home view 가 추적 |
| `관련 작업` | relation | 선행·후속·재작업 카드 연결. 값은 카드 페이지 URL 배열 — `"관련 작업": ["https://..."]` |
| `세션ID` | text | 에이전트 세션/스레드 ID. **`scripts/session-id.sh` 로 구한다** — 실패하면 비워 둔다 |
| `resume` | formula | **자동 계산 — 쓰지 말 것.** `세션ID`·`에이전트`·`작업경로` 에서 `cd <경로> && claude --resume <id>` (또는 `codex resume <id>`) 를 만든다. 로컬 트랜스크립트까지 확인하려면 `scripts/resume.sh <세션ID>` 를 쓴다 |
| `참고링크` | url | PR, Jira, Confluence |
| `ID` `생성일시` `수정일시` | 자동 | 값은 쓰지 말 것. 다만 **본문에서 `AGT-50` 처럼 다른 카드를 참조할 때는 링크를 건다** (아래) |

## 카드 번호 참조

본문에서 다른 카드를 `AGT-50` 처럼 번호로 부를 때는 **해당 페이지로 링크를 건다.**
번호만 적으면 죽은 참조가 되어 보드에서 다시 검색해야 한다.

```markdown
이전 웹 작업 [AGT-50](https://app.notion.com/p/3ceb714d4b7f81198acfc6e6972a1011) 의 콘텐츠를 재사용했다.
```

ID와 URL은 한 번의 조회로 함께 얻는다.

```sql
SELECT "userDefined:ID", "작업명", url
FROM "collection://<dataSourceId>"
WHERE "userDefined:ID" IN (45, 50)
```

- SQL 의 `userDefined:ID` 는 **접두어 없는 정수**(`50`)로 나오고, `notion-fetch` 는 `AGT-50` 형태로 준다.
- `update_content` 로 넣은 마크다운 링크는 멘션으로 변환되지 않고 **링크 그대로 유지**된다.
- 구조적 선후 관계는 `관련 작업` relation 이 담당한다. 본문 링크는 산문 안의 언급용이다.

## 작업명 규칙

**한 줄 요약만 쓴다.** `[프로젝트]` `[고객사]` 같은 대괄호 접두어를 붙이지 않는다.

| ❌ | ✅ |
|---|---|
| `[EDP] EKS 1.31 업그레이드 작업계획서` | `EKS 1.31 업그레이드 작업계획서` (`프로젝트` = `EDP`) |
| `[개인/샌드박스] Shotta 웹사이트 배포` | `Shotta 웹사이트 배포` (`프로젝트` = `개인/샌드박스`) |

분류는 `프로젝트` 속성이 담당한다. 제목에 같은 값을 또 적으면 보드 카드에서 두 번
반복되고, 프로젝트 이름이 바뀌었을 때 제목과 속성이 어긋난다.

접두어를 떼면 제목이 무슨 일인지 알 수 없어질 때는 **접두어를 되살리지 말고
제목 자체를 구체적으로 쓴다** — `단축키 안내 추가` 가 아니라
`Shotta 에디터 단축키 안내 추가`.

## 프로젝트 규칙

`프로젝트` 는 **사람이 정하는 값**이다. 경로에서 기계적으로 파생하지 않는다.

1. 데이터소스를 조회해 **기존 옵션 중에서 고른다.** 이게 대부분의 경우다.
2. 같은 `작업경로` 의 지난 카드가 있으면 **그 카드의 `프로젝트` 를 그대로 쓴다.**
3. 맞는 옵션이 하나도 없으면 **사용자에게 묻는다.** 에이전트가 새 옵션을 만들어 내지 않는다.
   확인을 받은 뒤에만 `notion-update-data-source` 로 옵션을 추가한다.
   **기존 옵션을 모두 포함해서** 넘겨야 한다 — 빠뜨린 옵션의 값은 사라진다.

```sql
ALTER COLUMN "프로젝트" SET SELECT('기존1':blue, '기존2':green, '신규':orange)
```

> 정확한 위치는 `작업경로` 가 남긴다. 절대경로는 머신·사용자·worktree 마다 달라져
> 필터 키로 쓸 수 없기 때문에, 묶어 보는 키는 `프로젝트` 하나로 둔다.

## 카드 생성

```json
{
  "parent": { "type": "data_source_id", "data_source_id": "<dataSourceId>" },
  "pages": [{
    "properties": {
      "작업명": "API 서버 v2 마이그레이션",
      "상태": "계획",
      "에이전트": "Codex",
      "모델": "gpt-5.6",
      "프로젝트": "프로젝트A",
      "유형": ["운영", "문서"],
      "우선순위": "P1",
      "시작": "2026-08-26",
      "작업경로": "/path/to/your-repo"
    },
    "content": "# 1. 계획\n\n## 목표\n사내 API 게이트웨이를 v2 스키마로 옮긴다.\n\n## 범위 / 범위 밖\n..."
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
    "old_str": "# 3. 결과",
    "new_str": "- (14:20) 의존 라이브러리 버전 충돌로 스키마 마이그레이션을 먼저 적용\n\n# 3. 결과"
  }]
}
```

`2. 실행` 섹션 끝에 붙이려면 그 다음 헤딩(`# 3. 결과`) 을 앵커로 잡고 앞에 끼워 넣는 것이 안전하다.
**섹션은 `#`(제목1), 그 안의 항목은 `##`(제목2)** 이므로 앵커를 잡을 때 `#` 개수를 틀리지 말 것.

## 브랜치/커밋 링크 규칙

`브랜치@짧은해시` 를 표시 문자열로, 커밋 URL을 링크로 넣는다.
**텍스트 속성은 마크다운을 해석하므로** `[표시](URL)` 형태로 쓰면 하이퍼링크가 된다.

```
[main@0e89e71](https://github.com/owner/repo/commit/0e89e714e971cb3a7a181214363337195dd7a1dc)
```

만드는 순서:

1. `git rev-parse --abbrev-ref HEAD` → 브랜치명
2. `git rev-parse --short=7 HEAD` → 표시용 짧은 해시 / `git rev-parse HEAD` → 링크용 전체 해시
3. `git remote get-url origin` → 웹 URL로 정규화
   - `https://host/o/r.git` → `https://host/o/r`
   - `git@host:o/r.git` → `https://host/o/r`
4. `<웹URL>/commit/<전체해시>` 로 링크를 만든다

| 상황 | 값 |
|---|---|
| 원격이 있는 git 레포 | `[main@0e89e71](https://github.com/o/r/commit/<full>)` |
| 원격 없는 로컬 레포 | `main@0e89e71` (링크 없이) |
| git 레포가 아님 | 비워 둔다 |

> GitLab·Bitbucket 은 커밋 경로가 다르다 (`/-/commit/`, `/commits/`).
> 호스트를 보고 맞추되 확실하지 않으면 링크 없이 `브랜치@해시` 만 넣는다.

**부연을 붙이지 않는다.** `main@0e89e71 (pushed)` 나 `main (미커밋)` 처럼 쓰면 안 된다.
값은 `브랜치@짧은해시` 이거나 비어 있거나 둘 중 하나다.

## 푸시 판정

```bash
git branch -r --contains <짧은해시>    # 출력이 있으면 푸시됨
```

| 상황 | `브랜치/커밋` | `푸시` |
|---|---|---|
| 커밋 후 푸시함 | `[main@0e89e71](...)` | ✅ |
| 커밋만 하고 푸시 안 함 | `[main@0e89e71](...)` | ⬜ |
| 원격이 없는 로컬 레포 | `main@0e89e71` (링크 없이) | ⬜ |
| 커밋 자체가 없음 / git 레포 아님 | 비워 둔다 | ⬜ |

## 종료 처리

```json
{
  "page_id": "<카드 page id>",
  "command": "update_properties",
  "properties": {
    "상태": "검증",
    "결과": "성공",
    "완료일": "2026-08-26",
    "브랜치/커밋": "[feat/api-v2@a1b2c3d](https://github.com/owner/repo/commit/a1b2c3d4e5f6789012345678901234567890abcd)"
  }
}
```

> 날짜 속성은 클라이언트에 따라 `"date:완료일:start"` 형태의 확장 키를 요구할 수 있다.
> `notion-fetch` 로 데이터소스를 먼저 조회해 SQLite 컬럼 정의를 확인하면 확실하다.

## 이력 조회

```json
{ "query": "API 서버 마이그레이션", "data_source_url": "collection://<dataSourceId>" }
```

특정 프로젝트의 작업만 보려면 `프로젝트` 로 거른다.

```sql
SELECT "작업명", "상태", "결과", "date:시작:start"
FROM "collection://<dataSourceId>"
WHERE "프로젝트" = 'EDP'
ORDER BY "생성일시" DESC
```

한 레포에서 나온 작업만 보려면 `작업경로` 로 거른다.

```sql
SELECT "작업명", "상태", "결과"
FROM "collection://<dataSourceId>"
WHERE "작업경로" = '/Users/me/dev/api-server'
ORDER BY "생성일시" DESC
```

## 프로젝트 노트 DB

카드가 쌓이면 종합되는 wiki 계층. 프로젝트당 1페이지.

- 데이터소스: 환경변수 `NOTION_WORKLOG_PROJECT_NOTES_ID` → `worklog.config.json` 의
  `notion.projectNotesDataSourceId` 순서로 찾는다.
- 속성: `프로젝트`(title, 칸반 select 옵션명과 동일 문자열) · `한 줄 요약`(text) ·
  `미해결 수`(number) · `최종 갱신`(자동)
- 본문 섹션: `# 현재 상태` / `# 누적 개선점` / `# 미해결 질문` / `# 변경 이력`
- 페이지 찾기: `notion-query-data-sources` 로
  `SELECT url FROM "collection://<노트ID>" WHERE "프로젝트" = ?` — 없으면 생성한다.
- 환류는 `update_content` append 로 한다. 노트 전체를 다시 쓰지 않는다.
