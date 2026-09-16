class_name UIFont
extends RefCounted

## The one font in the game. Every string - whether it goes through a Control
## node or a hand-rolled draw_string() in some _draw() - comes from here, so
## swapping the typeface is a one-line change.
##
## Controls that draw their own text (Label and friends) pick monogram up from
## the `gui/theme/custom_font` project setting instead; that setting points at
## the same file as FONT and exists so a newly added Control is already right
## without anyone having to remember this class.

const FONT: Font = preload("res://ui/fonts/monogram.ttf")

## monogram is a pixel font drawn on a 16px grid: glyphs are 5px wide with a
## 6px advance, caps are 7px tall and descenders reach 2px below the baseline.
## Only whole multiples of 16 land on that grid - anything in between puts
## glyphs on half pixels and the text comes out unevenly spaced, which is very
## visible at the game's 480x270 internal resolution. Use this, or 2 * this.
const SIZE := 16

## Height of a capital above the baseline, at SIZE. Handy when centring text in
## a bar of a known height, since draw_string() positions by baseline.
const CAP_H := 7
