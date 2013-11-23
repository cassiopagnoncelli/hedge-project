###
### Empiricamente, a inclinação das MMs (DMM) descreve uma distribuição
### normal com média 0.
###

## carregar e ordenar os dados
brutos <- read.table('angulacao_candle-a-candle.dat', header=TRUE)
dados <- sort(brutos$ANGULACAO)

## critério de Sturges para definir número de classes:
##   num_classes := teto(1 + lg n)
num_classes <- ceiling(1 + logb(length(dados), 2))
print(pretty(dados, num_classes))

## histograma dos dados
require(MASS)
truehist(dados)

## histograma de uma distribuição normal
#truehist(sort(rnorm(1:length(dados), 0, 1)))
