# UNIVERSIDADE FEDERAL DO PARANÁ
# Departamento de Informática
# Cássio Jandir Pagnoncelli, kimble9t (em) gmail (ponto) com
#
# AN EXAMPLE USING SPLINES

# splines
x <- 1:10
y <- c(2,4,6,8,7,8,14,16,18,20)
lo <- loess(y~x)
plot(x,y)
xl <- seq(min(x),max(x), (max(x) - min(x))/1000)
lines(xl, predict(lo,xl), col='red', lwd=2)
