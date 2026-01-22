// Robust API client with retry, timeout, and error handling
import { createClient } from './supabase'

interface RetryOptions {
  maxRetries?: number
  retryDelay?: number
  timeout?: number
}

interface RequestOptions extends RetryOptions {
  signal?: AbortSignal
}

class ApiClient {
  private supabase = createClient()
  private activeRequests = new Map<string, AbortController>()

  /**
   * Execute a Supabase query with retry logic, timeout, and error handling
   */
  async query<T>(
    queryFn: (supabase: ReturnType<typeof createClient>) => Promise<{ data: T | null; error: any }>,
    options: RequestOptions = {}
  ): Promise<{ data: T | null; error: any }> {
    const {
      maxRetries = 3,
      retryDelay = 1000,
      timeout = 30000, // 30 seconds default timeout
      signal,
    } = options

    const requestId = `${Date.now()}-${Math.random()}`
    const controller = new AbortController()
    
    // Combine signals if both provided
    if (signal) {
      signal.addEventListener('abort', () => controller.abort())
    }

    this.activeRequests.set(requestId, controller)

    try {
      // Create timeout
      const timeoutId = setTimeout(() => {
        controller.abort()
      }, timeout)

      let lastError: any = null
      
      for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          // Check if request was aborted
          if (controller.signal.aborted) {
            throw new Error('Request aborted')
          }

          // Execute query
          const result = await queryFn(this.supabase)
          
          clearTimeout(timeoutId)
          this.activeRequests.delete(requestId)
          
          // If error and we have retries left, retry
          if (result.error && attempt < maxRetries) {
            lastError = result.error
            
            // Don't retry on certain errors
            if (this.isNonRetryableError(result.error)) {
              return result
            }
            
            // Exponential backoff
            const delay = retryDelay * Math.pow(2, attempt)
            await this.delay(delay)
            continue
          }
          
          return result
        } catch (error: any) {
          clearTimeout(timeoutId)
          
          // If aborted, don't retry
          if (error.name === 'AbortError' || controller.signal.aborted) {
            this.activeRequests.delete(requestId)
            return { data: null, error: { message: 'Request cancelled', code: 'CANCELLED' } }
          }
          
          lastError = error
          
          // Retry on network errors
          if (this.isNetworkError(error) && attempt < maxRetries) {
            const delay = retryDelay * Math.pow(2, attempt)
            await this.delay(delay)
            continue
          }
          
          // Don't retry on other errors
          this.activeRequests.delete(requestId)
          return { data: null, error: this.normalizeError(error) }
        }
      }
      
      // All retries exhausted
      this.activeRequests.delete(requestId)
      return { data: null, error: this.normalizeError(lastError) }
    } catch (error: any) {
      this.activeRequests.delete(requestId)
      return { data: null, error: this.normalizeError(error) }
    }
  }

  /**
   * Cancel all active requests
   */
  cancelAll() {
    this.activeRequests.forEach((controller) => {
      controller.abort()
    })
    this.activeRequests.clear()
  }

  /**
   * Cancel a specific request by ID
   */
  cancel(requestId: string) {
    const controller = this.activeRequests.get(requestId)
    if (controller) {
      controller.abort()
      this.activeRequests.delete(requestId)
    }
  }

  /**
   * Check if error is non-retryable
   */
  private isNonRetryableError(error: any): boolean {
    if (!error) return false
    
    const code = error.code || error.status || ''
    const message = (error.message || '').toLowerCase()
    
    // Authentication errors
    if (code === 'PGRST301' || code === 401 || message.includes('unauthorized')) {
      return true
    }
    
    // Permission errors
    if (code === 'PGRST301' || code === 403 || message.includes('permission') || message.includes('forbidden')) {
      return true
    }
    
    // Not found errors
    if (code === 404 || message.includes('not found')) {
      return true
    }
    
    // Validation errors
    if (code === 400 || message.includes('validation') || message.includes('invalid')) {
      return true
    }
    
    return false
  }

  /**
   * Check if error is a network error
   */
  private isNetworkError(error: any): boolean {
    if (!error) return false
    
    const message = (error.message || '').toLowerCase()
    const code = error.code || ''
    
    return (
      error.name === 'NetworkError' ||
      error.name === 'TypeError' ||
      message.includes('network') ||
      message.includes('fetch') ||
      message.includes('connection') ||
      message.includes('timeout') ||
      code === 'ECONNREFUSED' ||
      code === 'ETIMEDOUT' ||
      code === 'ENOTFOUND'
    )
  }

  /**
   * Normalize error to consistent format
   */
  private normalizeError(error: any): any {
    if (!error) {
      return { message: 'Unknown error', code: 'UNKNOWN' }
    }
    
    if (typeof error === 'string') {
      return { message: error, code: 'ERROR' }
    }
    
    return {
      message: error.message || 'An error occurred',
      code: error.code || error.status || 'ERROR',
      details: error.details || error.hint || null,
    }
  }

  /**
   * Delay helper
   */
  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms))
  }

  /**
   * Get fresh Supabase client instance
   */
  getSupabase() {
    return this.supabase
  }
}

// Singleton instance
export const apiClient = new ApiClient()

// Helper function for common query patterns
export async function safeQuery<T>(
  queryFn: (supabase: ReturnType<typeof createClient>) => Promise<{ data: T | null; error: any }>,
  options?: RequestOptions
): Promise<{ data: T | null; error: any }> {
  return apiClient.query(queryFn, options)
}
