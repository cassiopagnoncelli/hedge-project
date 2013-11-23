# UNIVERSIDADE FEDERAL DO PARANÁ
# Departamento de Informática
# Cássio Jandir Pagnoncelli, kimble9t (em) gmail (ponto) com
#
# FITTING CURVES TO DATA
#
#   Generates a random data whose points are that from matrix [x y] and fit
# a regression line, a loess curve, and splines.
#
#   To see more from regression analysis, uncomment the last lines.
#

# data
x <- 1:100
y <- runif(1) * 
     (((0.1 * (70 - abs(30 - 1:100)))^log(5)) + exp(rnorm(100, 1, 0.5)))

# predictions
fit <- lm(y ~ x)
lo  <- loess(y ~ x)
smoothingSpline = smooth.spline(x, y, spar=0.35)

# plots
# (see colors().)
plot(x, y, t='l', col='black', lwd=1,
     main="Fitting curves to data", xlab="Time", ylab="Price")
lines(predict(fit), col='magenta', lwd=3, pch='p')       # == abline(fit)
lines(predict(lo), col='green3', lwd=3)
lines(smoothingSpline, col='blue', lwd=3)
legend(x="topright",
       legend=c("original data", "regression line", "loess", "splines"),
       pch=c('-', '-', '-', '-'),
       col=c('black', 'magenta', 'green3', 'blue'))

# regression analysis
#attributes(fit)
#plot(fit)
#summary(fit)
