# 'ggplot2' Graphics for `figsr_fit` Models

`ggfigs()` draws a fitted Fast Interpretable Greedy-Tree Sums (FIGS)
model with 'ggplot2'. Five views are available:

- `"tree"`: every tree of the sum as a node-link diagram, edge width
  proportional to the observations that flow through it and leaves
  filled by their contribution on a diverging scale.

- `"rules"`: every tree as a horizontal list of rules, with `+` between
  trees. Each node continues to the right through the child with more
  nodes below it and the other child drops down, so a tree in which
  every split has a leaf child reads as a single line.

- `"waterfall"`: where the prediction for one observation comes from, as
  one bar per tree accumulating to the final prediction.

- `"cuts"`: every numeric cutpoint drawn over the data it was chosen
  from, one panel per predictor.

- `"profile"`: the exact partial dependence of the prediction on each
  predictor that carries a split.

With `interactive = FALSE` (the default) the result is an ordinary
`ggplot` object, ready for `ggsave()`, PDF output or further `+` layers.
With `interactive = TRUE` it is an HTML widget built with 'ggiraph',
with tooltips that show the full rule behind each node, leaf or cut;
this needs the 'ggiraph' package to be installed.

[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html) is
the same function under the 'ggplot2' generic, and always returns a
`ggplot`.

## Usage

``` r
ggfigs(
  x,
  type = c("tree", "rules", "waterfall", "cuts", "profile"),
  data = NULL,
  newdata = NULL,
  tree_idx = NULL,
  digits = 3,
  interactive = FALSE,
  ...
)

# S3 method for class 'figsr_fit'
autoplot(
  object,
  type = c("tree", "rules", "waterfall", "cuts", "profile"),
  ...
)
```

## Arguments

- x, object:

  A fitted `figsr_fit` model object.

- type:

  The view to draw: `"tree"`, `"rules"`, `"waterfall"`, `"cuts"` or
  `"profile"`.

- data:

  The data frame the model was fit on. Required by `"cuts"` and
  `"profile"`, which draw the data, and optional for `"rules"`, which
  then adds the outcome rate (classification) or mean (regression) to
  each rule. The fitted model does not store its training data.

- newdata:

  A data frame with exactly one row, the observation that
  `type = "waterfall"` decomposes.

- tree_idx:

  Optional integer vector of the trees to draw in `type = "tree"`.
  Default `NULL` draws them all.

- digits:

  Significant digits for cutpoints and leaf values.

- interactive:

  Logical. `FALSE` (default) returns a `ggplot`; `TRUE` returns a
  'ggiraph' `girafe` HTML widget.

- ...:

  Further arguments for the chosen view: `width_svg` and `height_svg`
  (inches) size the interactive widget; `grid_n` (default 160) and
  `features` select the grid and the predictors of `"profile"`;
  `max_points` (default 2000) caps the points drawn by `"cuts"`.

## Value

A `ggplot` object, or a `girafe` HTML widget when `interactive = TRUE`.
For `type = "rules"` the `ggplot` carries an attribute `"ggfigs_size"`,
the natural `c(width, height)` of the drawing in inches, to size
`ggsave()` with.

## See also

[`plot.figsr_fit()`](https://bonijoao.github.io/figsr/dev/reference/plot.figsr_fit.md)
for the base-graphics tree diagram.

## Examples

``` r
fit <- figs(mpg ~ wt + hp + disp, data = mtcars, max_splits = 5)
ggfigs(fit)

ggfigs(fit, type = "rules", data = mtcars)

ggfigs(fit, type = "waterfall", newdata = mtcars[1, ])

ggfigs(fit, type = "cuts", data = mtcars)

ggfigs(fit, type = "profile", data = mtcars)


# the 'ggplot2' generic gives the same plots
ggplot2::autoplot(fit, type = "rules")


# \donttest{
if (requireNamespace("ggiraph", quietly = TRUE)) {
  ggfigs(fit, type = "rules", data = mtcars, interactive = TRUE)
}

{"x":{"html":"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' class='ggiraph-svg' role='graphics-document' id='svg_680a92dbd423a9d5' viewBox='0 0 594.58 452.88'>\n <defs id='svg_680a92dbd423a9d5_defs'>\n  <clipPath id='svg_680a92dbd423a9d5_c1'>\n   <rect x='0' y='0' width='594.58' height='452.88'/>\n  <\/clipPath>\n  <clipPath id='svg_680a92dbd423a9d5_c2'>\n   <rect x='0' y='16.21' width='594.58' height='420.46'/>\n  <\/clipPath>\n <\/defs>\n <g id='svg_680a92dbd423a9d5_rootg' class='ggiraph-svg-rootg'>\n  <g clip-path='url(#svg_680a92dbd423a9d5_c1)'>\n   <rect x='0' y='0' width='594.58' height='452.88' fill='#FFFFFF' fill-opacity='1' stroke='#FFFFFF' stroke-opacity='1' stroke-width='0.75' stroke-linejoin='round' stroke-linecap='round' class='ggiraph-svg-bg'/>\n  <\/g>\n  <g clip-path='url(#svg_680a92dbd423a9d5_c2)'>\n   <rect x='0' y='16.21' width='594.58' height='420.46' fill='#FCFCFB' fill-opacity='1' stroke='none'/>\n  <\/g>\n  <g clip-path='url(#svg_680a92dbd423a9d5_c1)'>\n   <rect x='11.96' y='62.77' width='570.67' height='361.95' fill='#FCFCFB' fill-opacity='1' stroke='none'/>\n   <line x1='346.79' y1='101.69' x2='346.79' y2='214.03' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='round' stroke-linecap='butt'/>\n   <line x1='165.16' y1='101.69' x2='165.16' y2='139.38' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='162.67,135.06 165.16,139.38 167.65,135.06' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='143.42' y1='101.69' x2='219.52' y2='101.69' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='215.21,104.18 219.52,101.69 215.21,99.20' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='325.05' y1='101.69' x2='401.15' y2='101.69' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='396.83,104.18 401.15,101.69 396.83,99.20' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='528.42' y1='101.69' x2='528.42' y2='139.38' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='525.92,135.06 528.42,139.38 530.91,135.06' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='506.67' y1='101.69' x2='551.61' y2='101.69' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='547.29,104.18 551.61,101.69 547.29,99.20' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='346.79' y1='214.03' x2='401.15' y2='214.03' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='396.83,216.52 401.15,214.03 396.83,211.54' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='528.42' y1='214.03' x2='528.42' y2='251.72' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='525.92,247.40 528.42,251.72 530.91,247.40' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='506.67' y1='214.03' x2='551.61' y2='214.03' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='547.29,216.52 551.61,214.03 547.29,211.54' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='165.16' y1='366.23' x2='165.16' y2='403.92' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='162.67,399.60 165.16,403.92 167.65,399.60' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <line x1='143.42' y1='366.23' x2='188.36' y2='366.23' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <polygon points='184.04,368.72 188.36,366.23 184.04,363.74' fill='#52514E' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.85' stroke-linejoin='miter' stroke-linecap='butt'/>\n   <rect id='svg_680a92dbd423a9d5_e1' x='37.89' y='79.22' width='105.53' height='44.94' fill='#F1F0EC' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.75' stroke-linejoin='miter' stroke-linecap='butt' title='&amp;lt;b&amp;gt;wt &amp;lt;= 2.26&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 32, mean 20.1&amp;lt;br&amp;gt;SSE gain = 735' data-id='t1_1'/>\n   <rect id='svg_680a92dbd423a9d5_e2' x='219.52' y='79.22' width='105.53' height='44.94' fill='#F1F0EC' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.75' stroke-linejoin='miter' stroke-linecap='butt' title='&amp;lt;b&amp;gt;disp &amp;lt;= 267&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 26, mean 17.8&amp;lt;br&amp;gt;SSE gain = 219&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;reached when wt &amp;amp;gt; 2.26&amp;lt;/i&amp;gt;' data-id='t1_3'/>\n   <rect id='svg_680a92dbd423a9d5_e3' x='401.15' y='79.22' width='105.53' height='44.94' fill='#F1F0EC' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.75' stroke-linejoin='miter' stroke-linecap='butt' title='&amp;lt;b&amp;gt;hp &amp;lt;= 192&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 14, mean 15.1&amp;lt;br&amp;gt;SSE gain = 39.8&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;reached when wt &amp;amp;gt; 2.26&amp;lt;br&amp;gt;and disp &amp;amp;gt; 267&amp;lt;/i&amp;gt;' data-id='t1_5'/>\n   <rect id='svg_680a92dbd423a9d5_e4' x='401.15' y='191.56' width='105.53' height='44.94' fill='#F1F0EC' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.75' stroke-linejoin='miter' stroke-linecap='butt' title='&amp;lt;b&amp;gt;disp &amp;lt;= 153&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 12, mean 20.9&amp;lt;br&amp;gt;SSE gain = 16.6&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;reached when wt &amp;amp;gt; 2.26&amp;lt;br&amp;gt;and disp &amp;amp;le; 267&amp;lt;/i&amp;gt;' data-id='t1_4'/>\n   <rect id='svg_680a92dbd423a9d5_e5' x='37.89' y='343.76' width='105.53' height='44.94' fill='#F1F0EC' fill-opacity='1' stroke='#52514E' stroke-opacity='1' stroke-width='0.75' stroke-linejoin='miter' stroke-linecap='butt' title='&amp;lt;b&amp;gt;hp &amp;lt;= 78.5&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 32, mean 20.1&amp;lt;br&amp;gt;SSE gain = 8.63' data-id='t2_1'/>\n   <text x='85.84' y='92.71' font-size='6.51pt' font-weight='bold' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>wt<\/text>\n   <text x='263.37' y='92.71' font-size='6.51pt' font-weight='bold' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>disp<\/text>\n   <text x='448.62' y='92.71' font-size='6.51pt' font-weight='bold' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>hp<\/text>\n   <text x='445' y='205.05' font-size='6.51pt' font-weight='bold' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>disp<\/text>\n   <text x='85.37' y='357.25' font-size='6.51pt' font-weight='bold' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>hp<\/text>\n   <text x='76.67' y='104.53' font-size='6.19pt' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>&lt;= 2.26<\/text>\n   <text x='259.44' y='104.53' font-size='6.19pt' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>&lt;= 267<\/text>\n   <text x='441.07' y='104.53' font-size='6.19pt' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>&lt;= 192<\/text>\n   <text x='441.07' y='216.86' font-size='6.19pt' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>&lt;= 153<\/text>\n   <text x='76.67' y='369.07' font-size='6.19pt' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>&lt;= 78.5<\/text>\n   <text x='59.61' y='116.29' font-size='5.76pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>n = 32, mean 20.1<\/text>\n   <text x='241.24' y='116.29' font-size='5.76pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>n = 26, mean 17.8<\/text>\n   <text x='422.86' y='116.29' font-size='5.76pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>n = 14, mean 15.1<\/text>\n   <text x='422.86' y='228.63' font-size='5.76pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>n = 12, mean 20.9<\/text>\n   <text x='59.61' y='380.83' font-size='5.76pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>n = 32, mean 20.1<\/text>\n   <text x='160.44' y='98.07' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>No<\/text>\n   <text x='168.79' y='121.19' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>Yes<\/text>\n   <text x='342.07' y='98.07' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>No<\/text>\n   <text x='523.69' y='98.07' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>No<\/text>\n   <text x='532.04' y='121.19' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>Yes<\/text>\n   <text x='350.41' y='121.19' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>Yes<\/text>\n   <text x='523.69' y='210.4' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>No<\/text>\n   <text x='532.04' y='233.53' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>Yes<\/text>\n   <text x='160.44' y='362.6' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>No<\/text>\n   <text x='168.79' y='385.73' font-size='5.55pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>Yes<\/text>\n   <text id='svg_680a92dbd423a9d5_e6' x='153.3' y='150.18' font-size='7.04pt' font-weight='bold' font-family='Liberation Sans' fill='#D03B3B' fill-opacity='1' title='&amp;lt;b&amp;gt;Leaf: +30.1&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 6&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;wt &amp;amp;le; 2.26&amp;lt;/i&amp;gt;' data-id='t1_2'>+30.1<\/text>\n   <text id='svg_680a92dbd423a9d5_e7' x='516.56' y='150.18' font-size='7.04pt' font-weight='bold' font-family='Liberation Sans' fill='#D03B3B' fill-opacity='1' title='&amp;lt;b&amp;gt;Leaf: +16.8&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 7&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;wt &amp;amp;gt; 2.26&amp;lt;br&amp;gt;and disp &amp;amp;gt; 267&amp;lt;br&amp;gt;and hp &amp;amp;le; 192&amp;lt;/i&amp;gt;' data-id='t1_6'>+16.8<\/text>\n   <text id='svg_680a92dbd423a9d5_e8' x='556.68' y='104.91' font-size='7.04pt' font-weight='bold' font-family='Liberation Sans' fill='#D03B3B' fill-opacity='1' title='&amp;lt;b&amp;gt;Leaf: +13.4&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 7&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;wt &amp;amp;gt; 2.26&amp;lt;br&amp;gt;and disp &amp;amp;gt; 267&amp;lt;br&amp;gt;and hp &amp;amp;gt; 192&amp;lt;/i&amp;gt;' data-id='t1_7'>+13.4<\/text>\n   <text id='svg_680a92dbd423a9d5_e9' x='516.56' y='262.52' font-size='7.04pt' font-weight='bold' font-family='Liberation Sans' fill='#D03B3B' fill-opacity='1' title='&amp;lt;b&amp;gt;Leaf: +22.1&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 6&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;wt &amp;amp;gt; 2.26&amp;lt;br&amp;gt;and disp &amp;amp;le; 267&amp;lt;br&amp;gt;and disp &amp;amp;le; 153&amp;lt;/i&amp;gt;' data-id='t1_8'>+22.1<\/text>\n   <text id='svg_680a92dbd423a9d5_e10' x='556.68' y='217.25' font-size='7.04pt' font-weight='bold' font-family='Liberation Sans' fill='#D03B3B' fill-opacity='1' title='&amp;lt;b&amp;gt;Leaf: +19.8&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 6&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;wt &amp;amp;gt; 2.26&amp;lt;br&amp;gt;and disp &amp;amp;le; 267&amp;lt;br&amp;gt;and disp &amp;amp;gt; 153&amp;lt;/i&amp;gt;' data-id='t1_9'>+19.8<\/text>\n   <text id='svg_680a92dbd423a9d5_e11' x='153.3' y='414.72' font-size='7.04pt' font-weight='bold' font-family='Liberation Sans' fill='#D03B3B' fill-opacity='1' title='&amp;lt;b&amp;gt;Leaf: +1.21&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 5&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;hp &amp;amp;le; 78.5&amp;lt;/i&amp;gt;' data-id='t2_2'>+1.21<\/text>\n   <text id='svg_680a92dbd423a9d5_e12' x='193.43' y='369.45' font-size='7.04pt' font-weight='bold' font-family='Liberation Sans' fill='#2A78D6' fill-opacity='1' title='&amp;lt;b&amp;gt;Leaf: -0.223&amp;lt;/b&amp;gt;&amp;lt;br&amp;gt;n = 27&amp;lt;br&amp;gt;&amp;lt;br&amp;gt;&amp;lt;i&amp;gt;hp &amp;amp;gt; 78.5&amp;lt;/i&amp;gt;' data-id='t2_3'>-0.223<\/text>\n   <text x='84.84' y='296.98' font-size='14.94pt' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>+<\/text>\n   <text x='11.96' y='50.64' font-size='7.84pt' font-family='Liberation Sans' fill='#52514E' fill-opacity='1'>2 trees, 5 splits<\/text>\n   <text x='11.96' y='38.38' font-size='11.14pt' font-weight='bold' font-family='Liberation Sans' fill='#0B0B0B' fill-opacity='1'>FIGS rules<\/text>\n  <\/g>\n <\/g>\n<\/svg>","js":null,"uid":"svg_680a92dbd423a9d5","ratio":1.312877583465819,"settings":{"tooltip":{"css":".tooltip_SVGID_ { background:#fcfcfb;color:#0b0b0b;border:1px solid #c3c2b7;border-radius:6px;padding:7px 9px;font-family:sans-serif;font-size:11.5px;box-shadow:0 2px 8px rgba(0,0,0,.12); ; position:absolute;pointer-events:none;z-index:9999;}","placement":"doc","opacity":1,"offx":10,"offy":10,"use_cursor_pos":true,"use_fill":false,"use_stroke":false,"delay_over":200,"delay_out":500},"hover":{"css":".hover_data_SVGID_ { stroke:#0b0b0b;stroke-width:1.4px; }","reactive":true,"nearest_distance":null,"linked":false},"hover_inv":{"css":""},"hover_key":{"css":".hover_key_SVGID_ { fill:orange;stroke:black;cursor:pointer; }\ntext.hover_key_SVGID_ { stroke:none;fill:orange; }\ncircle.hover_key_SVGID_ { fill:orange;stroke:black; }\nline.hover_key_SVGID_, polyline.hover_key_SVGID_ { fill:none;stroke:orange; }\nrect.hover_key_SVGID_, polygon.hover_key_SVGID_, path.hover_key_SVGID_ { fill:orange;stroke:none; }\nimage.hover_key_SVGID_ { stroke:orange; }","reactive":true},"hover_theme":{"css":".hover_theme_SVGID_ { fill:orange;stroke:black;cursor:pointer; }\ntext.hover_theme_SVGID_ { stroke:none;fill:orange; }\ncircle.hover_theme_SVGID_ { fill:orange;stroke:black; }\nline.hover_theme_SVGID_, polyline.hover_theme_SVGID_ { fill:none;stroke:orange; }\nrect.hover_theme_SVGID_, polygon.hover_theme_SVGID_, path.hover_theme_SVGID_ { fill:orange;stroke:none; }\nimage.hover_theme_SVGID_ { stroke:orange; }","reactive":true},"select":{"css":".select_data_SVGID_ { fill:red;stroke:black;cursor:pointer; }\ntext.select_data_SVGID_ { stroke:none;fill:red; }\ncircle.select_data_SVGID_ { fill:red;stroke:black; }\nline.select_data_SVGID_, polyline.select_data_SVGID_ { fill:none;stroke:red; }\nrect.select_data_SVGID_, polygon.select_data_SVGID_, path.select_data_SVGID_ { fill:red;stroke:none; }\nimage.select_data_SVGID_ { stroke:red; }","type":"multiple","only_shiny":true,"selected":[],"linked":false},"select_inv":{"css":""},"select_key":{"css":".select_key_SVGID_ { fill:red;stroke:black;cursor:pointer; }\ntext.select_key_SVGID_ { stroke:none;fill:red; }\ncircle.select_key_SVGID_ { fill:red;stroke:black; }\nline.select_key_SVGID_, polyline.select_key_SVGID_ { fill:none;stroke:red; }\nrect.select_key_SVGID_, polygon.select_key_SVGID_, path.select_key_SVGID_ { fill:red;stroke:none; }\nimage.select_key_SVGID_ { stroke:red; }","type":"single","only_shiny":true,"selected":[]},"select_theme":{"css":".select_theme_SVGID_ { fill:red;stroke:black;cursor:pointer; }\ntext.select_theme_SVGID_ { stroke:none;fill:red; }\ncircle.select_theme_SVGID_ { fill:red;stroke:black; }\nline.select_theme_SVGID_, polyline.select_theme_SVGID_ { fill:none;stroke:red; }\nrect.select_theme_SVGID_, polygon.select_theme_SVGID_, path.select_theme_SVGID_ { fill:red;stroke:none; }\nimage.select_theme_SVGID_ { stroke:red; }","type":"single","only_shiny":true,"selected":[]},"zoom":{"min":1,"max":1,"duration":300,"default_on":false},"toolbar":{"position":"topright","pngname":"diagram","tooltips":null,"fixed":false,"hidden":[],"delay_over":200,"delay_out":500},"sizing":{"rescale":true,"width":1}}},"evals":[],"jsHooks":[]}# }
```
