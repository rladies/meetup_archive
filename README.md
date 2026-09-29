# RLadies+ Meetup Archive

[![Meetup archive](https://github.com/rladies/jinx/actions/workflows/ops-meetup-archive.yml/badge.svg)](https://github.com/rladies/jinx/actions/workflows/ops-meetup-archive.yml)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

Automated data archival and analysis of RLadies+ chapters and events from Meetup.com.
This repository maintains a historical record of RLadies+ community activities and generates analytical reports to support chapter management and community growth.

## 📊 Available Reports

View all reports in the [reports](reports/) directory:

### Chapter Management

- **[Chapter Health Report](reports/chapter-health.qmd)** - Monitors chapter activity, engagement metrics, and identifies chapters needing support
- **[New Chapter Guide](reports/new-chapter-guide.qmd)** - Guidelines and insights for starting and growing new RLadies+ chapters
- **[Geographic Analysis](reports/geographic-analysis.qmd)** - Geographic distribution and regional patterns of chapters worldwide

### Event Analysis

- **[Event Analytics](reports/event-analytics.qmd)** - Comprehensive analysis of events including attendance, frequency, and trends over time
- **[Topic Analysis](reports/topic-analysis.qmd)** - Analysis of event topics, themes, and content areas covered by chapters

### Summary Reports

- **[Quarterly Summary](reports/quarterly-summary.qmd)** - Quarterly overview of community activities and key metrics
- **[Funder Report](reports/funder-report.qmd)** - Summary report for funders and stakeholders highlighting community impact

## 🔄 Data Pipeline

### Automated Data Collection

Meetup data is archived every 12 hours by [Jinx](https://github.com/rladies/jinx), the RLadies+ organisation bot, through its [`ops-meetup-archive.yml`](https://github.com/rladies/jinx/blob/main/.github/workflows/ops-meetup-archive.yml) workflow.
Jinx holds the Meetup credentials, runs the scripts in this repository, and commits the results as `jinx[bot]`:

1. **Archive** (`scripts/archive_all.R`) - Fetches chapters and events from the Meetup Pro API into `archive/raw_data/`, and archives inactive chapters under `archive/inactive_chapters/`
2. **Website data** (`scripts/data_prep_website.R`) - Builds `data/events.json`, `data/chapters.json` and `data/updated.json` for the RLadies+ website
3. **Storage** - The JSON output is committed back to this repository

### Report Generation

Reports are generated using [Quarto](https://quarto.org/) and support multiple output formats:

- HTML (primary format for web viewing)
- PDF (for distribution)
- Markdown (for Hugo static sites, intended for RLadies+ Global website integration)

## 🚀 Getting Started

### Prerequisites

- R (≥ 4.0)
- [Quarto](https://quarto.org/docs/get-started/)
- Meetup API credentials (for data collection)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/rladies/meetup_archive.git
cd meetup_archive
```

2. Restore R package dependencies:

```r
# For data archiving
renv::activate(profile = "archive")
renv::restore()

# For report generation
renv::activate(profile = "reports")
renv::restore()
```

### Running Scripts

#### Collect Data

```r
# Activate archive profile
renv::activate(profile = "archive")

# Fetch chapter data
source("scripts/get_chapters.R")

# Fetch event data
source("scripts/get_events.R")

# Or run complete pipeline
source("scripts/archive_all.R")
```

#### Generate Reports

```bash
# Activate reports profile
RENV_PROFILE="reports"

# Render all reports
quarto render reports/

# Render specific report
quarto render reports/chapter-health.qmd
```

## 🔐 Authentication

Data collection requires Meetup API authentication via the [`meetupr`](https://github.com/rladies/meetupr) package.

For local development:

```r
# Interactive OAuth flow
meetupr::meetup_auth()
```

The scheduled archive authenticates with Jinx's Meetup JWT credentials, so this repository holds no Meetup secrets.
See the "Meetup credentials" section of [Jinx's AGENTS.md](https://github.com/rladies/jinx/blob/main/.github/AGENTS.md) for how they are set up and rotated.

## 📦 Dependencies

The project uses [`renv`](https://rstudio.github.io/renv/) with two separate profiles:

- **`archive` profile** - Packages for data collection (`meetupr`, `httr2`, `jsonlite`, etc.)
- **`reports` profile** - Packages for analysis and visualization (`dplyr`, `ggplot2`, `knitr`, etc.)

## 🤝 Contributing

Contributions are welcome! This repository supports the RLadies+ Global community.

To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For questions or suggestions, please open an issue.
