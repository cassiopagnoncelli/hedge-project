# Bibliotecas.
library('fGarch')
library('tseries')
library('zoo')
library('MASS')

# Carregando os dados.
intel <- read.table('intel-rtn.csv', head=T)

# Correção de datas.
intel$date <- paste(substr(intel$date, 1, 4), substr(intel$date, 5, 6), substr(intel$date, 7, 8), sep='-')
intel$date <- as.Date(as.yearmon(intel$date, '%Y-%m-%d'))

# Separação da base para treinamento e previsão.
data <- intel$date
r <- ts(log(1 + intel$rtn))
#data.prev <- intel$date[349:358]
#r.prev <- intel$rtn[349:358]

# Limite da modelagem.
I <- 4
J <- 4

# Modelagem GARCH(i,j) com 1 <= i <= I e 1 <= j <= J.
aics <- matrix(rep(0, I*J), nrow=I)
bics <- matrix(rep(0, I*J), nrow=I)
for (i in 1:I) {
  for (j in 1:J) {
    aics[i,j] <- AIC(garch(r, order=c(i,j)), k=2)
    bics[i,j] <- AIC(garch(r, order=c(i,j)), k=log(length(r)))
  }
}

# Busca o melhor modelo.
melhor.aic <- 1000
melhor.i <- 0
melhor.j <- 0
for (i in 1:I) {
  for (j in 1:J) {
    if (aics[i,j] < melhor.aic) {
      melhor.aic <- aics[i,j]
      melhor.i <- i
      melhor.j <- j
    }
  }
}

# Melhor modelo.
print(paste('Melhor modelo: GARCH(', melhor.i, ',', melhor.j, ')', sep=''))

# Dados do ajuste com garch.
ajuste <- garch(r, order=c(melhor.i, melhor.j))
#summary(ajuste)
names(ajuste)

# Volatilidade ajustada.
media <- mean(r)
sigt <- ajuste$fitted.values[,1]
residuos <- ajuste$residuals[2:length(ajuste$residuals)]

# Gráficos.
# 1) Volatilidade ajustada.
plot(x=data, y=sigt, type='l', main='Desvio padrão condicional com GARCH(1,1)',
     xlab='Tempo', ylab='Desvio padrão')
# 2) Modelagem GARCH(1,1): Retornos com bandas.
banda_sup_sd <- media + sigt
banda_inf_sd <- media - sigt
banda_sup_2sd <- media + 2*sigt
banda_inf_2sd <- media - 2*sigt
ts.plot(cbind(banda_sup_2sd, banda_inf_2sd), type='l', lty=2, col='black',
        main='Log-retornos com bandas de 2 desvios padrões condicionais',
        ylab='Log-retornos', xlab='Tempo')
lines(rep(media, length(sigt)), type='l', col='black')
lines(r, type='l', col='blue')
# 3) Série e histograma dos resíduos.
ts.plot(residuos, main='Série dos resíduos padronizados', xlab='Tempo', ylab='Resíduos')
truehist(residuos, main='Histograma dos resíduos padronizados')
jarque.bera.test(residuos)
# 4) FAC dos resíduos e dos quadrados dos resíduos.
acf(residuos, main='FAC dos resíduos padronizados', ylab='FAC', xlab='Defasagem')
acf(residuos^2, main='FAC dos quadrados dos resíduos padronizados', ylab='FAC', xlab='Defasagem')
# 5) QQ-Plot dos resíduos padronizados.
qqnormPlot(residuos, title=F, labels=F, main='QQ-plot para os log-retornos',
           xlab='Normal', ylab='Log-retornos')

# Previsão.
sd.previsto <- predict(garchFit(~garch(1,1), data=r, trace=F, include.mean=F), n.ahead=3, doplot=F)$standardDeviation
sd.previsto

# Log-retornos dos últimos três meses.
r.seguinte <- c(0.042699724, 0.067371202, -0.01663932)
data.seguinte <- as.Date(as.yearmon(c("2013-09-01", "2013-10-01", "2013-11-01"),
                                    '%Y-%m-%d'))
# Gráficos.
# 6) Volatilidade condicional com previsão.
plot(x=c(data[481:488], data.seguinte), y=c(sigt[481:488], sd.previsto[1], rep(NA, 2)),
     type='l', main='Desvio padrão condicional com GARCH(1,1)',
     xlab='Tempo', ylab='Desvio padrão',
     ylim=c(min(c(sd.previsto, sigt[481:488])), max(sigt[481:488])))
lines(x=data.seguinte, y=sd.previsto, t='l', lty='dashed')
# 7) Log-retornos com bandas de confiança usando a volatilidade condicional.
bsup <- (media + sigt)[481:488]
binf <- (media - sigt)[481:488]
altura <- max(abs(r[481:488]), abs(r.seguinte), bsup)
plot(x=c(data[481:488], data.seguinte), y=c(r[481:488], r.seguinte),
     type='l', main='Log-retornos com bandas de 1 desvio padrão',
     ylab='Log-retornos', xlab='Tempo',
     ylim=c(-altura, altura), col='blue')
lines(x=c(data[481:488], data.seguinte), y=rep(media, 11), type='l', col='black')
lines(x=c(data[481:488], data.seguinte[1]), y=c(bsup, media+sd.previsto[1]), type='l', col='black', lwd=2)
lines(x=c(data[481:488], data.seguinte[1]), y=c(binf, media-sd.previsto[1]), type='l', col='black', lwd=2)
lines(x=data.seguinte, y=media+sd.previsto, type='l', col='black', lwd=2, lty='dashed')
lines(x=data.seguinte, y=media-sd.previsto, type='l', col='black', lwd=2, lty='dashed')
