# gdp-nowcasting-greece
An out-of-sample linear regression model nowcasting quarterly Greek GDP using real-time Google Trends search data.
# Nowcasting Greek GDP via Google Trends 📈🇬🇷

**Author:** [Your Name]  
**Language:** R  
**Core Packages:** `tidyverse`, `zoo`, `lubridate`, `broom`, `ggplot2`

---

## 📌 Project Executive Summary
Official macroeconomic indicators like Gross Domestic Product (GDP) are typically published with significant time lags. This project builds an out-of-sample Ordinary Least Squares (OLS) forecasting engine to **nowcast** quarterly Greek GDP using real-time consumer search volume indices extracted from Google Trends. 

Rather than relying on pre-cleaned data, this project implements an end-to-end analytical pipeline: from raw microdata ingestion and localized encoding translation to feature engineering, strict econometric diagnostics, and predictive performance scoring.

---

## 🛠️ Data Architecture & Pipeline Design
Handling real-world, unformatted datasets required custom wrangling strategies before modeling:
* **Microdata Ingestion:** Programmatically parsed localized historical GDP spreadsheets, resolving native `ISO-8859-7` character encodings, stripping metadata headers, and unpivoting wide matrices into clean time-series formats.
* **Temporal Aggregation:** Standardized disparate reporting frequencies by mapping monthly Google Trends search metrics (`Vacation: Greece`) into aggregated quarterly averages utilizing the `zoo` library.
* **Relational Merging:** Executed precise inner joins across economic and behavioral datasets aligned strictly on standardized quarterly timestamps.

---

## 🧠 Feature Engineering & Behavioral Hypotheses
To capture actual macroeconomic behaviors, the model integrates two advanced feature sets:
1. **Seasonality Adjustments:** Engineered categorical dummy variables (`quarters(date)`) to isolate and control for severe seasonal fluctuations inherent to the Greek economy (e.g., Q3 summer tourism surges).
2. **The Time-Lag Hypothesis:** Formulated and tested a behavioral lag model comparing immediate search volumes against previous-quarter search indices (`lag(n = 1)`). This sandbox test evaluates whether consumers research significant expenditures months prior to capital execution.

---

## 📊 Econometric Diagnostics (The "LINE" Protocol)
To ensure classical linear regression validity, the model explicitly tests core Gauss-Markov assumptions visually using `broom` and `ggplot2` rather than relying solely on overall model fit ($R^2$):
* **Linearity:** Evaluated via Residuals vs. Fitted value mapping to ensure flat tracking.
* **Independence:** Monitored residual sequences over time to detect unmodeled serial correlation in the time series.
* **Normality:** Verified error term distributions using standardized Q-Q plots.
* **Homoscedasticity:** Validated constant variance across residuals using Scale-Location transformations.

---

## 🎯 Forecasting Performance & Out-of-Sample Testing
To prevent overfitting and prove true real-world utility, the models were evaluated using a strict temporal split:
* **Training Window:** Historical data up to Q3 2023.
* **Restricted Test Window:** Blind out-of-sample forecasting from Q4 2023 to Q2 2024.
* **Evaluation Metric:** Models are bench-marked against actual realized GDP using **Mean Absolute Percentage Error (MAPE)** to determine whether immediate or lagged consumer intent yields superior predictive accuracy.

---

## 🚀 How to Execute the Script
1. Clone this repository to your local machine and open the primary `.R` script in RStudio.
2. Ensure the raw data dependencies (`gdp_m.csv` and `multiTimeline_m.csv`) are located in your working directory.
3. Execute the script. The console automatically outputs OLS regression summaries, generates the four core diagnostic verification plots, prints the side-by-side forecast matrix, and returns the final comparative MAPE scores.
