# 새 워크스페이스에 기록용 DB 만들기

`assets/worklog.config.json` 에 유효한 ID가 없거나 다른 Notion 워크스페이스로 옮길 때 쓴다.

## 1. 부모 페이지 생성

`notion-create-pages` 로 제목 `에이전트 작업 기록 (Agent Work Log)`, 아이콘 `🤖` 페이지를 만든다.
본문에는 상태 흐름과 카드 템플릿을 넣어 사람이 읽을 수 있게 한다.

## 2. DB 생성

`notion-create-database` 에 부모 페이지 ID와 아래 DDL을 넘긴다.

```sql
CREATE TABLE (
  "작업명" TITLE COMMENT '한 줄 요약. 대괄호 접두어를 붙이지 않는다 — 분류는 프로젝트 속성이 담당',
  "상태" SELECT('Backlog':gray, '계획':purple, '진행중':blue, '검증':yellow, '완료':green, '중단/실패':red) COMMENT '칸반 보드의 그룹 기준',
  "에이전트" SELECT('Claude Code':orange, 'Codex':gray, 'Gemini CLI':blue, 'Cursor':purple, '사람':brown, '기타':default),
  "모델" SELECT('claude-opus-5':orange, 'claude-sonnet-5':blue, 'claude-haiku-4-5':green, 'claude-fable-5':purple, 'gpt-5.6':gray, '기타':default) COMMENT '쓰는 모델에 맞게 옵션을 조정할 것',
  "프로젝트" SELECT('프로젝트A':blue, '프로젝트B':green, '프로젝트C':orange, '사내':default, '개인/샌드박스':default) COMMENT '고객사·프로젝트 이름. 분류/필터의 유일한 키 — 자기 환경에 맞게 교체할 것',
  "유형" MULTI_SELECT('구축':blue, '운영':green, '조사/분석':purple, '문서':yellow, '버그수정':red, '자동화':orange, '리팩토링':brown, '설정/환경':gray),
  "우선순위" SELECT('P0':red, 'P1':orange, 'P2':yellow, 'P3':gray),
  "결과" SELECT('성공':green, '부분성공':yellow, '실패':red, '롤백':orange) COMMENT '완료 시점에 채움',
  "시작" DATE,
  "완료일" DATE,
  "작업경로" RICH_TEXT COMMENT '레포 또는 디렉토리 경로 (cwd)',
  "브랜치/커밋" RICH_TEXT COMMENT '브랜치@짧은해시 형식만. 커밋 URL 하이퍼링크. 부연 금지',
  "푸시" CHECKBOX COMMENT '커밋이 원격에 올라갔는지. git branch -r --contains <해시> 로 확인',
  "세션ID" RICH_TEXT COMMENT '에이전트 세션/스레드 ID — 원본 로그 추적용',
  "참고링크" URL,
  "ID" UNIQUE_ID PREFIX 'AGT',
  "생성일시" CREATED_TIME,
  "수정일시" LAST_EDITED_TIME
)
```

`상태` 를 Notion의 `STATUS` 타입 대신 `SELECT` 로 잡은 이유: DDL에서 STATUS는 옵션명을 지정할 수 없어
한글 단계명을 쓸 수 없다.

## 3. 칸반 뷰 추가

`notion-create-view` 로 board 뷰를 만든다.

```
type: board
configure:
  GROUP BY "상태"
  SORT BY "우선순위" ASC
  SHOW "작업명", "에이전트", "프로젝트", "유형", "우선순위", "결과", "시작"
```

## 4. config 갱신

응답의 `database_id` 와 `collection://` 뒤의 `data_source_id` 를 `assets/worklog.config.json` 에 써 넣는다.

## 5. 프로젝트 옵션 관리

`프로젝트` 는 select 이므로 DDL에 없는 값을 그냥 쓸 수 없다.
DDL의 `'프로젝트A'` `'프로젝트B'` `'프로젝트C'` 는 자리표시자이니 실제 고객사·프로젝트 이름으로 바꾼다.

```sql
ALTER COLUMN "프로젝트" SET SELECT('EDP':blue, 'IMK':orange, '사내':default, '개인/샌드박스':default)
```

`ALTER ... SET SELECT` 는 **옵션명이 같으면 기존 카드의 값을 유지**한다.
기존 옵션을 빠뜨리고 새로 지정하면 그 값들이 사라지니, 항상 기존 목록에 더해서 넘긴다.

프로젝트 이름은 경로 같은 데서 기계적으로 파생되지 않고 사람이 정한다.
**에이전트가 임의로 옵션을 추가하지 않는다** — 맞는 옵션이 없으면 사용자에게 묻게 돼 있다.

## 주의

- 보드에서 **카드가 없는 레인은 기본 숨김**이다. Notion UI의 보드 설정에서 "빈 그룹 표시"를 켜야 6개 레인이 다 보인다.
- 생성 직후 기본 탭은 표 뷰다. 칸반을 기본으로 두려면 UI에서 탭을 드래그한다.
