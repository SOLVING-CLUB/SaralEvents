import { NextResponse } from 'next/server'

export const dynamic = 'force-static'

export async function GET() {
  const teamId = process.env.NEXT_PUBLIC_APPLE_TEAM_ID || 'YOUR_APPLE_TEAM_ID'
  const bundleId = process.env.NEXT_PUBLIC_IOS_BUNDLE_ID || 'com.mycompany.saralevents'
  const payload = {
    applinks: {
      apps: [] as string[],
      details: [
        {
          appID: `${teamId}.${bundleId}`,
          paths: [
            '/invite/*',
            '/invite/*?*',
            '/refer*',
            '/refer?*',
            '/service/*',
            '/service/*?*',
          ],
        },
      ],
    },
  }
  return new NextResponse(JSON.stringify(payload), {
    headers: {
      'content-type': 'application/json',
      // iOS requires no redirects and correct content-type at exact path
      'cache-control': 'public, max-age=600',
    },
  })
}


