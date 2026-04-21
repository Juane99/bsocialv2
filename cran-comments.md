## Update submission

This is an update from 0.1.0 → 0.2.0. Highlights (full list in NEWS.md):

* Breaking change: `analyze_diversity()` no longer produces the four
  `diversity_best_*` slots. The Top-k strain ranking path has been
  removed; affected code is contained within this package.
* New exported function `plot_growth_scatter()` with optional
  IQR-based outlier hiding for visualization.
* `plot_processed_curves()` now uses a log10 y-axis by default.
* `summarize_social_behavior()` exposes per-strain `stats_gen` /
  `stats_gr` data frames and decorates the social plots with
  Cooperator / Cheater / Neutral classification badges.

## R CMD check results

0 errors | 0 warnings | 0 notes on a clean CRAN-like environment.

Local check on Windows 11 (R 4.1.2) reports 1 WARNING ("qpdf is needed
for checks on size reduction of PDFs") and 1 NOTE ("unable to verify
current time") — both are environmental and do not appear on CRAN's
test infrastructure.

## Test environments

* Windows 11 (local), R 4.1.2
* win-builder (R-devel), via `devtools::check_win_devel()`
* GitHub Actions (ubuntu-latest), R release and R devel

## Reverse dependencies

None on CRAN. The companion Shiny application `BSocialApp` consumes
bsocialv2 from GitHub and has been updated in tandem with this
release to match the breaking change in `analyze_diversity()`.
