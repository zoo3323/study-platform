# StudyPlatform Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Korean tutoring platform where teachers input student exam results, AI (GPT-4o) generates weak-pattern analysis reports, and charts show performance by problem type.

**Architecture:** Next.js 14 App Router with two route groups — `(auth)` for login/register and `(dashboard)` for teacher pages — plus a public `/exam` route for student web submission. Prisma + Supabase PostgreSQL for data; NextAuth JWT for teacher-only auth; OpenAI GPT-4o for async analysis with PENDING→GENERATING→DONE polling.

**Tech Stack:** Next.js 14 App Router, TypeScript, Tailwind CSS, shadcn/ui, Prisma ORM, Supabase PostgreSQL, NextAuth.js v4, OpenAI GPT-4o, Recharts, Vitest + @testing-library/react

---

## File Map

```
study-platform/
├── prisma/
│   ├── schema.prisma              # 7 models + 3 enums
│   └── seed.ts                    # 13 Korean default types
├── src/
│   ├── lib/
│   │   ├── prisma.ts              # Prisma client singleton
│   │   ├── auth.ts                # NextAuth config
│   │   ├── exam-code.ts           # 6-char random code generator
│   │   └── analysis.ts            # aggregateByType, buildPrompt, generateAnalysis
│   ├── middleware.ts               # Route protection
│   ├── app/
│   │   ├── api/
│   │   │   ├── auth/[...nextauth]/route.ts
│   │   │   ├── problems/
│   │   │   │   ├── route.ts       # GET /POST
│   │   │   │   └── [id]/route.ts  # PUT /DELETE
│   │   │   ├── exams/
│   │   │   │   ├── route.ts       # GET /POST
│   │   │   │   └── [id]/
│   │   │   │       ├── route.ts   # GET /PUT
│   │   │   │       └── submissions/route.ts  # POST (teacher input)
│   │   │   ├── students/route.ts  # GET /POST /DELETE
│   │   │   ├── type-groups/
│   │   │   │   ├── route.ts       # GET /POST
│   │   │   │   └── [id]/route.ts  # PUT /DELETE (cascade ProblemTypes)
│   │   │   ├── exam/
│   │   │   │   ├── [code]/route.ts       # GET exam by code (public)
│   │   │   │   └── [code]/submit/route.ts # POST student submission (public)
│   │   │   └── analysis/
│   │   │       ├── [examId]/[studentName]/route.ts  # GET status + result
│   │   │       └── [examId]/[studentName]/generate/route.ts  # POST trigger
│   │   ├── exam/
│   │   │   └── page.tsx           # Public: code+name entry → answer submission
│   │   ├── (auth)/
│   │   │   ├── login/page.tsx
│   │   │   └── register/page.tsx
│   │   └── (dashboard)/
│   │       ├── layout.tsx          # Sidebar nav
│   │       ├── dashboard/page.tsx  # Student performance overview + Recharts
│   │       ├── problems/
│   │       │   ├── page.tsx        # Problem list
│   │       │   └── new/page.tsx    # Create problem (manual + OCR)
│   │       ├── exams/
│   │       │   ├── page.tsx        # Exam list
│   │       │   ├── new/page.tsx    # Create exam
│   │       │   └── [id]/
│   │       │       ├── page.tsx    # Exam detail + answer input tab
│   │       │       └── analysis/[studentName]/page.tsx
│   │       ├── students/page.tsx   # RegisteredStudent CRUD
│   │       └── settings/types/page.tsx  # TypeGroup management
│   └── components/
│       ├── ui/                     # shadcn/ui auto-generated
│       ├── ExamAnswerInput.tsx     # O/X toggle + Tab nav form
│       ├── TypeGroupEditor.tsx     # Drag-order + CRUD for types
│       ├── AnalysisReport.tsx      # Teacher + parent report display
│       └── PerformanceChart.tsx    # Recharts bar chart by type
└── tests/
    ├── lib/
    │   ├── exam-code.test.ts
    │   └── analysis.test.ts
    └── api/
        ├── problems.test.ts
        └── exam-public.test.ts
```

---

### Task 1: Project Initialization

**Files:**
- Create: `prisma/schema.prisma`
- Create: `src/lib/prisma.ts`
- Create: `vitest.config.ts`
- Create: `tests/lib/exam-code.test.ts`
- Create: `src/lib/exam-code.ts`

- [ ] **Step 1: Initialize Next.js project**

```bash
npx create-next-app@latest study-platform --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
cd study-platform
```

- [ ] **Step 2: Install dependencies**

```bash
npm install prisma @prisma/client next-auth bcryptjs
npm install @types/bcryptjs
npm install -D vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom jsdom
npx shadcn-ui@latest init
npx shadcn-ui@latest add button input label card badge tabs table dialog form select toast
npm install recharts
npm install openai
```

- [ ] **Step 3: Configure vitest**

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    globals: true,
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
})
```

```typescript
// tests/setup.ts
import '@testing-library/jest-dom'
```

- [ ] **Step 4: Write failing test for exam-code generator**

```typescript
// tests/lib/exam-code.test.ts
import { describe, it, expect } from 'vitest'
import { generateExamCode } from '@/lib/exam-code'

describe('generateExamCode', () => {
  it('returns 6 uppercase alphanumeric characters', () => {
    const code = generateExamCode()
    expect(code).toMatch(/^[A-Z0-9]{6}$/)
  })

  it('returns different codes on repeated calls', () => {
    const codes = new Set(Array.from({ length: 20 }, generateExamCode))
    expect(codes.size).toBeGreaterThan(1)
  })
})
```

- [ ] **Step 5: Run test to verify it fails**

```bash
npx vitest run tests/lib/exam-code.test.ts
```
Expected: FAIL — `generateExamCode` not found

- [ ] **Step 6: Implement exam-code generator**

```typescript
// src/lib/exam-code.ts
const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

export function generateExamCode(): string {
  return Array.from({ length: 6 }, () =>
    CHARS[Math.floor(Math.random() * CHARS.length)]
  ).join('')
}
```

- [ ] **Step 7: Run test to verify it passes**

```bash
npx vitest run tests/lib/exam-code.test.ts
```
Expected: PASS

- [ ] **Step 8: Create Prisma client singleton**

```typescript
// src/lib/prisma.ts
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

export const prisma =
  globalForPrisma.prisma ?? new PrismaClient({ log: ['error'] })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: project setup with Next.js 14, Prisma, Vitest, shadcn/ui"
```

---

### Task 2: Prisma Schema + Database + Seed

**Files:**
- Create: `prisma/schema.prisma`
- Create: `prisma/seed.ts`
- Modify: `package.json` (prisma seed script)

- [ ] **Step 1: Write Prisma schema**

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id         String   @id @default(cuid())
  email      String   @unique
  name       String
  password   String
  isPaid     Boolean  @default(false)
  createdAt  DateTime @default(now())

  problems   Problem[]
  exams      Exam[]
  students   RegisteredStudent[]
  typeGroups TypeGroup[]
}

model RegisteredStudent {
  id        String @id @default(cuid())
  teacherId String
  name      String
  teacher   User   @relation(fields: [teacherId], references: [id], onDelete: Cascade)

  @@unique([teacherId, name])
}

model TypeGroup {
  id        String        @id @default(cuid())
  teacherId String
  name      String
  subject   String
  isDefault Boolean       @default(false)
  teacher   User          @relation(fields: [teacherId], references: [id], onDelete: Cascade)
  types     ProblemType[]
}

model ProblemType {
  id       String    @id @default(cuid())
  groupId  String
  name     String
  order    Int       @default(0)
  group    TypeGroup @relation(fields: [groupId], references: [id], onDelete: Cascade)
  problems Problem[]
}

model Problem {
  id          String      @id @default(cuid())
  teacherId   String
  title       String
  content     String
  answer      String
  typeId      String
  inputMethod InputMethod @default(MANUAL)
  ocrOriginal String?
  createdAt   DateTime    @default(now())

  teacher      User          @relation(fields: [teacherId], references: [id], onDelete: Cascade)
  type         ProblemType   @relation(fields: [typeId], references: [id])
  examProblems ExamProblem[]
  submissions  Submission[]
}

enum InputMethod {
  MANUAL
  OCR
}

model Exam {
  id        String   @id @default(cuid())
  teacherId String
  title     String
  date      DateTime
  code      String   @unique
  isOpen    Boolean  @default(true)
  createdAt DateTime @default(now())

  teacher     User          @relation(fields: [teacherId], references: [id], onDelete: Cascade)
  problems    ExamProblem[]
  submissions Submission[]
  analyses    Analysis[]
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

model Submission {
  id          String    @id @default(cuid())
  examId      String
  problemId   String
  studentName String
  answer      String
  processNote String?
  isCorrect   Boolean?
  gradedAt    DateTime?
  enteredBy   EnteredBy @default(STUDENT)
  createdAt   DateTime  @default(now())

  exam    Exam    @relation(fields: [examId], references: [id], onDelete: Cascade)
  problem Problem @relation(fields: [problemId], references: [id])

  @@unique([examId, problemId, studentName])
  @@index([examId, studentName])
}

enum EnteredBy {
  STUDENT
  TEACHER
}

model Analysis {
  id          String         @id @default(cuid())
  examId      String
  studentName String
  status      AnalysisStatus @default(PENDING)
  weakTypes   Json?
  aiReport    Json?
  createdAt   DateTime       @default(now())
  updatedAt   DateTime       @updatedAt

  exam Exam @relation(fields: [examId], references: [id], onDelete: Cascade)

  @@unique([examId, studentName])
}

enum AnalysisStatus {
  PENDING
  GENERATING
  DONE
  FAILED
}
```

- [ ] **Step 2: Set up Supabase and .env**

Create a project at supabase.com. Copy the connection string (Transaction mode, port 6543 for pooling).

```bash
# .env.local
DATABASE_URL="postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:5432/postgres"
NEXTAUTH_SECRET="generate-with-openssl-rand-base64-32"
NEXTAUTH_URL="http://localhost:3000"
OPENAI_API_KEY="sk-..."
```

Update schema.prisma to use DIRECT_URL for migrations:
```prisma
datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}
```

- [ ] **Step 3: Run migration**

```bash
npx prisma migrate dev --name init
```
Expected: Migration created, Prisma client generated.

- [ ] **Step 4: Write seed for Korean default types**

```typescript
// prisma/seed.ts
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export const defaultKoreanTypes = [
  { name: '독서 - 인문',     order: 1 },
  { name: '독서 - 사회',     order: 2 },
  { name: '독서 - 과학',     order: 3 },
  { name: '독서 - 기술',     order: 4 },
  { name: '독서 - 예술',     order: 5 },
  { name: '문학 - 현대시',   order: 6 },
  { name: '문학 - 고전시가', order: 7 },
  { name: '문학 - 현대소설', order: 8 },
  { name: '문학 - 고전소설', order: 9 },
  { name: '문학 - 수필/극',  order: 10 },
  { name: '언어 - 문법',     order: 11 },
  { name: '매체 - 매체 자료', order: 12 },
  { name: '화법과 작문',     order: 13 },
]

export async function createDefaultKoreanTypeGroup(teacherId: string) {
  const group = await prisma.typeGroup.create({
    data: {
      teacherId,
      name: '기본 국어 유형',
      subject: '국어',
      isDefault: true,
      types: {
        create: defaultKoreanTypes,
      },
    },
  })
  return group
}

async function main() {
  console.log('Seed complete (types created per-teacher on register)')
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
```

- [ ] **Step 5: Add seed script to package.json**

```json
{
  "prisma": {
    "seed": "ts-node --compiler-options '{\"module\":\"CommonJS\"}' prisma/seed.ts"
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add prisma/ package.json
git commit -m "feat: prisma schema + seed for Korean default type group"
```

---

### Task 3: NextAuth + Middleware

**Files:**
- Create: `src/lib/auth.ts`
- Create: `src/app/api/auth/[...nextauth]/route.ts`
- Create: `src/middleware.ts`
- Create: `src/types/next-auth.d.ts`

- [ ] **Step 1: Create NextAuth config**

```typescript
// src/lib/auth.ts
import { NextAuthOptions } from 'next-auth'
import CredentialsProvider from 'next-auth/providers/credentials'
import bcrypt from 'bcryptjs'
import { prisma } from './prisma'

export const authOptions: NextAuthOptions = {
  session: { strategy: 'jwt' },
  providers: [
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null

        const user = await prisma.user.findUnique({
          where: { email: credentials.email },
        })
        if (!user) return null

        const valid = await bcrypt.compare(credentials.password, user.password)
        if (!valid) return null

        return { id: user.id, email: user.email, name: user.name, isPaid: user.isPaid }
      },
    }),
  ],
  callbacks: {
    jwt({ token, user }) {
      if (user) {
        token.id = user.id
        token.isPaid = (user as { isPaid: boolean }).isPaid
      }
      return token
    },
    session({ session, token }) {
      session.user.id = token.id as string
      session.user.isPaid = token.isPaid as boolean
      return session
    },
  },
  pages: {
    signIn: '/login',
  },
}
```

```typescript
// src/types/next-auth.d.ts
import 'next-auth'
import 'next-auth/jwt'

declare module 'next-auth' {
  interface User {
    isPaid: boolean
  }
  interface Session {
    user: {
      id: string
      email: string
      name: string
      isPaid: boolean
    }
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    id: string
    isPaid: boolean
  }
}
```

- [ ] **Step 2: Create NextAuth route handler**

```typescript
// src/app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth'
import { authOptions } from '@/lib/auth'

const handler = NextAuth(authOptions)
export { handler as GET, handler as POST }
```

- [ ] **Step 3: Create middleware**

```typescript
// src/middleware.ts
import { withAuth } from 'next-auth/middleware'
import { NextResponse } from 'next/server'

export default withAuth(
  function middleware(req) {
    return NextResponse.next()
  },
  {
    callbacks: {
      authorized: ({ token, req }) => {
        const { pathname } = req.nextUrl
        // Public routes
        if (pathname.startsWith('/exam') || pathname.startsWith('/api/exam')) {
          return true
        }
        // Auth routes accessible without login
        if (pathname.startsWith('/login') || pathname.startsWith('/register')) {
          return true
        }
        return !!token
      },
    },
  }
)

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}
```

- [ ] **Step 4: Commit**

```bash
git add src/lib/auth.ts src/app/api/auth src/middleware.ts src/types/
git commit -m "feat: NextAuth credentials provider + JWT middleware"
```

---

### Task 4: Auth Pages (Login + Register)

**Files:**
- Create: `src/app/(auth)/login/page.tsx`
- Create: `src/app/(auth)/register/page.tsx`
- Create: `src/app/api/auth/register/route.ts`

- [ ] **Step 1: Create register API**

```typescript
// src/app/api/auth/register/route.ts
import { NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { prisma } from '@/lib/prisma'
import { createDefaultKoreanTypeGroup } from '@/../prisma/seed'

export async function POST(req: Request) {
  const { email, name, password } = await req.json()

  if (!email || !name || !password) {
    return NextResponse.json({ error: '모든 필드를 입력해주세요.' }, { status: 400 })
  }

  const exists = await prisma.user.findUnique({ where: { email } })
  if (exists) {
    return NextResponse.json({ error: '이미 사용 중인 이메일입니다.' }, { status: 409 })
  }

  const hashed = await bcrypt.hash(password, 12)
  const user = await prisma.user.create({
    data: { email, name, password: hashed },
  })

  await createDefaultKoreanTypeGroup(user.id)

  return NextResponse.json({ id: user.id }, { status: 201 })
}
```

- [ ] **Step 2: Create login page**

```tsx
// src/app/(auth)/login/page.tsx
'use client'
import { useState } from 'react'
import { signIn } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import Link from 'next/link'

export default function LoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const res = await signIn('credentials', {
      email,
      password,
      redirect: false,
    })
    if (res?.error) {
      setError('이메일 또는 비밀번호가 올바르지 않습니다.')
    } else {
      router.push('/dashboard')
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>로그인</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="email">이메일</Label>
              <Input id="email" type="email" value={email} onChange={e => setEmail(e.target.value)} required />
            </div>
            <div>
              <Label htmlFor="password">비밀번호</Label>
              <Input id="password" type="password" value={password} onChange={e => setPassword(e.target.value)} required />
            </div>
            {error && <p className="text-sm text-red-500">{error}</p>}
            <Button type="submit" className="w-full">로그인</Button>
          </form>
          <p className="mt-4 text-center text-sm text-gray-600">
            계정이 없으신가요?{' '}
            <Link href="/register" className="text-blue-600 hover:underline">회원가입</Link>
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
```

- [ ] **Step 3: Create register page**

```tsx
// src/app/(auth)/register/page.tsx
'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import Link from 'next/link'

export default function RegisterPage() {
  const router = useRouter()
  const [form, setForm] = useState({ email: '', name: '', password: '' })
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const res = await fetch('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form),
    })
    if (!res.ok) {
      const data = await res.json()
      setError(data.error)
    } else {
      router.push('/login')
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>회원가입</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="name">이름</Label>
              <Input id="name" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} required />
            </div>
            <div>
              <Label htmlFor="email">이메일</Label>
              <Input id="email" type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} required />
            </div>
            <div>
              <Label htmlFor="password">비밀번호</Label>
              <Input id="password" type="password" value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} required />
            </div>
            {error && <p className="text-sm text-red-500">{error}</p>}
            <Button type="submit" className="w-full">가입하기</Button>
          </form>
          <p className="mt-4 text-center text-sm text-gray-600">
            이미 계정이 있으신가요?{' '}
            <Link href="/login" className="text-blue-600 hover:underline">로그인</Link>
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
```

- [ ] **Step 4: Commit**

```bash
git add src/app/(auth) src/app/api/auth/register
git commit -m "feat: login and register pages with default Korean type group creation"
```

---

### Task 5: Dashboard Layout + TypeGroup Management

**Files:**
- Create: `src/app/(dashboard)/layout.tsx`
- Create: `src/app/api/type-groups/route.ts`
- Create: `src/app/api/type-groups/[id]/route.ts`
- Create: `src/app/(dashboard)/settings/types/page.tsx`
- Create: `src/components/TypeGroupEditor.tsx`

- [ ] **Step 1: Create dashboard layout**

```tsx
// src/app/(dashboard)/layout.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { SignOutButton } from '@/components/SignOutButton'

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authOptions)
  if (!session) redirect('/login')

  return (
    <div className="flex min-h-screen">
      <aside className="w-56 bg-gray-900 text-white flex flex-col p-4">
        <div className="text-lg font-bold mb-8">StudyPlatform</div>
        <nav className="flex flex-col gap-2 text-sm">
          <Link href="/dashboard" className="hover:text-gray-300">대시보드</Link>
          <Link href="/problems" className="hover:text-gray-300">문제 관리</Link>
          <Link href="/exams" className="hover:text-gray-300">시험 관리</Link>
          <Link href="/students" className="hover:text-gray-300">학생 관리</Link>
          <Link href="/settings/types" className="hover:text-gray-300">유형 설정</Link>
        </nav>
        <div className="mt-auto">
          <p className="text-xs text-gray-400 mb-2">{session.user.name}</p>
          <SignOutButton />
        </div>
      </aside>
      <main className="flex-1 p-6 bg-gray-50">{children}</main>
    </div>
  )
}
```

```tsx
// src/components/SignOutButton.tsx
'use client'
import { signOut } from 'next-auth/react'
import { Button } from '@/components/ui/button'

export function SignOutButton() {
  return (
    <Button variant="ghost" size="sm" className="text-gray-400 w-full justify-start" onClick={() => signOut({ callbackUrl: '/login' })}>
      로그아웃
    </Button>
  )
}
```

- [ ] **Step 2: Create type-groups API**

```typescript
// src/app/api/type-groups/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const groups = await prisma.typeGroup.findMany({
    where: { teacherId: session.user.id },
    include: { types: { orderBy: { order: 'asc' } } },
    orderBy: { isDefault: 'desc' },
  })
  return NextResponse.json(groups)
}

export async function POST(req: Request) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { name, subject } = await req.json()
  const group = await prisma.typeGroup.create({
    data: { teacherId: session.user.id, name, subject },
    include: { types: true },
  })
  return NextResponse.json(group, { status: 201 })
}
```

```typescript
// src/app/api/type-groups/[id]/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const data = await req.json()
  // data can contain: group name/subject update, OR types array (full replace)
  const { name, subject, types } = data

  if (types !== undefined) {
    // Replace all ProblemTypes for this group
    await prisma.$transaction([
      prisma.problemType.deleteMany({ where: { groupId: params.id } }),
      ...types.map((t: { name: string; order: number }) =>
        prisma.problemType.create({ data: { groupId: params.id, name: t.name, order: t.order } })
      ),
    ])
  }

  const group = await prisma.typeGroup.update({
    where: { id: params.id, teacherId: session.user.id },
    data: { ...(name && { name }), ...(subject && { subject }) },
    include: { types: { orderBy: { order: 'asc' } } },
  })
  return NextResponse.json(group)
}

export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  await prisma.typeGroup.delete({
    where: { id: params.id, teacherId: session.user.id },
  })
  return NextResponse.json({ ok: true })
}
```

- [ ] **Step 3: Create TypeGroupEditor component**

```tsx
// src/components/TypeGroupEditor.tsx
'use client'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

interface ProblemType { id: string; name: string; order: number }
interface TypeGroup { id: string; name: string; subject: string; isDefault: boolean; types: ProblemType[] }

interface Props {
  groups: TypeGroup[]
  onUpdate: () => void
}

export function TypeGroupEditor({ groups, onUpdate }: Props) {
  const [editing, setEditing] = useState<string | null>(null)
  const [newTypeName, setNewTypeName] = useState('')

  async function addType(groupId: string, currentTypes: ProblemType[]) {
    if (!newTypeName.trim()) return
    const updated = [...currentTypes, { name: newTypeName.trim(), order: currentTypes.length + 1 }]
    await fetch(`/api/type-groups/${groupId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ types: updated }),
    })
    setNewTypeName('')
    onUpdate()
  }

  async function removeType(groupId: string, currentTypes: ProblemType[], typeId: string) {
    const updated = currentTypes
      .filter(t => t.id !== typeId)
      .map((t, i) => ({ name: t.name, order: i + 1 }))
    await fetch(`/api/type-groups/${groupId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ types: updated }),
    })
    onUpdate()
  }

  async function deleteGroup(groupId: string) {
    await fetch(`/api/type-groups/${groupId}`, { method: 'DELETE' })
    onUpdate()
  }

  return (
    <div className="space-y-4">
      {groups.map(group => (
        <Card key={group.id}>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-base">
              {group.name}
              {group.isDefault && <Badge variant="secondary" className="ml-2">기본</Badge>}
              <span className="text-sm text-gray-500 ml-2">{group.subject}</span>
            </CardTitle>
            {!group.isDefault && (
              <Button variant="destructive" size="sm" onClick={() => deleteGroup(group.id)}>삭제</Button>
            )}
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-2 mb-3">
              {group.types.map(type => (
                <Badge key={type.id} variant="outline" className="flex items-center gap-1">
                  {type.name}
                  <button
                    onClick={() => removeType(group.id, group.types, type.id)}
                    className="ml-1 text-gray-400 hover:text-red-500 text-xs"
                  >×</button>
                </Badge>
              ))}
            </div>
            {editing === group.id ? (
              <div className="flex gap-2">
                <Input
                  value={newTypeName}
                  onChange={e => setNewTypeName(e.target.value)}
                  placeholder="유형 이름"
                  className="h-8 text-sm"
                  onKeyDown={e => { if (e.key === 'Enter') addType(group.id, group.types) }}
                />
                <Button size="sm" onClick={() => addType(group.id, group.types)}>추가</Button>
                <Button size="sm" variant="ghost" onClick={() => setEditing(null)}>취소</Button>
              </div>
            ) : (
              <Button size="sm" variant="ghost" onClick={() => setEditing(group.id)}>+ 유형 추가</Button>
            )}
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
```

- [ ] **Step 4: Create settings/types page**

```tsx
// src/app/(dashboard)/settings/types/page.tsx
'use client'
import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { TypeGroupEditor } from '@/components/TypeGroupEditor'

interface TypeGroup { id: string; name: string; subject: string; isDefault: boolean; types: { id: string; name: string; order: number }[] }

export default function TypesSettingsPage() {
  const [groups, setGroups] = useState<TypeGroup[]>([])
  const [newName, setNewName] = useState('')
  const [newSubject, setNewSubject] = useState('')

  async function load() {
    const res = await fetch('/api/type-groups')
    setGroups(await res.json())
  }

  useEffect(() => { load() }, [])

  async function addGroup() {
    if (!newName || !newSubject) return
    await fetch('/api/type-groups', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: newName, subject: newSubject }),
    })
    setNewName(''); setNewSubject('')
    load()
  }

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-bold mb-6">유형 그룹 관리</h1>
      <TypeGroupEditor groups={groups} onUpdate={load} />
      <div className="mt-6 flex gap-2 items-end">
        <div>
          <label className="text-sm font-medium">그룹명</label>
          <Input value={newName} onChange={e => setNewName(e.target.value)} placeholder="2025 수능 기준" />
        </div>
        <div>
          <label className="text-sm font-medium">과목</label>
          <Input value={newSubject} onChange={e => setNewSubject(e.target.value)} placeholder="국어" />
        </div>
        <Button onClick={addGroup}>그룹 추가</Button>
      </div>
    </div>
  )
}
```

- [ ] **Step 5: Commit**

```bash
git add src/app/(dashboard) src/app/api/type-groups src/components/
git commit -m "feat: dashboard layout + TypeGroup management UI"
```

---

### Task 6: Problem Management CRUD

**Files:**
- Create: `src/app/api/problems/route.ts`
- Create: `src/app/api/problems/[id]/route.ts`
- Create: `src/app/(dashboard)/problems/page.tsx`
- Create: `src/app/(dashboard)/problems/new/page.tsx`

- [ ] **Step 1: Create problems API**

```typescript
// src/app/api/problems/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const problems = await prisma.problem.findMany({
    where: { teacherId: session.user.id },
    include: { type: { include: { group: true } } },
    orderBy: { createdAt: 'desc' },
  })
  return NextResponse.json(problems)
}

export async function POST(req: Request) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { title, content, answer, typeId, inputMethod, ocrOriginal } = await req.json()

  const problem = await prisma.problem.create({
    data: {
      teacherId: session.user.id,
      title,
      content,
      answer,
      typeId,
      inputMethod: inputMethod ?? 'MANUAL',
      ocrOriginal,
    },
    include: { type: { include: { group: true } } },
  })
  return NextResponse.json(problem, { status: 201 })
}
```

```typescript
// src/app/api/problems/[id]/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const data = await req.json()
  const problem = await prisma.problem.update({
    where: { id: params.id, teacherId: session.user.id },
    data,
    include: { type: { include: { group: true } } },
  })
  return NextResponse.json(problem)
}

export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  await prisma.problem.delete({ where: { id: params.id, teacherId: session.user.id } })
  return NextResponse.json({ ok: true })
}
```

- [ ] **Step 2: Create problem list page**

```tsx
// src/app/(dashboard)/problems/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import Link from 'next/link'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'

export default async function ProblemsPage() {
  const session = await getServerSession(authOptions)!
  const problems = await prisma.problem.findMany({
    where: { teacherId: session!.user.id },
    include: { type: { include: { group: true } } },
    orderBy: { createdAt: 'desc' },
  })

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">문제 목록</h1>
        <Link href="/problems/new"><Button>문제 추가</Button></Link>
      </div>
      <div className="space-y-2">
        {problems.map(p => (
          <div key={p.id} className="bg-white rounded-lg border p-4 flex justify-between items-center">
            <div>
              <p className="font-medium">{p.title}</p>
              <Badge variant="outline" className="text-xs mt-1">{p.type.name}</Badge>
            </div>
            <div className="flex gap-2">
              <Link href={`/problems/${p.id}/edit`}><Button size="sm" variant="outline">수정</Button></Link>
            </div>
          </div>
        ))}
        {problems.length === 0 && (
          <p className="text-gray-500 text-center py-12">아직 등록된 문제가 없습니다.</p>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Create problem creation page**

```tsx
// src/app/(dashboard)/problems/new/page.tsx
'use client'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

interface ProblemType { id: string; name: string }
interface TypeGroup { id: string; name: string; types: ProblemType[] }

export default function NewProblemPage() {
  const router = useRouter()
  const [groups, setGroups] = useState<TypeGroup[]>([])
  const [form, setForm] = useState({ title: '', content: '', answer: '', typeId: '' })

  useEffect(() => {
    fetch('/api/type-groups').then(r => r.json()).then(setGroups)
  }, [])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const res = await fetch('/api/problems', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form),
    })
    if (res.ok) router.push('/problems')
  }

  const allTypes = groups.flatMap(g => g.types.map(t => ({ ...t, groupName: g.name })))

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-bold mb-6">문제 추가</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <Label>제목</Label>
          <Input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} required />
        </div>
        <div>
          <Label>문제 내용 (지문 포함)</Label>
          <Textarea value={form.content} onChange={e => setForm(f => ({ ...f, content: e.target.value }))} rows={8} required />
        </div>
        <div>
          <Label>정답</Label>
          <Input value={form.answer} onChange={e => setForm(f => ({ ...f, answer: e.target.value }))} required />
        </div>
        <div>
          <Label>문제 유형</Label>
          <Select value={form.typeId} onValueChange={v => setForm(f => ({ ...f, typeId: v }))}>
            <SelectTrigger><SelectValue placeholder="유형 선택" /></SelectTrigger>
            <SelectContent>
              {allTypes.map(t => (
                <SelectItem key={t.id} value={t.id}>{t.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <Button type="submit" disabled={!form.typeId}>저장</Button>
      </form>
    </div>
  )
}
```

- [ ] **Step 4: Commit**

```bash
git add src/app/api/problems src/app/(dashboard)/problems
git commit -m "feat: problem CRUD API and pages"
```

---

### Task 7: Student Management

**Files:**
- Create: `src/app/api/students/route.ts`
- Create: `src/app/(dashboard)/students/page.tsx`

- [ ] **Step 1: Create students API**

```typescript
// src/app/api/students/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const students = await prisma.registeredStudent.findMany({
    where: { teacherId: session.user.id },
    orderBy: { name: 'asc' },
  })
  return NextResponse.json(students)
}

export async function POST(req: Request) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // isPaid check: free tier = 5 students max
  if (!session.user.isPaid) {
    const count = await prisma.registeredStudent.count({ where: { teacherId: session.user.id } })
    if (count >= 5) {
      return NextResponse.json({ error: '무료 플랜은 학생 5명까지 등록 가능합니다. 베타 신청으로 문의해주세요.' }, { status: 403 })
    }
  }

  const { name } = await req.json()
  const student = await prisma.registeredStudent.create({
    data: { teacherId: session.user.id, name },
  })
  return NextResponse.json(student, { status: 201 })
}

export async function DELETE(req: Request) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await req.json()
  await prisma.registeredStudent.delete({
    where: { id, teacherId: session.user.id },
  })
  return NextResponse.json({ ok: true })
}
```

- [ ] **Step 2: Create students page**

```tsx
// src/app/(dashboard)/students/page.tsx
'use client'
import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

interface Student { id: string; name: string }

export default function StudentsPage() {
  const [students, setStudents] = useState<Student[]>([])
  const [name, setName] = useState('')
  const [error, setError] = useState('')

  async function load() {
    const res = await fetch('/api/students')
    setStudents(await res.json())
  }

  useEffect(() => { load() }, [])

  async function add() {
    setError('')
    if (!name.trim()) return
    const res = await fetch('/api/students', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: name.trim() }),
    })
    if (!res.ok) {
      const data = await res.json()
      setError(data.error)
    } else {
      setName('')
      load()
    }
  }

  async function remove(id: string) {
    await fetch('/api/students', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    })
    load()
  }

  return (
    <div className="max-w-md">
      <h1 className="text-2xl font-bold mb-6">학생 명단</h1>
      <div className="flex gap-2 mb-4">
        <Input
          value={name}
          onChange={e => setName(e.target.value)}
          placeholder="학생 이름"
          onKeyDown={e => { if (e.key === 'Enter') add() }}
        />
        <Button onClick={add}>추가</Button>
      </div>
      {error && <p className="text-sm text-red-500 mb-3">{error}</p>}
      <div className="space-y-2">
        {students.map(s => (
          <div key={s.id} className="flex justify-between items-center bg-white border rounded-lg px-4 py-2">
            <span>{s.name}</span>
            <Button size="sm" variant="ghost" onClick={() => remove(s.id)}>삭제</Button>
          </div>
        ))}
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add src/app/api/students src/app/(dashboard)/students
git commit -m "feat: student management with isPaid gating (5 students free)"
```

---

### Task 8: Exam Management

**Files:**
- Create: `src/app/api/exams/route.ts`
- Create: `src/app/api/exams/[id]/route.ts`
- Create: `src/app/(dashboard)/exams/page.tsx`
- Create: `src/app/(dashboard)/exams/new/page.tsx`
- Create: `src/app/(dashboard)/exams/[id]/page.tsx`

- [ ] **Step 1: Create exams API**

```typescript
// src/app/api/exams/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { generateExamCode } from '@/lib/exam-code'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const exams = await prisma.exam.findMany({
    where: { teacherId: session.user.id },
    include: { _count: { select: { problems: true, submissions: true } } },
    orderBy: { createdAt: 'desc' },
  })
  return NextResponse.json(exams)
}

export async function POST(req: Request) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // isPaid check: free tier = 3 exams max
  if (!session.user.isPaid) {
    const count = await prisma.exam.count({ where: { teacherId: session.user.id } })
    if (count >= 3) {
      return NextResponse.json({ error: '무료 플랜은 시험 3개까지 생성 가능합니다.' }, { status: 403 })
    }
  }

  const { title, date, problemIds } = await req.json()

  // Generate unique exam code
  let code = generateExamCode()
  while (await prisma.exam.findUnique({ where: { code } })) {
    code = generateExamCode()
  }

  const exam = await prisma.exam.create({
    data: {
      teacherId: session.user.id,
      title,
      date: new Date(date),
      code,
      problems: {
        create: problemIds.map((id: string, i: number) => ({ problemId: id, order: i + 1 })),
      },
    },
    include: { problems: { include: { problem: true }, orderBy: { order: 'asc' } } },
  })
  return NextResponse.json(exam, { status: 201 })
}
```

```typescript
// src/app/api/exams/[id]/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET(_req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const exam = await prisma.exam.findUnique({
    where: { id: params.id, teacherId: session.user.id },
    include: {
      problems: {
        include: { problem: { include: { type: true } } },
        orderBy: { order: 'asc' },
      },
    },
  })
  if (!exam) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  return NextResponse.json(exam)
}

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const data = await req.json()
  const exam = await prisma.exam.update({
    where: { id: params.id, teacherId: session.user.id },
    data: { isOpen: data.isOpen },
  })
  return NextResponse.json(exam)
}
```

- [ ] **Step 2: Create exam list page**

```tsx
// src/app/(dashboard)/exams/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import Link from 'next/link'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'

export default async function ExamsPage() {
  const session = await getServerSession(authOptions)
  const exams = await prisma.exam.findMany({
    where: { teacherId: session!.user.id },
    include: { _count: { select: { problems: true, submissions: true } } },
    orderBy: { createdAt: 'desc' },
  })

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">시험 목록</h1>
        <Link href="/exams/new"><Button>시험 생성</Button></Link>
      </div>
      <div className="space-y-3">
        {exams.map(exam => (
          <Link key={exam.id} href={`/exams/${exam.id}`}>
            <div className="bg-white border rounded-lg p-4 hover:border-blue-400 transition-colors">
              <div className="flex justify-between items-start">
                <div>
                  <p className="font-medium">{exam.title}</p>
                  <p className="text-sm text-gray-500 mt-1">
                    코드: <span className="font-mono font-bold">{exam.code}</span> · {exam._count.problems}문제 · {exam._count.submissions}개 답안
                  </p>
                </div>
                <Badge variant={exam.isOpen ? 'default' : 'secondary'}>
                  {exam.isOpen ? '진행 중' : '마감'}
                </Badge>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Create exam creation page**

```tsx
// src/app/(dashboard)/exams/new/page.tsx
'use client'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Checkbox } from '@/components/ui/checkbox'

interface Problem { id: string; title: string; type: { name: string } }

export default function NewExamPage() {
  const router = useRouter()
  const [problems, setProblems] = useState<Problem[]>([])
  const [title, setTitle] = useState('')
  const [date, setDate] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())

  useEffect(() => {
    fetch('/api/problems').then(r => r.json()).then(setProblems)
  }, [])

  function toggle(id: string) {
    setSelected(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const res = await fetch('/api/exams', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, date, problemIds: Array.from(selected) }),
    })
    if (res.ok) {
      const exam = await res.json()
      router.push(`/exams/${exam.id}`)
    }
  }

  return (
    <div className="max-w-xl">
      <h1 className="text-2xl font-bold mb-6">시험 생성</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <Label>시험 제목</Label>
          <Input value={title} onChange={e => setTitle(e.target.value)} required />
        </div>
        <div>
          <Label>시험 날짜</Label>
          <Input type="date" value={date} onChange={e => setDate(e.target.value)} required />
        </div>
        <div>
          <Label className="mb-2 block">문제 선택</Label>
          <div className="space-y-2 max-h-64 overflow-y-auto border rounded p-3">
            {problems.map(p => (
              <label key={p.id} className="flex items-center gap-2 cursor-pointer">
                <Checkbox checked={selected.has(p.id)} onCheckedChange={() => toggle(p.id)} />
                <span className="text-sm">{p.title}</span>
                <span className="text-xs text-gray-400">({p.type.name})</span>
              </label>
            ))}
          </div>
        </div>
        <Button type="submit" disabled={selected.size === 0 || !title || !date}>
          시험 생성 ({selected.size}문제 선택됨)
        </Button>
      </form>
    </div>
  )
}
```

- [ ] **Step 4: Commit**

```bash
git add src/app/api/exams src/app/(dashboard)/exams
git commit -m "feat: exam management with code generation and isPaid gating"
```

---

### Task 9: Teacher Answer Input (Core Feature)

**Files:**
- Create: `src/app/api/exams/[id]/submissions/route.ts`
- Create: `src/components/ExamAnswerInput.tsx`
- Create: `src/app/(dashboard)/exams/[id]/page.tsx`

- [ ] **Step 1: Create submissions API (teacher input)**

```typescript
// src/app/api/exams/[id]/submissions/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET(req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const url = new URL(req.url)
  const studentName = url.searchParams.get('studentName')

  const submissions = await prisma.submission.findMany({
    where: {
      examId: params.id,
      ...(studentName ? { studentName } : {}),
    },
    include: { problem: true },
  })
  return NextResponse.json(submissions)
}

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { studentName, answers } = await req.json()
  // answers: Array<{ problemId: string; answer: string; processNote?: string; isCorrect: boolean }>

  const now = new Date()
  const upserts = answers.map((a: { problemId: string; answer: string; processNote?: string; isCorrect: boolean }) =>
    prisma.submission.upsert({
      where: {
        examId_problemId_studentName: {
          examId: params.id,
          problemId: a.problemId,
          studentName,
        },
      },
      create: {
        examId: params.id,
        problemId: a.problemId,
        studentName,
        answer: a.answer,
        processNote: a.processNote ?? null,
        isCorrect: a.isCorrect,
        gradedAt: now,
        enteredBy: 'TEACHER',
      },
      update: {
        answer: a.answer,
        processNote: a.processNote ?? null,
        isCorrect: a.isCorrect,
        gradedAt: now,
        enteredBy: 'TEACHER',
      },
    })
  )

  await prisma.$transaction(upserts)
  return NextResponse.json({ ok: true })
}
```

- [ ] **Step 2: Create ExamAnswerInput component**

```tsx
// src/components/ExamAnswerInput.tsx
'use client'
import { useState, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { useToast } from '@/components/ui/use-toast'

interface Problem {
  problem: { id: string; title: string; answer: string; type: { name: string } }
  order: number
}

interface AnswerState {
  answer: string
  processNote: string
  isCorrect: boolean | null
}

interface Props {
  examId: string
  problems: Problem[]
  students: { id: string; name: string }[]
}

export function ExamAnswerInput({ examId, problems, students }: Props) {
  const [selectedStudent, setSelectedStudent] = useState<string | null>(null)
  const [answers, setAnswers] = useState<Record<string, AnswerState>>({})
  const [saving, setSaving] = useState(false)
  const { toast } = useToast()
  const inputRefs = useRef<Record<string, HTMLInputElement | null>>({})

  function initAnswers() {
    const init: Record<string, AnswerState> = {}
    problems.forEach(ep => {
      init[ep.problem.id] = { answer: '', processNote: '', isCorrect: null }
    })
    setAnswers(init)
  }

  function selectStudent(name: string) {
    setSelectedStudent(name)
    initAnswers()
  }

  function setAnswer(problemId: string, field: keyof AnswerState, value: string | boolean | null) {
    setAnswers(prev => ({
      ...prev,
      [problemId]: { ...prev[problemId], [field]: value },
    }))
  }

  function handleKeyDown(e: React.KeyboardEvent, idx: number) {
    if (e.key === 'Tab' || e.key === 'Enter') {
      e.preventDefault()
      const nextId = problems[idx + 1]?.problem.id
      if (nextId) inputRefs.current[nextId]?.focus()
    }
  }

  async function save() {
    if (!selectedStudent) return
    setSaving(true)
    const payload = problems.map(ep => ({
      problemId: ep.problem.id,
      answer: answers[ep.problem.id]?.answer ?? '',
      processNote: answers[ep.problem.id]?.processNote || undefined,
      isCorrect: answers[ep.problem.id]?.isCorrect ?? false,
    }))

    await fetch(`/api/exams/${examId}/submissions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ studentName: selectedStudent, answers: payload }),
    })
    setSaving(false)
    toast({ title: `${selectedStudent} 답안 저장 완료` })
  }

  if (!selectedStudent) {
    return (
      <div>
        <p className="text-sm text-gray-500 mb-3">학생을 선택하세요</p>
        <div className="grid grid-cols-3 gap-2">
          {students.map(s => (
            <Button key={s.id} variant="outline" onClick={() => selectStudent(s.name)}>
              {s.name}
            </Button>
          ))}
        </div>
      </div>
    )
  }

  return (
    <div>
      <div className="flex items-center gap-3 mb-4">
        <Badge>{selectedStudent}</Badge>
        <Button variant="ghost" size="sm" onClick={() => setSelectedStudent(null)}>← 학생 변경</Button>
      </div>
      <div className="space-y-3">
        {problems.map((ep, idx) => {
          const state = answers[ep.problem.id] ?? { answer: '', processNote: '', isCorrect: null }
          return (
            <div key={ep.problem.id} className="flex items-center gap-3 bg-white border rounded-lg p-3">
              <span className="text-sm text-gray-400 w-6">{ep.order}</span>
              <span className="text-sm flex-1 truncate">{ep.problem.title}</span>
              <Badge variant="outline" className="text-xs">{ep.problem.type.name}</Badge>
              <div className="flex gap-1">
                <Button
                  size="sm"
                  variant={state.isCorrect === true ? 'default' : 'outline'}
                  className={state.isCorrect === true ? 'bg-green-500 hover:bg-green-600' : ''}
                  onClick={() => setAnswer(ep.problem.id, 'isCorrect', true)}
                >O</Button>
                <Button
                  size="sm"
                  variant={state.isCorrect === false ? 'default' : 'outline'}
                  className={state.isCorrect === false ? 'bg-red-500 hover:bg-red-600' : ''}
                  onClick={() => setAnswer(ep.problem.id, 'isCorrect', false)}
                >X</Button>
              </div>
              <Input
                ref={el => { inputRefs.current[ep.problem.id] = el }}
                value={state.answer}
                onChange={e => setAnswer(ep.problem.id, 'answer', e.target.value)}
                onKeyDown={e => handleKeyDown(e, idx)}
                placeholder="학생 답"
                className="w-20 h-8 text-sm"
              />
              <Input
                value={state.processNote}
                onChange={e => setAnswer(ep.problem.id, 'processNote', e.target.value)}
                placeholder="풀이 (선택)"
                className="w-40 h-8 text-sm"
              />
            </div>
          )
        })}
      </div>
      <Button className="mt-4" onClick={save} disabled={saving}>
        {saving ? '저장 중...' : '저장하기'}
      </Button>
    </div>
  )
}
```

- [ ] **Step 3: Create exam detail page**

```tsx
// src/app/(dashboard)/exams/[id]/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { notFound } from 'next/navigation'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ExamAnswerInput } from '@/components/ExamAnswerInput'
import { Badge } from '@/components/ui/badge'

export default async function ExamDetailPage({ params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  const exam = await prisma.exam.findUnique({
    where: { id: params.id, teacherId: session!.user.id },
    include: {
      problems: {
        include: { problem: { include: { type: true } } },
        orderBy: { order: 'asc' },
      },
    },
  })
  if (!exam) notFound()

  const students = await prisma.registeredStudent.findMany({
    where: { teacherId: session!.user.id },
    orderBy: { name: 'asc' },
  })

  return (
    <div>
      <div className="flex items-center gap-3 mb-6">
        <h1 className="text-2xl font-bold">{exam.title}</h1>
        <span className="font-mono text-lg font-bold text-blue-600">{exam.code}</span>
        <Badge variant={exam.isOpen ? 'default' : 'secondary'}>{exam.isOpen ? '진행 중' : '마감'}</Badge>
      </div>
      <Tabs defaultValue="input">
        <TabsList>
          <TabsTrigger value="input">답안 입력</TabsTrigger>
          <TabsTrigger value="results">결과 분석</TabsTrigger>
        </TabsList>
        <TabsContent value="input" className="mt-4">
          <ExamAnswerInput
            examId={exam.id}
            problems={exam.problems as Parameters<typeof ExamAnswerInput>[0]['problems']}
            students={students}
          />
        </TabsContent>
        <TabsContent value="results" className="mt-4">
          <p className="text-gray-500">분석 결과는 답안 입력 후 생성 가능합니다.</p>
        </TabsContent>
      </Tabs>
    </div>
  )
}
```

- [ ] **Step 4: Commit**

```bash
git add src/app/api/exams src/components/ExamAnswerInput.tsx src/app/(dashboard)/exams/
git commit -m "feat: teacher answer input with O/X toggle and Tab navigation"
```

---

### Task 10: Student Web Submission (Public /exam)

**Files:**
- Create: `src/app/api/exam/[code]/route.ts`
- Create: `src/app/api/exam/[code]/submit/route.ts`
- Create: `src/app/exam/page.tsx`
- Modify: `tests/api/exam-public.test.ts`

- [ ] **Step 1: Write failing test for public exam API**

```typescript
// tests/api/exam-public.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock prisma
vi.mock('@/lib/prisma', () => ({
  prisma: {
    exam: {
      findUnique: vi.fn(),
    },
    submission: {
      upsert: vi.fn(),
    },
    $transaction: vi.fn((ops: unknown[]) => Promise.all(ops)),
  },
}))

describe('GET /api/exam/[code]', () => {
  it('returns 404 for unknown code', async () => {
    const { prisma } = await import('@/lib/prisma')
    vi.mocked(prisma.exam.findUnique).mockResolvedValue(null)

    // Import route handler
    const { GET } = await import('@/app/api/exam/[code]/route')
    const req = new Request('http://localhost/api/exam/XXXXXX')
    const res = await GET(req, { params: { code: 'XXXXXX' } })
    expect(res.status).toBe(404)
  })

  it('returns 403 when exam is closed', async () => {
    const { prisma } = await import('@/lib/prisma')
    vi.mocked(prisma.exam.findUnique).mockResolvedValue({
      id: '1', isOpen: false, title: 'Test', code: 'ABC123', teacherId: 't1',
      date: new Date(), createdAt: new Date(),
      problems: [],
    } as never)

    const { GET } = await import('@/app/api/exam/[code]/route')
    const req = new Request('http://localhost/api/exam/ABC123')
    const res = await GET(req, { params: { code: 'ABC123' } })
    expect(res.status).toBe(403)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npx vitest run tests/api/exam-public.test.ts
```
Expected: FAIL — route module not found

- [ ] **Step 3: Create public exam API**

```typescript
// src/app/api/exam/[code]/route.ts
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET(_req: Request, { params }: { params: { code: string } }) {
  const exam = await prisma.exam.findUnique({
    where: { code: params.code },
    include: {
      problems: {
        include: { problem: { select: { id: true, title: true, content: true } } },
        orderBy: { order: 'asc' },
      },
    },
  })

  if (!exam) return NextResponse.json({ error: '존재하지 않는 시험 코드입니다.' }, { status: 404 })
  if (!exam.isOpen) return NextResponse.json({ error: '마감된 시험입니다.' }, { status: 403 })

  return NextResponse.json({
    id: exam.id,
    title: exam.title,
    date: exam.date,
    problems: exam.problems,
  })
}
```

```typescript
// src/app/api/exam/[code]/submit/route.ts
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(req: Request, { params }: { params: { code: string } }) {
  const exam = await prisma.exam.findUnique({ where: { code: params.code } })
  if (!exam) return NextResponse.json({ error: '존재하지 않는 시험입니다.' }, { status: 404 })
  if (!exam.isOpen) return NextResponse.json({ error: '마감된 시험입니다.' }, { status: 403 })

  const { studentName, answers } = await req.json()
  // answers: Array<{ problemId: string; answer: string; processNote?: string }>

  const problems = await prisma.examProblem.findMany({ where: { examId: exam.id } })
  const problemMap = new Map(problems.map(p => [p.problemId, p]))

  const upserts = answers
    .filter((a: { problemId: string }) => problemMap.has(a.problemId))
    .map(async (a: { problemId: string; answer: string; processNote?: string }) => {
      const problemRecord = await prisma.problem.findUnique({ where: { id: a.problemId }, select: { answer: true } })
      const isCorrect = problemRecord?.answer === a.answer

      return prisma.submission.upsert({
        where: {
          examId_problemId_studentName: {
            examId: exam.id,
            problemId: a.problemId,
            studentName,
          },
        },
        create: {
          examId: exam.id,
          problemId: a.problemId,
          studentName,
          answer: a.answer,
          processNote: a.processNote ?? null,
          isCorrect,
          gradedAt: new Date(),
          enteredBy: 'STUDENT',
        },
        update: {
          answer: a.answer,
          processNote: a.processNote ?? null,
          isCorrect,
          gradedAt: new Date(),
        },
      })
    })

  await Promise.all(upserts)
  return NextResponse.json({ ok: true })
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npx vitest run tests/api/exam-public.test.ts
```
Expected: PASS

- [ ] **Step 5: Create public exam page**

```tsx
// src/app/exam/page.tsx
'use client'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

interface Problem { problem: { id: string; title: string; content: string }; order: number }
interface ExamData { id: string; title: string; problems: Problem[] }
interface Answer { answer: string; processNote: string }

export default function ExamPage() {
  const [code, setCode] = useState('')
  const [studentName, setStudentName] = useState('')
  const [exam, setExam] = useState<ExamData | null>(null)
  const [answers, setAnswers] = useState<Record<string, Answer>>({})
  const [error, setError] = useState('')
  const [submitted, setSubmitted] = useState(false)
  const [step, setStep] = useState<'entry' | 'exam'>('entry')

  async function enterExam(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const res = await fetch(`/api/exam/${code.toUpperCase()}`)
    if (!res.ok) {
      const data = await res.json()
      setError(data.error)
      return
    }
    const data = await res.json()
    setExam(data)
    const init: Record<string, Answer> = {}
    data.problems.forEach((ep: Problem) => { init[ep.problem.id] = { answer: '', processNote: '' } })
    setAnswers(init)
    setStep('exam')
  }

  async function submitExam() {
    const payload = Object.entries(answers).map(([problemId, a]) => ({
      problemId,
      answer: a.answer,
      processNote: a.processNote || undefined,
    }))
    await fetch(`/api/exam/${code.toUpperCase()}/submit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ studentName, answers: payload }),
    })
    setSubmitted(true)
  }

  if (submitted) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="w-full max-w-md text-center">
          <CardContent className="py-12">
            <p className="text-2xl font-bold mb-2">제출 완료!</p>
            <p className="text-gray-500">답안이 성공적으로 제출되었습니다.</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (step === 'entry') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <Card className="w-full max-w-md">
          <CardHeader><CardTitle>시험 입장</CardTitle></CardHeader>
          <CardContent>
            <form onSubmit={enterExam} className="space-y-4">
              <div>
                <Label>시험 코드</Label>
                <Input value={code} onChange={e => setCode(e.target.value.toUpperCase())} placeholder="KR3F9A" maxLength={6} required />
              </div>
              <div>
                <Label>이름</Label>
                <Input value={studentName} onChange={e => setStudentName(e.target.value)} placeholder="홍길동" required />
              </div>
              {error && <p className="text-sm text-red-500">{error}</p>}
              <Button type="submit" className="w-full">입장하기</Button>
            </form>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-2">{exam?.title}</h1>
      <p className="text-sm text-gray-500 mb-6">{studentName}</p>
      <div className="space-y-6">
        {exam?.problems.map(ep => (
          <Card key={ep.problem.id}>
            <CardHeader>
              <CardTitle className="text-base">{ep.order}. {ep.problem.title}</CardTitle>
            </CardHeader>
            <CardContent>
              {ep.problem.content && (
                <p className="text-sm text-gray-600 whitespace-pre-wrap mb-4 bg-gray-50 p-3 rounded">{ep.problem.content}</p>
              )}
              <div className="space-y-3">
                <div>
                  <Label>답</Label>
                  <Input
                    value={answers[ep.problem.id]?.answer ?? ''}
                    onChange={e => setAnswers(prev => ({ ...prev, [ep.problem.id]: { ...prev[ep.problem.id], answer: e.target.value } }))}
                    placeholder="답을 입력하세요"
                  />
                </div>
                <div>
                  <Label>풀이 과정 (선택)</Label>
                  <Textarea
                    value={answers[ep.problem.id]?.processNote ?? ''}
                    onChange={e => setAnswers(prev => ({ ...prev, [ep.problem.id]: { ...prev[ep.problem.id], processNote: e.target.value } }))}
                    placeholder="풀이 과정을 적어주세요"
                    rows={3}
                  />
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
      <Button className="mt-6 w-full" onClick={submitExam}>제출하기</Button>
    </div>
  )
}
```

- [ ] **Step 6: Commit**

```bash
git add src/app/api/exam src/app/exam tests/api/
git commit -m "feat: public student exam submission via exam code"
```

---

### Task 11: Analysis Engine (lib/analysis.ts)

**Files:**
- Create: `src/lib/analysis.ts`
- Create: `tests/lib/analysis.test.ts`

- [ ] **Step 1: Write failing tests for analysis logic**

```typescript
// tests/lib/analysis.test.ts
import { describe, it, expect } from 'vitest'
import { aggregateByType, detectGuessing } from '@/lib/analysis'

const submissions = [
  { problemTypeName: '독서 - 인문', isCorrect: true,  processNote: null,    answer: '1' },
  { problemTypeName: '독서 - 인문', isCorrect: false, processNote: '분석함', answer: '2' },
  { problemTypeName: '문학 - 현대시', isCorrect: true, processNote: '',     answer: '3' },
  { problemTypeName: '문학 - 현대시', isCorrect: true, processNote: '시 분석 완료', answer: '4' },
]

describe('aggregateByType', () => {
  it('counts total and correct per type', () => {
    const result = aggregateByType(submissions)
    expect(result['독서 - 인문'].total).toBe(2)
    expect(result['독서 - 인문'].correct).toBe(1)
    expect(result['문학 - 현대시'].total).toBe(2)
    expect(result['문학 - 현대시'].correct).toBe(2)
  })

  it('flags guessing when correct with no/short processNote', () => {
    const result = aggregateByType(submissions)
    expect(result['독서 - 인문'].possibleGuessing).toBe(1) // correct + null processNote
    expect(result['문학 - 현대시'].possibleGuessing).toBe(1) // correct + empty processNote
  })

  it('flags concept weakness when incorrect with substantial processNote', () => {
    const result = aggregateByType(submissions)
    expect(result['독서 - 인문'].conceptWeakness).toBe(1) // incorrect + '분석함'(3 chars — below 10)
  })
})

describe('detectGuessing', () => {
  it('returns true when correct and processNote is null', () => {
    expect(detectGuessing(true, null)).toBe(true)
  })

  it('returns true when correct and processNote is shorter than 10 chars', () => {
    expect(detectGuessing(true, '짧음')).toBe(true)
  })

  it('returns false when correct and processNote is 10+ chars', () => {
    expect(detectGuessing(true, '충분한 풀이과정입니다')).toBe(false)
  })

  it('returns false when incorrect', () => {
    expect(detectGuessing(false, null)).toBe(false)
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
npx vitest run tests/lib/analysis.test.ts
```
Expected: FAIL — module not found

- [ ] **Step 3: Implement analysis.ts**

```typescript
// src/lib/analysis.ts
import OpenAI from 'openai'
import { prisma } from './prisma'

export interface SubmissionData {
  problemTypeName: string
  answer: string
  processNote: string | null
  isCorrect: boolean
}

export interface TypeStat {
  total: number
  correct: number
  possibleGuessing: number
  conceptWeakness: number
}

export function detectGuessing(isCorrect: boolean, processNote: string | null): boolean {
  if (!isCorrect) return false
  return !processNote || processNote.trim().length < 10
}

export function aggregateByType(submissions: SubmissionData[]): Record<string, TypeStat> {
  const stats: Record<string, TypeStat> = {}

  for (const s of submissions) {
    if (!stats[s.problemTypeName]) {
      stats[s.problemTypeName] = { total: 0, correct: 0, possibleGuessing: 0, conceptWeakness: 0 }
    }
    const stat = stats[s.problemTypeName]
    stat.total++
    if (s.isCorrect) {
      stat.correct++
      if (detectGuessing(s.isCorrect, s.processNote)) {
        stat.possibleGuessing++
      }
    } else {
      if (s.processNote && s.processNote.trim().length >= 10) {
        stat.conceptWeakness++
      }
    }
  }
  return stats
}

function buildPrompt(studentName: string, examTitle: string, submissions: SubmissionData[], typeStats: Record<string, TypeStat>): string {
  const problemList = submissions
    .map((s, i) => {
      const status = s.isCorrect ? '정답' : '오답'
      const guess = detectGuessing(s.isCorrect, s.processNote) ? ' (찍기 가능성)' : ''
      const process = s.processNote ? `\n   풀이: ${s.processNote}` : ''
      return `  - 문제${i + 1} (${s.problemTypeName}): ${status}${guess}${process}`
    })
    .join('\n')

  const typeList = Object.entries(typeStats)
    .map(([type, stat]) => `  - ${type}: ${stat.correct}/${stat.total} 정답 (찍기의심 ${stat.possibleGuessing}개, 개념취약 ${stat.conceptWeakness}개)`)
    .join('\n')

  return `다음은 학원 강사를 위한 학생 답안 분석 요청입니다.

[학생 정보]
이름: ${studentName}
시험: ${examTitle}

[유형별 통계]
${typeList}

[문제별 답안]
${problemList}

위 데이터를 기반으로 다음 4가지를 분석해 JSON으로 응답해주세요:

{
  "weakTypeAnalysis": "유형별 약점 요약 (어느 유형이 취약하고 왜인지)",
  "solvingMethodDiagnosis": "풀이 방식 진단 (찍기 vs 이해 기반 분류, 각 근거)",
  "weaknessCauses": "약점 원인 분류 (개념 미숙지 / 계산 실수 / 문제 해석 실패 - 각 해당 문제 유형)",
  "studyRecommendations": ["학습 방향 제안 1", "학습 방향 제안 2", "학습 방향 제안 3"],
  "teacherReport": "강사용 상세 분석 레포트 (위 4가지 전체 포함, 수치 데이터 포함)",
  "parentReport": "학부모용 요약 (3-4문장, 전문용어 없이, 긍정적 어조)"
}`
}

export async function generateAnalysis(analysisId: string): Promise<void> {
  const analysis = await prisma.analysis.findUnique({
    where: { id: analysisId },
    include: {
      exam: {
        include: {
          problems: {
            include: { problem: { include: { type: true } } },
          },
        },
      },
    },
  })
  if (!analysis) throw new Error('Analysis not found')

  await prisma.analysis.update({
    where: { id: analysisId },
    data: { status: 'GENERATING' },
  })

  try {
    const submissions = await prisma.submission.findMany({
      where: { examId: analysis.examId, studentName: analysis.studentName },
      include: { problem: { include: { type: true } } },
    })

    const submissionData: SubmissionData[] = submissions.map(s => ({
      problemTypeName: s.problem.type.name,
      answer: s.answer,
      processNote: s.processNote,
      isCorrect: s.isCorrect ?? false,
    }))

    const typeStats = aggregateByType(submissionData)

    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
    const completion = await client.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: '당신은 한국 학원 강사를 돕는 학생 성적 분석 전문가입니다. JSON 형식으로만 응답하세요.',
        },
        {
          role: 'user',
          content: buildPrompt(analysis.studentName, analysis.exam.title, submissionData, typeStats),
        },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.3,
    })

    const result = JSON.parse(completion.choices[0].message.content ?? '{}')

    await prisma.analysis.update({
      where: { id: analysisId },
      data: {
        status: 'DONE',
        weakTypes: typeStats,
        aiReport: {
          teacherReport: result.teacherReport,
          parentReport: result.parentReport,
          weakTypeAnalysis: result.weakTypeAnalysis,
          solvingMethodDiagnosis: result.solvingMethodDiagnosis,
          weaknessCauses: result.weaknessCauses,
          studyRecommendations: result.studyRecommendations,
        },
      },
    })
  } catch (err) {
    await prisma.analysis.update({
      where: { id: analysisId },
      data: { status: 'FAILED' },
    })
    throw err
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
npx vitest run tests/lib/analysis.test.ts
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/lib/analysis.ts tests/lib/analysis.test.ts
git commit -m "feat: analysis engine with type aggregation, guessing detection, GPT-4o prompt"
```

---

### Task 12: Analysis API + Polling

**Files:**
- Create: `src/app/api/analysis/[examId]/[studentName]/route.ts`
- Create: `src/app/api/analysis/[examId]/[studentName]/generate/route.ts`

- [ ] **Step 1: Create analysis status API**

```typescript
// src/app/api/analysis/[examId]/[studentName]/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET(
  _req: Request,
  { params }: { params: { examId: string; studentName: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const analysis = await prisma.analysis.findUnique({
    where: {
      examId_studentName: {
        examId: params.examId,
        studentName: decodeURIComponent(params.studentName),
      },
    },
  })

  if (!analysis) {
    return NextResponse.json({ status: 'NONE' })
  }
  return NextResponse.json(analysis)
}
```

- [ ] **Step 2: Create analysis generate API**

```typescript
// src/app/api/analysis/[examId]/[studentName]/generate/route.ts
import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { generateAnalysis } from '@/lib/analysis'

export async function POST(
  _req: Request,
  { params }: { params: { examId: string; studentName: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const studentName = decodeURIComponent(params.studentName)

  // Verify exam belongs to this teacher
  const exam = await prisma.exam.findUnique({
    where: { id: params.examId, teacherId: session.user.id },
  })
  if (!exam) return NextResponse.json({ error: 'Not found' }, { status: 404 })

  // Upsert analysis record in PENDING state
  const analysis = await prisma.analysis.upsert({
    where: { examId_studentName: { examId: params.examId, studentName } },
    create: { examId: params.examId, studentName, status: 'PENDING' },
    update: { status: 'PENDING' },
  })

  // Fire async — do not await. Returns immediately while GPT-4o runs.
  generateAnalysis(analysis.id).catch(console.error)

  return NextResponse.json({ id: analysis.id, status: 'PENDING' }, { status: 202 })
}
```

- [ ] **Step 3: Commit**

```bash
git add src/app/api/analysis
git commit -m "feat: analysis API with async trigger and status polling"
```

---

### Task 13: Reports Page + Recharts Dashboard

**Files:**
- Create: `src/components/AnalysisReport.tsx`
- Create: `src/components/PerformanceChart.tsx`
- Create: `src/app/(dashboard)/exams/[id]/analysis/[studentName]/page.tsx`
- Create: `src/app/(dashboard)/dashboard/page.tsx`

- [ ] **Step 1: Create PerformanceChart component**

```tsx
// src/components/PerformanceChart.tsx
'use client'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts'

interface TypeStat {
  total: number
  correct: number
  possibleGuessing: number
  conceptWeakness: number
}

interface Props {
  weakTypes: Record<string, TypeStat>
}

export function PerformanceChart({ weakTypes }: Props) {
  const data = Object.entries(weakTypes).map(([type, stat]) => ({
    name: type.length > 8 ? type.slice(0, 8) + '…' : type,
    fullName: type,
    correctRate: stat.total > 0 ? Math.round((stat.correct / stat.total) * 100) : 0,
    total: stat.total,
  }))

  return (
    <div className="w-full h-64">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 5, right: 10, left: -10, bottom: 40 }}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="name" angle={-30} textAnchor="end" interval={0} tick={{ fontSize: 11 }} />
          <YAxis domain={[0, 100]} tickFormatter={v => `${v}%`} tick={{ fontSize: 11 }} />
          <Tooltip
            formatter={(value, _name, props) => [`${value}%`, props.payload.fullName]}
            labelFormatter={() => ''}
          />
          <Bar dataKey="correctRate" name="정답률" radius={[4, 4, 0, 0]}>
            {data.map((entry, idx) => (
              <Cell
                key={idx}
                fill={entry.correctRate >= 70 ? '#22c55e' : entry.correctRate >= 40 ? '#f59e0b' : '#ef4444'}
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
```

- [ ] **Step 2: Create AnalysisReport component**

```tsx
// src/components/AnalysisReport.tsx
'use client'
import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { PerformanceChart } from './PerformanceChart'

interface TypeStat { total: number; correct: number; possibleGuessing: number; conceptWeakness: number }
interface AiReport {
  teacherReport: string
  parentReport: string
  weakTypeAnalysis: string
  solvingMethodDiagnosis: string
  weaknessCauses: string
  studyRecommendations: string[]
}
interface Analysis {
  id: string
  status: 'NONE' | 'PENDING' | 'GENERATING' | 'DONE' | 'FAILED'
  weakTypes: Record<string, TypeStat> | null
  aiReport: AiReport | null
}

interface Props {
  examId: string
  studentName: string
}

export function AnalysisReport({ examId, studentName }: Props) {
  const [analysis, setAnalysis] = useState<Analysis | null>(null)
  const [polling, setPolling] = useState(false)

  async function fetchStatus() {
    const res = await fetch(`/api/analysis/${examId}/${encodeURIComponent(studentName)}`)
    const data = await res.json()
    setAnalysis(data)
    return data
  }

  useEffect(() => { fetchStatus() }, [])

  useEffect(() => {
    if (!polling) return
    const interval = setInterval(async () => {
      const data = await fetchStatus()
      if (data.status === 'DONE' || data.status === 'FAILED') {
        setPolling(false)
        clearInterval(interval)
      }
    }, 2000)
    return () => clearInterval(interval)
  }, [polling])

  async function triggerAnalysis() {
    await fetch(`/api/analysis/${examId}/${encodeURIComponent(studentName)}/generate`, {
      method: 'POST',
    })
    setPolling(true)
    fetchStatus()
  }

  if (!analysis) return <p className="text-gray-500">로딩 중...</p>

  if (analysis.status === 'NONE') {
    return (
      <div className="text-center py-8">
        <p className="text-gray-500 mb-4">아직 분석이 생성되지 않았습니다.</p>
        <Button onClick={triggerAnalysis}>AI 분석 생성</Button>
      </div>
    )
  }

  if (analysis.status === 'PENDING' || analysis.status === 'GENERATING') {
    return (
      <div className="text-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto mb-4" />
        <p className="text-gray-500">AI가 분석 중입니다... (약 30초 소요)</p>
      </div>
    )
  }

  if (analysis.status === 'FAILED') {
    return (
      <div className="text-center py-8">
        <p className="text-red-500 mb-4">분석 생성에 실패했습니다.</p>
        <Button onClick={triggerAnalysis}>다시 시도</Button>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {analysis.weakTypes && (
        <Card>
          <CardHeader><CardTitle>유형별 정답률</CardTitle></CardHeader>
          <CardContent>
            <PerformanceChart weakTypes={analysis.weakTypes} />
          </CardContent>
        </Card>
      )}
      {analysis.aiReport && (
        <Tabs defaultValue="teacher">
          <TabsList>
            <TabsTrigger value="teacher">강사용 레포트</TabsTrigger>
            <TabsTrigger value="parent">학부모용 레포트</TabsTrigger>
          </TabsList>
          <TabsContent value="teacher">
            <Card>
              <CardContent className="pt-6 space-y-4">
                <div>
                  <Badge className="mb-2">유형별 약점</Badge>
                  <p className="text-sm whitespace-pre-wrap">{analysis.aiReport.weakTypeAnalysis}</p>
                </div>
                <div>
                  <Badge className="mb-2">풀이 방식 진단</Badge>
                  <p className="text-sm whitespace-pre-wrap">{analysis.aiReport.solvingMethodDiagnosis}</p>
                </div>
                <div>
                  <Badge className="mb-2">약점 원인</Badge>
                  <p className="text-sm whitespace-pre-wrap">{analysis.aiReport.weaknessCauses}</p>
                </div>
                <div>
                  <Badge className="mb-2">학습 방향</Badge>
                  <ul className="text-sm space-y-1 list-disc list-inside">
                    {analysis.aiReport.studyRecommendations.map((r, i) => (
                      <li key={i}>{r}</li>
                    ))}
                  </ul>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
          <TabsContent value="parent">
            <Card>
              <CardContent className="pt-6">
                <p className="text-base leading-relaxed">{analysis.aiReport.parentReport}</p>
                <Button className="mt-4" variant="outline" onClick={() => navigator.clipboard.writeText(analysis.aiReport!.parentReport)}>
                  복사하기
                </Button>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Create analysis page**

```tsx
// src/app/(dashboard)/exams/[id]/analysis/[studentName]/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { AnalysisReport } from '@/components/AnalysisReport'
import Link from 'next/link'

export default async function AnalysisPage({
  params,
}: {
  params: { id: string; studentName: string }
}) {
  await getServerSession(authOptions)
  const studentName = decodeURIComponent(params.studentName)

  return (
    <div className="max-w-2xl">
      <div className="flex items-center gap-2 mb-6">
        <Link href={`/exams/${params.id}`} className="text-sm text-gray-500 hover:text-gray-700">← 시험으로</Link>
        <h1 className="text-2xl font-bold">{studentName} 분석 레포트</h1>
      </div>
      <AnalysisReport examId={params.id} studentName={studentName} />
    </div>
  )
}
```

- [ ] **Step 4: Create dashboard page**

```tsx
// src/app/(dashboard)/dashboard/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import Link from 'next/link'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

export default async function DashboardPage() {
  const session = await getServerSession(authOptions)

  const [examCount, studentCount, recentAnalyses] = await Promise.all([
    prisma.exam.count({ where: { teacherId: session!.user.id } }),
    prisma.registeredStudent.count({ where: { teacherId: session!.user.id } }),
    prisma.analysis.findMany({
      where: { exam: { teacherId: session!.user.id }, status: 'DONE' },
      include: { exam: { select: { id: true, title: true } } },
      orderBy: { updatedAt: 'desc' },
      take: 10,
    }),
  ])

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">대시보드</h1>
      <div className="grid grid-cols-2 gap-4 mb-8">
        <Card>
          <CardHeader><CardTitle className="text-sm text-gray-500">전체 시험</CardTitle></CardHeader>
          <CardContent><p className="text-3xl font-bold">{examCount}</p></CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle className="text-sm text-gray-500">등록 학생</CardTitle></CardHeader>
          <CardContent><p className="text-3xl font-bold">{studentCount}</p></CardContent>
        </Card>
      </div>
      <h2 className="text-lg font-semibold mb-3">최근 분석 레포트</h2>
      <div className="space-y-2">
        {recentAnalyses.map(a => (
          <Link key={a.id} href={`/exams/${a.exam.id}/analysis/${encodeURIComponent(a.studentName)}`}>
            <div className="bg-white border rounded-lg p-3 flex justify-between items-center hover:border-blue-400 transition-colors">
              <div>
                <p className="font-medium text-sm">{a.studentName}</p>
                <p className="text-xs text-gray-500">{a.exam.title}</p>
              </div>
              <Badge variant="outline" className="text-green-600">완료</Badge>
            </div>
          </Link>
        ))}
        {recentAnalyses.length === 0 && (
          <p className="text-gray-500 text-sm">아직 생성된 분석 레포트가 없습니다.</p>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 5: Update exam detail page results tab to link to analysis**

Modify `src/app/(dashboard)/exams/[id]/page.tsx` — replace the results tab content:

```tsx
// Replace the TabsContent value="results" section in exams/[id]/page.tsx
import { AnalysisLinks } from '@/components/AnalysisLinks'
```

Add this component:

```tsx
// src/components/AnalysisLinks.tsx
'use client'
import Link from 'next/link'
import { Button } from '@/components/ui/button'

interface Props {
  examId: string
  students: { id: string; name: string }[]
}

export function AnalysisLinks({ examId, students }: Props) {
  return (
    <div className="space-y-2">
      {students.map(s => (
        <div key={s.id} className="flex justify-between items-center bg-white border rounded-lg px-4 py-2">
          <span className="text-sm">{s.name}</span>
          <Link href={`/exams/${examId}/analysis/${encodeURIComponent(s.name)}`}>
            <Button size="sm" variant="outline">분석 레포트</Button>
          </Link>
        </div>
      ))}
    </div>
  )
}
```

Then update the results tab in exams/[id]/page.tsx:

```tsx
<TabsContent value="results" className="mt-4">
  <AnalysisLinks examId={exam.id} students={students} />
</TabsContent>
```

- [ ] **Step 6: Run full test suite**

```bash
npx vitest run
```
Expected: All tests PASS

- [ ] **Step 7: Final commit**

```bash
git add src/components/AnalysisReport.tsx src/components/PerformanceChart.tsx src/components/AnalysisLinks.tsx src/app/(dashboard)/exams/[id]/analysis src/app/(dashboard)/dashboard
git commit -m "feat: AI analysis report + Recharts performance chart + dashboard"
```

---

## Self-Review

### Spec coverage check

| Spec requirement | Task |
|---|---|
| 교사 회원가입 + 기본 국어 유형 자동 생성 | Task 2, 4 |
| TypeGroup 추가/수정/삭제 | Task 5 |
| 문제 생성 (manual) | Task 6 |
| 시험 생성 + 6자리 코드 | Task 8 |
| 교사 직접 답안 입력 (O/X 토글, Tab 이동) | Task 9 |
| 학생 웹 제출 (/exam 공개 페이지) | Task 10 |
| isPaid 제한 (학생 5명, 시험 3개) | Task 7, 8 |
| AI 분석 4가지 항목 + 교사/학부모 레포트 | Task 11, 12, 13 |
| 유형별 정답률 차트 (Recharts) | Task 13 |
| 분석 상태 폴링 (PENDING→DONE) | Task 12, 13 |
| 미들웨어 라우팅 (/exam 공개, /dashboard 인증) | Task 3 |

### Type consistency check

- `SubmissionData` defined in Task 11, used in Task 11 tests — consistent
- `TypeStat` defined in Task 11, used in Task 13 `PerformanceChart` — consistent
- `ExamAnswerInput` props use `problems` array from Prisma include — consistent with Task 9 API
- `generateAnalysis(analysisId)` takes string, called in Task 12 with `analysis.id` — consistent

### No placeholders found. All tasks have complete code.
