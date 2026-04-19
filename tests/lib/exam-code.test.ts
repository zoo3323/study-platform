import { describe, it, expect } from 'vitest'
import { generateExamCode } from '@/lib/exam-code'

describe('generateExamCode', () => {
  it('6자리 대문자 영숫자를 반환한다', () => {
    const code = generateExamCode()
    expect(code).toMatch(/^[A-Z0-9]{6}$/)
  })

  it('반복 호출 시 다른 코드를 생성한다', () => {
    const codes = new Set(Array.from({ length: 20 }, generateExamCode))
    expect(codes.size).toBeGreaterThan(1)
  })
})
