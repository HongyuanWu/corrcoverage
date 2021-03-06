% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/corrected_credset.R
\name{corrected_cs_bhat}
\alias{corrected_cs_bhat}
\title{Corrected credible set using estimated effect sizes and their standard errors}
\usage{
corrected_cs_bhat(bhat, V, N0, N1, Sigma, W = 0.2, lower = 0,
  upper = 1, desired.cov, acc = 0.005, max.iter = 20,
  pp0min = 0.001)
}
\arguments{
\item{bhat}{Estimated effect sizes}

\item{V}{Prior variance of estimated effect sizes}

\item{N0}{Number of controls}

\item{N1}{Number of cases}

\item{Sigma}{Correlation matrix of SNPs}

\item{W}{Prior for the standard deviation of the effect size parameter, beta (default 0.2)}

\item{lower}{Lower threshold (default = 0)}

\item{upper}{Upper threshold (default = 1)}

\item{desired.cov}{The desired coverage of the causal variant in the credible set}

\item{acc}{Accuracy of corrected coverage to desired coverage (default = 0.005)}

\item{max.iter}{Maximum iterations (default = 20)}

\item{pp0min}{Only average over SNPs with pp0 > pp0min}
}
\value{
List of variants in credible set, required threshold, the corrected coverage and the size of the credible set
}
\description{
Corrected credible set using estimated effect sizes and their standard errors
}
\examples{

\donttest{
 # this is a long running example

# In this example, the function is used to find a corrected 95\% credible set
# using bhats and their standard errors, that is the smallest set of variants
# required such that the resultant credible set has coverage close to (/within
# some accuracy of) the "desired coverage" (here set to 0.95). Max.iter parameter
# defines the maximum number of iterations to try in the root bisection algorithm,
# this should be increased to ensure convergence to the desired coverage, but is set
# to 1 here for speed (and thus the resultant credible set will not be accurate).

set.seed(18)
nsnps <- 100
N0 <- 500 # number of controls
N1 <- 500 # number of cases

# simulate fake haplotypes to obtain MAFs and LD matrix
## generate example LD matrix
library(mvtnorm)
nsamples = 1000

simx <- function(nsnps, nsamples, S, maf=0.1) {
    mu <- rep(0,nsnps)
    rawvars <- rmvnorm(n=nsamples, mean=mu, sigma=S)
    pvars <- pnorm(rawvars)
    x <- qbinom(1-pvars, 1, maf)
}

S <- (1 - (abs(outer(1:nsnps,1:nsnps,`-`))/nsnps))^4
X <- simx(nsnps,nsamples,S)
LD <- cor2(X)
maf <- colMeans(X)

varbeta <- Var.data.cc(f = maf, N = N0 + N1, s = N1/(N0+N1))

bhats = rnorm(nsnps,0,0.2) # log OR

names(bhats) <- seq(1,length(bhats))

corrected_cs_bhat(bhat = bhats, V = varbeta, N0, N1, Sigma = LD, desired.cov = 0.9, max.iter = 1)
# max.iter set low for speed, should be set to at
# least the default to ensure convergence to desired coverage
}

}
\author{
Anna Hutchinson
}
