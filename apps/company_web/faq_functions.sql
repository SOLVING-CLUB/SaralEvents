-- SQL Functions for FAQ interactions
-- These functions handle incrementing view counts and feedback

-- Function to increment FAQ view count
CREATE OR REPLACE FUNCTION increment_faq_view_count(faq_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE faqs
  SET view_count = view_count + 1
  WHERE id = faq_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment FAQ helpful count
CREATE OR REPLACE FUNCTION increment_faq_helpful_count(faq_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE faqs
  SET helpful_count = helpful_count + 1
  WHERE id = faq_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment FAQ not helpful count
CREATE OR REPLACE FUNCTION increment_faq_not_helpful_count(faq_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE faqs
  SET not_helpful_count = not_helpful_count + 1
  WHERE id = faq_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_faq_view_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_faq_helpful_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_faq_not_helpful_count(UUID) TO authenticated;
