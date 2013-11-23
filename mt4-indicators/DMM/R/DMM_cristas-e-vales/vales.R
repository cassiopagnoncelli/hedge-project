## carrega e ordena os dados
bruto <- read.table('vales.dat', header=TRUE)
dados <- sort(bruto$DMM)

## gráfico de frequência
require(MASS)
truehist(dados, nbins=sqrt(length(dados)), prob=FALSE, xlab="DMM", ylab="frequência")
