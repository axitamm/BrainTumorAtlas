# Note: this script should be sourced as: source('<path to file>', chdir=T)

FAST_TSNE_SCRIPT_DIR <<- getwd() 

message("FIt-SNE R wrapper loading.")
message("FIt-SNE root directory was set to ",  FAST_TSNE_SCRIPT_DIR)

# Compute FIt-SNE of a dataset
#       dims - dimensionality of the embedding. Default 2.
#       perplexity - perplexity is used to determine the
#           bandwidth of the Gaussian kernel in the input
#           space.  Default 30.
#       theta - Set to 0 for exact.  If non-zero, then will use either
#           Barnes Hut or FIt-SNE based on nbody_algo.  If Barnes Hut, then
#           this determins the accuracy of BH approximation.
#           Default 0.5.
#       max_iter - Number of iterations of t-SNE to run.
#           Default 750.
#       fft_not_bh - if theta is nonzero, this determines whether to
#            use FIt-SNE or Barnes Hut approximation. Default is FIt-SNE.
#            set to be True for FIt-SNE
#       ann_not_vptree - use vp-trees (as in bhtsne) or approximate nearest neighbors (default).
#            set to be True for approximate nearest neighbors
#       exaggeration_factor - coefficient for early exaggeration
#           (>1). Default 12.
#       no_momentum_during_exag - Set to 0 to use momentum
#           and other optimization tricks. 1 to do plain,vanilla
#           gradient descent (useful for testing large exaggeration
#           coefficients)
#       stop_early_exag_iter - When to switch off early exaggeration.
#           Default 250.
#        start_late_exag_iter - When to start late exaggeration. 'auto' means
#        that late exaggeration is not used, unless late_exag_coeff>0. In that
#        case, start_late_exag_iter is set to stop_early_exag_iter. Otherwise,
#        set to equal the iteration at which late exaggeration should begin.
#          Default 'auto'
#       late_exag_coeff - Late exaggeration coefficient.
#          Set to -1 to not use late exaggeration.
#           Default -1
#       learning_rate - Set to desired learning rate or 'auto', which
#       sets learning rate to N/exaggeration_factor where N is the sample size, or to 200 if
#       N/exaggeration_factor < 200.
#           Default 'auto'
#       max_step_norm -  Maximum distance that a point is allowed to move on
#       one iteration. Larger steps are clipped to this value. This prevents
#       possible instabilities during gradient descent.  Set to -1 to switch it
#       off. Default: 5
#       nterms - If using FIt-SNE, this is the number of
#                      interpolation points per sub-interval
#       intervals_per_integer - See min_num_intervals              
#       min_num_intervals - Let maxloc = ceil(max(max(X)))
#           and minloc = floor(min(min(X))). i.e. the points are in
#           a [minloc]^no_dims by [maxloc]^no_dims interval/square.
#           The number of intervals in each dimension is either
#           min_num_intervals or ceil((maxloc -
#           minloc)/intervals_per_integer), whichever is
#           larger. min_num_intervals must be an integer >0,
#           and intervals_per_integer must be >0. Default:
#           min_num_intervals=50, intervals_per_integer =
#           1
#
#       sigma - Fixed sigma value to use when perplexity==-1
#            Default -1 (None)
#       K - Number of nearest neighbours to get when using fixed sigma
#            Default -30 (None)
#
#       initialization -  'pca', 'random', or N x no_dims array to intialize the solution.
#            Default: 'pca'
#
#       load_affinities - 
#            If 1, input similarities are loaded from a file and not computed
#            If 2, input similarities are saved into a file.
#            If 0, affinities are neither saved nor loaded
#
#       perplexity_list - if perplexity==0 then perplexity combination will
#            be used with values taken from perplexity_list. Default: NULL
#       df - Degree of freedom of t-distribution, must be greater than 0.
#       Values smaller than 1 correspond to heavier tails, which can often 
#       resolve substructure in the embedding. See Kobak et al. (2019) for
#       details. Default is 1.0
#
fftRtsne <- function(X, 
		     dims = 2, perplexity = 73, theta = 0.5,
		     max_iter = 1000,
		     fft_not_bh = TRUE,
		     ann_not_vptree = TRUE,
		     stop_early_exag_iter = 250,
		     exaggeration_factor = 12.0, no_momentum_during_exag = FALSE,
		     start_late_exag_iter = -1, late_exag_coeff = 1.0,
         mom_switch_iter = 250, momentum = 0.5, final_momentum = 0.8, learning_rate = 'auto',
		     n_trees = 50, search_k = -1, rand_seed = -1,
		     nterms = 3, intervals_per_integer = 1, min_num_intervals = 50, 
		     K = -1, sigma = -30, initialization = 'pca',max_step_norm = 5,
		     data_path = NULL, result_path = NULL,
		     load_affinities = NULL,
		     fast_tsne_path = NULL, nthreads = 0, perplexity_list = NULL, 
         get_costs = FALSE, df = 1.0) {
  
  version_number <- '1.2.1'

	if (is.null(fast_tsne_path)) {
		if (.Platform$OS.type == "unix") {
			fast_tsne_path <- file.path(FAST_TSNE_SCRIPT_DIR, "bin", "fast_tsne")
		} else {
			fast_tsne_path <- file.path(FAST_TSNE_SCRIPT_DIR, "bin", "FItSNE.exe")
		}
	}

	if (is.null(data_path)) {
		data_path <- tempfile(pattern = 'fftRtsne_data_', fileext = '.dat')
	}
	if (is.null(result_path)) {
		result_path <- tempfile(pattern = 'fftRtsne_result_', fileext = '.dat')
	}
	if (is.null(fast_tsne_path)) {
		fast_tsne_path <- system2('which', 'fast_tsne', stdout = TRUE)
	}
	fast_tsne_path <- normalizePath(fast_tsne_path)
	if (!file_test('-x', fast_tsne_path)) {
		stop(fast_tsne_path, " does not exist or is not executable; check your fast_tsne_path parameter")
	}

	is.wholenumber <- function(x, tol = .Machine$double.eps^0.5)  abs(x - round(x)) < tol

	if (!is.numeric(theta) || (theta < 0.0) || (theta > 1.0) ) { stop("Incorrect theta.")}
	if (nrow(X) - 1 < 3 * perplexity) { stop("Perplexity is too large.")}
	if (!is.matrix(X)) { stop("Input X is not a matrix")}
	if (!(max_iter > 0)) { stop("Incorrect number of iterations.")}
	if (!is.wholenumber(stop_early_exag_iter) || stop_early_exag_iter < 0) { stop("stop_early_exag_iter should be a positive integer")}
	if (!is.numeric(exaggeration_factor)) { stop("exaggeration_factor should be numeric")}
	if (!is.numeric(df)) { stop("df should be numeric")}
	if (!is.wholenumber(dims) || dims <= 0) { stop("Incorrect dimensionality.")}
	if (search_k == -1) {
    if (perplexity > 0) {
      search_k <- n_trees * perplexity * 3
    } else if (perplexity == 0) {
      search_k <- n_trees * max(perplexity_list) * 3
    } else { 
      search_k <- n_trees * K
    }
  }

        if (is.character(learning_rate) && learning_rate =='auto') {
            learning_rate = max(200, nrow(X)/exaggeration_factor)
        }
        if (is.character(start_late_exag_iter) && start_late_exag_iter =='auto') {
            if (late_exag_coeff > 0) {
                start_late_exag_iter = stop_early_exag_iter
            }else {
                start_late_exag_iter = -1
            }
        }

        if (is.character(initialization) && initialization =='pca') {
            if (rand_seed != -1)  {
                set.seed(rand_seed)
            }
            if ("rsvd" %in% utils::installed.packages()) {
                message('Using rsvd() to compute the top PCs for initialization.')
                X_c <- scale(X, center=T, scale=F)
                rsvd_out <- rsvd::rsvd(X_c, k=dims)
                X_top_pcs <- rsvd_out$u %*% diag(rsvd_out$d, nrow=dims)
            }else if("irlba" %in% utils::installed.packages()) { 
                message('Using irlba() to compute the top PCs for initialization.')
                X_colmeans <- colMeans(X)
                irlba_out <- irlba::irlba(X,nv=dims, center=X_colmeans)
                X_top_pcs <- irlba_out$u %*% diag(irlba_out$d, nrow=dims)
            }else{
                stop("By default, FIt-SNE initializes the embedding with the
                     top PCs. We use either rsvd or irlba for fast computation.
                     To use this functionality, please install the rsvd package
                     with install.packages('rsvd') or the irlba package with
                     install.packages('ilrba').  Otherwise, set initialization
                     to NULL for random initialization, or any N by dims matrix
                     for custom initialization.")
            }
                initialization <- 0.0001*(X_top_pcs/sd(X_top_pcs[,1])) 

        }else if (is.character(initialization) && initialization == 'random'){
            message('Random initialization')
            initialization = NULL
        }

	if (fft_not_bh) {
	  nbody_algo <- 2
	} else {
	  nbody_algo <- 1
	}

	if (is.null(load_affinities)) {
		load_affinities <- 0
	} else {
		if (load_affinities == 'load') {
			load_affinities <- 1
		} else if (load_affinities == 'save') {
			load_affinities <- 2
		} else {
			load_affinities <- 0
		}
	}
	
	if (ann_not_vptree) {
	  knn_algo <- 1
	} else {
	  knn_algo <- 2
	}
	tX <- as.numeric(t(X))

	f <- file(data_path, "wb")
	n <- nrow(X)
	D <- ncol(X)
	writeBin(as.integer(n), f, size = 4)
	writeBin(as.integer(D), f, size = 4)
	writeBin(as.numeric(theta), f, size = 8) #theta
	writeBin(as.numeric(perplexity), f, size = 8)

  if (perplexity == 0) {
  	writeBin(as.integer(length(perplexity_list)), f, size = 4)
    writeBin(perplexity_list, f) 
  }

	writeBin(as.integer(dims), f, size = 4)
	writeBin(as.integer(max_iter), f, size = 4)
	writeBin(as.integer(stop_early_exag_iter), f, size = 4)
	writeBin(as.integer(mom_switch_iter), f, size = 4)
	writeBin(as.numeric(momentum), f, size = 8)
	writeBin(as.numeric(final_momentum), f, size = 8)
	writeBin(as.numeric(learning_rate), f, size = 8)
	writeBin(as.numeric(max_step_norm), f, size = 8)
	writeBin(as.integer(K), f, size = 4) #K
	writeBin(as.numeric(sigma), f, size = 8) #sigma
	writeBin(as.integer(nbody_algo), f, size = 4)  #not barnes hut
	writeBin(as.integer(knn_algo), f, size = 4) 
	writeBin(as.numeric(exaggeration_factor), f, size = 8) #compexag
	writeBin(as.integer(no_momentum_during_exag), f, size = 4) 
	writeBin(as.integer(n_trees), f, size = 4) 
	writeBin(as.integer(search_k), f, size = 4) 
	writeBin(as.integer(start_late_exag_iter), f, size = 4) 
	writeBin(as.numeric(late_exag_coeff), f, size = 8) 
	
	writeBin(as.integer(nterms), f, size = 4) 
	writeBin(as.numeric(intervals_per_integer), f, size = 8) 
	writeBin(as.integer(min_num_intervals), f, size = 4) 
	writeBin(tX, f) 
	writeBin(as.integer(rand_seed), f, size = 4) 
  writeBin(as.numeric(df), f, size = 8)
	writeBin(as.integer(load_affinities), f, size = 4) 
	if (!is.null(initialization) ) { writeBin( c(t(initialization)), f) }		
	close(f) 

	flag <- system2(command = fast_tsne_path, 
	                args = c(version_number, data_path, result_path, nthreads))
	if (flag != 0) {
		stop('tsne call failed')
	}
	f <- file(result_path, "rb")
	n <- readBin(f, integer(), n = 1, size = 4)
	d <- readBin(f, integer(), n = 1, size = 4)
	Y <- readBin(f, numeric(), n = n * d)
  Y <- t(matrix(Y, nrow = d))
  if (get_costs) {
    readBin(f, integer(), n = 1, size = 4)
    costs <- readBin(f, numeric(), n = max_iter, size = 8)
    Yout <- list(Y = Y, costs = costs)
  } else {
    Yout <- Y
  }
  close(f)
  file.remove(data_path)
  file.remove(result_path)
  Yout
}
