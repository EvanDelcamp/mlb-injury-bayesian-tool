library(shiny)
library(rstanarm)   # <-- use rstanarm instead of cmdstanr
library(ggplot2)

# optional:
# options(mc.cores = parallel::detectCores())
# rstan_options(auto_write = TRUE)

# ---------- Core functions ----------

build_data <- function(n_low, inj_low, n_high, inj_high,
                       workload_low, workload_high) {

  if (inj_low  > n_low)  stop("inj_low cannot be greater than n_low")
  if (inj_high > n_high) stop("inj_high cannot be greater than n_high")

  data.frame(
    injury = c(
      rep(1, inj_low),
      rep(0, n_low - inj_low),
      rep(1, inj_high),
      rep(0, n_high - inj_high)
    ),
    workload = c(
      rep(workload_low,  n_low),
      rep(workload_high, n_high)
    )
  )
}

fit_injury_model <- function(df,
                             center_at     = 85,
                             baseline_risk = 0.30,
                             sigma_beta0   = 1.0,  # prior SD for intercept
                             sigma_beta1   = 0.3)  # prior SD for slope
{
  df$workload_centered <- df$workload - center_at

  # Prior on intercept: centered at logit(baseline_risk)
  prior_intercept <- normal(
    location  = qlogis(baseline_risk),
    scale     = sigma_beta0,
    autoscale = FALSE
  )

  # Prior on slope: Normal(0, sigma_beta1)
  prior <- normal(
    location  = 0,
    scale     = sigma_beta1,
    autoscale = FALSE
  )

  fit_stan <- stan_glm(
    injury ~ workload_centered,
    data   = df,
    family = binomial("logit"),
    prior_intercept = prior_intercept,
    prior           = prior,
    chains = 2,
    iter   = 2000,
    refresh = 0
  )

  list(
    stanfit   = fit_stan,
    center_at = center_at
  )
}

posterior_curve <- function(fit, from = 60, to = 110) {
  # grid in original workload scale
  work_grid <- data.frame(
    workload_centered = seq(from, to, by = 1) - fit$center_at
  )

  # draws x grid_points matrix of posterior predictive probabilities
  pred_mat <- posterior_linpred(
    fit$stanfit,
    newdata   = work_grid,
    transform = TRUE
  )

  mean_risk <- apply(pred_mat, 2, mean)
  lower     <- apply(pred_mat, 2, quantile, 0.025)
  upper     <- apply(pred_mat, 2, quantile, 0.975)

  data.frame(
    workload  = work_grid$workload_centered + fit$center_at,
    mean_risk = mean_risk,
    lower     = lower,
    upper     = upper
  )
}

# ---------- UI ----------

ui <- fluidPage(
  titlePanel("Bayesian Injury Risk vs Workload (Pitches per Start)"),

  sidebarLayout(
    sidebarPanel(
      h4("Data inputs"),
      numericInput("n_low",  "Low-workload pitchers (N)",   value = 100, min = 5),
      numericInput("inj_low","Injuries in low group",       value = 15,  min = 0),
      numericInput("n_high", "High-workload pitchers (N)",  value = 100, min = 5),
      numericInput("inj_high","Injuries in high group",     value = 30,  min = 0),

      sliderInput("workload_low",  "Low workload (pitches/start)",
                  min = 50, max = 100, value = 75, step = 1),
      sliderInput("workload_high", "High workload (pitches/start)",
                  min = 70, max = 120, value = 95, step = 1),

      hr(),
      h4("Prior on baseline risk"),
      sliderInput("baseline_risk",
                  "Prior injury probability at 85 pitches/start",
                  min = 0.01, max = 0.60, value = 0.30, step = 0.01),

      helpText(
        "Interpret this as: for a typical pitcher with ~85 pitches/start, ",
        "before seeing the data, what do you believe their chance of at least ",
        "one injury in a season is? It may make sense to use the league-wide ",
        "rate of the injury being considered if that is known."
      ),

      hr(),
      actionButton("fit_btn", "Update model")
    ),

    mainPanel(
      plotOutput("risk_plot",  height = "350px"),
      br(),
      
      plotOutput("or_plot",    height = "250px"),
      helpText("The histogram shows the posterior distribution of how much injury odds ",
               "change for a 10-pitch increase in average workload. A value of 1 (red line) ",
               "means no effect; values above 1 mean higher workload increases injury odds."),
      br(),
      
      plotOutput("delta_plot", height = "250px"),
      helpText(
        "The bottom histogram shows the posterior distribution of the difference ",
        "in injury probability between the chosen high- and low-workload groups ",
        "(high minus low). The red vertical line at 0 represents no difference: ",
        "values to the right of 0 mean the high-workload group is more likely to be injured, ",
        "and values to the left mean the high-workload group is less likely to be injured."
      )
      
    )
  )
)

# ---------- Server ----------

server <- function(input, output, session) {

  data_df <- reactive({
    build_data(
      n_low        = input$n_low,
      inj_low      = input$inj_low,
      n_high       = input$n_high,
      inj_high     = input$inj_high,
      workload_low = input$workload_low,
      workload_high= input$workload_high
    )
  })

  fit_reactive <- eventReactive(input$fit_btn, {
    df <- data_df()
    fit_injury_model(
      df,
      center_at     = 85,
      baseline_risk = input$baseline_risk
    )
  })

  curve_reactive <- reactive({
    fit <- fit_reactive()
    req(fit)
    posterior_curve(fit, from = 60, to = 110)
  })

  output$risk_plot <- renderPlot({
    curve_df <- curve_reactive()
    ggplot(curve_df, aes(x = workload)) +
      geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2) +
      geom_line(aes(y = mean_risk)) +
      labs(
        x = "Pitches per start",
        y = "Posterior injury probability",
        title = "Injury risk vs workload"
      ) +
      ylim(0, 1)
  })
  
  # Posterior for workload effect as odds ratio per +10 pitches
  output$or_plot <- renderPlot({
    fit <- fit_reactive()
    req(fit)
    
    beta_mat <- as.matrix(fit$stanfit)
    beta1    <- beta_mat[, "workload_centered"]
    
    # Odds ratio for a +10 pitch increase
    or10 <- exp(10 * beta1)
    
    hist(or10, breaks = 30,
         main = "Posterior odds ratio for +10 pitches/start",
         xlab = "Odds ratio (10-pitch increase)")
    abline(v = 1, col = "red", lwd = 2)  # 1 = no effect
  })
  
  # Posterior difference in injury probability (high - low workload)
  output$delta_plot <- renderPlot({
    fit <- fit_reactive()
    req(fit)
    
    beta_mat <- as.matrix(fit$stanfit)
    beta0    <- beta_mat[, "(Intercept)"]
    beta1    <- beta_mat[, "workload_centered"]
    
    # Centered workloads for the chosen low/high values
    x_low  <- input$workload_low  - 85
    x_high <- input$workload_high - 85
    
    # Posterior injury probabilities at low and high workloads
    p_low  <- plogis(beta0 + beta1 * x_low)
    p_high <- plogis(beta0 + beta1 * x_high)
    
    delta  <- p_high - p_low  # difference in probability
    
    hist(delta, breaks = 30,
         main = "Posterior difference in injury probability\n(high - low workload)",
         xlab = "Difference in probability (high - low)")
    abline(v = 0, col = "red", lwd = 2)  # 0 = no difference
  })
}

shinyApp(ui, server)
