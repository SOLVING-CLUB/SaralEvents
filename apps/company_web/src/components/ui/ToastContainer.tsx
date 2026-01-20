"use client"

import { ToastComponent, Toast } from './Toast'

interface ToastContainerProps {
  toasts: Toast[]
  onRemove: (id: string) => void
}

export function ToastContainer({ toasts, onRemove }: ToastContainerProps) {
  if (toasts.length === 0) return null

  return (
    <div className="fixed top-20 right-2 sm:right-4 z-50 flex flex-col gap-2 pointer-events-none max-w-[calc(100vw-1rem)] sm:max-w-[420px]">
      {toasts.map((toast) => (
        <div key={toast.id} className="pointer-events-auto">
          <ToastComponent toast={toast} onClose={onRemove} />
        </div>
      ))}
    </div>
  )
}
