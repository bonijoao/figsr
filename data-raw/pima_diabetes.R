# Builds data/pima_diabetes.rda from the raw source file below.
#
# Run this script from the package root to reproduce data/pima_diabetes.rda.
# It is not part of the built package (data-raw/ is listed in
# .Rbuildignore); only its output, data/pima_diabetes.rda, ships.
#
# Source: Smith, J. W., Everhart, J. E., Dickson, W. C., Knowler, W. C., and
# Johannes, R. S. (1988). Using the ADAP learning algorithm to forecast the
# onset of diabetes mellitus. Proceedings of the Symposium on Computer
# Applications and Medical Care, 261-265. Distributed by the UCI Machine
# Learning Repository and, from there, on Kaggle as
# kaggle.com/datasets/uciml/pima-indians-diabetes-database.

raw <- read.csv("data-raw/pima-diabetes-raw.csv")

# Glucose, BloodPressure, SkinThickness, Insulin and BMI cannot be zero in a
# living patient; a 0 recorded for any of them is a missing measurement
# encoded as if it were data, a well-documented quirk of this data set and
# the standard first preprocessing step for it. Recoded to NA here so the
# data set ships ready to demonstrate na_method = "mia".
zero_as_na_cols <- c("Glucose", "BloodPressure", "SkinThickness", "Insulin", "BMI")
for (col in zero_as_na_cols) raw[[col]][raw[[col]] == 0] <- NA

raw$Outcome <- factor(raw$Outcome, levels = c(0, 1), labels = c("no", "yes"))

pima_diabetes <- raw
save(pima_diabetes, file = "data/pima_diabetes.rda", compress = "bzip2")
