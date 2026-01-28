import nodemailer from 'nodemailer'
import { NextResponse } from 'next/server'

type VendorPayload = {
  Name: string
  email: string
  phone: string
  category: string
}

export async function POST(request: Request) {
  try {
    const { Name, email, phone, category } = (await request.json()) as Partial<VendorPayload>

    if (!Name || !email || !phone || !category) {
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
      subject: `New Vendor Registration - ${Name}`,
      html: `
        <h2>Vendor Registration</h2>
        <p><strong>Name:</strong> ${Name}</p>
        <p><strong>Email:</strong> ${email}</p>
        <p><strong>Phone:</strong> ${phone}</p>
        <p><strong>Category:</strong> ${category}</p>
      `,
    })

    await transporter.sendMail({
      from: `"Saral Events" <${gmailUser}>`,
      to: email,
      subject: 'Welcome to Saral Events!',
      html: `
        <h2>Hi ${Name},</h2>
        <p>Thanks for registering as a vendor on <strong>Saral Events</strong>.</p>
        <p>Details received:</p>
        <ul>
          <li><strong>Email:</strong> ${email}</li>
          <li><strong>Phone:</strong> ${phone}</li>
          <li><strong>Category:</strong> ${category}</li>
        </ul>
        <p>Our team will contact you within 24 hours.</p>
      `,
    })

    return NextResponse.json({ message: 'Registration successful. Emails sent!' }, { status: 200 })
  } catch (error) {
    console.error('Vendor Email Error:', error)
    return NextResponse.json({ error: 'Something went wrong' }, { status: 500 })
  }
}

