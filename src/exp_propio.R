# Load the necessary libraries for data analysis and visualization
library(ggplot2)  # For creating plots
library(dplyr)    # For data manipulation
library(gridExtra)

# Constants and global variables
PARALLELIZE <- TRUE # Set the option for parallelization of computations
N_THREADS <- 30     # Define the number of threads for parallel processing
N_BINS <- 10        # Define the number of bins for discretization
RERUN_EXP <- FALSE   # Set the option to rerun the experiment

# Load provided functions
set.seed(589115021)
source("provided_functions.R")

sub_sample <- function(data, clase){
  #te da el tamaño de la clase con menor cantidad de observaciones (n)
  tamaño_muestra <- min(table(data[,clase]))
  
  
  # Submuestreo de la clase mayoritaria (agarro n observaciones)
  submuestra_mayoritaria <- data %>%
    group_by_at(clase) %>%
    sample_n(tamaño_muestra)
}



#' Run an experiment to evaluate the performance of a predictive model under different conditions.
#'
#' @param datasets_to_pred A list of data frames, each containing a dataset to be predicted.
#' @param filepath The path to the file where the experiment results will be saved.
#' @return None (the experiment results are saved to a file).
#'
#' @details
#' This function iterates through the given datasets, imputation methods, and proportions
#' of missing data. For each combination, it configures the preprocessing options, performs
#' the experiment, and stores the results in a list. The list of results is then combined into
#' a single data frame, which is saved to the specified file.

run_experiment <- function(datasets_to_pred, filepath) {
  
  exp_results <- list()  # Store experiment results
  i <- 1  # Initialize counter for experiment results
  
  # Iterate through different dataset, imputation, and proportion of missing values combinations
  for (dtp in datasets_to_pred) {
    for (subsamplear in c("Yes", "No")) {
        print(c(dtp$dataset_name, subsamplear))
        
        # Configure preprocessing options based on imputation choice
        if (subsamplear == "Yes") {
          data_nueva <- sub_sample(dtp$data_df, dtp$var_to_predict)
          dtp$data_df = data_nueva
          
          preprocess_control <- list(
            prop_NAs= 0,
            impute_NAs=FALSE,
            treat_NAs_as_new_levels=FALSE,
            do_ohe=FALSE,
            discretize=FALSE,
            n_bins=N_BINS,
            ord_to_numeric=FALSE,
            prop_switch_y=0
          )
        } else if (subsamplear == "No") {
          preprocess_control <- list(
            prop_NAs= 0,
            impute_NAs=FALSE,
            treat_NAs_as_new_levels=FALSE,
            do_ohe=FALSE,
            discretize=FALSE,
            n_bins=N_BINS,
            ord_to_numeric=FALSE,
            prop_switch_y=0
          )
        }
        
        # Perform the experiment for the current settings
        if (PARALLELIZE == TRUE) {
          res_tmp <- est_auc_across_depths(dtp, preprocess_control,
                                           max_maxdepth=30, prop_val=0.25,
                                           val_reps=30)
        } else {
          res_tmp <- est_auc_across_depths_no_par(dtp, preprocess_control,
                                                  max_maxdepth=30, prop_val=0.25,
                                                  val_reps=30)
        }
        
        res_tmp$SUBSAMPLED <- subsamplear
        exp_results[[i]] <- res_tmp
        rm(res_tmp)  # Clean up temporary result
        i <- i + 1  # Increment result counter
    }
  }
  
  # Combine experiment results into a single data frame
  exp_results <- do.call(rbind, exp_results)
  
  # Save experiment results to a file
  write.table(exp_results, filepath, row.names=FALSE, sep="\t")
}

#' Plot the results of the sample experiment using ggplot2.
#'
#' @param filename_exp_results The filename of the experiment results file.
#' @param filename_plot The filename to save the plot (e.g., "my_plot.png").
#' @param width The width of the plot in inches.
#' @param height The height of the plot in inches.
#' @return None (the plot is saved as an image file).
#'
#' @details
#' This function reads the experiment results, calculates the mean AUC values for different
#' experimental conditions, and generates a line plot using ggplot2. The plot displays the mean AUC
#' values against maximum tree depths, with different lines for different imputation methods and facets
#' for different datasets and proportions of missing data. The resulting plot is saved as the specified file.
#'
plot_exp_results <- function(filename_exp_results, filename_plot, width, height) {
  # Load experiment results
  exp_results <- read.table(filename_exp_results, header=TRUE, sep="\t")
  
  # Calculate mean AUC values for different groups of experimental results
  data_for_plot <- exp_results %>%
    group_by(dataset_name, SUBSAMPLED, maxdepth) %>%
    summarize(mean_auc=mean(auc), .groups='drop')
  
  data_churn <- data_for_plot %>%
    filter(dataset_name == "Churn")
  data_sleep <- data_for_plot %>%
    filter(dataset_name == "Sleep")
  data_heart <- data_for_plot %>%
    filter(dataset_name == "Heart")
  
  # Create a ggplot object for the line plot
  plot1 <- ggplot(data_churn, aes(x=maxdepth, y=mean_auc, color=SUBSAMPLED)) +
    geom_line() +
    theme_bw() +
    xlab("Maximum tree depth") +
    ylab("AUC (estimated through repeated validation)") +
    ggtitle("Churn") +
    theme(legend.position="bottom",
          panel.grid.major=element_blank(),
          strip.background=element_blank(),
          panel.border=element_rect(colour="black", fill=NA),
          plot.title = element_text(hjust = 0.5))
  
  plot2 <- ggplot(data_sleep, aes(x=maxdepth, y=mean_auc, color=SUBSAMPLED)) +
    geom_line() +
    theme_bw() +
    xlab("Maximum tree depth") +
    ylab("AUC (estimated through repeated validation)") +
    ggtitle("Sleep") +
    theme(legend.position="bottom",
          panel.grid.major=element_blank(),
          strip.background=element_blank(),
          panel.border=element_rect(colour="black", fill=NA),
          plot.title = element_text(hjust = 0.5))
  
  plot3 <- ggplot(data_heart, aes(x=maxdepth, y=mean_auc, color=SUBSAMPLED)) +
    geom_line() +
    theme_bw() +
    xlab("Maximum tree depth") +
    ylab("AUC (estimated through repeated validation)") +
    ggtitle("Heart") +
    theme(legend.position="bottom",
          panel.grid.major=element_blank(),
          strip.background=element_blank(),
          panel.border=element_rect(colour="black", fill=NA),
          plot.title = element_text(hjust = 0.5))
  
  grid.arrange(plot1, plot2, plot3, ncol = 3)

}

# Load the datasets
datasets_to_pred <- list(
  load_df("./data/sleep_health_proc.csv", "Sleep", "Sleep.Disorder"),
  load_df("./data/customer_churn.csv", "Churn", "churn"), # Source: https://archive.ics.uci.edu/dataset/563/iranian+churn+dataset
  load_df("./data/heart.csv", "Heart", "HeartDisease")    # Source: https://www.kaggle.com/datasets/arnabchaki/data-science-salaries-2023
)

# Run the experiment
if (RERUN_EXP ==  TRUE) {
  run_experiment(datasets_to_pred, "./outputs/tables/exp_propio.txt")
}

# Plot the experiment results
plot_exp_results( "./outputs/tables/exp_propio.txt", "./outputs/plots/exp_1.jpg", width=5, height=4)
