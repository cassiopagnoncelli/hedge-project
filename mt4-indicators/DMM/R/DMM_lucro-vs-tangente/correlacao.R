###
### Empiricamente, o lucro e a tangente não estão correlacionados.
###

## carrega e ordena os dados conforme lucro
bruto <- read.table('3MM-lucro_vs_DMM.dat', header=TRUE, sep=" ")
dados <- bruto[order(bruto$LUCRO),]

# mostra os dados sob a ótica das medidas de resumo básicas
print(summary(dados))

## teste de correlação Kendall entre LUCRO e DMM
print(cor.test(dados$DMM, dados$LUCRO, alternative="two.sided",
               method="kendall", conf.level=0.95))

## mostra o scatter plot matrix das posições lucrativas e não-lucrativas
require(lattice)
positivas <- dados[dados$LUCRO>=0,]
negativas <- dados[dados$LUCRO<0,]
splom(positivas, ylab="Posições lucrativas")
splom(negativas, ylab="Posições não-lucrativas")
splom(dados, ylab="Todas as posições")

## distribuição das inclinações de MMs conforme o lucro
require(MASS)
#sturges <- 1 + ceiling(logb(length(dados$DMM), 2))
truehist(dados$DMM, nbins="FD", prob=TRUE,
         xlab="Lucro", ylab="Inclinação da média móvel")
