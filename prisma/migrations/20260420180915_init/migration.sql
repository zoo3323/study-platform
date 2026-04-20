-- CreateEnum
CREATE TYPE "InputMethod" AS ENUM ('MANUAL', 'OCR');

-- CreateEnum
CREATE TYPE "EnteredBy" AS ENUM ('STUDENT', 'TEACHER');

-- CreateEnum
CREATE TYPE "AnalysisStatus" AS ENUM ('PENDING', 'GENERATING', 'DONE', 'FAILED');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "isPaid" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RegisteredStudent" (
    "id" TEXT NOT NULL,
    "teacherId" TEXT NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "RegisteredStudent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TypeGroup" (
    "id" TEXT NOT NULL,
    "teacherId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "TypeGroup_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProblemType" (
    "id" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "ProblemType_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Problem" (
    "id" TEXT NOT NULL,
    "teacherId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "answer" TEXT NOT NULL,
    "typeId" TEXT NOT NULL,
    "inputMethod" "InputMethod" NOT NULL DEFAULT 'MANUAL',
    "ocrOriginal" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Problem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Exam" (
    "id" TEXT NOT NULL,
    "teacherId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "code" TEXT NOT NULL,
    "isOpen" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Exam_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ExamProblem" (
    "examId" TEXT NOT NULL,
    "problemId" TEXT NOT NULL,
    "order" INTEGER NOT NULL,

    CONSTRAINT "ExamProblem_pkey" PRIMARY KEY ("examId","problemId")
);

-- CreateTable
CREATE TABLE "Submission" (
    "id" TEXT NOT NULL,
    "examId" TEXT NOT NULL,
    "problemId" TEXT NOT NULL,
    "studentName" TEXT NOT NULL,
    "answer" TEXT NOT NULL,
    "processNote" TEXT,
    "isCorrect" BOOLEAN,
    "gradedAt" TIMESTAMP(3),
    "enteredBy" "EnteredBy" NOT NULL DEFAULT 'STUDENT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Submission_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Analysis" (
    "id" TEXT NOT NULL,
    "examId" TEXT NOT NULL,
    "studentName" TEXT NOT NULL,
    "status" "AnalysisStatus" NOT NULL DEFAULT 'PENDING',
    "weakTypes" JSONB,
    "aiReport" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Analysis_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "RegisteredStudent_teacherId_name_key" ON "RegisteredStudent"("teacherId", "name");

-- CreateIndex
CREATE UNIQUE INDEX "Exam_code_key" ON "Exam"("code");

-- CreateIndex
CREATE INDEX "ExamProblem_examId_order_idx" ON "ExamProblem"("examId", "order");

-- CreateIndex
CREATE INDEX "Submission_examId_studentName_idx" ON "Submission"("examId", "studentName");

-- CreateIndex
CREATE UNIQUE INDEX "Submission_examId_problemId_studentName_key" ON "Submission"("examId", "problemId", "studentName");

-- CreateIndex
CREATE UNIQUE INDEX "Analysis_examId_studentName_key" ON "Analysis"("examId", "studentName");

-- AddForeignKey
ALTER TABLE "RegisteredStudent" ADD CONSTRAINT "RegisteredStudent_teacherId_fkey" FOREIGN KEY ("teacherId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TypeGroup" ADD CONSTRAINT "TypeGroup_teacherId_fkey" FOREIGN KEY ("teacherId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProblemType" ADD CONSTRAINT "ProblemType_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "TypeGroup"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Problem" ADD CONSTRAINT "Problem_teacherId_fkey" FOREIGN KEY ("teacherId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Problem" ADD CONSTRAINT "Problem_typeId_fkey" FOREIGN KEY ("typeId") REFERENCES "ProblemType"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Exam" ADD CONSTRAINT "Exam_teacherId_fkey" FOREIGN KEY ("teacherId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExamProblem" ADD CONSTRAINT "ExamProblem_examId_fkey" FOREIGN KEY ("examId") REFERENCES "Exam"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExamProblem" ADD CONSTRAINT "ExamProblem_problemId_fkey" FOREIGN KEY ("problemId") REFERENCES "Problem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Submission" ADD CONSTRAINT "Submission_examId_fkey" FOREIGN KEY ("examId") REFERENCES "Exam"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Submission" ADD CONSTRAINT "Submission_problemId_fkey" FOREIGN KEY ("problemId") REFERENCES "Problem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Analysis" ADD CONSTRAINT "Analysis_examId_fkey" FOREIGN KEY ("examId") REFERENCES "Exam"("id") ON DELETE CASCADE ON UPDATE CASCADE;
