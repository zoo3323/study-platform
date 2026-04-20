import { defineConfig } from '@prisma/config'
import * as path from 'path'
import * as fs from 'fs'

// Manually load .env since @prisma/config env() doesn't auto-load .env files
function loadEnvFile() {
  const envPath = path.resolve(process.cwd(), '.env')
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, 'utf-8')
    for (const line of content.split('\n')) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith('#')) continue
      const eqIdx = trimmed.indexOf('=')
      if (eqIdx === -1) continue
      const key = trimmed.slice(0, eqIdx).trim()
      const val = trimmed
        .slice(eqIdx + 1)
        .trim()
        .replace(/^["']|["']$/g, '')
      if (!process.env[key]) {
        process.env[key] = val
      }
    }
  }
}

loadEnvFile()

// For migrations, use the direct connection URL (port 5432, not the pooler at 6543)
// The pooler (PgBouncer) does not support the DDL statements needed for shadow DB creation
export default defineConfig({
  datasource: {
    url: process.env.DIRECT_URL!,
  },
})
