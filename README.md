# 🧬 Clinical Genomic Variant & Actionability Explorer

![R](https://img.shields.io/badge/R-276DC3?style=for-the-badge&logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-Blue?style=for-the-badge)
![Data.Table](https://img.shields.io/badge/Data.Table-Fast-success?style=for-the-badge)

A highly optimized R Shiny web application designed for clinical bioinformaticians and genomic researchers. This dashboard allows users to upload primary variant files (`.csv`) and instantly cross-reference their findings against massive clinical databases to identify associated drugs, and clinical trials.

## ✨ Key Features & Architecture

Handling gigabyte-sized genomic datasets in a web browser typically results in memory crashes or severe lag. This application solves that using a **Master-Detail Lazy Query** architecture:

* **Ultra-Fast Ingestion (`data.table`):** Utilizes `fread` and memory indexing (`setkey`) to load and hold the 5GB+ COSMIC Actionability database in the server's RAM exactly once upon startup.
* **Lazy Loading / No Cartesian Joins:** Replaces heavy upfront database joins. Clinical trials are queried in milliseconds *only* when a specific variant is clicked in the main table.
* **Live Fuzzy Matching:** Uses optimized substring matching (`grepl`) to accurately map isolated user genes (e.g., *EGFR*) against complex mutation strings in the COSMIC database (e.g., *(EGFR_Exon_19...*).
* **Interactive Filtering:** Features synchronized sliders for Allele Frequency (AF) and Total Scores, alongside Bootstrap 5-safe virtualized dropdowns (`shinyWidgets`) that handle thousands of VEP Consequences without UI lag.
* **Responsive UI:** Clean, single-page layout built with `bslib`, featuring live Key Performance Indicators (KPIs) and exportable data tables (`DT`).

---

## 🚀 Getting Started

### 1. Prerequisites
Ensure you have **R (>= 4.0.0)** and RStudio installed. The application relies on the following R packages:
* `shiny`
* `DT`
* `dplyr`
* `data.table`
* `bslib`
* `shinyWidgets`

*Note: The app includes an auto-install script that will attempt to install these packages if you do not already have them.*

### 2. Database Preparation (Crucial Step)
Because the COSMIC Actionability TSV is over 5GB, it is not included in this repository. You must download it locally before running the app.

1. Download the `Actionability_AllData_v20_GRCh37.tsv` (or your specific version) from the COSMIC database.
2. Place the `.tsv` file in the **same root directory** as `app.R`.
3. Ensure the filename matches the string inside the `fread()` function at the top of the `app.R` script.

### 3. Running the Application
Open `app.R` in RStudio and click the **Run App** button, or run the following command in your R console:

```R
shiny::runApp("path/to/directory")


📖 How to Use
Upload Data: Use the sidebar to upload your primary variant file (.csv). The app supports uploads up to 1GB.

Filter & Explore: Use the sidebar dropdowns, text searches, and sliders to narrow down your variant list. The KPI cards at the top will update in real-time.

Query Actionability: The top table (Table 1) displays your uploaded variants. Click on any row in this table.

View Clinical Trials: The bottom table (Table 2) will instantly trigger a fuzzy-match query against the 5GB COSMIC database in memory, displaying all clinical trials, drugs, and phases associated with the specific gene you clicked.

📁 Repository Structure
Plaintext
├── app.R                                    # Main Shiny application script (UI & Server)
├── Actionability_AllData_v20_GRCh37.tsv     # 5GB+ COSMIC database (Not tracked via Git)
├── sample_variant_data.csv                  # (Optional) Small mock dataset for testing
└── README.md                                # Project documentation
🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the issues page if you want to contribute.

📝 License
This project is licensed under the MIT License.
