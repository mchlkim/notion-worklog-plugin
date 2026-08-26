---
description: 지금 하려는 작업을 Notion 칸반에 카드로 만들고 계획을 기록합니다
argument-hint: "[프로젝트] 작업 요약"
---

`notion-worklog-skill` 스킬의 **1) 착수** 절차를 수행한다.

작업 요약: $ARGUMENTS

1. `skills/notion-worklog-skill/assets/worklog.config.json` 에서 `dataSourceId` 를 읽는다
   (환경변수 `NOTION_WORKLOG_DATA_SOURCE_ID` 우선).
2. 같은 작업의 카드가 이미 있는지 먼저 확인한다.
3. 인자가 비었거나 프로젝트 태그가 없으면, 지금까지의 대화 맥락에서 작업명·프로젝트·유형을 추론한다.
   추론이 애매하면 사용자에게 한 번만 되묻는다.
4. `작업경로` 와 `태그` 를 정한다. 같은 경로의 기존 카드가 있으면 **그 태그를 그대로 쓴다**.
   없으면 git 최상위(없으면 cwd)의 basename을 슬러그화한다.
5. `상태=계획` 으로 카드를 만들고 본문 `1. 계획` 섹션을 채운다.
6. 만든 카드 URL을 한 줄로 알린다.
