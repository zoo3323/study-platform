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
      name: string | null
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
