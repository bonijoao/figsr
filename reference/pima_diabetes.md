# Pima Indians Diabetes Database

Diagnostic measurements for 768 women of Pima Indian heritage, aged at
least 21, together with whether diabetes was diagnosed within five
years. Five columns carry physiologically impossible zeros that are, in
fact, missing measurements; they are recoded to `NA` in this copy of the
data, as documented under Details.

## Usage

``` r
pima_diabetes
```

## Format

A data frame with 768 rows and 9 columns:

- Pregnancies:

  Number of times pregnant.

- Glucose:

  Plasma glucose concentration at 2 hours in an oral glucose tolerance
  test.

- BloodPressure:

  Diastolic blood pressure (mm Hg).

- SkinThickness:

  Triceps skinfold thickness (mm).

- Insulin:

  2-hour serum insulin (mu U/mL).

- BMI:

  Body mass index, weight in kg divided by height in m, squared.

- DiabetesPedigreeFunction:

  A score of diabetes likelihood based on family history.

- Age:

  Age in years.

- Outcome:

  Factor with levels `"no"` and `"yes"`: whether diabetes was diagnosed
  within five years.

## Source

Smith, J. W., Everhart, J. E., Dickson, W. C., Knowler, W. C., and
Johannes, R. S. (1988). Using the ADAP learning algorithm to forecast
the onset of diabetes mellitus. *Proceedings of the Symposium on
Computer Applications and Medical Care*, 261-265. Distributed by the UCI
Machine Learning Repository and, from there, on Kaggle as
<https://www.kaggle.com/datasets/uciml/pima-indians-diabetes-database>.

## Details

`Glucose`, `BloodPressure`, `SkinThickness`, `Insulin` and `BMI` cannot
be zero in a living patient; a `0` recorded for any of them is a missing
measurement encoded as if it were data, a well-documented quirk of this
data set. Those zeros are recoded to `NA` here, the standard first
preprocessing step for it (see `data-raw/pima_diabetes.R` in the source
package for the exact recoding). `Insulin` is missing in 48.7% of
records and `SkinThickness` in 29.6%; only 51% of rows are complete on
all five. Whether a measurement is missing is not unrelated to the
outcome; see
[`vignette("missing-values", package = "figsr")`](https://bonijoao.github.io/figsr/articles/missing-values.md)
for a worked example using `na_method = "mia"`.

## Examples

``` r
data(pima_diabetes)
summary(pima_diabetes)
#>   Pregnancies        Glucose      BloodPressure    SkinThickness  
#>  Min.   : 0.000   Min.   : 44.0   Min.   : 24.00   Min.   : 7.00  
#>  1st Qu.: 1.000   1st Qu.: 99.0   1st Qu.: 64.00   1st Qu.:22.00  
#>  Median : 3.000   Median :117.0   Median : 72.00   Median :29.00  
#>  Mean   : 3.845   Mean   :121.7   Mean   : 72.41   Mean   :29.15  
#>  3rd Qu.: 6.000   3rd Qu.:141.0   3rd Qu.: 80.00   3rd Qu.:36.00  
#>  Max.   :17.000   Max.   :199.0   Max.   :122.00   Max.   :99.00  
#>                   NAs    :5       NAs    :35       NAs    :227    
#>     Insulin            BMI        DiabetesPedigreeFunction      Age       
#>  Min.   : 14.00   Min.   :18.20   Min.   :0.0780           Min.   :21.00  
#>  1st Qu.: 76.25   1st Qu.:27.50   1st Qu.:0.2437           1st Qu.:24.00  
#>  Median :125.00   Median :32.30   Median :0.3725           Median :29.00  
#>  Mean   :155.55   Mean   :32.46   Mean   :0.4719           Mean   :33.24  
#>  3rd Qu.:190.00   3rd Qu.:36.60   3rd Qu.:0.6262           3rd Qu.:41.00  
#>  Max.   :846.00   Max.   :67.10   Max.   :2.4200           Max.   :81.00  
#>  NAs    :374      NAs    :11                                              
#>  Outcome  
#>  no :500  
#>  yes:268  
#>           
#>           
#>           
#>           
#>           
```
