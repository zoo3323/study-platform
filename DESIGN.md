# StudyPlatform — 기획 설계 문서

> /office-hours 세션 산출물 | 2026-04-20
> Status: APPROVED (spec review 반영 완료)

---

## 핵심 인사이트 (EUREKA)

모든 AI 튜터링 플랫폼은 "학생을 더 잘 가르친다"는 방향으로 만들어졌다.

그런데 한국 학원 강사의 실제 고통은 학생이 못 배우는 것이 아니다.
**학부모에게 성과를 증명하는 것**이다.

월 20-30만원 학원비를 정당화하는 레포트가 없다. 지금은 카톡으로 비구조적 피드백을 보낸다.

진짜 제품 = **강사가 학부모에게 보내는 AI 성과 레포트 생성기**

---

## 문제 정의

학원 강사가 학생 1인당 성과를 학부모에게 정기적으로 증명해야 한다.

**현재 워크플로:**
1. 시험지 채점 (30분~1시간/학생)
2. 틀린 문제 유형별 수동 분류 (엑셀)
3. 카카오톡으로 비구조적 피드백 전송
4. AI 분석 없음, 시각화 없음

강사 1명이 학생 10명 관리 시 주 5-10시간 채점/분석 소요.

---

## 타겟 사용자

**학원 강사 (입시 집중형, 수학/과학/국어)**
- 학생당 성과 관리가 매출과 직결 (성적 오르면 수강 유지, 안 오르면 이탈)
- 학부모 신뢰 확보가 핵심 업무
- 도메인 특화: 한국 수능/내신 문제 유형을 알고 있음

---

## 수요 증거

- 직접 교사이거나 학원 강사 지인이 "이런 게 필요하다"고 직접 언급
- 한국 학원 참여율 78.3% → 거대 시장
- 강사 매출이 학생 성과와 직결 → 도구에 돈 낼 인센티브 충분

---

## 전제

1. ✅ 핵심 가치 = 학부모에게 전달하는 AI 레포트 (내부 분석 도구 X)
2. ✅ 문제 입력 = 직접 입력 + 인쇄체 OCR 스캔 지원 (손글씨 OCR은 Phase 2)
3. ✅ 한국 수능/내신 문제 유형 DB = 글로벌 경쟁자 대비 핵심 방어선

---

## MVP 범위 (Phase 1 — 3개월 목표)

**4가지 핵심 기능:**

1. **문제 관리** — 교사가 문제 입력 + 유형 태그 (직접 입력, 인쇄체 OCR)
2. **학생 답안 제출** — 학생이 답 + 풀이과정 텍스트로 입력
3. **유형별 성적 그래프** — 학생 대시보드에서 문제 유형별 정답률 시각화 (Recharts)
4. **AI 분석 레포트** — GPT-4o로 다음 4가지 분석 + 학부모용 레포트 자동 생성:
   - 유형별 약점 패턴 (어떤 유형이 취약한지)
   - 풀이 방식 진단 (찍어서 맞춘 건지 vs 이해해서 맞춘 건지 — 풀이과정 텍스트 기반)
   - 구체적 약점 원인 (개념 미숙지 / 실수 / 적용 실패 구분)
   - 맞춤 학습 방향 제안 (다음에 어떻게 공부하면 좋은지 3가지)

**Phase 2 (이후):** 학부모 포털 (별도 로그인), 손글씨 OCR, 카카오톡 알림, 학생 간 비교 분석

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| Frontend | Next.js 14 (App Router) + Tailwind CSS + shadcn/ui |
| Backend | Next.js API Routes + Prisma ORM |
| Database | PostgreSQL (Supabase) |
| AI 분석 | OpenAI GPT-4o API |
| OCR (인쇄체) | Google Vision API |
| 인증 | NextAuth.js (교사/학생/학부모 역할 분리) |
| 차트 | Recharts |
| 배포 | Vercel + Supabase |

---

## 데이터 모델

```
User
  - id, email, name, role (TEACHER | STUDENT | PARENT), createdAt

Student
  - id, name, teacherId (FK→User), parentId (FK→User)

ProblemType
  - id, subject (수학/국어/영어...), category (수1/수2/확통...), name, description

Problem
  - id, teacherId, title, content, answer, typeId (FK→ProblemType)
  - inputMethod: MANUAL | OCR
  - ocrOriginal (원본 이미지 URL, OCR인 경우)

Exam
  - id, teacherId, title, date, problems (M:N)

Submission
  - id, studentId, examId, problemId
  - answer, processNote (풀이과정 텍스트)
  - isCorrect, gradedAt

Analysis
  - id, submissionId or examId
  - weakTypes (JSON: 취약 유형 배열)
  - aiReport (GPT-4o 생성 레포트 텍스트)
  - createdAt
```

---

## 권한 매트릭스

| 기능 | 교사 | 학생 | 학부모 |
|------|------|------|--------|
| 문제 생성/편집 | ✅ | ❌ | ❌ |
| 시험 생성 | ✅ | ❌ | ❌ |
| 답안 제출 | ❌ | ✅ (본인만) | ❌ |
| AI 분석 실행 | ✅ | ❌ | ❌ |
| 레포트 조회 | ✅ (전체) | ✅ (본인) | ✅ (자녀만) |
| 학생 관리 | ✅ | ❌ | ❌ |

---

## 학생 제출 플로우

```
교사: 시험 생성 → 학생에게 링크/코드 공유
학생: 로그인 → 시험 입장 → 문제별 답안 + 풀이과정 텍스트 입력 → 제출
교사: 자동 채점 확인 (정답 대조) → AI 분석 실행 → 레포트 생성 → 학부모 공유
```

OCR 플로우:
```
교사: 인쇄된 시험지 촬영 → 업로드 → Google Vision OCR → 텍스트 추출 → 교사 검수 → 저장
※ 손글씨 풀이과정은 Phase 2까지 수동 텍스트 입력
```

---

## AI 분석 로직

**입력:** 학생의 제출 답안 + 풀이과정 텍스트 + 문제 유형 태그 + 정오답 여부

**GPT-4o 프롬프트 구조 (예시):**
```
[학생 정보] 이름: OOO, 시험: 수학 내신 1회차
[문제별 데이터]
  - 문제1 (수열의 극한): 오답, 풀이: "an=... 으로 놓고 극한값을 구했는데..."
  - 문제2 (미분법): 정답, 풀이: "f'(x) 구한 후..." → 풀이 없이 정답만 기재
  - 문제3 (수열의 극한): 오답, 풀이: (없음)
→ 출력 4가지:
  1. 유형별 약점 요약 (어느 유형이 취약한지 + 이유)
  2. 풀이 방식 진단 (풀이 없는 정답 = 찍기 가능성, 풀이 있는 오답 = 개념 미숙지)
  3. 약점 원인 분류 (개념 미숙지 / 계산 실수 / 문제 해석 실패)
  4. 학습 방향 제안 3가지 (구체적: "수열의 극한 개념 재학습 후 유형 문제 5개씩")
```

**출력:** 한국어 레포트 2버전
- **강사용:** 위 4가지 전체 + 수치 데이터
- **학부모용:** 3-4문장 요약 (전문용어 없이, 긍정적 어조로)

---

## 비용 추정

| 항목 | 추정 비용 |
|------|-----------|
| Vercel (Hobby/Pro) | $0-20/월 |
| Supabase | $0-25/월 |
| OpenAI GPT-4o | $0.01/학생분석, 강사10명×학생20명×주1회 = ~$8/월 |
| Google Vision OCR | $1.5/1000페이지, 무시 가능 수준 |
| **합계 (MVP)** | **~$30-50/월** |

강사 1명 구독료 2-5만원이면 손익분기 달성 가능.

---

## 성공 지표

- 학원 강사 1명이 첫 학생 레포트를 30분 안에 생성
- 3개월 내 유료 강사 10명 확보
- 강사 1명이 학생 20명을 기존 대비 50% 시간으로 관리
- 학부모 레포트 공유율 70% 이상 (생성 후 실제로 보내는 비율)

---

## 배포 계획

```
GitHub → push → Vercel 자동 빌드/배포
Supabase: DB 마이그레이션은 prisma migrate deploy
도메인: study-platform.kr (또는 유사)
오픈베타: 지인 학원 강사 3-5명
```

---

## 확정 사항 (2026-04-20 업데이트)

1. **첫 과목** → **국어** (수능/내신 유형 체계로 시작)
2. **학부모 알림** → **미구현** (교사가 별도 처리, Phase 2에서 카카오 알림 검토)
3. **가격 모델** → **isPaid 플래그** (결제 UI 미구현, 베타 사용자는 수동 활성화)
4. **학생 진입 방식** → **시험 코드 + 이름** (학생 계정 없음) + 교사 직접 입력 병행
   - 핵심 시나리오: 교사가 채점지 보고 직접 입력 (속도 최적화)
   - 부가 시나리오: 학생이 /exam 페이지에서 코드로 접근해 웹 제출

> 상세 스펙: `docs/superpowers/specs/2026-04-20-study-platform-v2.md`

---

## 다음 액션 (The Assignment)

**지금 당장:** 학원 강사 지인 1명과 30분 인터뷰 예약.

물어볼 것:
- "학생 레포트를 지금 어떻게 만들어서 학부모에게 어떻게 전달하는가?"
- "한 달에 이 작업에 몇 시간 쓰는가?"
- "월 2만원짜리 앱이 이 시간을 절반으로 줄여준다면 쓰겠는가?"

---

## 구현 시작 가이드

다음 세션에서 `/plan-eng-review`를 실행하면 이 문서를 자동으로 읽어 구체적인 구현 계획을 수립합니다.

```bash
cd ~/Desktop/njkim/study-platform
# 다음 세션 시작 후:
# /plan-eng-review
```

---

*이 문서는 /office-hours 스킬로 생성되었습니다. 코드 구현은 포함하지 않습니다.*

---

## 비주얼 디자인 시스템

> /design-consultation 세션 산출물 | 2026-04-21
> 핵심 키워드: **신뢰감 — 전문 도구처럼 보여야**

### Aesthetic Direction

- **방향:** Industrial/Utilitarian — 데이터 우선, 장식 없음
- **장식 수준:** Minimal — 타이포그래피와 공백이 전부
- **분위기:** 학원 강사가 학부모에게 "AI로 분석했습니다"라고 자신 있게 말할 수 있는 전문성. Vercel·Linear 같은 프리미엄 개발자 도구의 언어.
- **레이아웃:** 좌측 다크 사이드바 + 우측 화이트 콘텐츠 영역

### Color

```css
/* Core */
--sidebar:    #0F172A;   /* 딥 슬레이트 — 거의 검정, 프리미엄 신호 */
--surface:    #FFFFFF;   /* 메인 콘텐츠 영역 */
--bg:         #F8FAFC;   /* 페이지 배경 */
--border:     #E2E8F0;   /* 구분선 */

/* Brand */
--primary:    #2563EB;   /* 프로페셔널 블루 — 버튼, 링크, active 상태 */
--primary-h:  #1D4ED8;   /* hover */

/* Semantic */
--strong:     #10B981;   /* 초록 — 강점, 정답, 완료 */
--weak:       #F97316;   /* 주황 — 약점, 경고 (빨강보다 덜 공격적) */

/* Text */
--text:       #0F172A;
--text-sub:   #475569;
--muted:      #64748B;
```

**색상 사용 원칙:**
- `--weak` (주황)은 빨강 대신 약점에 사용 — 학부모 레포트에서 경고이지만 불안감 없이 전달
- `--primary` (블루)는 행동 유도(버튼, 링크)에만 사용
- 색상은 드물게 사용할수록 의미가 강해짐 — 배경/카드는 무채색 유지

### Typography

| 역할 | 폰트 | 굵기 | 크기 |
|------|------|------|------|
| 한글 전체 | Pretendard | 400/500/600/700 | 스케일 참고 |
| 점수·백분율·숫자 | Geist Mono (또는 Courier New) | 700 | 26–28px |
| UI 라벨 (영문) | Geist | 500–600 | 11–13px |

**폰트 로딩:**
```html
<link href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css" rel="stylesheet">
```

**타이포그래피 스케일:**
```
페이지 제목:   Pretendard 700 · 22–24px · letter-spacing: -0.3px
섹션 제목:    Pretendard 600 · 15–16px
카드 제목:    Pretendard 600 · 13px
본문:        Pretendard 400 · 13px · line-height: 1.7
레이블:      Pretendard 600 · 11px · uppercase · letter-spacing: 0.4px · color: --muted
점수 숫자:   Geist Mono 700 · 26–28px
```

### Spacing

- **Base unit:** 8px
- **Density:** Comfortable (빽빽하지도, 낭비되지도 않게)
- **Scale:** `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64` (px)
- **Border radius:** sm: 4px, md: 6px, lg: 8px (둥글지 않게 — 전문 도구 느낌)

### Layout

- **사이드바:** 220px 고정, `#0F172A` 배경
- **콘텐츠 헤더:** 56px, 1px border-bottom
- **카드 패딩:** 18–20px
- **페이지 패딩:** 24–28px
- **그리드:** 4컬럼 stat cards, 2컬럼 main grid (chart + table)

### Motion

- **방향:** Minimal-functional — 이해를 돕는 전환만
- **Easing:** ease-out (enter), ease-in (exit)
- **Duration:** micro 100ms / short 200ms / medium 300ms
- AI 분석 대기 상태: 진행률 표시 + 예상 시간 안내 (로딩 스피너 금지)

### Component Conventions

**버튼:**
```
Primary:  bg #2563EB · text white · radius 6px · padding 7px 14px
Ghost:    bg transparent · border 1px #E2E8F0 · text --text-sub
Danger:   bg #EF4444 · text white (삭제 등 비가역 작업만)
```

**배지:**
```
완료:     bg #DCFCE7 · text #166534 (초록 계열)
진행 중:  bg #FEF3C7 · text #92400E (주황 계열)
미채점:   bg #FEE2E2 · text #991B1B (빨강 계열)
```

**약점 태그:**
```
bg #FFF7ED · border 1px #FDBA74 · text #C2410C · 앞에 주황 도트
```

**강점 태그:**
```
bg #EFF6FF · border 1px #BFDBFE · text #1D4ED8 · 앞에 블루 도트
```

### Design Decisions Log

| 날짜 | 결정 | 근거 |
|------|------|------|
| 2026-04-21 | 사이드바 #0F172A (거의 검정) | 한국 edu앱의 파란 사이드바 대신 프리미엄 도구 언어 채택 |
| 2026-04-21 | 약점 색상 주황 (not 빨강) | 학부모 레포트에서 공격적이지 않게 약점 전달 |
| 2026-04-21 | 점수 숫자 Geist Mono | "측정이지 마케팅이 아니다" 신호 — 신뢰감 증폭 |
| 2026-04-21 | border-radius 최대 8px | 둥글지 않은 직선형 — 전문 도구 느낌 유지 |
