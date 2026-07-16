import React from "react"
import { cn } from "@/lib/utils"

type Props = {
  durationMs: number
  size?: number
  className?: string
}

function useIsDarkTheme(): boolean {
  const getIsDark = () =>
    typeof document !== "undefined" && document.documentElement.classList.contains("dark")
  const [isDark, setIsDark] = React.useState(getIsDark)

  React.useEffect(() => {
    const update = () => setIsDark(getIsDark())
    const observer = new MutationObserver(update)
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })
    update()
    return () => observer.disconnect()
  }, [])

  return isDark
}

/**
 * Circular countdown ring for undo toasts. Starts full and drains to empty
 * over `durationMs` with a soft light stroke (faint white on dark surfaces).
 */
export function UndoCountdownRing({
  durationMs,
  size = 16,
  className,
}: Props): React.ReactNode {
  const isDark = useIsDarkTheme()
  const strokeWidth = 1.75
  const radius = (size - strokeWidth) / 2
  const circumference = 2 * Math.PI * radius
  const [offset, setOffset] = React.useState(0)
  const trackStroke = isDark ? "rgba(255, 255, 255, 0.16)" : "rgba(0, 0, 0, 0.12)"
  const progressStroke = isDark ? "rgba(255, 255, 255, 0.55)" : "rgba(0, 0, 0, 0.38)"

  React.useEffect(() => {
    const start = performance.now()
    let frame = 0
    const tick = (now: number) => {
      const elapsed = now - start
      const progress = Math.min(1, Math.max(0, elapsed / durationMs))
      setOffset(circumference * progress)
      if (progress < 1) {
        frame = window.requestAnimationFrame(tick)
      }
    }
    // Kick the drain on the next frame so the full ring paints first.
    frame = window.requestAnimationFrame(tick)
    return () => window.cancelAnimationFrame(frame)
  }, [circumference, durationMs])

  return (
    <span
      className={cn("inline-flex shrink-0 items-center justify-center", className)}
      style={{ width: size, height: size }}
      aria-hidden="true"
    >
      <svg
        viewBox={`0 0 ${size} ${size}`}
        width={size}
        height={size}
        className="-rotate-90"
      >
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={trackStroke}
          strokeWidth={strokeWidth}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={progressStroke}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
        />
      </svg>
    </span>
  )
}
