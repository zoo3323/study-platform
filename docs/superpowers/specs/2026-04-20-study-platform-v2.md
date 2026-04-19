# StudyPlatform v2 — 보완 스펙

> 2026-04-20 brainstorming 세션 산출물
> DESIGN.md를 기반으로 미결정 사항 해소 + 구조 보완

---

## 변경 요약

| 항목 | 기존 | 변경 |
|------|------|------|
| 첫 과목 | 미결정 | **국어** |
| 학생 접근 | 계정 로그인 | **시험 코드 + 이름 (계정 없음)** |
| 학부모 알림 | 미결정 | **미구현 (교사가 별도 처리)** |
| 결제 | 구독권 (미결정) | **isPaid 플래그만, 결제 UI 미구현** |
| 문제 구조 | Passage 모델 | **Problem.content에 지문 포함 (단순화)** |
| 유형 분류 | 글로벌 고정 | **교사별 커스텀 TypeGroup + ProblemType** |
| 인증 role | TEACHER/STUDENT/PARENT | **TEACHER만** |
| 주요 입력 모드 | 학생 웹 제출 | **교사 직접 입력이 핵심, 학생 웹은 부가** |

---

## 1. 데이터 모델 (최종)

### User
```prisma
model User {
  id         String   @id @default(cuid())
  email      String   @unique
  name       String
  password   String   // bcrypt
  isPaid     Boolean  @default(false)
  createdAt  DateTime @default(now())

  problems    Problem[]
  exams       Exam[]
  students    RegisteredStudent[]
  typeGroups  TypeGroup[]
}
```

### RegisteredStudent
```prisma
// 교사가 등록해 놓는 학생 명단 (계정 없음)
model RegisteredStudent {
  id        String @id @default(cuid())
  teacherId String
  name      String
  teacher   User   @relation(fields: [teacherId], references: [id])

  @@unique([teacherId, name])
}
```

### TypeGroup + ProblemType
```prisma
model TypeGroup {
  id        String        @id @default(cuid())
  teacherId String
  name      String        // "2025 수능 기준", "내신 기준"
  subject   String        // "국어", "수학"
  isDefault Boolean       @default(false)
  teacher   User          @relation(fields: [teacherId], references: [id])
  types     ProblemType[]
}

model ProblemType {
  id          String    @id @default(cuid())
  groupId     String
  name        String    // "독서 - 인문", "현대소설"
  order       Int       @default(0)
  group       TypeGroup @relation(fields: [groupId], references: [id], onDelete: Cascade)
  problems    Problem[]
}
```

### Problem
```prisma
model Problem {
  id          String      @id @default(cuid())
  teacherId   String
  title       String
  content     String      // 지문 포함 시 전체 텍스트
  answer      String
  typeId      String
  inputMethod InputMethod @default(MANUAL)
  ocrOriginal String?
  createdAt   DateTime    @default(now())

  teacher      User        @relation(fields: [teacherId], references: [id])
  type         ProblemType @relation(fields: [typeId], references: [id])
  examProblems ExamProblem[]
  submissions  Submission[]
}

enum InputMethod { MANUAL OCR }
```

### Exam
```prisma
model Exam {
  id        String   @id @default(cuid())
  teacherId String
  title     String
  date      DateTime
  code      String   @unique // 6자리 랜덤, 예: "KR3F9A"
  isOpen    Boolean  @default(true) // false면 학생 제출 불가
  createdAt DateTime @default(now())

  teacher      User          @relation(fields: [teacherId], references: [id])
  problems     ExamProblem[]
  submissions  Submission[]
  analyses     Analysis[]
}

model ExamProblem {
  examId    String
  problemId String
  order     Int
  exam      Exam    @relation(fields: [examId], references: [id], onDelete: Cascade)
  problem   Problem @relation(fields: [problemId], references: [id])

  @@id([examId, problemId])
  @@index([examId, order])
}
```

### Submission
```prisma
model Submission {
  id          String      @id @default(cuid())
  examId      String
  problemId   String
  studentName String      // 계정 없이 이름으로 식별
  answer      String
  processNote String?
  isCorrect   Boolean?
  gradedAt    DateTime?
  enteredBy   EnteredBy   @default(STUDENT)
  createdAt   DateTime    @default(now())

  exam    Exam    @relation(fields: [examId], references: [id])
  problem Problem @relation(fields: [problemId], references: [id])

  @@unique([examId, problemId, studentName])
  @@index([examId, studentName])
}

enum EnteredBy { STUDENT TEACHER }
```

### Analysis
```prisma
model Analysis {
  id          String         @id @default(cuid())
  examId      String
  studentName String
  status      AnalysisStatus @default(PENDING)
  weakTypes   Json?
  aiReport    Json?          // { teacherReport: string, parentReport: string }
  createdAt   DateTime       @default(now())
  updatedAt   DateTime       @updatedAt

  exam Exam @relation(fields: [examId], references: [id])

  @@unique([examId, studentName])
}

enum AnalysisStatus { PENDING GENERATING DONE FAILED }
```

---

## 2. 시험 코드 플로우

### 교사 직접 입력 (핵심 시나리오)

```
교사: 시험 상세 페이지 → "답안 입력" 탭
  → 등록된 학생 목록 카드
  → 학생 선택
  → 문제별 빠른 입력 모드:
      [ O ] [ X ]  문제 1 — 학생 답: [  3  ]  풀이: [____________]
      [ O ] [ X ]  문제 2 — 학생 답: [  1  ]  풀이: [____________]
      Tab/Enter으로 다음 문제 이동
  → 저장 → "다음 학생" 버튼
```

- O/X 토글 → `isCorrect` 직접 설정 (교사가 종이 채점 기준)
- 학생 실제 답안 입력 → `answer` 저장 (AI 분석용)
- 풀이과정은 선택 입력 (AI 분석 품질 향상용)
- `gradedAt` = 저장 시각

> 학생 웹 제출 시: `isCorrect` = (`submission.answer === problem.answer`) 자동 계산

### 학생 웹 제출 (부가 시나리오)

```
/exam 페이지:
  → 시험 코드 입력 → 이름 입력
  → 문제 목록 (isOpen: true인 시험만)
  → 문제별 답안 + 풀이과정 입력
  → 제출 → "제출 완료" 화면
```

`isOpen: false`이면 "마감된 시험입니다" 표시.

---

## 3. 국어 유형 기본 시드

교사 가입 시 자동 생성되는 기본 TypeGroup:

```typescript
// prisma/seed.ts (가입 시 생성 로직에도 동일 적용)
const defaultKoreanTypes = [
  { name: "독서 - 인문",    order: 1 },
  { name: "독서 - 사회",    order: 2 },
  { name: "독서 - 과학",    order: 3 },
  { name: "독서 - 기술",    order: 4 },
  { name: "독서 - 예술",    order: 5 },
  { name: "문학 - 현대시",  order: 6 },
  { name: "문학 - 고전시가", order: 7 },
  { name: "문학 - 현대소설", order: 8 },
  { name: "문학 - 고전소설", order: 9 },
  { name: "문학 - 수필/극", order: 10 },
  { name: "언어 - 문법",    order: 11 },
  { name: "매체 - 매체 자료", order: 12 },
  { name: "화법과 작문",    order: 13 },
]
// TypeGroup: name="기본 국어 유형", subject="국어", isDefault=true
```

교사는 /settings/types 에서 그룹 추가/수정/삭제, 유형 추가/수정/삭제/순서 변경 가능.

---

## 4. 인증 구조

```
NextAuth Credentials Provider
  - 이메일 + 비밀번호 (bcrypt)
  - JWT 세션: { id, email, name, isPaid }
  - role 필드 없음 (교사만 존재)
```

**미들웨어 라우팅:**
```
/exam/*          → 인증 불필요 (학생 시험 응시)
/dashboard/*     → 로그인 필요
/problems/*      → 로그인 필요
/exams/*         → 로그인 필요
/students/*      → 로그인 필요
/settings/*      → 로그인 필요
/api/exam/*      → 인증 불필요
/api/*           → 로그인 필요
```

**isPaid 제한 (베타):**
```
isPaid: false → 학생 5명, 시험 3개 무료
초과 시 → "베타 신청" 안내 (이메일/카톡으로 수동 활성화)
```

---

## 5. 페이지 구조 (최종)

```
app/
├── exam/                     # 인증 불필요
│   └── page.tsx              # 코드 입력 → 학생 답안 제출
├── (auth)/
│   ├── login/page.tsx
│   └── register/page.tsx
└── (dashboard)/              # 로그인 필요
    ├── layout.tsx            # 교사 공통 레이아웃
    ├── dashboard/page.tsx    # 학생별 성적 현황
    ├── problems/
    │   ├── page.tsx          # 문제 목록
    │   └── new/page.tsx      # 문제 생성 (manual + OCR)
    ├── exams/
    │   ├── page.tsx          # 시험 목록
    │   ├── new/page.tsx      # 시험 생성
    │   └── [id]/
    │       ├── page.tsx      # 시험 상세 + 답안 입력 탭
    │       └── analysis/
    │           └── [studentName]/page.tsx  # AI 분석 레포트
    ├── students/
    │   └── page.tsx          # 학생 명단 관리
    └── settings/
        └── types/page.tsx    # 유형 그룹 관리
```

---

## 6. 미구현 (Phase 2)

- 결제 / Stripe 연동
- 학부모 알림 (카카오톡 API)
- 손글씨 OCR
- 학생 결과 조회
- 학생 간 비교 분석
- 레포트 PDF 출력
