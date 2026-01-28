// app/api/vendor-registration/route.js
import nodemailer from 'nodemailer';
import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    const { Name, email, phone, category } = await request.json();

    if (!Name || !email || !phone || !category) {
      return NextResponse.json({ error: 'All fields are required' }, { status: 400 });
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_PASS,
      },
    });

    const ownerEmail = {
      from: `"Saral Events" <${process.env.GMAIL_USER}>`,
      to: process.env.GMAIL_USER,
      subject: `New Vendor Registration - ${Name}`,
      html: `
        <h2>Vendor Registration</h2>
        <p><strong>Name:</strong> ${Name}</p>
        <p><strong>Email:</strong> ${email}</p>
        <p><strong>Phone:</strong> ${phone}</p>
        <p><strong>Category:</strong> ${category}</p>
      `,
    };

    const vendorEmail = {
      from: `"Saral Events" <${process.env.GMAIL_USER}>`,
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
    };

    await transporter.sendMail(ownerEmail);
    await transporter.sendMail(vendorEmail);

    return NextResponse.json({ message: 'Registration successful. Emails sent!' }, { status: 200 });
  } catch (error) {
    console.error('Vendor Email Error:', error);
    return NextResponse.json({ error: 'Something went wrong' }, { status: 500 });
  }
}
