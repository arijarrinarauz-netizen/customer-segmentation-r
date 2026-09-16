## Customer Segmentation — Mall Customer dataset (public, 200 customers)
## Arianna Jarrin — personal project
## Goal: segment customers by income & spending behaviour to inform targeted marketing

library(ggplot2)
library(dplyr)

set.seed(42)

## ---- 1. Load & clean ----
df <- read.csv("Mall_Customers.csv", stringsAsFactors = FALSE)
names(df) <- c("CustomerID", "Gender", "Age", "AnnualIncome", "SpendingScore")
df$Gender <- as.factor(df$Gender)

cat("Rows:", nrow(df), " | Missing values:", sum(is.na(df)), "\n")
print(summary(df[, c("Age", "AnnualIncome", "SpendingScore")]))

## ---- 2. Exploratory visualisation ----
p_explore <- ggplot(df, aes(x = AnnualIncome, y = SpendingScore, color = Gender)) +
  geom_point(size = 2.4, alpha = 0.85) +
  labs(title = "Annual Income vs. Spending Score",
       x = "Annual Income (k$)", y = "Spending Score (1-100)") +
  theme_minimal(base_size = 13)
ggsave("plot_1_explore.png", p_explore, width = 7, height = 5, dpi = 150)

## ---- 3. Choosing k: elbow method ----
scaled <- scale(df[, c("AnnualIncome", "SpendingScore")])
wss <- sapply(1:10, function(k) kmeans(scaled, centers = k, nstart = 25)$tot.withinss)
elbow_df <- data.frame(k = 1:10, wss = wss)

p_elbow <- ggplot(elbow_df, aes(x = k, y = wss)) +
  geom_line(color = "#1b3a5c") + geom_point(size = 2, color = "#1b3a5c") +
  geom_vline(xintercept = 5, linetype = "dashed", color = "#c07214") +
  labs(title = "Elbow method for choosing k", x = "Number of clusters (k)",
       y = "Total within-cluster sum of squares") +
  theme_minimal(base_size = 13)
ggsave("plot_2_elbow.png", p_elbow, width = 7, height = 5, dpi = 150)

## ---- 4. K-means with k = 5 ----
k <- 5
km <- kmeans(scaled, centers = k, nstart = 25)
df$Segment <- factor(km$cluster)

## Label segments by their income/spending profile (business-readable names)
seg_summary <- df %>%
  group_by(Segment) %>%
  summarise(n = n(),
            avg_income = round(mean(AnnualIncome), 1),
            avg_spending = round(mean(SpendingScore), 1)) %>%
  arrange(desc(avg_income))
print(seg_summary)

# Rank-based labelling (robust to ties at the median, unlike a plain median split):
# the middle-income segment is "Standard"; among the two higher-income segments,
# the higher spender is the ideal "Target" customer and the lower spender is "Sensible";
# among the two lower-income segments, the higher spender is "Careless" (overspends
# relative to income) and the lower spender is "Careful".
seg_summary <- seg_summary %>% arrange(desc(avg_income)) %>%
  mutate(income_rank = row_number())
seg_summary$label <- NA
top2 <- seg_summary$income_rank %in% c(1, 2)
bot2 <- seg_summary$income_rank %in% c(4, 5)
seg_summary$label[top2][which.max(seg_summary$avg_spending[top2])] <- "Target (high income, high spending)"
seg_summary$label[top2][which.min(seg_summary$avg_spending[top2])] <- "Sensible (high income, low spending)"
seg_summary$label[bot2][which.max(seg_summary$avg_spending[bot2])] <- "Careless (low income, high spending)"
seg_summary$label[bot2][which.min(seg_summary$avg_spending[bot2])] <- "Careful (low income, low spending)"
seg_summary$label[seg_summary$income_rank == 3] <- "Standard (mid income, mid spending)"
print(seg_summary)

df <- df %>% left_join(seg_summary %>% select(Segment, label), by = "Segment")

p_clusters <- ggplot(df, aes(x = AnnualIncome, y = SpendingScore, color = label)) +
  geom_point(size = 2.6, alpha = 0.9) +
  labs(title = "Customer segments (k-means, k=5)",
       subtitle = "Mall Customer dataset, n=200",
       x = "Annual Income (k$)", y = "Spending Score (1-100)", color = "Segment") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom", legend.text = element_text(size = 9)) +
  guides(color = guide_legend(nrow = 3, byrow = TRUE)) +
  scale_color_brewer(palette = "Set2")
ggsave("plot_3_segments.png", p_clusters, width = 7.5, height = 6.3, dpi = 150)

## ---- 5. Write summary to file for the writeup ----
sink("segmentation_summary.txt")
cat("=== Segment summary (n, avg income k$, avg spending score) ===\n")
print(as.data.frame(seg_summary))
sink()

cat("\nDone. Outputs: plot_1_explore.png, plot_2_elbow.png, plot_3_segments.png, segmentation_summary.txt\n")
