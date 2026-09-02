########################################################################
# Silver as a Safe-Haven: Regression Analysis of Daily Silver Returns
# STA302 Final Project
#
# This script fits and evaluates a multiple linear regression model
# explaining daily silver returns using gold, equity, oil, and other
# precious-metal / FX market indicators.
#
# Data: data/model_data.csv (pre-cleaned daily series, 2010-01-19 to 2024-10-18)
# Note: all price series are daily closing SPOT prices (cash market),
# not futures contracts -- there is no roll-adjustment step because
# none is needed for this data.
########################################################################

library(tidyverse)  # data wrangling
library(car)        # vif()

# ------------------------------------------------------------------
# 1. Load data
# ------------------------------------------------------------------
# data/model_data.csv is the ready-to-model dataset: daily log-returns
# and lagged returns already computed from the raw daily price levels
# (silver, gold, S&P 500, Nasdaq, oil, platinum, palladium, USD/CHF,
# EUR/USD). Section 2 below documents, for reproducibility, exactly how
# that transformation was done from the original price-level series.

model_data <- read_csv("data/model_data.csv")

# ------------------------------------------------------------------
# 2. Why log-returns instead of price levels (reference / reproducibility)
# ------------------------------------------------------------------
# Daily price *levels* trend over time and have growing variance, which
# violates the linearity and homoscedasticity assumptions of OLS, and
# tend to produce spurious high R^2 values driven by shared trends
# rather than real relationships. Converting to daily log-returns:
#   r_t = log(P_t) - log(P_{t-1})
# stabilizes variance, straightens relationships between markets,
# produces more symmetric/near-normal residuals, and gives coefficients
# an intuitive "percent change" interpretation.
#
# Starting from a raw data frame `data_final` with *.close price levels:
#
#   data_final <- data_final[order(data_final$date), ]
#   data_final$log_silver <- log(data_final$silver.close)
#   data_final$log_gold   <- log(data_final$gold.close)
#   data_final$log_sp500  <- log(data_final$sp500.close)
#   data_final$log_oil    <- log(data_final$oil.close)
#   data_final$log_nasdaq <- log(data_final$nasdaq.close)
#
#   data_final$silver_ret <- c(NA, diff(data_final$log_silver))
#   data_final$gold_ret   <- c(NA, diff(data_final$log_gold))
#   data_final$sp500_ret  <- c(NA, diff(data_final$log_sp500))
#   data_final$oil_ret    <- c(NA, diff(data_final$log_oil))
#   data_final$nasdaq_ret <- c(NA, diff(data_final$log_nasdaq))
#
#   # 1-day lagged returns, to capture short-term persistence / spillover
#   data_final$silver_ret_lag1 <- c(NA, data_final$silver_ret[-nrow(data_final)])
#   data_final$gold_ret_lag1   <- c(NA, data_final$gold_ret[-nrow(data_final)])
#   data_final$sp500_ret_lag1  <- c(NA, data_final$sp500_ret[-nrow(data_final)])
#
#   data_final <- data_final[complete.cases(data_final), ]

# ------------------------------------------------------------------
# 3. Full model
# ------------------------------------------------------------------
full_model <- lm(
  silver_ret ~ gold_ret + sp500_ret + nasdaq_ret + oil_ret +
    silver_ret_lag1 + gold_ret_lag1 + sp500_ret_lag1 +
    platinum.close + palladium.close +
    usd_chf + eur_usd + sp500.spread,
  data = model_data
)
summary(full_model)

par(mfrow = c(2, 2)); plot(full_model)   # residual diagnostics
vif(full_model)                          # multicollinearity check

# ------------------------------------------------------------------
# 4. Model selection: drop statistically weak / redundant predictors
#    (t-test p-values in full model), then confirm with partial F-test,
#    adjusted R^2, AIC, and BIC.
# ------------------------------------------------------------------
reduced_model <- lm(
  silver_ret ~ gold_ret + sp500_ret + nasdaq_ret + oil_ret +
    gold_ret_lag1 + sp500_ret_lag1 + platinum.close,
  data = model_data
)
summary(reduced_model)

par(mfrow = c(2, 2)); plot(reduced_model)
vif(reduced_model)

anova(reduced_model, full_model)                 # partial F-test
summary(full_model)$adj.r.squared
summary(reduced_model)$adj.r.squared
AIC(full_model, reduced_model)
BIC(full_model, reduced_model)

# ------------------------------------------------------------------
# 5. Inference: confidence intervals
# ------------------------------------------------------------------
confint(reduced_model)

# ------------------------------------------------------------------
# 6. Out-of-sample style check: single-point prediction interval
# ------------------------------------------------------------------
new_point <- model_data[100, ]
predict(reduced_model, newdata = new_point, interval = "prediction")
actual_value <- model_data$silver_ret[101]
actual_value

# ------------------------------------------------------------------
# 7. Diagnostic plots referenced in the report/poster
# ------------------------------------------------------------------
plot(reduced_model, which = 2)  # Q-Q (heavy tails)
plot(reduced_model, which = 3)  # Scale-Location (heteroskedasticity)
