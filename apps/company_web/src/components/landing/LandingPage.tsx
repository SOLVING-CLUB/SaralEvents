// @ts-nocheck
'use client'

import { useEffect, useState } from 'react'
import {
  ArrowRight,
  ChevronDown,
  ChevronUp,
  Clock,
  Download,
  Filter,
  Globe,
  Headphones,
  Mail,
  MapPin,
  Menu,
  MessageCircle,
  Phone,
  Send,
  Settings,
  Shield,
  Star,
  Store,
  TrendingUp,
  UserCheck,
  Users,
  X,
  Zap,
  Award,
  Camera,
  Music,
  Palette,
} from 'lucide-react'
import { useSearchParams } from 'next/navigation'
import QRCode from 'react-qr-code'
import { Pagination } from 'swiper/modules'
import { Swiper, SwiperSlide } from 'swiper/react'
import 'swiper/css'
import 'swiper/css/pagination'

import AppStoreButton from '@/components/landing/AppStoreButton'

const SafeComponent = ({ children }) => {
  try {
    return children
  } catch (error) {
    console.error('Component error:', error)
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Loading...</h2>
          <p className="text-gray-600">Please wait while we prepare your experience.</p>
        </div>
      </div>
    )
  }
}

export default function LandingPage() {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [selectedCategory, setSelectedCategory] = useState('All')
  const [showPopup, setShowPopup] = useState(false)
  const [isClient, setIsClient] = useState(false)
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isContactSubmitting, setIsContactSubmitting] = useState(false)
  const [submitMessage, setSubmitMessage] = useState('')
  const [contactMessage, setContactMessage] = useState('')
  const [activeSection, setActiveSection] = useState('')
  const [openFAQ, setOpenFAQ] = useState(null)
  const [hasAnimated, setHasAnimated] = useState(false)

  const searchParams = useSearchParams()

  useEffect(() => {
    if (searchParams.get('popup') === 'true') {
      setShowPopup(true)
    }
  }, [searchParams])

  useEffect(() => {
    const timer = setTimeout(() => {
      setShowPopup(true)
    }, 4000)
    return () => clearTimeout(timer)
  }, [])

  const images = [
    '/images/Pictures/amit-kumar-ShO949vJwAg-unsplash.jpg',
    '/images/Pictures/anuj-kumar-QF-qYrnGhnY-unsplash.jpg',
    '/images/Pictures/wedding-sofa.jpg',
    '/images/Pictures/photo5.jpg',
  ]

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % images.length)
    }, 3000)
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    try {
      setIsClient(true)
    } catch (error) {
      console.error('Client detection error:', error)
      setTimeout(() => setIsClient(true), 100)
    }
  }, [])

  const scrollToSection = (sectionId) => {
    if (!isClient) return
    const element = document.getElementById(sectionId)
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' })
      setIsMenuOpen(false)
    }
  }

  useEffect(() => {
    if (!isClient) return
    const handleScroll = () => {
      try {
        const sections = ['hero', 'features', 'categories', 'stats', 'faq', 'contact', 'vendor-registration']
        const scrollPosition = window.scrollY + 100

        for (const section of sections) {
          const element = document.getElementById(section)
          if (element) {
            const { offsetTop, offsetHeight } = element
            if (scrollPosition >= offsetTop && scrollPosition < offsetTop + offsetHeight) {
              setActiveSection(section)
              break
            }
          }
        }
      } catch (error) {
        console.error('Scroll handler error:', error)
      }
    }

    try {
      window.addEventListener('scroll', handleScroll)
      return () => window.removeEventListener('scroll', handleScroll)
    } catch (error) {
      console.error('Scroll listener error:', error)
    }
  }, [isClient])

  const handlePhoneCall = (number) => {
    if (!isClient) return
    window.location.href = `tel:${number}`
  }

  const handleEmail = (email) => {
    if (!isClient) return
    window.location.href = `mailto:${email}`
  }

  const handleAppDownload = (platform) => {
    if (!isClient) return
    if (platform === 'ios') {
      window.open('https://apps.apple.com/app/saral-events', '_blank')
    } else if (platform === 'android') {
      window.open('https://play.google.com/store/apps/details?id=com.saralevents.userapp&hl=en_IN', '_blank')
    }
  }

  const handleQRClick = () => setShowPopup(true)
  const closePopup = () => setShowPopup(false)

  const handleQRScan = () => {
    if (!isClient) return
    alert('QR Code scanned! Redirecting to app store...')
    handleAppDownload('android')
  }

  const [formData, setFormData] = useState({
    Name: '',
    email: '',
    phone: '',
    category: '',
  })
  const [contactForm, setContactForm] = useState({
    name: '',
    email: '',
    phone: '',
    message: '',
  })

  const handleInputChange = (e) => {
    const { name, value } = e.target
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  const handleContactInputChange = (e) => {
    const { name, value } = e.target
    setContactForm((prev) => ({ ...prev, [name]: value }))
  }

  const handleVendorSubmit = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)

    if (!formData.Name || !formData.email || !formData.phone || !formData.category) {
      setSubmitMessage('Please fill in all fields')
      setIsSubmitting(false)
      return
    }

    try {
      const response = await fetch('/api/vendor-registration', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      })
      const result = await response.json()
      if (response.ok) {
        setSubmitMessage("Registration successful! We'll contact you within 24 hours.")
        setFormData({ Name: '', email: '', phone: '', category: '' })
      } else {
        setSubmitMessage(result.error || 'Registration failed. Please try again.')
      }
    } catch (error) {
      setSubmitMessage('Registration failed. Please try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleContactSubmit = async (e) => {
    e.preventDefault()
    setIsContactSubmitting(true)

    if (!contactForm.name || !contactForm.email || !contactForm.phone || !contactForm.message) {
      setContactMessage('Please fill in all fields')
      setIsContactSubmitting(false)
      return
    }

    try {
      const response = await fetch('/api/contact', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(contactForm),
      })
      const result = await response.json()
      if (response.ok) {
        setContactMessage("Message sent successfully! We'll get back to you soon.")
        setContactForm({ name: '', email: '', phone: '', message: '' })
      } else {
        setContactMessage(result.error || 'Failed to send message. Please try again.')
      }
    } catch (error) {
      setContactMessage('Failed to send message. Please try again.')
    } finally {
      setIsContactSubmitting(false)
    }
  }

  const toggleFAQ = (index) => setOpenFAQ(openFAQ === index ? null : index)

  const uspList = [
    { color: 'bg-blue-600', icon: <Zap className="w-12 h-12" />, title: 'Instant Booking', desc: 'Book vendors instantly without hassle.' },
    { color: 'bg-purple-600', icon: <Shield className="w-12 h-12" />, title: 'Verified Vendors', desc: 'Work only with trusted and verified vendors.' },
    { color: 'bg-amber-500', icon: <MessageCircle className="w-12 h-12" />, title: 'Custom Invitations', desc: 'Create and send beautiful digital invites easily.' },
    { color: 'bg-green-600', icon: <Filter className="w-12 h-12" />, title: 'Budget Calculator', desc: 'Manage event budgets easily and smartly.' },
    { color: 'bg-rose-500', icon: <Camera className="w-12 h-12" />, title: 'Vendor Tracking', desc: 'Track vendor status in real-time after booking.' },
    { color: 'bg-cyan-600', icon: <Headphones className="w-12 h-12" />, title: '24/7 Support', desc: 'Get help whenever you need it, any time, any day.' },
  ]

  const features = [
    { icon: Zap, title: 'Budget Planner', description: 'Track all your event expenses effortlessly.', color: 'from-blue-400 to-blue-600' },
    { icon: Shield, title: 'Vendor Discovery', description: 'Find verified vendors with real ratings & reviews.', color: 'from-green-400 to-green-600' },
    { icon: MessageCircle, title: 'Digital Invites', description: 'Send beautiful, customizable invites in seconds.', color: 'from-pink-400 to-pink-600' },
    { icon: Filter, title: 'Checklist Manager', description: 'Stay organized with smart to-do lists.', color: 'from-purple-400 to-purple-600' },
    { icon: Camera, title: 'Real-time Updates', description: 'Get instant alerts and vendor confirmations.', color: 'from-red-400 to-red-600' },
    { icon: Users, title: 'Multiple Event Support', description: 'Manage multiple events without the mess.', color: 'from-teal-400 to-teal-600' },
  ]

  const categories = [
    { name: 'The Bliss Hall', description: 'Affordable event venue in your city', bgImage: '/images/Pictures/sevices.webp' },
    { name: 'SnapStudio', description: 'Professional wedding & event photographers', bgImage: '/images/Pictures/ailbhe-flynn-jkZs3Oi9pq0-unsplash.jpg' },
    { name: 'Tasty Bites', description: 'Catering service for all budgets', bgImage: '/images/Pictures/saile-ilyas-SiwrpBnxDww-unsplash.jpg' },
    { name: 'Bloom Decor', description: 'Elegant décor for weddings & parties', bgImage: '/images/Pictures/photo3.png' },
    { name: 'DJ Rhythm', description: 'High-energy DJ services for your celebration', bgImage: '/images/Pictures/images.jpeg' },
    { name: 'GlamByRia', description: 'Makeup artist for bridal & party looks', bgImage: '/images/Pictures/skg-photography-O2HNmD4W43E-unsplash.jpg' },
  ]

  const faqs = [
    { question: 'How do I start planning my event?', answer: 'Simply download our app, choose your event type, and follow the guided setup to get started.' },
    { question: 'Are the vendors verified?', answer: 'Yes! All vendors are verified and reviewed by real customers' },
    { question: 'Can I use Saral Events for free?', answer: 'Absolutely. The core features of the app are free to use for all customers.' },
    { question: 'I’m a vendor. How do I register?', answer: 'Scroll down to the vendor form and submit your details to join our network.' },
  ]

  const contactInfo = [
    { icon: Phone, title: 'Call Us', details: ['+91 7815865959'], action: handlePhoneCall, color: 'from-green-400 to-green-600' },
    { icon: Mail, title: 'Email Us', details: ['contactus@saralevents.com'], action: handleEmail, color: 'from-blue-400 to-blue-600' },
    { icon: MapPin, title: 'Visit Us', details: ['14-1-129/11/2 Ground Floor', 'Padmavathi Nagar, Hyderabad. Telangana-500018'], action: () => isClient && window.open('https://maps.google.com', '_blank'), color: 'from-red-400 to-red-600' },
    { icon: Clock, title: 'Business Hours', details: ['Mon-Fri: 9:00 AM - 8:00 PM', 'Sat-Sun: 10:00 AM - 6:00 PM'], action: null, color: 'from-purple-400 to-purple-600' },
  ]

  if (!isClient) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-yellow-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading Saral Events...</p>
        </div>
      </div>
    )
  }

  return (
    <SafeComponent>
      <div className="min-h-screen bg-white">
        {/* Navigation */}
        <nav className="bg-white/95 backdrop-blur-md shadow-lg sticky top-0 z-50 border-b border-yellow-100">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center h-24">
              <div className="flex items-center cursor-pointer" onClick={() => scrollToSection('hero')}>
                <div className="h-full flex items-center">
                  <img
                    src="/images/Copy%20of%20SARAL%20EVENTS%20LOGO/5-removebg-preview.png"
                    alt="Saral Events"
                    className="h-[150px] w-auto object-contain"
                  />
                </div>
              </div>

              <div className="hidden md:block">
                <div className="ml-10 flex items-baseline space-x-8">
                  {[
                    { id: 'hero', label: 'Home' },
                    { id: 'features', label: 'Features' },
                    { id: 'categories', label: 'Categories' },
                    { id: 'faq', label: 'FAQ' },
                    { id: 'contact', label: 'Contact' },
                  ].map((item) => (
                    <button
                      key={item.id}
                      onClick={() => scrollToSection(item.id)}
                      className={`px-3 py-2 text-base md:text-lg font-medium transition-all duration-300 ${
                        activeSection === item.id
                          ? 'text-yellow-600 border-b-2 border-yellow-600'
                          : 'text-gray-700 hover:text-yellow-600'
                      }`}
                    >
                      {item.label}
                    </button>
                  ))}

                  <button
                    onClick={() => scrollToSection('vendor-registration')}
                    className="bg-gradient-to-r from-yellow-500 to-orange-500 text-white px-5 py-2.5 rounded-full text-base md:text-lg font-semibold hover:from-yellow-600 hover:to-orange-600 transition-all duration-300 transform hover:scale-105"
                  >
                    For Vendors
                  </button>
                </div>
              </div>

              <div className="md:hidden">
                <button onClick={() => setIsMenuOpen(!isMenuOpen)} className="text-gray-700 hover:text-yellow-600">
                  {isMenuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
                </button>
              </div>
            </div>
          </div>

          {/* Mobile menu */}
          {isMenuOpen && (
            <div className="md:hidden">
              <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3 bg-white/95 backdrop-blur-md shadow-lg border-t border-yellow-100">
                {[
                  { id: 'hero', label: 'Home' },
                  { id: 'features', label: 'Features' },
                  { id: 'categories', label: 'Categories' },
                  { id: 'faq', label: 'FAQ' },
                  { id: 'contact', label: 'Contact' },
                  { id: 'vendor-registration', label: 'For Vendors' },
                ].map((item) => (
                  <button
                    key={item.id}
                    onClick={() => scrollToSection(item.id)}
                    className="text-gray-700 hover:text-yellow-600 block px-3 py-2 text-base font-medium w-full text-left"
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>
          )}
        </nav>

        {/* HERO */}
        <section id="hero" className="relative min-h-screen overflow-x-hidden">
          <div className="absolute inset-0 z-0 pointer-events-none">
            {images.map((url, index) => (
              <div
                key={index}
                className={`absolute inset-0 w-full h-full bg-black bg-cover bg-center transition-opacity duration-1000 will-change-opacity ${
                  index === currentIndex ? 'opacity-100' : 'opacity-0'
                }`}
                style={{ backgroundImage: `url(${url})` }}
              />
            ))}
          </div>
          <div className="absolute inset-0 bg-black/40 z-10" />

          <div className="relative z-20 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
            <div className="grid lg:grid-cols-2 gap-12 items-start">
              <div className="space-y-8">
                <div className="inline-flex items-center px-4 py-2 bg-white/70 backdrop-blur-sm rounded-full text-sm font-medium text-yellow-700 border border-yellow-200">
                  <Star className="w-4 h-4 mr-2 text-yellow-500" />
                  India's #1 Event Planning Platform
                </div>
                <h1 className="text-4xl md:text-6xl font-bold text-white leading-tight">
                  Plan <span className="bg-gradient-to-r from-yellow-400 to-orange-400 bg-clip-text text-transparent">Less</span>
                  <br />
                  Celebrate{' '}
                  <span className="bg-gradient-to-r from-yellow-400 to-orange-400 bg-clip-text text-transparent">More</span>
                </h1>
                <p className="text-xl text-white/90">
                  Book trusted vendors, manage budgets, guest lists, and celebrate stress-free.
                </p>

                <div className="flex flex-col sm:flex-row gap-4">
                  <button
                    onClick={() => handleAppDownload('android')}
                    className="group bg-gradient-to-r from-yellow-600 to-orange-600 text-white px-8 py-4 rounded-xl font-semibold hover:scale-105 transition-all flex items-center"
                  >
                    <Download className="mr-2 h-5 w-5 group-hover:animate-bounce" />
                    Download App
                  </button>
                  <button
                    onClick={() => scrollToSection('categories')}
                    className="group border-2 border-yellow-600 text-yellow-600 px-8 py-4 rounded-xl font-semibold hover:bg-yellow-600 hover:text-white transition-all flex items-center"
                  >
                    <ArrowRight className="mr-2 h-5 w-5" />
                    Explore Vendors
                  </button>
                </div>
              </div>

              <div className="flex justify-center px-4 sm:px-0">
                <div className="relative bg-white/20 backdrop-blur-lg p-6 rounded-3xl shadow-xl border border-white/30 w-full max-w-sm sm:max-w-md">
                  <div className="text-center mb-4">
                    <div
                      className="mx-auto mb-4 w-48 h-48 bg-white/80 rounded-2xl flex items-center justify-center transition-transform duration-300 hover:scale-105 shadow-md cursor-pointer"
                      onClick={handleQRClick}
                    >
                      <QRCode value="https://saralevents.com/?popup=true" size={160} fgColor="#000000" bgColor="#ffffff" className="rounded-lg" />
                    </div>

                    <p className="text-base font-semibold text-gray-800 tracking-wide">SCAN TO DOWNLOAD</p>
                    <div className="mt-3 flex justify-center">
                      <AppStoreButton
                        platform="android"
                        href="https://play.google.com/store/apps/details?id=com.saralevents.userapp&hl=en_IN"
                        tone="light"
                        className="shadow-md"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* USP */}
        <section className="py-16 bg-white">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <h2 className="text-3xl md:text-4xl font-bold text-center text-gray-900 mb-12">What makes us different?</h2>

            <div className="md:hidden">
              <Swiper
                modules={[Pagination]}
                slidesPerView={1}
                spaceBetween={20}
                pagination={{ clickable: true, el: '.custom-usp-pagination' }}
                className="pb-6"
              >
                {uspList.map((usp, idx) => (
                  <SwiperSlide key={idx}>
                    <div className={`${usp.color} rounded-2xl p-6 text-center text-white shadow-md min-h-[180px] transition-all duration-300 scale-[1.02]`}>
                      <div className="mb-3 flex justify-center">{usp.icon}</div>
                      <h3 className="text-lg font-semibold mb-1">{usp.title}</h3>
                      <p className="text-sm text-white/90">{usp.desc}</p>
                    </div>
                  </SwiperSlide>
                ))}
              </Swiper>
              <div className="custom-usp-pagination flex justify-center mt-4 space-x-2"></div>
            </div>

            <div className="hidden md:grid grid-cols-2 lg:grid-cols-3 gap-6">
              {uspList.map((usp, idx) => (
                <div
                  key={idx}
                  className={`${usp.color} rounded-2xl p-6 text-center text-white shadow-md min-h-[220px] transition-all duration-300 hover:scale-[1.05]`}
                >
                  <div className="mb-3 flex justify-center">{usp.icon}</div>
                  <h3 className="text-lg font-semibold mb-1">{usp.title}</h3>
                  <p className="text-sm text-white/90">{usp.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* FEATURES */}
        <section id="features" className="py-16 sm:py-20 bg-neutral-50 relative">
          <div className="absolute inset-0 bg-gradient-to-b from-gray-50/50 to-white"></div>
          <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-12 sm:mb-16">
              <div className="inline-flex items-center px-3 sm:px-4 py-1.5 sm:py-2 bg-yellow-100 rounded-full text-xs sm:text-sm font-medium text-yellow-700 mb-3 sm:mb-4">
                <Zap className="w-4 h-4 mr-2" />
                Everything You Need
              </div>

              <p className="text-xs sm:text-sm uppercase tracking-widest text-yellow-600 font-semibold mb-1 sm:mb-2">
                Comprehensive Event Planning Tools
              </p>

              <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold text-gray-900 mb-3 sm:mb-4">
                All-in-One Event Planning, Made Simple
              </h2>

              <p className="text-sm sm:text-lg text-gray-600 max-w-3xl mx-auto">
                Whether it's a wedding, birthday, or corporate event, Saral Events has everything you need in one app.
              </p>
            </div>

            <div className="md:hidden">
              <Swiper
                modules={[Pagination]}
                slidesPerView={1}
                spaceBetween={20}
                pagination={{ clickable: true, el: '.custom-swiper-pagination' }}
                className="pb-6"
              >
                {features.map((feature, index) => (
                  <SwiperSlide key={index}>
                    <div className="min-h-[220px] bg-gradient-to-br from-yellow-50/50 to-orange-50/50 p-6 rounded-2xl border border-yellow-100 shadow-2xl transition-all duration-500 flex flex-col items-center gap-5">
                      <div className={`w-[52px] h-[52px] bg-gradient-to-r ${feature.color} rounded-2xl flex items-center justify-center shadow-lg`}>
                        <feature.icon className="w-[26px] h-[26px] text-white" />
                      </div>
                      <div className="text-center">
                        <h3 className="text-base font-bold text-yellow-600 mb-1">{feature.title}</h3>
                        <p className="text-sm text-gray-700">{feature.description}</p>
                      </div>
                    </div>
                  </SwiperSlide>
                ))}
              </Swiper>
              <div className="custom-swiper-pagination flex justify-center mt-4 space-x-2"></div>
            </div>

            <div className="hidden md:grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {features.map((feature, index) => (
                <div
                  key={index}
                  className="bg-white p-6 rounded-2xl border border-gray-100 transition-all hover:bg-gradient-to-br hover:from-yellow-50/50 hover:to-orange-50/50 hover:border-yellow-200 hover:shadow-2xl hover:-translate-y-2 duration-500"
                >
                  <div className={`w-12 h-12 sm:w-16 sm:h-16 bg-gradient-to-r ${feature.color} rounded-2xl flex items-center justify-center shadow-lg mb-4`}>
                    <feature.icon className="h-6 w-6 sm:h-8 sm:w-8 text-white" />
                  </div>
                  <h3 className="text-base sm:text-lg font-bold text-gray-900 hover:text-yellow-600 mb-1 transition-colors">{feature.title}</h3>
                  <p className="text-sm text-gray-600">{feature.description}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* CATEGORIES */}
        <section id="categories" className="py-20 bg-gradient-to-br from-gray-50 to-gray-100 relative">
          <div className="absolute inset-0 bg-gradient-to-r from-yellow-50/30 to-orange-50/30"></div>
          <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-16">
              <div className="inline-flex items-center px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm font-medium text-yellow-700 mb-4 border border-yellow-200">
                <Filter className="w-4 h-4 mr-2" />
                Browse by Category
              </div>
              <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">Find Trusted Vendors Near You</h2>
              <p className="text-xl text-gray-600 max-w-3xl mx-auto">
                Explore our curated list of top-rated decorators, caterers, photographers, venues, and more – all verified and reviewed by customers.
              </p>
            </div>

            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {categories.map((category, index) => (
                <div
                  key={index}
                  className="group relative p-8 rounded-2xl shadow-2xl -translate-y-2 border border-white/30 lg:shadow-lg lg:translate-y-0 lg:hover:shadow-2xl lg:hover:-translate-y-2 transition-all duration-500 cursor-pointer flex flex-col items-center justify-center min-h-[230px] gap-4"
                  style={{
                    backgroundImage: `url(${category.bgImage})`,
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                  }}
                >
                  <div className="absolute inset-0 bg-black/40 rounded-2xl opacity-60 lg:opacity-0 lg:group-hover:opacity-60 transition-opacity duration-500"></div>
                  <div className="relative flex flex-col items-center text-center z-10">
                    <h3 className="text-lg font-bold text-white mb-1 group-hover:text-yellow-300 transition-colors">{category.name}</h3>
                    <p className="text-sm text-white/90">{category.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* FAQ */}
        <section id="faq" className="py-20 bg-white">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-16">
              <div className="inline-flex items-center px-4 py-2 bg-yellow-100 rounded-full text-sm font-medium text-yellow-700 mb-4">
                <Headphones className="w-4 h-4 mr-2" />
                Frequently Asked Questions
              </div>
              <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">Got Questions? We've Got Answers</h2>
              <p className="text-xl text-gray-600">Everything you need to know about Saral Events and our services</p>
            </div>

            <div className="space-y-4">
              {faqs.map((faq, index) => (
                <div key={index} className="bg-white border border-gray-200 rounded-2xl shadow-sm hover:shadow-lg transition-all duration-300">
                  <button
                    onClick={() => toggleFAQ(index)}
                    className="w-full px-8 py-6 text-left flex items-center justify-between hover:bg-gray-50 rounded-2xl transition-colors duration-300"
                  >
                    <span className="text-lg font-semibold text-gray-900 pr-4">{faq.question}</span>
                    {openFAQ === index ? (
                      <ChevronUp className="h-6 w-6 text-yellow-600 flex-shrink-0" />
                    ) : (
                      <ChevronDown className="h-6 w-6 text-gray-400 flex-shrink-0" />
                    )}
                  </button>
                  {openFAQ === index && (
                    <div className="px-8 pb-6">
                      <div className="pt-4 border-t border-gray-100">
                        <p className="text-gray-600 leading-relaxed">{faq.answer}</p>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>

            <div className="text-center mt-12">
              <p className="text-gray-600 mb-4">Still have questions?</p>
              <button
                onClick={() => scrollToSection('contact')}
                className="bg-gradient-to-r from-yellow-600 to-orange-600 text-white px-8 py-3 rounded-xl font-semibold hover:from-yellow-700 hover:to-orange-700 transition-all duration-300 transform hover:scale-105"
              >
                Contact Our Support Team
              </button>
            </div>
          </div>
        </section>

        {/* CONTACT */}
        <section id="contact" className="py-20 bg-gradient-to-br from-gray-50 to-gray-100">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-16">
              <div className="inline-flex items-center px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm font-medium text-yellow-700 mb-4 border border-yellow-200">
                <MessageCircle className="w-4 h-4 mr-2" />
                Get in Touch
              </div>
              <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">We’d Love to Hear from You</h2>
              <p className="text-xl text-gray-600 max-w-3xl mx-auto">Have questions or need support? Fill the form or reach out via email/WhatsApp.</p>
            </div>

            <div className="grid lg:grid-cols-2 gap-12">
              <div className="space-y-8">
                <div className="grid md:grid-cols-2 gap-6">
                  {contactInfo.map((info, index) => (
                    <div
                      key={index}
                      className="group bg-white p-6 rounded-2xl shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1"
                    >
                      <div className={`w-12 h-12 bg-gradient-to-r ${info.color} rounded-xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform duration-300`}>
                        <info.icon className="h-6 w-6 text-white" />
                      </div>
                      <h3 className="text-lg font-semibold text-gray-900 mb-3">{info.title}</h3>
                      <div className="space-y-2">
                        {info.details.map((detail, idx) => (
                          <div key={idx}>
                            {info.action ? (
                              <button
                                onClick={() => info.action(detail)}
                                className="text-gray-600 hover:text-yellow-600 transition-colors duration-300 text-left block"
                              >
                                {detail}
                              </button>
                            ) : (
                              <p className="text-gray-600">{detail}</p>
                            )}
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>

                <div className="bg-gradient-to-r from-yellow-600 to-orange-600 p-8 rounded-2xl text-white">
                  <h3 className="text-2xl font-bold mb-4">Need Immediate Help?</h3>
                  <p className="mb-6 text-yellow-100">Our support team is available 24/7 to assist you with any urgent queries or booking issues.</p>
                  <div className="flex flex-col sm:flex-row gap-4">
                    <button
                      onClick={() => handlePhoneCall('+91 7815865959')}
                      className="bg-white/20 backdrop-blur-sm text-white px-6 py-3 rounded-xl font-semibold hover:bg-white/30 transition-all duration-300 flex items-center justify-center"
                    >
                      <Phone className="mr-2 h-5 w-5" />
                      Call Now
                    </button>
                    <button
                      onClick={() => handleEmail('contactus@saralevents.com')}
                      className="bg-white/20 backdrop-blur-sm text-white px-6 py-3 rounded-xl font-semibold hover:bg-white/30 transition-all duration-300 flex items-center justify-center"
                    >
                      <Mail className="mr-2 h-5 w-5" />
                      Email Us
                    </button>
                  </div>
                </div>
              </div>

              <div className="bg-white p-8 rounded-2xl shadow-xl">
                <h3 className="text-2xl font-bold text-gray-900 mb-6">Send us a Message</h3>
                <form onSubmit={handleContactSubmit} className="space-y-6">
                  <div className="grid md:grid-cols-2 gap-6">
                    <input
                      type="text"
                      name="name"
                      value={contactForm.name}
                      onChange={handleContactInputChange}
                      placeholder="Your Name"
                      className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300"
                      required
                    />
                    <input
                      type="email"
                      name="email"
                      value={contactForm.email}
                      onChange={handleContactInputChange}
                      placeholder="Email Address"
                      className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300"
                      required
                    />
                  </div>
                  <input
                    type="tel"
                    name="phone"
                    value={contactForm.phone}
                    onChange={handleContactInputChange}
                    placeholder="Phone Number"
                    className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300"
                    required
                  />
                  <textarea
                    name="message"
                    value={contactForm.message}
                    onChange={handleContactInputChange}
                    placeholder="Your Message"
                    rows={5}
                    className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300 resize-none"
                    required
                  ></textarea>
                  <button
                    type="submit"
                    disabled={isContactSubmitting}
                    className="w-full bg-gradient-to-r from-yellow-600 to-orange-600 text-white py-4 rounded-xl font-semibold hover:from-yellow-700 hover:to-orange-700 transition-all duration-300 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                  >
                    {isContactSubmitting ? (
                      'Sending...'
                    ) : (
                      <>
                        <Send className="mr-2 h-5 w-5" />
                        Send Message
                      </>
                    )}
                  </button>
                </form>
                {contactMessage && (
                  <div
                    className={`mt-6 p-4 rounded-xl text-sm ${
                      contactMessage.includes('sent') ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                    }`}
                  >
                    {contactMessage}
                  </div>
                )}
              </div>
            </div>
          </div>
        </section>

        {/* VENDOR REG */}
        <section id="vendor-registration" className="py-20 bg-white">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="grid lg:grid-cols-2 gap-12 items-center">
              <div className="space-y-8">
                <div>
                  <div className="inline-flex items-center px-4 py-2 bg-yellow-100 rounded-full text-sm font-medium text-yellow-700 mb-4">
                    <Users className="w-4 h-4 mr-2" />
                    For Business Partners
                  </div>
                  <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-6">Join Our Growing Vendor Network</h2>
                  <p className="text-xl text-gray-600 leading-relaxed">
                    Are you a decorator, caterer, DJ, photographer, or venue owner? Connect with thousands of customers actively planning events in your area.
                  </p>
                </div>

                <div className="space-y-6">
                  {[
                    { icon: Store, text: 'Free Vendor Listing' },
                    { icon: UserCheck, text: 'Verified Customer Leads' },
                    { icon: Settings, text: 'In-App Business Management' },
                    { icon: Star, text: 'Customer Reviews & Ratings' },
                  ].map((benefit, index) => (
                    <div key={index} className="flex items-center group">
                      <div className="w-8 h-8 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-full flex items-center justify-center mr-4 group-hover:scale-110 transition-transform duration-300">
                        <benefit.icon className="h-4 w-4 text-white" />
                      </div>
                      <span className="text-gray-700 group-hover:text-gray-900 transition-colors">{benefit.text}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="bg-gradient-to-br from-gray-50 to-gray-100 p-8 rounded-3xl shadow-xl border border-gray-200">
                <h3 className="text-2xl font-bold text-gray-900 mb-6">Quick Registration</h3>
                <form onSubmit={handleVendorSubmit} className="space-y-6">
                  <input
                    type="text"
                    name="Name"
                    value={formData.Name}
                    onChange={handleInputChange}
                    placeholder="Name"
                    className="w-full px-4 py-4 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300 bg-white"
                    required
                  />
                  <input
                    type="email"
                    name="email"
                    value={formData.email}
                    onChange={handleInputChange}
                    placeholder="Email Address"
                    className="w-full px-4 py-4 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300 bg-white"
                    required
                  />
                  <input
                    type="tel"
                    name="phone"
                    value={formData.phone}
                    onChange={handleInputChange}
                    placeholder="Phone Number"
                    className="w-full px-4 py-4 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300 bg-white"
                    required
                  />
                  <select
                    name="category"
                    value={formData.category}
                    onChange={handleInputChange}
                    className="w-full px-4 py-4 border border-gray-300 rounded-xl focus:ring-2 focus:ring-yellow-600 focus:border-transparent transition-all duration-300 bg-white"
                    required
                  >
                    <option value="">Select Service Category</option>
                    <option value="photography">Photography & Videography</option>
                    <option value="catering">Catering Services</option>
                    <option value="decoration">Decoration & Design</option>
                    <option value="entertainment">Entertainment & Music</option>
                    <option value="venues">Venues & Locations</option>
                    <option value="wedding-planning">Wedding Planning</option>
                    <option value="other">Other Services</option>
                  </select>
                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className="w-full bg-gradient-to-r from-yellow-600 to-orange-600 text-white py-4 rounded-xl font-semibold hover:from-yellow-700 hover:to-orange-700 transition-all duration-300 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
                  >
                    {isSubmitting ? 'Submitting...' : 'Register as Vendor'}
                  </button>
                </form>
                {submitMessage && (
                  <div
                    className={`mt-6 p-4 rounded-xl text-sm ${
                      submitMessage.includes('successful') ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                    }`}
                  >
                    {submitMessage}
                  </div>
                )}
              </div>
            </div>
          </div>
        </section>

        {/* FOOTER */}
        <section className="bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 text-white py-10 relative overflow-hidden">
          <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex flex-col items-center justify-center space-y-4">
              <img src="/images/saral-logo.png" alt="Saral Events" className="h-20 w-auto" />
              <p className="text-gray-400 text-center">Making Every Celebration Saral.</p>
              <div className="flex flex-col sm:flex-row items-center gap-4 text-gray-400">
                <button onClick={() => handlePhoneCall('+91 7815865959')} className="flex items-center hover:text-yellow-400 transition-colors group">
                  <Phone className="h-4 w-4 mr-2 group-hover:animate-pulse" />
                  <span>+91 7815865959</span>
                </button>
                <button onClick={() => handleEmail('contactus@saralevents.com')} className="flex items-center hover:text-yellow-400 transition-colors group">
                  <Mail className="h-4 w-4 mr-2 group-hover:animate-pulse" />
                  <span>contactus@saralevents.com</span>
                </button>
              </div>
              <p className="text-gray-500 text-center pt-2">&copy; 2025 Saral Events. All rights reserved.</p>
            </div>
          </div>
        </section>
      </div>
    </SafeComponent>
  )
}

