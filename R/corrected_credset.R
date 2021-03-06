#' @title Corrected credible set using Z-scores and MAFs
#'
#' @param z Z-scores
#' @param f Minor allele frequencies
#' @param N0 Number of controls
#' @param N1 Number of cases
#' @param Sigma Correlation matrix of SNPs
#' @param W Prior for the standard deviation of the effect size parameter, beta (default 0.2)
#' @param lower Lower threshold (default = 0)
#' @param upper Upper threshold (default = 1)
#' @param desired.cov The desired coverage of the causal variant in the credible set
#' @param acc Accuracy of corrected coverage to desired coverage (default = 0.005)
#' @param max.iter Maximum iterations (default = 20)
#' @param pp0min Only average over SNPs with pp0 > pp0min
#' @return List of variants in credible set, required threshold, the corrected coverage and the size of the credible set
#'
#' @examples
#' \donttest{
#'  # this is a long running example
#'
#' # In this example, the function is used to find a corrected 95% credible set
#' # using Z-scores and MAFs, that is the smallest set of variants
#' # required such that the resultant credible set has coverage close to (/within
#' # some accuracy of) the "desired coverage" (here set to 0.95). Max.iter parameter
#' # defines the maximum number of iterations to try in the root bisection algorithm,
#' # this should be increased to ensure convergence to the desired coverage, but is set
#' # to 1 here for speed (and thus the resultant credible set will not be accurate).
#'
#' set.seed(2)
#' nsnps = 200
#' N0 = 1000
#' N1 = 1000
#' z_scores <- rnorm(nsnps, 0, 1) # simulate a vector of Z-scores
#'
#' ## generate example LD matrix
#' library(mvtnorm)
#' nsamples = 1000
#'
#' simx <- function(nsnps, nsamples, S, maf=0.1) {
#'     mu <- rep(0,nsnps)
#'     rawvars <- rmvnorm(n=nsamples, mean=mu, sigma=S)
#'     pvars <- pnorm(rawvars)
#'     x <- qbinom(1-pvars, 1, maf)
#'}
#'
#' S <- (1 - (abs(outer(1:nsnps,1:nsnps,`-`))/nsnps))^4
#' X <- simx(nsnps,nsamples,S)
#' LD <- cor2(X)
#' maf <- colMeans(X)
#'
#' names(z_scores) <- seq(1,length(z_scores))
#'
#' corrected_cs(z = z_scores, f = maf, N0, N1, Sigma = LD, desired.cov = 0.9, max.iter = 1)
#' # max.iter set low for speed, should be set to at least
#' # the default to ensure convergence to desired coverage
#' }
#'
#' @export
#' @author Anna Hutchinson
corrected_cs <- function(z, f, N0, N1, Sigma, W = 0.2, lower = 0, upper = 1, desired.cov, acc = 0.005, max.iter = 20, pp0min = 0.001){

  s = N1/(N0+N1) # proportion of cases
  varbeta = 1/(2 * (N0+N1) * f * (1 - f) * s * (1 - s))
  r = W^2/(W^2 + varbeta)
  pp = ppfunc(z, V = varbeta) # pp of system in question
  muhat = sum(abs(z) * pp)
  nsnps = length(pp)
  temp = diag(x = muhat, nrow = nsnps, ncol = nsnps)
  usesnps=which(pp > pp0min)
  zj = lapply(usesnps, function(i) temp[i, ])  # nsnp zj vectors for each snp considered causal
  
  nrep = 1000

  ERR = mvtnorm::rmvnorm(nrep, rep(0, ncol(Sigma)), Sigma)

  pps = mapply(.zj_pp, Zj = zj, MoreArgs = list(int.Sigma = Sigma, int.nrep = nrep, int.ERR = ERR, int.r = r), SIMPLIFY =     FALSE)

  n_pps = length(pps)
  args = 1:length(pp)

  f <- function(thr){ # finds the difference between corrcov and desired.cov
    d5 <- lapply(1:n_pps, function(x) {
      credsetC(pps[[x]], CV = rep(usesnps[x], dim(pps[[x]])[1]), thr = thr)
    })
    propcov <- lapply(d5, prop_cov) %>% unlist()
    sum(propcov * pp[usesnps])/sum(pp[usesnps]) - desired.cov
  }

  o = order(pp, decreasing = TRUE)  # order index for true pp
  cumpp = cumsum(pp[o])  # cum sums of ordered pps

  corrcov.tmp <- f(desired.cov)
  nvar.tmp <- which(cumpp > desired.cov)[1]

  if(corrcov.tmp > 0 & nvar.tmp == 1) stop("Cannot make credible set smaller")

  # initalize
  N=1
  fa = f(lower)
  fb = f(upper)

  if (fa * fb > 0) {
    stop("No root in range, increase window")
  } else {
    fc = min(fa, fb)
    while (N <= max.iter & !dplyr::between(fc, 0, acc)) {
      c = lower + (upper-lower)/2
      fc = f(c)
      print(paste("thr: ", c, ", cov: ", desired.cov + fc))

      if (fa * fc < 0) {
        upper = c
        fb = fc
      } else if (f(upper) * fc < 0) {
        lower = c
        fa = fc
      }
      N = N + 1
    }
  }
  wh = which(cumpp > c)[1]  # how many needed to exceed thr
  size = cumpp[wh]
  names(size) = NULL
  list(credset = names(pp)[o[1:wh]], req.thr = c, corr.cov = desired.cov + fc, size = size)
}

#' @title Corrected credible set using estimated effect sizes and their standard errors
#'
#' @param bhat Estimated effect sizes
#' @param V Prior variance of estimated effect sizes
#' @param N0 Number of controls
#' @param N1 Number of cases
#' @param Sigma Correlation matrix of SNPs
#' @param W Prior for the standard deviation of the effect size parameter, beta (default 0.2)
#' @param lower Lower threshold (default = 0)
#' @param upper Upper threshold (default = 1)
#' @param desired.cov The desired coverage of the causal variant in the credible set
#' @param acc Accuracy of corrected coverage to desired coverage (default = 0.005)
#' @param max.iter Maximum iterations (default = 20)
#' @param pp0min Only average over SNPs with pp0 > pp0min
#'
#' @return List of variants in credible set, required threshold, the corrected coverage and the size of the credible set
#'
#' @examples
#'
#' \donttest{
#'  # this is a long running example
#'
#' # In this example, the function is used to find a corrected 95% credible set
#' # using bhats and their standard errors, that is the smallest set of variants
#' # required such that the resultant credible set has coverage close to (/within
#' # some accuracy of) the "desired coverage" (here set to 0.95). Max.iter parameter
#' # defines the maximum number of iterations to try in the root bisection algorithm,
#' # this should be increased to ensure convergence to the desired coverage, but is set
#' # to 1 here for speed (and thus the resultant credible set will not be accurate).
#'
#' set.seed(18)
#' nsnps <- 100
#' N0 <- 500 # number of controls
#' N1 <- 500 # number of cases
#'
#' # simulate fake haplotypes to obtain MAFs and LD matrix
#' ## generate example LD matrix
#' library(mvtnorm)
#' nsamples = 1000
#'
#' simx <- function(nsnps, nsamples, S, maf=0.1) {
#'     mu <- rep(0,nsnps)
#'     rawvars <- rmvnorm(n=nsamples, mean=mu, sigma=S)
#'     pvars <- pnorm(rawvars)
#'     x <- qbinom(1-pvars, 1, maf)
#' }
#'
#' S <- (1 - (abs(outer(1:nsnps,1:nsnps,`-`))/nsnps))^4
#' X <- simx(nsnps,nsamples,S)
#' LD <- cor2(X)
#' maf <- colMeans(X)
#'
#' varbeta <- Var.data.cc(f = maf, N = N0 + N1, s = N1/(N0+N1))
#'
#' bhats = rnorm(nsnps,0,0.2) # log OR
#'
#' names(bhats) <- seq(1,length(bhats))
#'
#' corrected_cs_bhat(bhat = bhats, V = varbeta, N0, N1, Sigma = LD, desired.cov = 0.9, max.iter = 1)
#' # max.iter set low for speed, should be set to at
#' # least the default to ensure convergence to desired coverage
#' }
#'
#' @export
#' @author Anna Hutchinson
corrected_cs_bhat <- function(bhat, V, N0, N1, Sigma, W = 0.2, lower = 0, upper = 1, desired.cov, acc = 0.005, max.iter = 20, pp0min = 0.001){

  z = bhat/sqrt(V)
  r = W^2/(W^2 + V)
  pp = ppfunc(z, V = V) # pp of system in question
  muhat = sum(abs(z) * pp)
  nsnps = length(pp)
  temp = diag(x = muhat, nrow = nsnps, ncol = nsnps)
  usesnps=which(pp > pp0min)
  zj = lapply(usesnps, function(i) temp[i, ])  # nsnp zj vectors for each snp considered causal
  
  nrep = 1000
  
  ERR = mvtnorm::rmvnorm(nrep, rep(0, ncol(Sigma)), Sigma)
  
  pps = mapply(.zj_pp, Zj = zj, MoreArgs = list(int.Sigma = Sigma, int.nrep = nrep, int.ERR = ERR, int.r = r), SIMPLIFY =     FALSE)
  
  n_pps = length(pps)
  args = 1:length(pp)
  
  f <- function(thr){ # finds the difference between corrcov and desired.cov
    d5 <- lapply(1:n_pps, function(x) {
      credsetC(pps[[x]], CV = rep(usesnps[x], dim(pps[[x]])[1]), thr = thr)
    })
    propcov <- lapply(d5, prop_cov) %>% unlist()
    sum(propcov * pp[usesnps])/sum(pp[usesnps]) - desired.cov
  }
  
  o = order(pp, decreasing = TRUE)  # order index for true pp
  cumpp = cumsum(pp[o])  # cum sums of ordered pps
  
  corrcov.tmp <- f(desired.cov)
  nvar.tmp <- which(cumpp > desired.cov)[1]
  
  if(corrcov.tmp > 0 & nvar.tmp == 1) stop("Cannot make credible set smaller")
  
  # initalize
  N=1
  fa = f(lower)
  fb = f(upper)
  
  if (fa * fb > 0) {
    stop("No root in range, increase window")
  } else {
    fc = min(fa, fb)
    while (N <= max.iter & !dplyr::between(fc, 0, acc)) {
      c = lower + (upper-lower)/2
      fc = f(c)
      print(paste("thr: ", c, ", cov: ", desired.cov + fc))
      
      if (fa * fc < 0) {
        upper = c
        fb = fc
      } else if (f(upper) * fc < 0) {
        lower = c
        fa = fc
      }
      N = N + 1
    }
  }
  wh = which(cumpp > c)[1]  # how many needed to exceed thr
  size = cumpp[wh]
  names(size) = NULL
  list(credset = names(pp)[o[1:wh]], req.thr = c, corr.cov = desired.cov + fc, size = size)
}
