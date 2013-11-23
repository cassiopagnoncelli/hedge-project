source('arx.r')

require('e1071')             # naive bayes
require('kernlab')           # SVM

if (T)
# importing dataset from CSV
dataset.original <- as.matrix(read.csv('eurusd.csv', header=T))
dataset <- as.matrix(dataset.original[1:2000, c(1,3:dim(dataset.original)[2])])

# fit ARX model
orders <- rep(10, 21)
dataset.interval <- seq(from=1+max(orders), to=dim(dataset)[1], by=1)

S <- arx.transform(dataset, orders)
S.fit <- arx.fit(S, method='lsq')
S.fitted <- S.fit$fitted.values
S.err <- S[,1] - S.fitted

# dataset for machine learning
ml.X <- S[,2:dim(S)[2]]
ml.high <- dataset[dataset.interval,1]
ml.close <- dataset[dataset.interval,2]

## svm
#ml.filterHigh <- ksvm(ml.X, ml.high, type='eps-svr', scale=F)
#ml.filterClose <- ksvm(ml.X, ml.close, type='eps-svr', scale=F)

#ml.high.fitted <- predict(ml.filterHigh, ml.X)
#ml.close.fitted <- predict(ml.filterClose, ml.X)

#ml.high.err <- ml.high - ml.high.fitted
#ml.close.err <- ml.close - ml.close.fitted

## naive bayes
ml.X <- S[,2:ncol(S)]
ml.y <- ml.high > 10 & ml.close > 0

print('classifing')
classifier <- naiveBayes(ml.X, ml.y)

