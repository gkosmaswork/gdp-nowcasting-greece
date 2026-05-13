# ==========================================
# 0. SETUP & PACKAGES
# ==========================================
if(!require(readr)) install.packages("readr")
if(!require(dplyr)) install.packages("dplyr")
if(!require(lubridate)) install.packages("lubridate")
if(!require(zoo)) install.packages("zoo")
if(!require(tidyverse)) install.packages("tidyverse")
if(!require(broom)) install.packages("broom")
library(readr)
library(dplyr)
library(lubridate)
library(zoo)
library(tidyverse)
library(broom) 
library(ggplot2)
library(broom)

# ==========================================
# 1. DATA LOADING & CLEANING
# ==========================================

# Print instructions for the user
print("STEP 1: Select your GDP CSV (gdp_m.csv)")
# Reading the broken Greek CSV correctly with ISO-8859-7 encoding
gdp_data <- read_delim(file.choose(), 
                       delim = ";", 
                       skip = 4, 
                       locale = locale(encoding = "ISO-8859-7"),
                       show_col_types = FALSE)

print("STEP 2: Select your Trends CSV (multiTimeline_m.csv)")
trends_path <- file.choose()

# 1. Cleaning and Rotating the GDP
gdp_clean <- gdp_data %>%
  slice(1) %>%
  select(-1) %>% 
  pivot_longer(cols = everything(), names_to = "garbage_date", values_to = "gdp") %>%
  select(gdp) %>%
  mutate(gdp = as.numeric(gdp)) %>%
  # Adding proper Quarterly Dates (1995 to present)
  mutate(date = seq(from = as.Date("1995-01-01"), 
                    by = "quarter", 
                    length.out = n()))

# 2. Cleaning Google Trends
vacation_data <- read_csv(trends_path, skip = 2, show_col_types = FALSE)

trends_clean <- vacation_data %>%
  rename(date = Month, trend = `Vacation: (Greece)`) %>%
  mutate(date = as.Date(paste0(date, "-01"))) %>%
  mutate(quarter = as.yearqtr(date))

# Aggregating Monthly Trends to Quarterly Averages
trends_clean_quarterly <- trends_clean %>%
  group_by(quarter) %>%
  summarise(trend_avg = mean(trend, na.rm = TRUE)) %>%
  mutate(date = as.Date(quarter)) %>%
  select(date, trend_avg)

# 3. Merging the Data
dataset_predictor_vacation <- inner_join(gdp_clean, trends_clean_quarterly, by = "date")

# Quick visual check of the merge
print("Data merged successfully. Preview:")
print(head(dataset_predictor_vacation))


# ==========================================
# 2. THE PROFESSOR'S REQUIREMENT (The Split)
# ==========================================

# 1. Define the Cutoff (2023 Q3)
cutoff_date <- as.Date("2023-07-01")

# 2. Creating Training Set (History up to Q3 2023)
train_data <- dataset_predictor_vacation %>%
  filter(date <= cutoff_date)

# 3. THE FIX: Restricted Test Set (Q4 2023 - Q2 2024 ONLY)
test_data_restricted <- dataset_predictor_vacation %>%
  filter(date > as.Date("2023-07-01") & date <= as.Date("2024-04-01"))

print(paste("Training Observations (N):", nrow(train_data)))
print(paste("Testing Observations (N):", nrow(test_data_restricted)))

# ==========================================
# 3. MODELING & DIAGNOSTICS (With Seasonality) #credits to Karaganis for the idea
# ==========================================

train_data <- train_data %>%
  mutate(season = as.factor(quarters(date)))

# Apply seasonality factor to the restricted test set
test_data_restricted <- test_data_restricted %>%
  mutate(season = as.factor(quarters(date)))

# Fit the Model with Seasonality Dummies
m1_restricted <- lm(gdp ~ trend_avg + season, data = train_data)

print("--- MODEL SUMMARY (TRAINING DATA WITH SEASONALITY) ---")
print(summary(m1_restricted))
#===========================================
#Step 3.1 the conditions according to duke the LINE ones
# 5. DIAGNOSTICS WITH GGPLOT2 (The "LINE" Check)
# ==========================================

# 1. Get the data from the model (Residuals, Fitted values, etc.)
model_diagnostics <- augment(m1_restricted) %>%
  mutate(obs_number = row_number()) # Add an index for the Independence plot

# --- GRAPH 1: LINEARITY (Residuals vs. Fitted) ---
# Goal: A horizontal line with no curves.
 ggplot(model_diagnostics, aes(x = .fitted, y = .resid)) +
  geom_point(color = "#2C3E50", alpha = 0.6) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  geom_smooth(se = FALSE, color = "blue", size = 0.8) +
  labs(title = "1. Linearity Check",
       subtitle = "Residuals vs Fitted (Should be flat)",
       x = "Fitted Values", y = "Residuals") +
  theme_minimal()

# --- GRAPH 2: INDEPENDENCE (Residuals vs. Time) ---
# Goal: No waves  over time.
# Note: This is crucial for your GDP data (Time Series).
 ggplot(model_diagnostics, aes(x = obs_number, y = .resid)) +
  geom_line(color = "gray") +
  geom_point(color = "#2C3E50") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  labs(title = "2. Independence Check",
       subtitle = "Residuals over Time (Look for patterns)",
       x = "Time (Observation Order)", y = "Residuals") +
  theme_minimal()

# --- GRAPH 3: NORMALITY (Q-Q Plot) ---
# Goal: Dots should hug the diagonal line.
 ggplot(model_diagnostics, aes(sample = .resid)) +
  stat_qq(color = "#2C3E50") +
  stat_qq_line(color = "red", linetype = "dashed") +
  labs(title = "3. Normality Check",
       subtitle = "Normal Q-Q Plot (Should follow line)",
       x = "Theoretical Quantiles", y = "Sample Quantiles") +
  theme_minimal()

# --- GRAPH 4: EQUAL VARIANCE (Scale-Location) ---
# Goal: A flat line, dots spread evenly (no cone shape).
 ggplot(model_diagnostics, aes(x = .fitted, y = sqrt(abs(.std.resid)))) +
  geom_point(color = "#2C3E50", alpha = 0.6) +
  geom_smooth(se = FALSE, color = "blue", size = 0.8) +
  labs(title = "4. Equal Variance Check",
       subtitle = "Scale-Location (Should be flat)",
       x = "Fitted Values", y = "Sqrt(|Standardized Residuals|)") +
  theme_minimal()

# ==========================================
# 4. FORECASTING & MAPE (The Performance Check)
# ==========================================

# Predict GDP for the Restricted Test Set
predictions <- predict(m1_restricted, newdata = test_data_restricted)

# Compare Prediction vs Reality
results_table <- data.frame(
  Date = test_data_restricted$date,
  Actual_GDP = test_data_restricted$gdp,
  Predicted_GDP = predictions,
  Error = test_data_restricted$gdp - predictions,
  Abs_Error_Pct = abs((test_data_restricted$gdp - predictions) / test_data_restricted$gdp) * 100
)

print("--- FORECAST RESULTS (Q4 2023 - Q2 2024 ONLY) ---")
print(results_table)

# Calculate MAPE for the specific window
mape_score <- mean(results_table$Abs_Error_Pct)
print(paste("FINAL MAPE SCORE (Seasonal):", round(mape_score, 2), "%"))

# ==========================================
# STEP 5: THE LAG UPGRADE (Sandbox Mode - RESTRICTED)
# ==========================================
print("--- TESTING THE 'TIME LAG' HYPOTHESIS (RESTRICTED WINDOW) ---")

dataset_lagged <- dataset_predictor_vacation %>%
  arrange(date) %>%
  mutate(trend_prev_Q = lag(trend_avg, n = 1)) %>%
  filter(!is.na(trend_prev_Q)) 

train_lag <- dataset_lagged %>% filter(date <= cutoff_date)

# Restricted Lag Test Set
test_lag_restricted <- dataset_lagged %>% 
  filter(date > as.Date("2023-07-01") & date <= as.Date("2024-04-01"))

train_lag <- train_lag %>% mutate(season = as.factor(quarters(date)))
test_lag_restricted <- test_lag_restricted %>% mutate(season = as.factor(quarters(date)))

m_lagged <- lm(gdp ~ trend_prev_Q + season, data = train_lag)

predictions_lag <- predict(m_lagged, newdata = test_lag_restricted)

results_lag <- data.frame(
  Date = test_lag_restricted$date,
  Real_GDP = test_lag_restricted$gdp,
  Predicted_GDP_Lag = predictions_lag,
  Abs_Error_Pct = abs((test_lag_restricted$gdp - predictions_lag) / test_lag_restricted$gdp) * 100
)

mape_lag <- mean(results_lag$Abs_Error_Pct)

print(paste("MAIN SEASONAL MAPE (Immediate):", round(mape_score, 2), "%"))
print(paste("LAG SEASONAL MAPE (Previous Q):", round(mape_lag, 2), "%"))
if(mape_lag < mape_score) {
  print("VERDICT: The Lag Model WINS! People search months before they spend.")
} else {
  print("VERDICT: The Lag Model LOST. Immediate search is the better predictor.")
}
# Reshape data so ggplot can draw two lines (Actual vs Predicted)
plot_data <- results_table %>%
  select(Date, Actual_GDP, Predicted_GDP) %>%
  pivot_longer(cols = c("Actual_GDP", "Predicted_GDP"), 
               names_to = "Legend", 
               values_to = "GDP")

# Draw the lines
ggplot(plot_data, aes(x = Date, y = GDP, color = Legend)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Actual_GDP" = "black", "Predicted_GDP" = "red")) +
  labs(title = "Actual vs Predicted GDP (Q4 2023 - Q2 2024 non lag)",
       subtitle = paste("It's not perfect, but it tracks. MAPE:", round(mape_score, 2), "%"),
       y = "GDP (Millions)", x = "") +
  theme_minimal() +
  theme(legend.position = "bottom")

# Reshape the LAG results
plot_data_lag <- results_lag %>%
  select(Date, Real_GDP, Predicted_GDP_Lag) %>%
  rename(Actual_GDP = Real_GDP) %>% # Renaming for consistency in the legend
  pivot_longer(cols = c("Actual_GDP", "Predicted_GDP_Lag"), 
               names_to = "Legend", 
               values_to = "GDP")

# Plotting the Lag Model results
ggplot(plot_data_lag, aes(x = Date, y = GDP, color = Legend)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  # Using a fresh color palette: Deep Blue and Orange
  scale_color_manual(values = c("Actual_GDP" = "#2C3E50", "Predicted_GDP_Lag" = "#D35400")) +
  labs(title = "Lag Model Check: Actual vs. Predicted GDP",
       subtitle = paste("Testing if 'Previous Quarter Searches' predict better. MAPE:", round(mape_lag, 2), "%"),
       y = "GDP (Millions)", x = "") +
  theme_minimal() +
  theme(legend.position = "bottom")