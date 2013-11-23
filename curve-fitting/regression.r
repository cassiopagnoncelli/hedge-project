# UNIVERSIDADE FEDERAL DO PARANÁ
# Departamento de Informática
# Cássio Jandir Pagnoncelli, kimble9t (em) gmail (ponto) com
#
# A TUTORIAL ON R
#

# as seen at
# http://www.statmethods.net/stats/regression.html

# carrega os dados
dados <- read.csv2("~/tmp/saida.csv", header=TRUE)

# Multiple Linear Regression Example
fit <- lm(dados$vol ~ dados$min + dados$hour + dados$day_of_week, data=dados)

summary(fit)

# Other useful functions
coefficients(fit) # model coefficients
confint(fit, level=0.95) # CIs for model parameters
fitted(fit) # predicted values
residuals(fit) # residuals
anova(fit) # anova table
vcov(fit) # covariance matrix for model parameters
influence(fit) # regression diagnostics 

# diagnostic plots
layout(matrix(c(1,2,3,4),2,2)) # optional 4 graphs/page
plot(fit)
