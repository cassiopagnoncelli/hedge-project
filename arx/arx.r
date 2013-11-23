# This package deals with Autoregressive model with exogenous inputs.
# It has three available functions:
#
#   arx.transform(T, orders)
#     Takes the matrix T, which is m x n, and serialize columns by orders,
#     which should be of size m.
#
#   arx.fit(S, method, tvt)
#     Takes a matrix S, which should look like the return of arx.transform,
#     and fit the 2:end columns to the 1st column by using one of the
#     available methods. The available methods are 'training', identical to
#     neural network training --in this case, the train-validation-test sizes
#     must be provided--, and linear least squares ('lsq').
#
#     Similarly to linear model ('lm'), it returns a list containing the
#     $parameters, $rmse, and $fitted.values.
#
#   arx.autofit(S, method, tvt=c(0.7, 0.15, 0.15), upto=13)
#     Find a locally optimal instance for `orders'.
#
require('MASS')

arx.transform <- function(T, orders=rep(0,dim(T)[2]), NA.fill=FALSE) {
    # check parameters.
    if (!is.matrix(T) || !is.vector(orders) || dim(T)[2] != length(orders) ||
        sum(orders < 0) > 0)
        return(NULL)
    
    # interval of the resulting matrix S.
    S <- NULL
    S.interval <- seq(from=1+max(orders), to=dim(T)[1], by=1)
    
    # column names
    has.colnames <- !is.null(colnames(T))
    columnnames <- c()
    
    # calculate columns and append them horizontally in S.
    for (i in 1:length(orders)) {
        interval <- seq(from=1+max(orders), to=dim(T)[1], by=1)
        for (j in 0:orders[i]) {
            S <- cbind(S, T[interval-j,i])
            if (has.colnames)
                columnnames <- c(columnnames,
                                 paste(colnames(T)[i], j, sep='_'))
        }
    }
    if (has.colnames) { colnames(S) <- columnnames }
    
    # fill first values with NA.
    if (NA.fill) {
        S <- rbind(as.matrix(rep(NA, max(orders) * length(orders)),
                             ncol=length(orders)),
                   S)
    }

    return(S)
}

arx.lsq <- function(X, y) {
    ginv(t(X) %*% X) %*% t(X) %*% y
}

arx.fit <- function(S, method='lsq', tvt=c(0.7, 0.15, 0.15)) {
    # check parameters
    if (!is.matrix(S) || (method == 'training' && sum(tvt) != 1) ||
        (method != 'training' && method != 'lsq'))
        return(NULL)
    
    # fit S[,2:end] to S[,1].
    featurecols <- 2:dim(S)[2]
    if (method == 'lsq') {
        parameters <- arx.lsq(S[,featurecols], S[,1])
    } else {
        print('Method not implemented.')
        return(NULL)
    }

    # fitted values
    fitted <- S[,featurecols] %*% as.matrix(as.vector(parameters))
    
    # RMSE
    error <- sum((fitted - S[,1])^2) / length(S[,1])
    
    # list containing parameters, rmse, and fitted values.
    return(list(params=parameters, rmse=error, fitted.values=fitted))
}
