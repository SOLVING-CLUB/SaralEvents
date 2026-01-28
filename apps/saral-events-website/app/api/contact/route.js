// app/api/contact/route.js
import nodemailer from 'nodemailer';
import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    const { name, email, phone, message } = await request.json();

    if (!name || !email || !phone || !message) {
      return NextResponse.json({ error: 'All fields are required' }, { status: 400 });
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_PASS,
      },
    });

    const ownerMail = {
      from: `"Saral Events" <${process.env.GMAIL_USER}>`,
      to: process.env.GMAIL_USER,
      subject: `New Contact - ${name}`,
      html: `
        <h2>Contact Submission</h2>
        <p><strong>Name:</strong> ${name}</p>
        <p><strong>Email:</strong> ${email}</p>
        <p><strong>Phone:</strong> ${phone}</p>
        <p><strong>Message:</strong> ${message}</p>
      `,
    };

    const senderMail = {
      from: `"Saral Events" <${process.env.GMAIL_USER}>`,
      to: email,
      subject: `Thanks for contacting Saral Events!`,
      html: `
        <p>Hi ${name},</p>
        <p>Thank you for reaching out to <strong>Saral Events</strong>. We received your message:</p>
        <blockquote>${message}</blockquote>
        <p>We’ll get back to you shortly.</p>
        <p>📞 +91 7815865959</p>
        <p>✨ Plan Less, Celebrate More!</p>
      `,
    };

    await transporter.sendMail(ownerMail);
    await transporter.sendMail(senderMail);

    return NextResponse.json({ message: 'Emails sent successfully!' }, { status: 200 });
  } catch (error) {
    console.error('Contact Error:', error);
    return NextResponse.json({ error: 'Something went wrong' }, { status: 500 });
  }
}
