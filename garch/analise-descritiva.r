# Carregando dados de retornos.
intel <- read.table('intel-rtn.csv', head=TRUE)

# Séries de retornos e log-retornos.
R <- ts(intel$rtn)
logR <- ts(log(1 + intel$rtn))

# Gráfico das séries.
X11()
par(mfrow=c(2,1))
plot(R, xlab='Tempo', ylab='Retornos', t='l')
plot(logR, xlab='Tempo', ylab='Log-retornos', t='l')

# Descrição básica dos dados.
library('fBasics')
basicStats(R)
basicStats(logR)

# Teste de aderência dos retornos à distribuição normal.
library('tseries')
jarque.bera.test(R)
jarque.bera.test(logR)

# Gráfico quantil-quantil da Normal.
X11()
par(mfrow=c(1,2))
qqnormPlot(R, title=F, labels=F, main='QQ-plot para os retornos', xlab='Normal', ylab='Retornos')
qqnormPlot(logR, title=F, labels=F, main='QQ-plot para os log-retornos', xlab='Normal', ylab='Log-retornos')

# Visualização do efeito ARCH.
X11()
par(mfrow=c(2,2))
acf(logR, xlab='Defasagem', ylab='Autocorrelação', main=expression(r))
acf(logR^2, xlab='Defasagem', ylab='Autocorrelação', main=expression(r^2))
acf(abs(logR), xlab='Defasagem', ylab='Autocorrelação', main=expression(abs(r)))
pacf(logR^2, xlab='Defasagem', ylab='Autocorrelação parcial', main=expression(r^2))

# Teste para o efeito ARCH
Box.test((logR-mean(logR))^2, lag=12, type='Ljung-Box')