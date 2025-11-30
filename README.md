# MLB Bayesian Injury Risk vs Workload: Interactive Simulator

This repository contains a Shiny app that lets users explore a simple **Bayesian logistic regression** model for pitcher injury risk as a function of **workload** (average pitches per start).

The app was originally built as an optional activity for a Bayesian statistics course, but it’s also meant to be a clean, sports-themed example of:

- Bayesian regression with priors on regression coefficients  
- Posterior uncertainty visualization  
- Interpretable derived quantities like **odds ratios** and **risk differences**

---

## Live App

You can try the app here:

👉 **[Live Shiny app](https://evan-delcamp.shinyapps.io/optional_activity_bayesian_tool/)**

---

## Concept Overview

We model injury risk for **starting pitchers** in MLB using:

- A binary outcome:  
  - `injury = 1` if the pitcher is injured at least once during the season  
  - `injury = 0` otherwise  
- A continuous predictor:  
  - `workload =` average pitches per start (centered at 85 pitches)

The Bayesian model is:

$$
\text{logit}(p_i) = \beta_0 + \beta_1 x_i,
$$

where $x_i$ is workload (pitches per start, centered at 85) and $p_i$ is the probability pitcher $i$ is injured at least once.

### Priors

The app uses Normal priors on the coefficients:

- **Intercept:**

  - $$\beta_0 \sim \mathcal{N}\big(\mu_0(\pi_{\text{baseline}}), \sigma_0^2\big)$$
  - $\pi_{\text{baseline}}$ = user-chosen prior baseline injury probability at 85 pitches/start  
  - $\mu_0(\pi_{\text{baseline}})$ = log-odds corresponding to that probability  
  - $\sigma_0 = 1.0$

- **Slope:**

  - $$\beta_1 \sim \mathcal{N}(0, \sigma_1^2), \quad \sigma_1 = 0.3$$
  - Prior centered at “no workload effect”  
  - Deliberately diffuse, allowing a wide range of plausible workload effects

Posterior inference is done via **MCMC** using `rstanarm::stan_glm` (NUTS/HMC).

---

## What the App Lets You Do

The app takes a **simple synthetic dataset** summarised into two workload groups:

- **Low-workload group**
  - Number of pitchers
  - Number of injuries
  - Average pitches per start (e.g., 75)

- **High-workload group**
  - Number of pitchers
  - Number of injuries
  - Average pitches per start (e.g., 95)

- **Prior**
  - Slider for prior baseline injury probability at 85 pitches/start

After setting these values and clicking **“Update model”**, the app:

1. Fits a Bayesian logistic regression using `rstanarm`
2. Draws from the posterior of $(\beta_0, \beta_1)$
3. Updates three visualizations:

### 1. Posterior Injury Risk vs Workload

- X-axis: workload (pitches per start)  
- Y-axis: posterior mean injury probability  
- Shaded band: 95% credible interval  
- Shows how estimated injury risk changes as workload increases, and how uncertain that relationship is.

### 2. Posterior Odds Ratio for +10 Pitches

- Histogram of:

  $$\text{OR}_{10} = \exp(10 \beta_1)$$

- Interpreted as the **multiplicative change in odds of injury** for a 10-pitch increase in average workload.
- Red line at 1:
  - Values > 1 → increased odds with higher workload  
  - Values near 1 → weak/uncertain effect

### 3. Posterior Difference in Injury Probability (High vs Low)

- Histogram of:

  $$\Delta = p_{\text{high}} - p_{\text{low}}$$

  where $p_{\text{high}}$ and $p_{\text{low}}$ are posterior injury probabilities at the chosen high/low workloads.
- Red line at 0:
  - Values > 0 → high-workload group is more likely to be injured  
- Directly answers:  
  > “By how many percentage points does injury risk change between these two workload levels?”

---

## Bayesian Concepts Demonstrated

This app is meant as a **teaching/demo tool**, not a full-blown injury model. It illustrates:

- **Prior + likelihood → posterior**  
  Priors on baseline injury and workload effect are combined with data via a Bernoulli–logistic likelihood.

- **Uncertainty via full posterior distributions**  
  Credible intervals, histograms of odds ratios, and risk differences—not just single point estimates.

- **Role of the prior**  
  Changing the baseline injury prior changes the posterior risk curve, especially when sample sizes are small.

- **Derived posterior quantities**  
  The app focuses on interpretable quantities (odds ratios, risk differences) rather than just $\beta_0$ and $\beta_1$.

---

## How to Run Locally

### Requirements

- R (4.x recommended)
- RStudio (optional but convenient)

Install required packages in R:

```r
install.packages(c(
  "shiny",
  "rstanarm",
  "ggplot2"
))
