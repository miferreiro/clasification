technique <- "ig"
for(technique in c("chi","ig")){
library(tm);library(pipeR);library(tokenizers);library(FSelector)
source("functions/chi2.R")
source("functions/IG.R")
ytbidDF <- read.csv(file = "csvs/output_youtube_last.csv", header = TRUE, 
                          sep = ";", dec = ".", fill = FALSE, stringsAsFactors = FALSE)
  
ytbid.corpus <- VCorpus(VectorSource(ytbidDF$data))
ytbid.corpus <- tm_map(ytbid.corpus, content_transformer(gsub), pattern = '[!"#$%&\'()*+,.\\/:;<=>?@\\\\^_\\{\\}|~-]+', replacement = ' ')
ytbid.corpus <- tm_map(ytbid.corpus, stripWhitespace)
ytbid.corpus <- tm_map(ytbid.corpus, removeNumbers)
removeLongWords <- content_transformer(function(x, length) {
  
  return(gsub(paste("(?:^|[[:space:]])[[:alnum:]]{", length, ",}(?=$|[[:space:]])", sep = ""), "", x, perl = T))
})
ytbid.corpus <- tm_map(ytbid.corpus, removeLongWords, 25)

#Creating Term-Document Matrices
ytbid.dtm <- DocumentTermMatrix(ytbid.corpus)
ytbid.matrix.dtm <- as.matrix(ytbid.dtm)
ytbid.matrix.dtm <- cbind(as.factor(ytbidDF$target), ytbid.matrix.dtm)
colnames(ytbid.matrix.dtm)[1] <- "targetHamSpam"
ytbid.data.frame.dtm <- as.data.frame(ytbid.matrix.dtm)

# ytbid.chi <- chi_squared("targetHamSpam", ytbid.data.frame.dtm)
# ytbid.ig <- information_gain("targetHamSpam", ytbid.data.frame.dtm)
# 
# saveRDS(ytbid.chi, file = "results/ytbid-chi.rds")
# saveRDS(ytbid.ig, file = "results/ytbid-ig.rds")

################################################################################
################################################################################
################################################################################
library("kernlab");library("caret");library("tidyverse");library("recipes");library("rlist");library("dplyr")
ytbid.data.frame.dtm <- dplyr::select(ytbid.data.frame.dtm, -targetHamSpam)
technique.reduce.dimensionality <- readRDS(paste("results/ytbid-",technique,".rds",sep=""))
order <- order(technique.reduce.dimensionality, decreasing = TRUE)
ytbid.dtm.cutoff <- ytbid.data.frame.dtm[,order[1:2000]]

ytbid.dtm.cutoff$X.userName <- ytbidDF$X.userName
ytbid.dtm.cutoff$hashtag <- ytbidDF$hashtag 
ytbid.dtm.cutoff$URLs <- ytbidDF$URLs
ytbid.dtm.cutoff$emoticon <- ytbidDF$emoticon   
ytbid.dtm.cutoff$emoji <- ytbidDF$emoji
ytbid.dtm.cutoff$interjection <- ytbidDF$interjection
ytbid.dtm.cutoff$extension <- as.factor(ytbidDF$extension)
ytbid.dtm.cutoff$targetHamSpam <- as.factor(ytbidDF$target)

source("transformColums.R")

ytbid.dtm.cutoff <- ytbid.dtm.cutoff %>%
  transformColums("X.userName") %>%
  transformColums("hashtag") %>%
  transformColums("URLs") %>%
  transformColums("emoticon") %>%
  transformColums("emoji") %>% 
  transformColums("interjection") 

def.formula <- as.formula("targetHamSpam~.")

#YTBID
{
  cat("Starting SVM YTBID...\n")
  set.seed(100)
  dataYtbid <- subset(ytbid.dtm.cutoff, extension == "ytbid")
  indexYtbid <- caret::createDataPartition(dataYtbid$targetHamSpam, p = .75, list = FALSE)
  ytbid.train <- dataYtbid[indexYtbid, ]
  ytbid.test <-  dataYtbid[-indexYtbid, ]
  
  ytbid.svm.rec <- recipes::recipe(formula = def.formula, data = ytbid.train) %>%
    step_zv(all_predictors()) # %>% #remove zero variance
    # step_nzv(all_predictors()) %>% #remove near-zero variance
    # step_corr(all_predictors()) 

  
  ytbid.svm.trControl <- caret::trainControl(method = "cv", #use cross-validation
                                             number = 10, #divide cross-validation into 10 folds
                                             search = "random", #"grid"
                                             savePredictions = "final", #save predictions of best model.
                                             classProbs = TRUE, #save probabilities obtained for the best model.
                                             summaryFunction = defaultSummary, #use defaultSummary function (only computes Accuracy and Kappa values)
                                             allowParallel = TRUE, #execute in parallel.
                                             seeds = set.seed(100)
  )
  cat("Training SVM YTBID...\n")
  ytbid.svm.trained <- caret::train(ytbid.svm.rec,
                                    data = ytbid.train,
                                    method = "svmLinear",
                                    trControl = ytbid.svm.trControl,
                                    metric = "Kappa")
  
  cat("Testing SVM YTBID...\n")
  ytbid.svm.cf <- caret::confusionMatrix(
    predict(ytbid.svm.trained, newdata = ytbid.test, type = "raw"),
    reference = ytbid.test$targetHamSpam,
    positive = "spam"
  )
  
  cat("Finished SVM YTBID...\n")
  saveRDS(ytbid.svm.trained, file = paste("resultsWithOutSteps/ytbid-tokens-",technique,"-svm-train.rds",sep=""))
  saveRDS(ytbid.svm.cf, file = paste("resultsWithOutSteps/ytbid-tokens-",technique,"-svm-test.rds",sep=""))
}
}
