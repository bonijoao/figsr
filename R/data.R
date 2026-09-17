#' Pima Indians Diabetes Database
#'
#' @description
#' Diagnostic measurements for 768 women of Pima Indian heritage, aged at
#' least 21, together with whether diabetes was diagnosed within five years.
#' Five columns carry physiologically impossible zeros that are, in fact,
#' missing measurements; they are recoded to `NA` in this copy of the data,
#' as documented under Details.
#'
#' @format A data frame with 768 rows and 9 columns:
#' \describe{
#'   \item{Pregnancies}{Number of times pregnant.}
#'   \item{Glucose}{Plasma glucose concentration at 2 hours in an oral
#'     glucose tolerance test.}
#'   \item{BloodPressure}{Diastolic blood pressure (mm Hg).}
#'   \item{SkinThickness}{Triceps skinfold thickness (mm).}
#'   \item{Insulin}{2-hour serum insulin (mu U/mL).}
#'   \item{BMI}{Body mass index, weight in kg divided by height in m,
#'     squared.}
#'   \item{DiabetesPedigreeFunction}{A score of diabetes likelihood based on
#'     family history.}
#'   \item{Age}{Age in years.}
#'   \item{Outcome}{Factor with levels `"no"` and `"yes"`: whether diabetes
#'     was diagnosed within five years.}
#' }
#'
#' @details
#' `Glucose`, `BloodPressure`, `SkinThickness`, `Insulin` and `BMI` cannot be
#' zero in a living patient; a `0` recorded for any of them is a missing
#' measurement encoded as if it were data, a well-documented quirk of this
#' data set. Those zeros are recoded to `NA` here, the standard first
#' preprocessing step for it (see `data-raw/pima_diabetes.R` in the source
#' package for the exact recoding). `Insulin` is missing in 48.7% of records
#' and `SkinThickness` in 29.6%; only 51% of rows are complete on all five.
#' Whether a measurement is missing is not unrelated to the outcome; see
#' `vignette("missing-values", package = "figsr")` for a worked example using
#' `na_method = "mia"`.
#'
#' @source Smith, J. W., Everhart, J. E., Dickson, W. C., Knowler, W. C., and
#'   Johannes, R. S. (1988). Using the ADAP learning algorithm to forecast
#'   the onset of diabetes mellitus. *Proceedings of the Symposium on
#'   Computer Applications and Medical Care*, 261-265. Distributed by the UCI
#'   Machine Learning Repository and, from there, on Kaggle as
#'   \url{https://www.kaggle.com/datasets/uciml/pima-indians-diabetes-database}.
#'
#' @examples
#' data(pima_diabetes)
#' summary(pima_diabetes)
"pima_diabetes"
