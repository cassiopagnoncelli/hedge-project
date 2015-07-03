## carrega e ordena os dados
bruto <- read.table('cristas.dat', header=TRUE)
dados <- sort(bruto$DMM)

## medidas de resumo
print(summary(dados))

## gráfico de frequência
require(MASS)
truehist(dados, nbins=sqrt(length(dados)), prob=FALSE, xlab="DMM", ylab="frequência")
