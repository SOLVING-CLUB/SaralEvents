import { NextResponse } from 'next/server'

export const dynamic = 'force-static'

export async function GET() {
  const packageName = process.env.NEXT_PUBLIC_ANDROID_PACKAGE || 'com.mycompany.saralevents'
  const sha256 = (process.env.NEXT_PUBLIC_ANDROID_SHA256 || '').split(',').map(s => s.trim()).filter(Boolean)
  const statements = [
    {
      relation: [
        'delegate_permission/common.handle_all_urls'
      ],
      target: {
        namespace: 'android_app',
        package_name: packageName,
        sha256_cert_fingerprints: sha256.length ? sha256 : ['YOUR_RELEASE_SHA256']
      }
    }
  ]
  return new NextResponse(JSON.stringify(statements), {
    headers: {
      'content-type': 'application/json',
      'cache-control': 'public, max-age=600',
    },
  })
}


