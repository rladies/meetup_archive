# R-Ladies Meetup Archive

[![Archive meetup data](https://github.com/rladies/meetup_archive/workflows/Archive%20meetup%20data/badge.svg)](https://github.com/rladies/meetup_archive/actions)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

Automated data archival and analysis of R-Ladies chapters and events from Meetup.com. 
This repository maintains a historical record of R-Ladies community activities and generates analytical reports to support chapter management and community growth.

## 📊 Available Reports

View all reports in the [reports](reports/) directory:

### Chapter Management
- **[Chapter Health Report](reports/chapter-health.html)** - Monitors chapter activity, engagement metrics, and identifies chapters needing support
- **[New Chapter Guide](reports/new-chapter-guide.html)** - Guidelines and insights for starting and growing new R-Ladies chapters
- **[Geographic Analysis](reports/geographic-analysis.html)** - Geographic distribution and regional patterns of chapters worldwide

### Event Analysis
- **[Event Analytics](reports/event-analytics.html)** - Comprehensive analysis of events including attendance, frequency, and trends over time
- **[Topic Analysis](reports/topic-analysis.html)** - Analysis of event topics, themes, and content areas covered by chapters

### Summary Reports
- **[Quarterly Summary](reports/quarterly-summary.html)** - Quarterly overview of community activities and key metrics
- **[Funder Report](reports/funder-report.html)** - Summary report for funders and stakeholders highlighting community impact

## 🔄 Data Pipeline

### Automated Data Collection
The repository uses GitHub Actions to automatically archive Meetup data every 12 hours:

1. **Chapter Data** (`scripts/get_chapters.R`) - Fetches current information about all R-Ladies chapters
2. **Event Data** (`scripts/get_events.R`) - Retrieves event details including dates, attendance, and topics
3. **Storage** - Data is saved as JSON in the `data/` directory and committed to the repository

### Report Generation
Reports are generated using [Quarto](https://quarto.org/) and support multiple output formats:
- HTML (primary format for web viewing)  
- PDF (for distribution)  
- Markdown (for Hugo static sites, intended for R-Ladies Global website integration)  

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

For GitHub Actions, set the following secrets:  
- `"meetupr:token"` - Encrypted OAuth token  
- `"meetupr:token_file"` - Token file content  

## 📦 Dependencies

The project uses [`renv`](https://rstudio.github.io/renv/) with two separate profiles:

- **`archive` profile** - Packages for data collection (`meetupr`, `httr2`, `jsonlite`, etc.)  
- **`reports` profile** - Packages for analysis and visualization (`dplyr`, `ggplot2`, `knitr`, etc.)  

## 🤝 Contributing

Contributions are welcome! This repository supports the R-Ladies Global community. 

To contribute:  
1. Fork the repository  
2. Create a feature branch  
3. Make your changes  
4. Submit a pull request  

For questions or suggestions, please open an issue.
