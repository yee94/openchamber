import React from "react"
import { cn } from "@/lib/utils"
import { iconSpriteData } from "./sprite"
import type { IconName } from "./icons"

const SPRITE_ID = "openchamber-icon-sprite-v2"

/** Codex/Lucide-style stroke weight (Lucide default is 2; thinner reads more refined). */
export const ICON_STROKE_WIDTH = 1.5

/** Slightly heavier stroke for small chrome (message actions) — clearer on dense/mobile screens without going solid. */
export const ICON_STROKE_WIDTH_MEDIUM = 2

let spriteInjected = false

function ensureSpriteOnce() {
  if (spriteInjected) return
  if (typeof document === "undefined") return
  const body = document.body
  if (!body) return

  const existing = document.getElementById(SPRITE_ID)
  if (existing) {
    // 旧 sprite 写死 stroke-width，换成 CSS var 后需重建才能让 weight 生效
    if (!existing.innerHTML.includes('--oc-icon-stroke')) {
      existing.remove()
    } else {
      spriteInjected = true
      return
    }
  }

  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
  svg.id = SPRITE_ID
  svg.setAttribute("aria-hidden", "true")
  svg.style.display = "none"
  // Stroke weight via CSS var so individual <Icon> instances can bump weight
  // (e.g. message actions) without regenerating the sprite.
  svg.innerHTML = Object.entries(iconSpriteData)
    .map(
      ([name, content]) =>
        `<symbol id="oc-${name}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="var(--oc-icon-stroke, ${ICON_STROKE_WIDTH})" stroke-linecap="round" stroke-linejoin="round">${content}</symbol>`
    )
    .join("")
  body.insertBefore(svg, body.firstChild)
  spriteInjected = true
}

export interface IconProps extends React.ComponentPropsWithoutRef<"svg"> {
  name: IconName
  /** `medium` ≈ Lucide default (2) — use for small action chrome that must stay legible on mobile. */
  weight?: "regular" | "medium"
}

export const Icon = React.memo(({ name, className, weight = "regular", style, ...rest }: IconProps) => {
  // Inline sprite injection during render – must run before <use> tries
  // to resolve the #oc-* reference during the same commit.
  if (typeof document !== "undefined") {
    ensureSpriteOnce()
  }

  const strokeWidth = weight === "medium" ? ICON_STROKE_WIDTH_MEDIUM : ICON_STROKE_WIDTH

  return (
    <svg
      className={cn("oc-icon", className)}
      viewBox="0 0 24 24"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      style={{
        // 让 <use> 克隆继承实例描边粗细（symbol 用 var(--oc-icon-stroke)）
        ["--oc-icon-stroke" as string]: strokeWidth,
        ...style,
      }}
      {...rest}
    >
      <use href={`#oc-${name}`} />
    </svg>
  )
})

Icon.displayName = "Icon"
