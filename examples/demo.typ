#set page(paper: "a5", margin: 2cm, numbering: "1")
#set heading(numbering: "1.")

#if sys.inputs.at("bbedit-preview", default: "false") == "true" [
  #text(fill: gray)[_Rendered in the BBEdit live preview._]
]

= Typst live preview demo

#include "chapters/intro.typ"

== Some math
The Gaussian integral is $ integral_(-oo)^oo e^(-x^2) dif x = sqrt(pi). $

== A table
#table(
  columns: 3,
  [*Mode*], [*Updates*], [*Output*],
  [Preview filter], [as you type], [SVG in BBEdit],
  [Watch PDF], [on save], [PDF viewer],
)

#pagebreak()
= Second page
#lorem(80)
