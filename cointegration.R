set.seed(123)

# Z is a random walk.
Z <- rep(0, 10000)
for (i in 2:10000) Z[i] <- Z[i-1] + rnorm(1)

# P,Q,R are functions of Z.
P <- Q <- R <- rep(0, 10000)

P <- 0.3*Z + rnorm(10000)
Q <- 0.6*Z + rnorm(10000)
R <- 0.2*Z + rnorm(10000)

# Johansen test for cointegration.
library('urca')

jotest = ca.jo(data.frame(P,Q,R), type="trace", K=2, ecdet="none", spec="longrun")
summary(jotest)

# Building the stationary process, 
# take largest eigenvalue's eigenvector as coefficients.
S <- 1.0000000*P + 0.7064995*Q - 3.6156063*R
plot(S, t='l', col='red')

# Check series is really stationary.
library('tseries')
adf.test(S)
