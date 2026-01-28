export const createVendorWelcomeTemplate = (data: {
  Name: string
  email: string
  phone: string
  category: string
}) => {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1>Welcome to Saral Events!</h1>
      <p>Thank you for registering as a vendor.</p>
      <div>
        <h3>Your Details:</h3>
        <p><strong>Business:</strong> ${data.Name}</p>
        <p><strong>Email:</strong> ${data.email}</p>
        <p><strong>Phone:</strong> ${data.phone}</p>
        <p><strong>Category:</strong> ${data.category}</p>
      </div>
      <p>We'll contact you within 24 hours!</p>
    </div>
  `
}

export const createContactConfirmationTemplate = (data: {
  name: string
  email: string
  phone: string
  message: string
}) => {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1>Thank you for contacting us!</h1>
      <p>Dear ${data.name},</p>
      <p>We've received your message and will get back to you soon.</p>
      <div style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
        <p><strong>Your message:</strong></p>
        <p>${data.message}</p>
      </div>
      <p>Best regards,<br>Saral Events Team</p>
    </div>
  `
}
