# bsocialv2

Analysis of Microbial Social Behavior in Bacterial Consortia

## Overview

`bsocialv2` provides an S4 class and methods for analyzing microbial social
behavior in bacterial consortia. The package implements a complete analysis
pipeline:

1. **Data Import** - Raw plate reader data or pre-processed growth parameters
2. **Growth Analysis** - Parameter extraction (NGen, GR, LogPhase) via growthcurver or grofit
3. **Social Behavior** - Fitness comparisons identifying cooperators, cheaters, and neutrals
4. **Diversity Effects** - Relationship between consortium diversity and fitness
5. **Stability Analysis** - Coefficient of variation across replicates/diversity levels
6. **Assembly Paths** - Graph-based consortium assembly sequence finding

## Installation

```r
# Install from GitHub
remotes::install_github("Juane99/bsocial")

# Or install from CRAN (once accepted)
# install.packages("bsocialv2")
```

## Quick Start

```r
library(bsocialv2)

# Create a bsocial object
obj <- new("bsocial")

# Load your data
consortia <- read.csv("consortia.csv")
curated <- read.csv("curated_data.csv")

obj@cepas_seleccionadas <- setdiff(colnames(consortia), "Consortia")
obj@datos_crudos <- list(
  consortia = consortia,
  curated = curated,
  type = "curated"
)

# Run the analysis pipeline
obj <- transform_curated_data(obj)
obj <- analyze_growth(obj)
obj <- analyze_social_behavior(obj)
obj <- summarize_social_behavior(obj)
obj <- analyze_diversity(obj)
obj <- analyze_stability(obj)
obj <- analyze_biofilm_sequence(obj)

# Access results
obj@graficos$growth_scatter
obj@resultados_analisis$summary_gen
```

See `vignette("bsocial-workflow")` for a complete tutorial.

## License

MIT
