import nodemailer from 'nodemailer'
import { NextResponse } from 'next/server'

type ContactPayload = {
  name: string
  email: string
  phone: string
  message: string
}

export async function POST(request: Request) {
  try {
    const { name, email, phone, message } = (await request.json()) as Partial<ContactPayload>

    if (!name || !email || !phone || !message) {
      return NextResponse.json({ error: 'All fields are required' }, { status: 400 })
    }

    const gmailUser = process.env.GMAIL_USER
    const gmailPass = process.env.GMAIL_PASS
    if (!gmailUser || !gmailPass) {
      return NextResponse.json({ error: 'Server email is not configured' }, { status: 500 })
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: { user: gmailUser, pass: gmailPass },
    })

    await transporter.sendMail({
      from: `"Saral Events" <${gmailUser}>`,
      to: gmailUser,
      subject: `New Contact - ${name}`,
      html: `
        <h2>Contact Submission</h2>
        <p><strong>Name:</strong> ${name}</p>
        <p><strong>Email:</strong> ${email}</p>
        <p><strong>Phone:</strong> ${phone}</p>
        <p><strong>Message:</strong> ${message}</p>
      `,
    })

    await transporter.sendMail({
      from: `"Saral Events" <${gmailUser}>`,
      to: email,
      subject: 'Thanks for contacting Saral Events!',
      html: `
        <p>Hi ${name},</p>
        <p>Thank you for reaching out to <strong>Saral Events</strong>. We received your message:</p>
        <blockquote>${message}</blockquote>
        <p>We’ll get back to you shortly.</p>
        <p>📞 +91 7815865959</p>
        <p>✨ Plan Less, Celebrate More!</p>
      `,
    })

    return NextResponse.json({ message: 'Emails sent successfully!' }, { status: 200 })
  } catch (error) {
    console.error('Contact Error:', error)
    return NextResponse.json({ error: 'Something went wrong' }, { status: 500 })
  }
}

