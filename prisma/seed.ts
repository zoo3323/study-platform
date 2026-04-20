import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export const defaultKoreanTypes = [
  { name: '독서 - 인문',      order: 1 },
  { name: '독서 - 사회',      order: 2 },
  { name: '독서 - 과학',      order: 3 },
  { name: '독서 - 기술',      order: 4 },
  { name: '독서 - 예술',      order: 5 },
  { name: '문학 - 현대시',    order: 6 },
  { name: '문학 - 고전시가',  order: 7 },
  { name: '문학 - 현대소설',  order: 8 },
  { name: '문학 - 고전소설',  order: 9 },
  { name: '문학 - 수필/극',   order: 10 },
  { name: '언어 - 문법',      order: 11 },
  { name: '매체 - 매체 자료', order: 12 },
  { name: '화법과 작문',      order: 13 },
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
